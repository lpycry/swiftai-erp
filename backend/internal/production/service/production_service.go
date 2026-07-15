package service

import (
	"context"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	prodmodels "github.com/swiftai-erp/backend/internal/production/models"
	prorepo "github.com/swiftai-erp/backend/internal/production/repository"
)

type ProductionService struct {
	db      *pgxpool.Pool
	bomRepo *prorepo.BOMRepo
	wcRepo  *prorepo.WorkCenterRepo
	rtRepo  *prorepo.RoutingTemplateRepo
	opRepo  *prorepo.TemplateOperationRepo
	poRepo  *prorepo.ProductionOrderRepo
}

func NewProductionService(db *pgxpool.Pool, bomRepo *prorepo.BOMRepo,
	wcRepo *prorepo.WorkCenterRepo, rtRepo *prorepo.RoutingTemplateRepo,
	opRepo *prorepo.TemplateOperationRepo,
	poRepo *prorepo.ProductionOrderRepo) *ProductionService {
	return &ProductionService{
		db: db, bomRepo: bomRepo, wcRepo: wcRepo,
		rtRepo: rtRepo, opRepo: opRepo, poRepo: poRepo,
	}
}

// ── BOM ──
func (s *ProductionService) CreateBOM(ctx context.Context, tenantID, userID uuid.UUID, req *prodmodels.CreateBOMRequest) (*prodmodels.BOMHeader, error) {
	return s.bomRepo.Create(ctx, tenantID, userID, req)
}
func (s *ProductionService) GetBOM(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.BOMHeader, error) {
	return s.bomRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListBOMs(ctx context.Context, tenantID uuid.UUID, materialID *uuid.UUID, status string) ([]*prodmodels.BOMHeader, error) {
	return s.bomRepo.List(ctx, tenantID, materialID, status)
}
func (s *ProductionService) UpdateBOM(ctx context.Context, id, tenantID, userID uuid.UUID, req *prodmodels.UpdateBOMRequest) error {
	return s.bomRepo.Update(ctx, id, tenantID, req, userID)
}
func (s *ProductionService) DeleteBOM(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	return s.bomRepo.Delete(ctx, id, tenantID, userID)
}
func (s *ProductionService) AddBOMItem(ctx context.Context, bomID, tenantID uuid.UUID, req *prodmodels.CreateBOMItemRequest) (*prodmodels.BOMItem, error) {
	req.BOMID = bomID
	return s.bomRepo.AddItem(ctx, tenantID, req)
}
func (s *ProductionService) UpdateBOMItem(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateBOMItemRequest) error {
	return s.bomRepo.UpdateItem(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteBOMItem(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.bomRepo.DeleteItem(ctx, id, tenantID)
}
func (s *ProductionService) ExplodeBOM(ctx context.Context, tenantID uuid.UUID, req *prodmodels.ExplodeRequest) ([]*prodmodels.ExplosionItem, error) {
	return s.bomRepo.Explode(ctx, tenantID, req)
}

// ── Master Production Schedule (MPS) ──
func (s *ProductionService) RunMPS(ctx context.Context, tenantID, userID uuid.UUID, req *prodmodels.MPSRunRequest) (*prodmodels.MPSRunResult, error) {
	mode := strings.ToUpper(strings.TrimSpace(req.PlanningMode))
	if mode == "" {
		mode = "NETCH"
	}
	if mode != "NETCH" && mode != "NEUPL" {
		return nil, fmt.Errorf("invalid planning_mode %s", req.PlanningMode)
	}
	fenceDays := req.PlanningTimeFenceDays
	if fenceDays <= 0 {
		fenceDays = 5
	}

	runID := uuid.New()
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	result := &prodmodels.MPSRunResult{
		RunID:    runID,
		Status:   "COMPLETED",
		Progress: []prodmodels.MPSProgressStep{{Percent: 5, Message: "MPS run initialized"}},
		Summary:  map[string]interface{}{},
	}

	_, err := s.db.Exec(ctx, `INSERT INTO mps_runs
		(id, tenant_id, site_id, planning_mode, planning_time_fence_enabled, planning_time_fence_days,
		 status, progress_percent, progress_message, started_by, started_at)
		VALUES ($1,$2,$3,$4,$5,$6,'RUNNING',5,'MPS run initialized',$7,NOW())`,
		runID, tenantID, req.SiteID, mode, req.PlanningTimeFenceEnabled, fenceDays, userID)
	if err != nil {
		return nil, fmt.Errorf("create mps run: %w", err)
	}

	if mode == "NEUPL" {
		if _, err := s.db.Exec(ctx, `DELETE FROM mps_planned_orders
			WHERE tenant_id = $1 AND COALESCE(site_id, '00000000-0000-0000-0000-000000000000'::uuid) =
				COALESCE($2, '00000000-0000-0000-0000-000000000000'::uuid)
				AND is_firmed = false`, tenantID, req.SiteID); err != nil {
			return nil, fmt.Errorf("clear mps planned orders: %w", err)
		}
	}

	products, err := s.loadMPSProducts(ctx, tenantID, req.SiteID)
	if err != nil {
		return nil, err
	}
	if len(products) == 0 {
		result.Progress = append(result.Progress, prodmodels.MPSProgressStep{Percent: 100, Message: "No MPS materials found"})
		result.Summary["mps_materials"] = 0
		_ = s.finishMPSRun(ctx, runID, "COMPLETED", 100, "No MPS materials found")
		return result, nil
	}

	for i, product := range products {
		percent := 10 + int(math.Round(float64(i)/float64(len(products))*70))
		msg := fmt.Sprintf("Calculating %s...", product.SKU)
		result.Progress = append(result.Progress, prodmodels.MPSProgressStep{Percent: percent, Message: msg})

		planDate := today
		pirQty, err := s.sumPIR(ctx, tenantID, product.ID, req.SiteID, today)
		if err != nil {
			return nil, err
		}
		soQty, soDate, err := s.sumOpenSalesDemand(ctx, tenantID, product.ID, req.SiteID, today)
		if err != nil {
			return nil, err
		}
		if !soDate.IsZero() {
			planDate = soDate
		}
		grossDemand := math.Max(pirQty, soQty)
		if grossDemand <= 0 {
			continue
		}

		onHand, err := s.sumStock(ctx, tenantID, product.ID, req.SiteID)
		if err != nil {
			return nil, err
		}
		openSupply, err := s.sumOpenWOSupply(ctx, tenantID, product.ID, req.SiteID)
		if err != nil {
			return nil, err
		}
		firmed, err := s.sumFirmedMPS(ctx, tenantID, product.ID, req.SiteID)
		if err != nil {
			return nil, err
		}
		netReq := grossDemand - onHand - openSupply - firmed
		if netReq <= 0 {
			continue
		}

		dueDate := planDate
		if req.PlanningTimeFenceEnabled && dueDate.Before(today.AddDate(0, 0, fenceDays)) {
			dueDate = today.AddDate(0, 0, fenceDays)
			result.Exceptions = append(result.Exceptions, s.persistMPSException(ctx, tenantID, runID, product.ID, product.SKU, "20", "WARNING",
				fmt.Sprintf("%s shortage falls inside planning time fence; planned outside fence", product.SKU)))
		}
		if dueDate.Before(today) {
			result.Exceptions = append(result.Exceptions, s.persistMPSException(ctx, tenantID, runID, product.ID, product.SKU, "10", "WARNING",
				fmt.Sprintf("%s requirement date is in the past; planner review required", product.SKU)))
			dueDate = today
		}

		po, err := s.persistMPSPlannedOrder(ctx, tenantID, runID, req.SiteID, product, netReq, dueDate)
		if err != nil {
			return nil, err
		}
		result.PlannedOrders = append(result.PlannedOrders, po)

		deps, err := s.createMPSDependentDemands(ctx, tenantID, runID, req.SiteID, product, netReq, dueDate)
		if err != nil {
			return nil, err
		}
		result.DependentDemands = append(result.DependentDemands, deps...)
	}

	result.Progress = append(result.Progress, prodmodels.MPSProgressStep{Percent: 100, Message: "MPS run completed"})
	result.Summary["mps_materials"] = len(products)
	result.Summary["planned_orders"] = len(result.PlannedOrders)
	result.Summary["dependent_demands"] = len(result.DependentDemands)
	result.Summary["exceptions"] = len(result.Exceptions)
	if req.RunMRPAfterMPS {
		existingDeps, err := s.createDependentDemandsForExistingMPS(ctx, tenantID, runID, req.SiteID)
		if err != nil {
			result.Exceptions = append(result.Exceptions, s.persistMPSException(ctx, tenantID, runID, uuid.Nil, "", "BOM_ABORTED", "ERROR", err.Error()))
			_ = s.finishMPSRun(ctx, runID, "ABORTED", 100, "MPS completed but BOM breakdown aborted")
			return nil, err
		}
		result.DependentDemands = append(result.DependentDemands, existingDeps...)
		result.Summary["dependent_demands"] = len(result.DependentDemands)
		mrpResult, err := s.RunMRPFromMPS(ctx, tenantID, userID, runID, req.SiteID)
		if err != nil {
			result.Exceptions = append(result.Exceptions, s.persistMPSException(ctx, tenantID, runID, uuid.Nil, "", "MRP_ABORTED", "ERROR", err.Error()))
			_ = s.finishMPSRun(ctx, runID, "ABORTED", 100, "MPS completed but MRP aborted")
			return nil, err
		}
		result.MRPResult = mrpResult
		result.Summary["mrp_planned_purchase_requisitions"] = len(mrpResult.PlannedPurchaseRequisitions)
		result.Summary["mrp_exceptions"] = len(mrpResult.Exceptions)
		result.Progress = append(result.Progress, prodmodels.MPSProgressStep{Percent: 100, Message: "MPS and MRP completed"})
	}
	_ = s.finishMPSRun(ctx, runID, "COMPLETED", 100, "MPS run completed")
	return result, nil
}

// ── Work Center ──
type mrpDemand struct {
	ProductID uuid.UUID
	SKU       string
	Name      string
	DemandQty float64
	DueDate   time.Time
}

type mrpInfoRecord struct {
	ID           uuid.UUID
	VendorID     uuid.UUID
	VendorCode   string
	VendorName   string
	PurchaseUOM  string
	Currency     string
	Price        float64
	MinOrderQty  float64
	RoundingQty  float64
	LeadTimeDays int
}

func (s *ProductionService) RunMRPFromMPS(ctx context.Context, tenantID, userID, mpsRunID uuid.UUID, siteID *uuid.UUID) (*prodmodels.MRPRunResult, error) {
	if err := s.ensureMRPTables(ctx); err != nil {
		return nil, err
	}
	runID := uuid.New()
	result := &prodmodels.MRPRunResult{RunID: runID, MPSRunID: mpsRunID, Summary: map[string]interface{}{}}
	result.Summary["planning_parameters"] = prodmodels.MRPPlanningParameters{
		CreatePurchaseReq: 1,
		Scheduling:        2,
		CreateDepReq:      1,
		Description:       "Create PR immediately, lead-time scheduling, always break down BOM",
	}
	if _, err := s.db.Exec(ctx, `INSERT INTO mrp_runs
		(id, tenant_id, mps_run_id, site_id, status, started_by, started_at)
		VALUES ($1,$2,$3,$4,'RUNNING',$5,NOW())`, runID, tenantID, mpsRunID, siteID, userID); err != nil {
		return nil, fmt.Errorf("create mrp run: %w", err)
	}
	_, _ = s.db.Exec(ctx, `DELETE FROM mrp_planned_purchase_requisitions
		WHERE tenant_id = $1
			AND status = 'PLANNED'
			AND ($2::uuid IS NULL OR site_id = $2 OR site_id IS NULL)`, tenantID, siteID)

	orgID, err := s.resolvePlanningOrgID(ctx, tenantID, siteID)
	if err != nil {
		return nil, err
	}
	demands, err := s.loadMRPDemandsFromMPS(ctx, tenantID, mpsRunID, siteID)
	if err != nil {
		_ = s.abortMRPRun(ctx, runID, tenantID, "LOAD_DEMANDS", err)
		return nil, err
	}
	for _, demand := range demands {
		stock, err := s.sumStock(ctx, tenantID, demand.ProductID, siteID)
		if err != nil {
			_ = s.abortMRPRun(ctx, runID, tenantID, "STOCK", err)
			return nil, err
		}
		openPO, err := s.sumOpenPOSupply(ctx, tenantID, demand.ProductID, siteID)
		if err != nil {
			_ = s.abortMRPRun(ctx, runID, tenantID, "SUPPLY", err)
			return nil, err
		}
		netReq := demand.DemandQty - stock - openPO
		if netReq <= 0 {
			continue
		}
		info, err := s.lookupPreferredInfoRecord(ctx, orgID, demand.ProductID, siteID)
		if err != nil {
			if err == pgx.ErrNoRows {
				result.Exceptions = append(result.Exceptions, s.persistMRPException(ctx, tenantID, runID, demand.ProductID, demand.SKU, "NO_INFO_RECORD", "WARNING",
					fmt.Sprintf("%s has MRP purchase demand %.4f but no active purchasing info record", demand.SKU, netReq)))
				continue
			}
			return nil, err
		}
		orderQty := applyLotSizing(netReq, info.MinOrderQty, info.RoundingQty)
		releaseDate := demand.DueDate.AddDate(0, 0, -info.LeadTimeDays)
		pr, err := s.persistMRPPlannedPurchaseReq(ctx, tenantID, runID, mpsRunID, siteID, demand, info, netReq, orderQty, releaseDate)
		if err != nil {
			_ = s.abortMRPRun(ctx, runID, tenantID, "PR_CREATE", err)
			return nil, err
		}
		result.PlannedPurchaseRequisitions = append(result.PlannedPurchaseRequisitions, pr)
	}
	result.Summary["mrp_demands"] = len(demands)
	result.Summary["planned_purchase_requisitions"] = len(result.PlannedPurchaseRequisitions)
	result.Summary["exceptions"] = len(result.Exceptions)
	_, _ = s.db.Exec(ctx, `UPDATE mrp_runs
		SET status='COMPLETED', planned_purchase_requisitions=$2, exceptions=$3, completed_at=NOW()
		WHERE id=$1`, runID, len(result.PlannedPurchaseRequisitions), len(result.Exceptions))
	return result, nil
}

func (s *ProductionService) ensureMRPTables(ctx context.Context) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS mrp_runs (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			mps_run_id UUID REFERENCES mps_runs(id) ON DELETE SET NULL,
			site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
			status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
			planned_purchase_requisitions INTEGER NOT NULL DEFAULT 0,
			exceptions INTEGER NOT NULL DEFAULT 0,
			started_by UUID,
			started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			completed_at TIMESTAMPTZ
		)`,
		`CREATE INDEX IF NOT EXISTS idx_mrp_runs_tenant_started
			ON mrp_runs(tenant_id, started_at DESC)`,
		`CREATE TABLE IF NOT EXISTS mrp_planned_purchase_requisitions (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			run_id UUID REFERENCES mrp_runs(id) ON DELETE CASCADE,
			mps_run_id UUID REFERENCES mps_runs(id) ON DELETE SET NULL,
			site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
			product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
			vendor_id UUID REFERENCES vendors(id) ON DELETE SET NULL,
			info_record_id UUID REFERENCES purchasing_info_records(id) ON DELETE SET NULL,
			demand_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			net_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			order_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			due_date DATE NOT NULL,
			release_date DATE NOT NULL,
			purchase_uom VARCHAR(20) NOT NULL DEFAULT 'EA',
			currency VARCHAR(10) NOT NULL DEFAULT 'USD',
			price NUMERIC(18,4) NOT NULL DEFAULT 0,
			status VARCHAR(20) NOT NULL DEFAULT 'PLANNED',
			source VARCHAR(30) NOT NULL DEFAULT 'MRP',
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_mrp_planned_pr_tenant_product
			ON mrp_planned_purchase_requisitions(tenant_id, product_id, due_date)`,
		`CREATE TABLE IF NOT EXISTS mrp_exception_messages (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			run_id UUID REFERENCES mrp_runs(id) ON DELETE CASCADE,
			product_id UUID REFERENCES products(id) ON DELETE CASCADE,
			code VARCHAR(20) NOT NULL,
			severity VARCHAR(20) NOT NULL DEFAULT 'WARNING',
			message TEXT NOT NULL,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_mrp_exception_messages_run
			ON mrp_exception_messages(run_id)`,
	}
	for _, stmt := range stmts {
		if _, err := s.db.Exec(ctx, stmt); err != nil {
			return fmt.Errorf("ensure MRP table: %w", err)
		}
	}
	return nil
}

func (s *ProductionService) abortMRPRun(ctx context.Context, runID, tenantID uuid.UUID, code string, runErr error) error {
	_, _ = s.db.Exec(ctx, `INSERT INTO mrp_exception_messages(id, tenant_id, run_id, code, severity, message)
		VALUES ($1,$2,$3,$4,'ERROR',$5)`, uuid.New(), tenantID, runID, code, runErr.Error())
	_, err := s.db.Exec(ctx, `UPDATE mrp_runs
		SET status='ABORTED', exceptions = exceptions + 1, completed_at=NOW()
		WHERE id=$1`, runID)
	return err
}

func (s *ProductionService) resolvePlanningOrgID(ctx context.Context, tenantID uuid.UUID, siteID *uuid.UUID) (uuid.UUID, error) {
	var orgID uuid.UUID
	if siteID != nil {
		if err := s.db.QueryRow(ctx, `SELECT organization_id FROM sites WHERE id = $1`, *siteID).Scan(&orgID); err == nil {
			return orgID, nil
		}
	}
	if err := s.db.QueryRow(ctx, `SELECT id FROM organizations WHERE tenant_id = $1 ORDER BY created_at LIMIT 1`, tenantID).Scan(&orgID); err != nil {
		return uuid.Nil, fmt.Errorf("resolve planning organization: %w", err)
	}
	return orgID, nil
}

func (s *ProductionService) loadMRPDemandsFromMPS(ctx context.Context, tenantID, mpsRunID uuid.UUID, siteID *uuid.UUID) ([]mrpDemand, error) {
	byProduct := map[uuid.UUID]*mrpDemand{}
	addDemand := func(d mrpDemand) {
		if d.DemandQty <= 0 {
			return
		}
		existing := byProduct[d.ProductID]
		if existing == nil {
			cp := d
			byProduct[d.ProductID] = &cp
			return
		}
		existing.DemandQty += d.DemandQty
		if existing.DueDate.IsZero() || (!d.DueDate.IsZero() && d.DueDate.Before(existing.DueDate)) {
			existing.DueDate = d.DueDate
		}
	}

	rows, err := s.db.Query(ctx, `SELECT d.component_id, COALESCE(p.sku,''), COALESCE(p.name,''), SUM(d.demand_qty), MIN(d.requirement_date)
		FROM mps_dependent_demands d
		JOIN products p ON p.id = d.component_id
		WHERE d.tenant_id = $1 AND d.run_id = $2
			AND d.component_mrp_type = 'MRP'
		GROUP BY d.component_id, p.sku, p.name
		ORDER BY p.sku`, tenantID, mpsRunID)
	if err != nil {
		return nil, fmt.Errorf("load mrp demands: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var d mrpDemand
		if err := rows.Scan(&d.ProductID, &d.SKU, &d.Name, &d.DemandQty, &d.DueDate); err != nil {
			return nil, err
		}
		addDemand(d)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	siteFilter := ""
	args := []interface{}{tenantID}
	if siteID != nil {
		siteFilter = " AND (po.site_id = $2 OR po.site_id IS NULL)"
		args = append(args, *siteID)
	}
	rows, err = s.db.Query(ctx, `SELECT pom.component_id, COALESCE(p.sku,''), COALESCE(p.name,''),
			SUM(GREATEST(pom.required_qty - COALESCE(pom.issue_qty,0),0))::float8,
			MIN(COALESCE(po.planned_start_date, po.planned_end_date, CURRENT_DATE))::date
		FROM production_order_materials pom
		JOIN production_orders po ON po.id = pom.production_order_id
		JOIN products p ON p.id = pom.component_id
		LEFT JOIN product_plant_data ppd
			ON ppd.tenant_id = p.tenant_id AND ppd.product_id = p.id AND ppd.site_id = po.site_id
		WHERE po.tenant_id = $1
			AND po.status IN ('RELEASED','IN_PROCESS','PARTIALLY_PRODUCED')
			AND GREATEST(pom.required_qty - COALESCE(pom.issue_qty,0),0) > 0
			AND CASE
				WHEN COALESCE(p.mrp_type,'') IN ('MRP','NO','MPS') THEN p.mrp_type
				ELSE COALESCE(ppd.mrp_type, p.mrp_type, 'MPS')
			END = 'MRP'`+siteFilter+`
		GROUP BY pom.component_id, p.sku, p.name
		ORDER BY p.sku`, args...)
	if err != nil {
		return nil, fmt.Errorf("load production reservations for MRP: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var d mrpDemand
		if err := rows.Scan(&d.ProductID, &d.SKU, &d.Name, &d.DemandQty, &d.DueDate); err != nil {
			return nil, err
		}
		addDemand(d)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	demands := make([]mrpDemand, 0, len(byProduct))
	for _, d := range byProduct {
		demands = append(demands, *d)
	}
	sort.SliceStable(demands, func(i, j int) bool {
		return demands[i].SKU < demands[j].SKU
	})
	return demands, nil
}

func (s *ProductionService) sumOpenPOSupply(ctx context.Context, tenantID, productID uuid.UUID, siteID *uuid.UUID) (float64, error) {
	var qty float64
	err := s.db.QueryRow(ctx, `SELECT COALESCE(SUM(poi.quantity - COALESCE(poi.received_quantity,0)),0)
		FROM purchase_order_items poi
		JOIN purchase_orders po ON po.id = poi.po_id
		JOIN organizations o ON o.id = po.org_id
		WHERE o.tenant_id = $1 AND poi.item_id = $2
			AND ($3::uuid IS NULL OR poi.site_id = $3 OR poi.site_id IS NULL)
			AND po.status NOT IN ('CANCELLED')
			AND (poi.quantity - COALESCE(poi.received_quantity,0)) > 0`, tenantID, productID, siteID).Scan(&qty)
	return qty, err
}

func (s *ProductionService) lookupPreferredInfoRecord(ctx context.Context, orgID, productID uuid.UUID, siteID *uuid.UUID) (mrpInfoRecord, error) {
	var info mrpInfoRecord
	err := s.db.QueryRow(ctx, `SELECT pir.id, pir.vendor_id, COALESCE(v.vendor_code,''), COALESCE(v.name,''),
			pir.purchase_uom, pir.currency, pir.price, pir.min_order_qty, pir.rounding_qty, pir.lead_time_days
		FROM purchasing_info_records pir
		JOIN vendors v ON v.id = pir.vendor_id
		WHERE pir.org_id = $1 AND pir.product_id = $2
			AND pir.is_active = true AND pir.is_blocked = false
			AND pir.valid_from <= CURRENT_DATE
			AND (pir.valid_to IS NULL OR pir.valid_to >= CURRENT_DATE)
			AND ($3::uuid IS NULL OR pir.site_id = $3 OR pir.site_id IS NULL)
		ORDER BY pir.is_preferred DESC, CASE WHEN pir.site_id = $3 THEN 0 ELSE 1 END, pir.price ASC, v.vendor_code
		LIMIT 1`, orgID, productID, siteID).Scan(&info.ID, &info.VendorID, &info.VendorCode, &info.VendorName, &info.PurchaseUOM, &info.Currency, &info.Price, &info.MinOrderQty, &info.RoundingQty, &info.LeadTimeDays)
	return info, err
}

func applyLotSizing(netReq, minOrderQty, roundingQty float64) float64 {
	qty := netReq
	if minOrderQty > 0 && qty < minOrderQty {
		qty = minOrderQty
	}
	if roundingQty > 0 {
		qty = math.Ceil(qty/roundingQty) * roundingQty
	}
	return qty
}

func (s *ProductionService) persistMRPPlannedPurchaseReq(ctx context.Context, tenantID, runID, mpsRunID uuid.UUID, siteID *uuid.UUID, demand mrpDemand, info mrpInfoRecord, netQty, orderQty float64, releaseDate time.Time) (prodmodels.MRPPlannedPurchaseReq, error) {
	id := uuid.New()
	_, err := s.db.Exec(ctx, `INSERT INTO mrp_planned_purchase_requisitions
		(id, tenant_id, run_id, mps_run_id, site_id, product_id, vendor_id, info_record_id,
		 demand_qty, net_qty, order_qty, due_date, release_date, purchase_uom, currency, price, status, source)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,'PLANNED','MRP')`,
		id, tenantID, runID, mpsRunID, siteID, demand.ProductID, info.VendorID, info.ID,
		demand.DemandQty, netQty, orderQty, demand.DueDate, releaseDate, info.PurchaseUOM, info.Currency, info.Price)
	if err != nil {
		return prodmodels.MRPPlannedPurchaseReq{}, fmt.Errorf("insert mrp planned purchase requisition: %w", err)
	}
	return prodmodels.MRPPlannedPurchaseReq{
		ID: id, ProductID: demand.ProductID, ProductSKU: demand.SKU, ProductName: demand.Name,
		SiteID: siteID, VendorID: info.VendorID, VendorCode: info.VendorCode, VendorName: info.VendorName,
		InfoRecordID: info.ID, DemandQty: demand.DemandQty, NetQty: netQty, OrderQty: orderQty,
		DueDate: demand.DueDate.Format("2006-01-02"), ReleaseDate: releaseDate.Format("2006-01-02"),
		PurchaseUOM: info.PurchaseUOM, Currency: info.Currency, Price: info.Price, Status: "PLANNED",
	}, nil
}

func (s *ProductionService) persistMRPException(ctx context.Context, tenantID, runID, productID uuid.UUID, sku, code, severity, message string) prodmodels.MRPExceptionMessage {
	id := uuid.New()
	_, _ = s.db.Exec(ctx, `INSERT INTO mrp_exception_messages(id, tenant_id, run_id, product_id, code, severity, message)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`, id, tenantID, runID, productID, code, severity, message)
	return prodmodels.MRPExceptionMessage{ID: id, ProductID: productID, ProductSKU: sku, Code: code, Severity: severity, Message: message}
}

func (s *ProductionService) CreateWorkCenter(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateWorkCenterRequest) (*prodmodels.WorkCenter, error) {
	return s.wcRepo.Create(ctx, tenantID, req)
}
func (s *ProductionService) GetWorkCenter(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.WorkCenter, error) {
	return s.wcRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListWorkCenters(ctx context.Context, tenantID uuid.UUID) ([]*prodmodels.WorkCenter, error) {
	return s.wcRepo.List(ctx, tenantID)
}
func (s *ProductionService) UpdateWorkCenter(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateWorkCenterRequest) error {
	return s.wcRepo.Update(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteWorkCenter(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.wcRepo.Delete(ctx, id, tenantID)
}

// ── Routing Template ──
func (s *ProductionService) CreateRoutingTemplate(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateRoutingTemplateRequest) (*prodmodels.RoutingTemplate, error) {
	return s.rtRepo.Create(ctx, tenantID, req)
}
func (s *ProductionService) GetRoutingTemplate(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.RoutingTemplate, error) {
	return s.rtRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListRoutingTemplates(ctx context.Context, tenantID uuid.UUID) ([]*prodmodels.RoutingTemplate, error) {
	return s.rtRepo.List(ctx, tenantID)
}
func (s *ProductionService) UpdateRoutingTemplate(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateRoutingTemplateRequest) error {
	return s.rtRepo.Update(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteRoutingTemplate(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.rtRepo.Delete(ctx, id, tenantID)
}

// ── Template Operation ──
func (s *ProductionService) CreateTemplateOperation(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateTemplateOperationRequest) (*prodmodels.TemplateOperation, error) {
	return s.opRepo.Create(ctx, tenantID, req)
}
func (s *ProductionService) UpdateTemplateOperation(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateTemplateOperationRequest) error {
	return s.opRepo.Update(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteTemplateOperation(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.opRepo.Delete(ctx, id, tenantID)
}

// ── Production Order ──
func (s *ProductionService) CreateProductionOrder(ctx context.Context, tenantID, userID uuid.UUID, req *prodmodels.CreateProductionOrderRequest) (*prodmodels.ProductionOrder, error) {
	po, err := s.poRepo.Create(ctx, tenantID, userID, req)
	if err != nil {
		return nil, err
	}
	// Auto-sync materials if BOM attached
	if req.BOMID != nil {
		_ = s.poRepo.SyncPOMaterials(ctx, po.ID, tenantID)
		po, _ = s.poRepo.GetByID(ctx, po.ID, tenantID)
	}
	return po, nil
}
func (s *ProductionService) GetProductionOrder(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.ProductionOrder, error) {
	return s.poRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListProductionOrders(ctx context.Context, tenantID uuid.UUID, materialID *uuid.UUID, status string) ([]*prodmodels.ProductionOrder, error) {
	return s.poRepo.List(ctx, tenantID, materialID, status)
}
func (s *ProductionService) UpdateProductionOrder(ctx context.Context, id, tenantID, userID uuid.UUID, req *prodmodels.UpdateProductionOrderRequest) error {
	if err := s.poRepo.Update(ctx, id, tenantID, req, userID); err != nil {
		return err
	}
	// Re-sync materials whenever bom_id or order_qty changes
	if req.BOMID != nil || req.OrderQty != nil {
		_ = s.poRepo.SyncPOMaterials(ctx, id, tenantID)
	}
	return nil
}
func (s *ProductionService) DeleteProductionOrder(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	return s.poRepo.Delete(ctx, id, tenantID, userID)
}
func (s *ProductionService) SyncPOMaterials(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.poRepo.SyncPOMaterials(ctx, id, tenantID)
}
func (s *ProductionService) UpdatePOMaterialIssueQty(ctx context.Context, materialID, tenantID uuid.UUID, issueQty float64) error {
	return s.poRepo.UpdatePOMaterialIssueQty(ctx, materialID, tenantID, issueQty)
}
func (s *ProductionService) CreateTimeConfirmation(ctx context.Context, orderID, tenantID, userID uuid.UUID, req *prodmodels.CreateTimeConfirmationRequest) (*prodmodels.ProductionOrderTimeConfirmation, error) {
	return s.poRepo.CreateTimeConfirmation(ctx, orderID, tenantID, userID, req)
}
func (s *ProductionService) ListTimeConfirmations(ctx context.Context, orderID, tenantID uuid.UUID) ([]*prodmodels.ProductionOrderTimeConfirmation, error) {
	return s.poRepo.ListTimeConfirmations(ctx, orderID, tenantID)
}

// GetPORoutingInfo returns routing template info for a production order via its BOM
func (s *ProductionService) GetPORoutingInfo(ctx context.Context, poID, tenantID uuid.UUID) (*prodmodels.RoutingTemplate, error) {
	po, err := s.poRepo.GetByID(ctx, poID, tenantID)
	if err != nil {
		return nil, err
	}
	// BOM is optional; if no BOM, return nil
	if po.BOMID == nil {
		return nil, nil
	}
	// Get BOM header
	bom, err := s.bomRepo.GetByID(ctx, *po.BOMID, tenantID)
	if err != nil {
		return nil, err
	}
	// If BOM has no routing template, return nil
	if bom.RoutingTemplateID == nil {
		return nil, nil
	}
	// Get routing template
	return s.rtRepo.GetByID(ctx, *bom.RoutingTemplateID, tenantID)
}

var _ = time.Now

type mpsProduct struct {
	ID   uuid.UUID
	SKU  string
	Name string
}

func (s *ProductionService) loadMPSProducts(ctx context.Context, tenantID uuid.UUID, siteID *uuid.UUID) ([]mpsProduct, error) {
	rows, err := s.db.Query(ctx, `SELECT p.id, p.sku, p.name
		FROM products p
		LEFT JOIN product_plant_data ppd
			ON ppd.tenant_id = p.tenant_id AND ppd.product_id = p.id AND ppd.site_id = $2
		WHERE p.tenant_id = $1
			AND CASE
				WHEN COALESCE(p.mrp_type,'') IN ('MRP','NO') THEN p.mrp_type
				ELSE COALESCE(ppd.mrp_type, p.mrp_type, 'MPS')
			END = 'MPS'
			AND COALESCE(ppd.is_active, p.is_active, true) = true
			AND ($2::uuid IS NULL OR ppd.site_id = $2)
		ORDER BY p.sku`, tenantID, siteID)
	if err != nil {
		return nil, fmt.Errorf("load mps products: %w", err)
	}
	defer rows.Close()
	var list []mpsProduct
	for rows.Next() {
		var p mpsProduct
		if err := rows.Scan(&p.ID, &p.SKU, &p.Name); err != nil {
			return nil, err
		}
		list = append(list, p)
	}
	return list, nil
}

func (s *ProductionService) sumPIR(ctx context.Context, tenantID, productID uuid.UUID, siteID *uuid.UUID, fromDate time.Time) (float64, error) {
	var qty float64
	err := s.db.QueryRow(ctx, `SELECT COALESCE(SUM(quantity - consumed_qty),0)
		FROM product_independent_requirements
		WHERE tenant_id = $1 AND product_id = $2 AND status = 'ACTIVE'
			AND requirement_date >= $3
			AND ($4::uuid IS NULL OR site_id = $4)`,
		tenantID, productID, fromDate, siteID).Scan(&qty)
	return qty, err
}

func (s *ProductionService) sumOpenSalesDemand(ctx context.Context, tenantID, productID uuid.UUID, siteID *uuid.UUID, today time.Time) (float64, time.Time, error) {
	var qty float64
	var firstDate *time.Time
	err := s.db.QueryRow(ctx, `SELECT COALESCE(SUM(soi.quantity),0),
			MIN(COALESCE(soi.delivery_date, so.delivery_date, so.requested_date, CURRENT_DATE))
		FROM sales_order_items soi
		JOIN sales_orders so ON so.id = soi.so_id
		WHERE so.tenant_id = $1 AND soi.product_id = $2
			AND (
				$4::uuid IS NULL
				OR soi.delivering_site_id = $4
				OR (
					soi.delivering_site_id IS NULL
					AND EXISTS (
						SELECT 1
						FROM product_plant_data ppd
						WHERE ppd.tenant_id = so.tenant_id
							AND ppd.product_id = soi.product_id
							AND ppd.site_id = $4
							AND ppd.is_active = true
					)
				)
			)
			AND so.status NOT IN ('CANCELLED','COMPLETED','INVOICED')
			AND COALESCE(soi.delivery_date, so.delivery_date, so.requested_date, CURRENT_DATE) >= $3`,
		tenantID, productID, today, siteID).Scan(&qty, &firstDate)
	if err != nil {
		return 0, time.Time{}, err
	}
	if firstDate == nil {
		return qty, time.Time{}, nil
	}
	return qty, *firstDate, nil
}

func (s *ProductionService) sumStock(ctx context.Context, tenantID, productID uuid.UUID, siteID *uuid.UUID) (float64, error) {
	var qty float64
	err := s.db.QueryRow(ctx, `SELECT COALESCE(SUM(si.quantity_on_hand - si.quantity_reserved),0)
		FROM stock_items si
		JOIN warehouses w ON w.id = si.warehouse_id
		WHERE si.tenant_id = $1 AND si.product_id = $2
			AND ($3::uuid IS NULL OR w.site_id = $3)`, tenantID, productID, siteID).Scan(&qty)
	if qty < 0 {
		qty = 0
	}
	return qty, err
}

func (s *ProductionService) sumOpenWOSupply(ctx context.Context, tenantID, productID uuid.UUID, siteID *uuid.UUID) (float64, error) {
	var qty float64
	err := s.db.QueryRow(ctx, `SELECT COALESCE(SUM(order_qty - COALESCE(completed_qty,0)),0)
		FROM production_orders
		WHERE tenant_id = $1 AND material_id = $2
			AND ($3::uuid IS NULL OR site_id = $3)
			AND status IN ('RELEASED','IN_PROCESS','PARTIALLY_PRODUCED')
			AND (order_qty - COALESCE(completed_qty,0)) > 0`, tenantID, productID, siteID).Scan(&qty)
	return qty, err
}

func (s *ProductionService) sumFirmedMPS(ctx context.Context, tenantID, productID uuid.UUID, siteID *uuid.UUID) (float64, error) {
	var qty float64
	err := s.db.QueryRow(ctx, `SELECT COALESCE(SUM(planned_qty),0)
		FROM mps_planned_orders
		WHERE tenant_id = $1 AND product_id = $2 AND is_firmed = true
			AND ($3::uuid IS NULL OR site_id = $3)`, tenantID, productID, siteID).Scan(&qty)
	return qty, err
}

func (s *ProductionService) persistMPSPlannedOrder(ctx context.Context, tenantID, runID uuid.UUID, siteID *uuid.UUID, product mpsProduct, qty float64, dueDate time.Time) (prodmodels.MPSPlannedOrder, error) {
	id := uuid.New()
	_, err := s.db.Exec(ctx, `INSERT INTO mps_planned_orders
		(id, tenant_id, run_id, site_id, product_id, planned_qty, due_date, source)
		VALUES ($1,$2,$3,$4,$5,$6,$7,'MPS')`,
		id, tenantID, runID, siteID, product.ID, qty, dueDate)
	if err != nil {
		return prodmodels.MPSPlannedOrder{}, fmt.Errorf("insert mps planned order: %w", err)
	}
	return prodmodels.MPSPlannedOrder{ID: id, SiteID: siteID, ProductID: product.ID, ProductSKU: product.SKU, ProductName: product.Name, PlannedQty: qty, DueDate: dueDate.Format("2006-01-02")}, nil
}

func (s *ProductionService) createMPSDependentDemands(ctx context.Context, tenantID, runID uuid.UUID, siteID *uuid.UUID, parent mpsProduct, parentQty float64, requirementDate time.Time) ([]prodmodels.MPSDependentDemand, error) {
	visited := map[uuid.UUID]bool{}
	return s.explodeMPSDependentDemands(ctx, tenantID, runID, siteID, parent, parentQty, requirementDate, visited)
}

func (s *ProductionService) createDependentDemandsForExistingMPS(ctx context.Context, tenantID, runID uuid.UUID, siteID *uuid.UUID) ([]prodmodels.MPSDependentDemand, error) {
	rows, err := s.db.Query(ctx, `SELECT mpo.product_id, p.sku, p.name, mpo.planned_qty, mpo.due_date
		FROM mps_planned_orders mpo
		JOIN products p ON p.id = mpo.product_id
		WHERE mpo.tenant_id = $1
			AND ($2::uuid IS NULL OR mpo.site_id = $2)
			AND mpo.converted_production_order_id IS NULL
			AND (mpo.run_id IS DISTINCT FROM $3)
		ORDER BY mpo.due_date, p.sku`, tenantID, siteID, runID)
	if err != nil {
		return nil, fmt.Errorf("load existing mps planned orders for MRP: %w", err)
	}
	defer rows.Close()
	var out []prodmodels.MPSDependentDemand
	for rows.Next() {
		var product mpsProduct
		var qty float64
		var dueDate time.Time
		if err := rows.Scan(&product.ID, &product.SKU, &product.Name, &qty, &dueDate); err != nil {
			return nil, err
		}
		deps, err := s.createMPSDependentDemands(ctx, tenantID, runID, siteID, product, qty, dueDate)
		if err != nil {
			return nil, err
		}
		out = append(out, deps...)
	}
	return out, nil
}

func (s *ProductionService) explodeMPSDependentDemands(ctx context.Context, tenantID, runID uuid.UUID, siteID *uuid.UUID, parent mpsProduct, parentQty float64, requirementDate time.Time, visited map[uuid.UUID]bool) ([]prodmodels.MPSDependentDemand, error) {
	if visited[parent.ID] {
		return nil, fmt.Errorf("BOM loop detected while exploding %s", parent.SKU)
	}
	visited[parent.ID] = true
	defer delete(visited, parent.ID)

	bomID, baseQty, err := s.findActiveBOM(ctx, tenantID, parent.ID)
	if err != nil || bomID == uuid.Nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `SELECT bi.component_id, p.sku, p.name,
			CASE
				WHEN COALESCE(p.mrp_type,'') IN ('MRP','NO') THEN p.mrp_type
				ELSE COALESCE(ppd.mrp_type, p.mrp_type, 'MPS')
			END,
			COALESCE(ppd.procurement_type, p.procurement_type, 'purchase'),
			bi.quantity, bi.scrap_factor, bi.is_phantom_item
		FROM bom_items bi
		JOIN products p ON p.id = bi.component_id
		LEFT JOIN product_plant_data ppd
			ON ppd.tenant_id = p.tenant_id AND ppd.product_id = p.id AND ppd.site_id = $2
		WHERE bi.bom_id = $1
			AND bi.valid_from <= NOW()
			AND bi.valid_to >= NOW()
		ORDER BY bi.item_position`, bomID, siteID)
	if err != nil {
		return nil, fmt.Errorf("load mps bom items: %w", err)
	}
	defer rows.Close()
	var out []prodmodels.MPSDependentDemand
	for rows.Next() {
		var componentID uuid.UUID
		var sku, name, mrpType, procurementType string
		var qty, scrap float64
		var phantom bool
		if err := rows.Scan(&componentID, &sku, &name, &mrpType, &procurementType, &qty, &scrap, &phantom); err != nil {
			return nil, err
		}
		mrpType = strings.ToUpper(strings.TrimSpace(mrpType))
		if mrpType == "" {
			mrpType = "MPS"
		}
		procurementType = strings.ToLower(strings.TrimSpace(procurementType))
		if mrpType == "NO" {
			continue
		}
		demandQty := parentQty * (qty / baseQty) * (1 + scrap)
		action := "DEPENDENT_DEMAND_ONLY"
		if phantom {
			action = "PHANTOM_BREAKDOWN"
		} else if mrpType == "MPS" {
			action = "MPS_RECURSION_CANDIDATE"
		} else if mrpType == "MRP" {
			action = "MRP_PURCHASE_REQ"
		}
		id := uuid.New()
		if _, err := s.db.Exec(ctx, `INSERT INTO mps_dependent_demands
			(id, tenant_id, run_id, parent_product_id, component_id, component_mrp_type, demand_qty, requirement_date, action)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
			id, tenantID, runID, parent.ID, componentID, mrpType, demandQty, requirementDate, action); err != nil {
			return nil, fmt.Errorf("insert mps dependent demand: %w", err)
		}
		out = append(out, prodmodels.MPSDependentDemand{
			ID: id, ParentProductID: parent.ID, ParentSKU: parent.SKU, ComponentID: componentID,
			ComponentSKU: sku, ComponentName: name, ComponentMRPType: mrpType,
			DemandQty: demandQty, RequirementDate: requirementDate.Format("2006-01-02"), Action: action,
		})
		if phantom || mrpType == "MPS" {
			child := mpsProduct{ID: componentID, SKU: sku, Name: name}
			childDeps, err := s.explodeMPSDependentDemands(ctx, tenantID, runID, siteID, child, demandQty, requirementDate, visited)
			if err != nil {
				return nil, err
			}
			out = append(out, childDeps...)
		}
	}
	return out, nil
}

func (s *ProductionService) findActiveBOM(ctx context.Context, tenantID, productID uuid.UUID) (uuid.UUID, float64, error) {
	var bomID uuid.UUID
	var baseQty float64
	err := s.db.QueryRow(ctx, `SELECT bom_id, base_qty FROM bom_headers
		WHERE tenant_id = $1 AND material_id = $2
			AND is_active = true
			AND status NOT IN ('OBSOLETE','CANCELLED','DELETED')
			AND valid_from <= NOW()
			AND valid_to >= NOW()
		ORDER BY CASE WHEN status = 'ACTIVE' THEN 0 ELSE 1 END, valid_from DESC
		LIMIT 1`, tenantID, productID).Scan(&bomID, &baseQty)
	if err != nil {
		return uuid.Nil, 1, nil
	}
	if baseQty <= 0 {
		baseQty = 1
	}
	return bomID, baseQty, nil
}

func (s *ProductionService) persistMPSException(ctx context.Context, tenantID, runID, productID uuid.UUID, sku, code, severity, message string) prodmodels.MPSExceptionMessage {
	id := uuid.New()
	var productArg interface{}
	if productID != uuid.Nil {
		productArg = productID
	}
	_, _ = s.db.Exec(ctx, `INSERT INTO mps_exception_messages(id, tenant_id, run_id, product_id, code, severity, message)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`, id, tenantID, runID, productArg, code, severity, message)
	return prodmodels.MPSExceptionMessage{ID: id, ProductID: productID, ProductSKU: sku, Code: code, Severity: severity, Message: message}
}

func (s *ProductionService) finishMPSRun(ctx context.Context, runID uuid.UUID, status string, percent int, message string) error {
	_, err := s.db.Exec(ctx, `UPDATE mps_runs
		SET status=$2, progress_percent=$3, progress_message=$4, completed_at=NOW()
		WHERE id=$1`, runID, status, percent, message)
	return err
}

func (s *ProductionService) ListMPSPlannedOrders(ctx context.Context, tenantID uuid.UUID) ([]prodmodels.MPSPlannedOrder, error) {
	rows, err := s.db.Query(ctx, `SELECT mpo.id, mpo.site_id, COALESCE(site.site_code,''), COALESCE(site.site_name,''),
			mpo.product_id, p.sku, p.name, mpo.planned_qty,
			mpo.due_date, mpo.is_firmed, mpo.converted_production_order_id, COALESCE(po.order_number,''),
			COALESCE(mpo.exception_code,''), COALESCE(mpo.exception_message,'')
		FROM mps_planned_orders mpo
		JOIN products p ON p.id = mpo.product_id
		LEFT JOIN sites site ON site.id = mpo.site_id
		LEFT JOIN production_orders po ON po.id = mpo.converted_production_order_id
		WHERE mpo.tenant_id = $1
		ORDER BY mpo.due_date DESC, p.sku`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []prodmodels.MPSPlannedOrder
	for rows.Next() {
		var o prodmodels.MPSPlannedOrder
		var due time.Time
		var siteID pgtype.UUID
		var convertedID pgtype.UUID
		if err := rows.Scan(&o.ID, &siteID, &o.SiteCode, &o.SiteName, &o.ProductID, &o.ProductSKU, &o.ProductName, &o.PlannedQty, &due, &o.IsFirmed, &convertedID, &o.ConvertedOrderNumber, &o.ExceptionCode, &o.ExceptionMessage); err != nil {
			return nil, err
		}
		o.SiteID = uuidPtrFromPgtype(siteID)
		o.ConvertedProductionOrderID = uuidPtrFromPgtype(convertedID)
		o.DueDate = due.Format("2006-01-02")
		list = append(list, o)
	}
	return list, nil
}

func (s *ProductionService) ListMPSDependentDemands(ctx context.Context, tenantID uuid.UUID) ([]prodmodels.MPSDependentDemand, error) {
	rows, err := s.db.Query(ctx, `SELECT d.id, d.parent_product_id, COALESCE(parent.sku,''),
			d.component_id, COALESCE(component.sku,''), COALESCE(component.name,''), d.component_mrp_type,
			d.demand_qty, d.requirement_date, d.action
		FROM mps_dependent_demands d
		JOIN products parent ON parent.id = d.parent_product_id
		JOIN products component ON component.id = d.component_id
		WHERE d.tenant_id = $1
			AND d.run_id = (
				SELECT id FROM mps_runs
				WHERE tenant_id = $1
				ORDER BY started_at DESC
				LIMIT 1
			)
		ORDER BY d.requirement_date DESC, parent.sku, component.sku`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []prodmodels.MPSDependentDemand
	for rows.Next() {
		var d prodmodels.MPSDependentDemand
		var requirementDate time.Time
		if err := rows.Scan(&d.ID, &d.ParentProductID, &d.ParentSKU, &d.ComponentID, &d.ComponentSKU, &d.ComponentName, &d.ComponentMRPType, &d.DemandQty, &requirementDate, &d.Action); err != nil {
			return nil, err
		}
		d.RequirementDate = requirementDate.Format("2006-01-02")
		list = append(list, d)
	}
	return list, nil
}

func (s *ProductionService) ListMPSExceptions(ctx context.Context, tenantID uuid.UUID) ([]prodmodels.MPSExceptionMessage, error) {
	rows, err := s.db.Query(ctx, `SELECT e.id, e.product_id, COALESCE(p.sku,''), e.code, e.severity, e.message
		FROM mps_exception_messages e
		LEFT JOIN products p ON p.id = e.product_id
		WHERE e.tenant_id = $1
			AND e.run_id = (
				SELECT id FROM mps_runs
				WHERE tenant_id = $1
				ORDER BY started_at DESC
				LIMIT 1
			)
		ORDER BY e.created_at DESC, e.severity, e.code`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []prodmodels.MPSExceptionMessage
	for rows.Next() {
		var e prodmodels.MPSExceptionMessage
		var productID pgtype.UUID
		if err := rows.Scan(&e.ID, &productID, &e.ProductSKU, &e.Code, &e.Severity, &e.Message); err != nil {
			return nil, err
		}
		if id := uuidPtrFromPgtype(productID); id != nil {
			e.ProductID = *id
		}
		list = append(list, e)
	}
	return list, nil
}

func (s *ProductionService) ListMRPPlannedPurchaseRequisitions(ctx context.Context, tenantID uuid.UUID) ([]prodmodels.MRPPlannedPurchaseReq, error) {
	if err := s.ensureMRPTables(ctx); err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `SELECT pr.id, pr.product_id, COALESCE(p.sku,''), COALESCE(p.name,''),
			pr.site_id, COALESCE(st.site_code,''), COALESCE(st.site_name,''), pr.vendor_id,
			COALESCE(v.vendor_code,''), COALESCE(v.name,''), pr.info_record_id,
			CASE WHEN pir.id IS NULL THEN '' ELSE CONCAT(COALESCE(v.vendor_code,''), ' / ', COALESCE(p.sku,''), ' / ', COALESCE(pir.purchase_uom,''), ' / ', COALESCE(pir.currency,''), ' ', COALESCE(pir.price,0)) END,
			pr.demand_qty, pr.net_qty, pr.order_qty, pr.due_date, pr.release_date, pr.purchase_uom,
			pr.currency, pr.price, pr.status
		FROM mrp_planned_purchase_requisitions pr
		JOIN products p ON p.id = pr.product_id
		LEFT JOIN sites st ON st.id = pr.site_id
		LEFT JOIN vendors v ON v.id = pr.vendor_id
		LEFT JOIN purchasing_info_records pir ON pir.id = pr.info_record_id
		WHERE pr.tenant_id = $1
			AND pr.run_id = (
				SELECT id FROM mrp_runs
				WHERE tenant_id = $1
				ORDER BY started_at DESC
				LIMIT 1
			)
		ORDER BY pr.due_date DESC, p.sku`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []prodmodels.MRPPlannedPurchaseReq
	for rows.Next() {
		var pr prodmodels.MRPPlannedPurchaseReq
		var siteID, vendorID, infoID pgtype.UUID
		var dueDate, releaseDate time.Time
		if err := rows.Scan(&pr.ID, &pr.ProductID, &pr.ProductSKU, &pr.ProductName, &siteID, &pr.SiteCode, &pr.SiteName, &vendorID, &pr.VendorCode, &pr.VendorName, &infoID, &pr.InfoRecord, &pr.DemandQty, &pr.NetQty, &pr.OrderQty, &dueDate, &releaseDate, &pr.PurchaseUOM, &pr.Currency, &pr.Price, &pr.Status); err != nil {
			return nil, err
		}
		pr.SiteID = uuidPtrFromPgtype(siteID)
		if id := uuidPtrFromPgtype(vendorID); id != nil {
			pr.VendorID = *id
		}
		if id := uuidPtrFromPgtype(infoID); id != nil {
			pr.InfoRecordID = *id
		}
		pr.DueDate = dueDate.Format("2006-01-02")
		pr.ReleaseDate = releaseDate.Format("2006-01-02")
		list = append(list, pr)
	}
	return list, nil
}

func (s *ProductionService) ListMRPExceptions(ctx context.Context, tenantID uuid.UUID) ([]prodmodels.MRPExceptionMessage, error) {
	if err := s.ensureMRPTables(ctx); err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `SELECT e.id, e.product_id, COALESCE(p.sku,''), e.code, e.severity, e.message
		FROM mrp_exception_messages e
		LEFT JOIN products p ON p.id = e.product_id
		WHERE e.tenant_id = $1
			AND e.run_id = (
				SELECT id FROM mrp_runs
				WHERE tenant_id = $1
				ORDER BY started_at DESC
				LIMIT 1
			)
		ORDER BY e.created_at DESC, e.severity, e.code`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []prodmodels.MRPExceptionMessage
	for rows.Next() {
		var e prodmodels.MRPExceptionMessage
		var productID pgtype.UUID
		if err := rows.Scan(&e.ID, &productID, &e.ProductSKU, &e.Code, &e.Severity, &e.Message); err != nil {
			return nil, err
		}
		if id := uuidPtrFromPgtype(productID); id != nil {
			e.ProductID = *id
		}
		list = append(list, e)
	}
	return list, nil
}

func (s *ProductionService) GetMaterialRequirementsList(ctx context.Context, tenantID, productID uuid.UUID, siteID *uuid.UUID) (*prodmodels.MaterialRequirementsList, error) {
	var out prodmodels.MaterialRequirementsList
	var siteArg interface{}
	if siteID != nil {
		siteArg = *siteID
	}

	var sitePg pgtype.UUID
	err := s.db.QueryRow(ctx, `SELECT p.id, p.sku, p.name, p.material_type, p.mrp_type, p.unit_of_measure,
			$3::uuid, COALESCE(st.site_code,''), COALESCE(st.site_name,'')
		FROM products p
		LEFT JOIN sites st ON st.id = $3::uuid
		WHERE p.tenant_id=$1 AND p.id=$2`, tenantID, productID, siteArg).
		Scan(&out.ProductID, &out.ProductSKU, &out.ProductName, &out.MaterialType, &out.MRPType, &out.BaseUOM, &sitePg, &out.SiteCode, &out.SiteName)
	if err != nil {
		return nil, fmt.Errorf("load material: %w", err)
	}
	out.SiteID = uuidPtrFromPgtype(sitePg)
	out.AsOf = time.Now()

	stockQuery := `SELECT COALESCE(SUM(si.quantity_on_hand),0)::float8,
			COALESCE(SUM(si.quantity_on_hand - si.quantity_reserved),0)::float8
		FROM stock_items si
		LEFT JOIN warehouses w ON w.id = si.warehouse_id
		WHERE si.tenant_id=$1 AND si.product_id=$2`
	args := []interface{}{tenantID, productID}
	if siteID != nil {
		stockQuery += ` AND w.site_id=$3`
		args = append(args, *siteID)
	}
	if err := s.db.QueryRow(ctx, stockQuery, args...).Scan(&out.StockQty, &out.AvailableQty); err != nil {
		return nil, fmt.Errorf("load stock: %w", err)
	}
	if siteID != nil {
		_ = s.db.QueryRow(ctx, `SELECT COALESCE(safety_stock, 0)::float8
			FROM product_plant_data
			WHERE tenant_id=$1 AND product_id=$2 AND site_id=$3
			LIMIT 1`, tenantID, productID, *siteID).Scan(&out.SafetyStock)
	} else {
		_ = s.db.QueryRow(ctx, `SELECT COALESCE(MAX(safety_stock), 0)::float8
			FROM product_plant_data
			WHERE tenant_id=$1 AND product_id=$2`, tenantID, productID).Scan(&out.SafetyStock)
	}

	type mrpElement struct {
		date    time.Time
		element prodmodels.MaterialRequirementsElement
	}
	var elements []mrpElement
	stockDate := time.Now()
	elements = append(elements, mrpElement{date: stockDate, element: prodmodels.MaterialRequirementsElement{
		Date:        stockDate.Format("2006-01-02"),
		MRPElement:  "Stock",
		ElementData: "Available stock",
		ReceiptQty:  out.AvailableQty,
		SourceType:  "STOCK",
		Status:      "UNRESTRICTED",
	}})

	addRows := func(rows pgx.Rows, receipt bool, element string) error {
		defer rows.Close()
		for rows.Next() {
			var id uuid.UUID
			var d time.Time
			var ref, status string
			var qty float64
			if err := rows.Scan(&id, &d, &ref, &qty, &status); err != nil {
				return err
			}
			item := prodmodels.MaterialRequirementsElement{
				Date:        d.Format("2006-01-02"),
				MRPElement:  element,
				ElementData: ref,
				SourceID:    id.String(),
				SourceType:  element,
				Status:      status,
			}
			if receipt {
				item.ReceiptQty = qty
			} else {
				item.RequirementQty = qty
			}
			elements = append(elements, mrpElement{date: d, element: item})
		}
		return rows.Err()
	}

	siteFilter := ""
	queryArgs := []interface{}{tenantID, productID}
	if siteID != nil {
		siteFilter = " AND soi.delivering_site_id=$3"
		queryArgs = append(queryArgs, *siteID)
	}
	rows, err := s.db.Query(ctx, `SELECT soi.id, COALESCE(soi.confirmed_delivery_date, soi.delivery_date, so.delivery_date, CURRENT_DATE)::date,
			CONCAT(so.so_number, '/', soi.line_no), GREATEST(soi.quantity - COALESCE((SELECT SUM(dni.delivery_qty) FROM sales_delivery_note_items dni JOIN sales_delivery_notes dn ON dn.id=dni.delivery_id WHERE dni.so_item_id=soi.id AND dn.status='PGI_POSTED'),0),0)::float8,
			so.status
		FROM sales_order_items soi
		JOIN sales_orders so ON so.id=soi.so_id
		WHERE so.tenant_id=$1 AND soi.product_id=$2 AND so.status IN ('CONFIRMED','PARTIALLY_DELIVERED')`+siteFilter+`
		ORDER BY 2`, queryArgs...)
	if err != nil {
		return nil, fmt.Errorf("load sales requirements: %w", err)
	}
	if err := addRows(rows, false, "SO"); err != nil {
		return nil, fmt.Errorf("scan sales requirements: %w", err)
	}

	siteFilter = ""
	queryArgs = []interface{}{tenantID, productID}
	if siteID != nil {
		siteFilter = " AND site_id=$3"
		queryArgs = append(queryArgs, *siteID)
	}
	rows, err = s.db.Query(ctx, `SELECT id, COALESCE(planned_end_date, planned_start_date, CURRENT_DATE)::date,
			order_number, GREATEST(order_qty - completed_qty,0)::float8, status
		FROM production_orders
		WHERE tenant_id=$1 AND material_id=$2 AND status IN ('RELEASED','IN_PROCESS','PARTIALLY_PRODUCED')`+siteFilter+`
		ORDER BY 2`, queryArgs...)
	if err != nil {
		return nil, fmt.Errorf("load work order receipts: %w", err)
	}
	if err := addRows(rows, true, "WO"); err != nil {
		return nil, fmt.Errorf("scan work order receipts: %w", err)
	}

	rows, err = s.db.Query(ctx, `SELECT id, due_date, 'MPS Planned Order', planned_qty::float8,
			CASE WHEN converted_production_order_id IS NULL THEN 'PLANNED' ELSE 'CONVERTED' END
		FROM mps_planned_orders
		WHERE tenant_id=$1 AND product_id=$2 AND converted_production_order_id IS NULL`+siteFilter+`
		ORDER BY due_date`, queryArgs...)
	if err != nil {
		return nil, fmt.Errorf("load mps planned orders: %w", err)
	}
	if err := addRows(rows, true, "PlOrd"); err != nil {
		return nil, fmt.Errorf("scan mps planned orders: %w", err)
	}

	rows, err = s.db.Query(ctx, `SELECT id, requirement_date, CONCAT('Parent ', COALESCE((SELECT sku FROM products WHERE id=parent_product_id),'')),
			demand_qty::float8, action
		FROM mps_dependent_demands
		WHERE tenant_id=$1 AND component_id=$2
		ORDER BY requirement_date`, tenantID, productID)
	if err != nil {
		return nil, fmt.Errorf("load dependent demands: %w", err)
	}
	if err := addRows(rows, false, "DepReq"); err != nil {
		return nil, fmt.Errorf("scan dependent demands: %w", err)
	}

	siteFilter = ""
	queryArgs = []interface{}{tenantID, productID}
	if siteID != nil {
		siteFilter = " AND (po.site_id=$3 OR po.site_id IS NULL)"
		queryArgs = append(queryArgs, *siteID)
	}
	rows, err = s.db.Query(ctx, `SELECT pom.id, COALESCE(po.planned_start_date, po.planned_end_date, CURRENT_DATE)::date,
			po.order_number,
			GREATEST(pom.required_qty - COALESCE(pom.issue_qty,0),0)::float8,
			po.status
		FROM production_order_materials pom
		JOIN production_orders po ON po.id = pom.production_order_id
		WHERE po.tenant_id=$1 AND pom.component_id=$2
			AND po.status IN ('RELEASED','IN_PROCESS','PARTIALLY_PRODUCED')
			AND GREATEST(pom.required_qty - COALESCE(pom.issue_qty,0),0) > 0`+siteFilter+`
		ORDER BY 2, po.order_number`, queryArgs...)
	if err != nil {
		return nil, fmt.Errorf("load production reservations: %w", err)
	}
	if err := addRows(rows, false, "Resb"); err != nil {
		return nil, fmt.Errorf("scan production reservations: %w", err)
	}

	siteFilter = ""
	queryArgs = []interface{}{tenantID, productID}
	if siteID != nil {
		siteFilter = " AND site_id=$3"
		queryArgs = append(queryArgs, *siteID)
	}
	rows, err = s.db.Query(ctx, `SELECT id, due_date, 'MRP Planned PR', order_qty::float8, status
		FROM mrp_planned_purchase_requisitions
		WHERE tenant_id=$1 AND product_id=$2 AND status='PLANNED'`+siteFilter+`
		ORDER BY due_date`, queryArgs...)
	if err != nil {
		return nil, fmt.Errorf("load mrp purchase requisitions: %w", err)
	}
	if err := addRows(rows, true, "PurRqs"); err != nil {
		return nil, fmt.Errorf("scan mrp purchase requisitions: %w", err)
	}

	sort.SliceStable(elements, func(i, j int) bool {
		if elements[i].date.Equal(elements[j].date) {
			return elements[i].element.MRPElement < elements[j].element.MRPElement
		}
		return elements[i].date.Before(elements[j].date)
	})
	running := out.AvailableQty
	out.Elements = make([]prodmodels.MaterialRequirementsElement, 0, len(elements))
	for _, row := range elements {
		if row.element.SourceType == "STOCK" {
			row.element.AvailableQty = out.AvailableQty
			running = out.AvailableQty
		} else {
			running += row.element.ReceiptQty
			running -= row.element.RequirementQty
			row.element.AvailableQty = running
		}
		if row.element.AvailableQty < 0 {
			row.element.Exception = "Shortage"
		} else if out.SafetyStock > 0 && row.element.AvailableQty < out.SafetyStock {
			row.element.Exception = "Below safety stock"
		}
		out.Elements = append(out.Elements, row.element)
	}
	return &out, nil
}

func (s *ProductionService) FirmMPSPlannedOrder(ctx context.Context, tenantID, userID, id uuid.UUID, firm bool) error {
	var firmedBy interface{}
	var firmedAt interface{}
	if firm {
		firmedBy = userID
		firmedAt = time.Now()
	}
	_, err := s.db.Exec(ctx, `UPDATE mps_planned_orders
		SET is_firmed=$3, firmed_by=$4, firmed_at=$5, updated_at=NOW()
		WHERE id=$1 AND tenant_id=$2`, id, tenantID, firm, firmedBy, firmedAt)
	return err
}

func (s *ProductionService) ConvertMPSPlannedOrders(ctx context.Context, tenantID, userID uuid.UUID, ids []uuid.UUID, convertAll bool) ([]*prodmodels.ProductionOrder, error) {
	if convertAll {
		rows, err := s.db.Query(ctx, `SELECT id
			FROM mps_planned_orders
			WHERE tenant_id = $1 AND converted_production_order_id IS NULL
			ORDER BY due_date, created_at`, tenantID)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		ids = nil
		for rows.Next() {
			var id uuid.UUID
			if err := rows.Scan(&id); err != nil {
				return nil, err
			}
			ids = append(ids, id)
		}
	}
	var converted []*prodmodels.ProductionOrder
	for _, id := range ids {
		po, err := s.ConvertMPSPlannedOrder(ctx, tenantID, userID, id)
		if err != nil {
			return converted, err
		}
		converted = append(converted, po)
	}
	return converted, nil
}

func (s *ProductionService) ConvertMPSPlannedOrder(ctx context.Context, tenantID, userID, id uuid.UUID) (*prodmodels.ProductionOrder, error) {
	var planned prodmodels.MPSPlannedOrder
	var due time.Time
	var siteID pgtype.UUID
	var convertedID pgtype.UUID
	err := s.db.QueryRow(ctx, `SELECT mpo.id, mpo.site_id, mpo.product_id, p.sku, p.name,
			mpo.planned_qty, mpo.due_date, mpo.converted_production_order_id
		FROM mps_planned_orders mpo
		JOIN products p ON p.id = mpo.product_id
		WHERE mpo.id = $1 AND mpo.tenant_id = $2`, id, tenantID).
		Scan(&planned.ID, &siteID, &planned.ProductID, &planned.ProductSKU, &planned.ProductName,
			&planned.PlannedQty, &due, &convertedID)
	if err != nil {
		return nil, fmt.Errorf("load mps planned order: %w", err)
	}
	planned.SiteID = uuidPtrFromPgtype(siteID)
	planned.ConvertedProductionOrderID = uuidPtrFromPgtype(convertedID)
	if planned.ConvertedProductionOrderID != nil {
		return s.GetProductionOrder(ctx, *planned.ConvertedProductionOrderID, tenantID)
	}

	dueText := due.Format("2006-01-02")
	po, err := s.CreateProductionOrder(ctx, tenantID, userID, &prodmodels.CreateProductionOrderRequest{
		MaterialID:     planned.ProductID,
		SiteID:         planned.SiteID,
		OrderQty:       planned.PlannedQty,
		Priority:       "MEDIUM",
		PlannedEndDate: dueText,
		Notes:          fmt.Sprintf("Converted from MPS planned order %s for %s", planned.ID.String(), planned.ProductSKU),
	})
	if err != nil {
		return nil, err
	}
	if _, err := s.db.Exec(ctx, `UPDATE mps_planned_orders
		SET converted_production_order_id = $3, converted_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND tenant_id = $2 AND converted_production_order_id IS NULL`, id, tenantID, po.ID); err != nil {
		return nil, fmt.Errorf("mark mps planned order converted: %w", err)
	}
	return po, nil
}

func uuidPtrFromPgtype(value pgtype.UUID) *uuid.UUID {
	if !value.Valid {
		return nil
	}
	id := uuid.UUID(value.Bytes)
	return &id
}
