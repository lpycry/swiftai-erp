package service

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
	glsvc "github.com/swiftai-erp/backend/internal/gl/service"
	whrepo "github.com/swiftai-erp/backend/internal/warehouse/repository"

	whmodels "github.com/swiftai-erp/backend/internal/warehouse/models"
)

// WarehouseService coordinates warehouse operations.
type WarehouseService struct {
	db            *pgxpool.Pool
	productRepo   *whrepo.ProductRepo
	warehouseRepo *whrepo.WarehouseRepo
	glSvc         *glsvc.GLService
}

func NewWarehouseService(db *pgxpool.Pool, productRepo *whrepo.ProductRepo, warehouseRepo *whrepo.WarehouseRepo, glSvc ...*glsvc.GLService) *WarehouseService {
	var gs *glsvc.GLService
	if len(glSvc) > 0 {
		gs = glSvc[0]
	}
	return &WarehouseService{
		db:            db,
		productRepo:   productRepo,
		warehouseRepo: warehouseRepo,
		glSvc:         gs,
	}
}

// ── Products (REQ-WM-002) ──

func (s *WarehouseService) CreateProduct(ctx context.Context, tenantID, userID uuid.UUID, req *whmodels.CreateProductRequest) (*whmodels.Product, error) {
	return s.productRepo.Create(ctx, tenantID, userID, req)
}

func (s *WarehouseService) GetProduct(ctx context.Context, id, tenantID uuid.UUID) (*whmodels.Product, error) {
	return s.productRepo.GetByID(ctx, id, tenantID)
}

func (s *WarehouseService) ListProducts(ctx context.Context, tenantID uuid.UUID, search string) ([]*whmodels.Product, error) {
	return s.productRepo.List(ctx, tenantID, search)
}

func (s *WarehouseService) UpdateProduct(ctx context.Context, id, tenantID uuid.UUID, req *whmodels.UpdateProductRequest) error {
	return s.productRepo.Update(ctx, id, tenantID, req)
}

func (s *WarehouseService) DeleteProduct(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.productRepo.Delete(ctx, id, tenantID)
}

// ── Warehouses ──

func (s *WarehouseService) CreateWarehouse(ctx context.Context, tenantID uuid.UUID, req *whmodels.CreateWarehouseRequest) (*whmodels.Warehouse, error) {
	return s.warehouseRepo.Create(ctx, tenantID, req)
}

func (s *WarehouseService) GetWarehouse(ctx context.Context, id, tenantID uuid.UUID) (*whmodels.Warehouse, error) {
	return s.warehouseRepo.GetByID(ctx, id, tenantID)
}

func (s *WarehouseService) ListWarehouses(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.Warehouse, error) {
	return s.warehouseRepo.List(ctx, tenantID)
}

func (s *WarehouseService) UpdateWarehouse(ctx context.Context, id, tenantID uuid.UUID, req *whmodels.UpdateWarehouseRequest) error {
	return s.warehouseRepo.UpdateWarehouse(ctx, id, tenantID, req)
}

func (s *WarehouseService) DeleteWarehouse(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.warehouseRepo.DeleteWarehouse(ctx, id, tenantID)
}

func (s *WarehouseService) ListMovements(ctx context.Context, tenantID uuid.UUID, warehouseID, binID uuid.UUID, dateFrom, dateTo string) ([]*whmodels.StockMovement, error) {
	return s.productRepo.ListMovements(ctx, tenantID, 200, warehouseID, binID, dateFrom, dateTo)
}

func (s *WarehouseService) ListZones(ctx context.Context, warehouseID uuid.UUID) ([]*whmodels.WarehouseZone, error) {
	return s.productRepo.ListZones(ctx, warehouseID)
}

func (s *WarehouseService) CreateZone(ctx context.Context, req *whmodels.CreateZoneRequest) (*whmodels.WarehouseZone, error) {
	return s.productRepo.CreateZone(ctx, req)
}

func (s *WarehouseService) ListBins(ctx context.Context, zoneID uuid.UUID) ([]*whmodels.WarehouseBin, error) {
	return s.productRepo.ListBins(ctx, zoneID)
}

func (s *WarehouseService) ListBinsBySite(ctx context.Context, siteID uuid.UUID) ([]*whmodels.WarehouseBin, error) {
	return s.productRepo.ListBinsBySite(ctx, siteID)
}

func (s *WarehouseService) ListBinsByWarehouse(ctx context.Context, warehouseID uuid.UUID) ([]*whmodels.WarehouseBin, error) {
	return s.productRepo.ListBinsByWarehouse(ctx, warehouseID)
}

func (s *WarehouseService) ListAllBins(ctx context.Context, tenantID uuid.UUID, search string) ([]*whmodels.WarehouseBin, error) {
	return s.productRepo.ListAllBins(ctx, tenantID, search)
}

func (s *WarehouseService) GetBin(ctx context.Context, id uuid.UUID) (*whmodels.WarehouseBin, error) {
	return s.productRepo.GetBin(ctx, id)
}

func (s *WarehouseService) CreateBin(ctx context.Context, req *whmodels.CreateBinRequest) (*whmodels.WarehouseBin, error) {
	return s.productRepo.CreateBin(ctx, req)
}

func (s *WarehouseService) UpdateBin(ctx context.Context, id uuid.UUID, req *whmodels.UpdateBinRequest) error {
	return s.productRepo.UpdateBin(ctx, id, req)
}

func (s *WarehouseService) DeleteBin(ctx context.Context, id uuid.UUID) error {
	return s.productRepo.DeleteBinByID(ctx, id)
}

// ── Stock Movements (REQ-WM-003 / 004 / 005) ──

func (s *WarehouseService) PostMovement(ctx context.Context, tenantID, userID uuid.UUID, req *whmodels.CreateMovementRequest) (*whmodels.StockMovement, error) {
	// Validate transaction type
	switch req.TransactionType {
	case "goods_receipt", "goods_issue", "transfer", "adjustment":
	default:
		return nil, fmt.Errorf("invalid transaction_type: %s", req.TransactionType)
	}

	if req.Quantity <= 0 {
		return nil, fmt.Errorf("quantity must be positive")
	}

	// Begin transaction
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	now := time.Now()
	movementID := uuid.New()

	// Insert stock movement
	_, err = tx.Exec(ctx, `
		INSERT INTO stock_movements (id, tenant_id, transaction_type,
			reference_type, reference_id, reference_no,
			product_id, warehouse_id, bin_id, batch_id,
			quantity, unit_cost, total_cost,
			to_warehouse_id, to_bin_id,
			description, status, created_by, created_at, posted_at, posted_by)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21)
	`, movementID, tenantID, req.TransactionType,
		req.ReferenceType, req.ReferenceID, req.ReferenceNo,
		req.ProductID, req.WarehouseID, req.BinID, req.BatchID,
		req.Quantity, req.UnitCost, req.TotalCost,
		req.ToWarehouseID, req.ToBinID,
		req.Description, "posted", userID, now, now, userID)
	if err != nil {
		return nil, fmt.Errorf("insert movement: %w", err)
	}

	// Update stock_items (upsert)
	switch req.TransactionType {
	case "goods_receipt":
		err = s.upsertStock(ctx, tx, tenantID, req.ProductID, req.WarehouseID, req.BinID, req.BatchID, req.Quantity)
	case "goods_issue":
		err = s.upsertStock(ctx, tx, tenantID, req.ProductID, req.WarehouseID, req.BinID, req.BatchID, -req.Quantity)
	case "adjustment":
		err = s.upsertStock(ctx, tx, tenantID, req.ProductID, req.WarehouseID, req.BinID, req.BatchID, req.Quantity)
	case "transfer":
		// Out from source
		err = s.upsertStock(ctx, tx, tenantID, req.ProductID, req.WarehouseID, req.BinID, req.BatchID, -req.Quantity)
		if err != nil {
			return nil, err
		}
		// In to destination
		err = s.upsertStock(ctx, tx, tenantID, req.ProductID, *req.ToWarehouseID, req.ToBinID, req.BatchID, req.Quantity)
	}
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit movement: %w", err)
	}

	return s.getMovement(ctx, movementID)
}

func (s *WarehouseService) upsertStock(ctx context.Context, tx pgx.Tx, tenantID, productID, warehouseID uuid.UUID, binID, batchID *uuid.UUID, qty float64) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO stock_items (id, tenant_id, product_id, warehouse_id, bin_id, batch_id,
			quantity_on_hand, unit_cost, total_cost, created_at, updated_at)
		VALUES (uuid_generate_v4(), $1, $2, $3, $4, $5,
			GREATEST($6, 0), 0, 0, NOW(), NOW())
		ON CONFLICT (tenant_id, product_id, warehouse_id, bin_id) DO UPDATE SET
			quantity_on_hand = GREATEST(stock_items.quantity_on_hand + $6, 0),
			last_movement_at = NOW(),
			updated_at = NOW()
	`, tenantID, productID, warehouseID, binID, batchID, qty)
	return err
}

func (s *WarehouseService) getMovement(ctx context.Context, id uuid.UUID) (*whmodels.StockMovement, error) {
	m := &whmodels.StockMovement{}
	err := s.db.QueryRow(ctx, `
		SELECT sm.id, sm.tenant_id, sm.transaction_type,
			COALESCE(sm.reference_type,''), sm.reference_id, COALESCE(sm.reference_no,''),
			sm.product_id, COALESCE(p.sku,''), COALESCE(p.name,''),
			sm.warehouse_id, COALESCE(w.name,''),
			sm.bin_id, COALESCE(b.code,''),
			sm.batch_id, COALESCE(bt.batch_no,''),
			sm.quantity, sm.unit_cost, sm.total_cost,
			sm.to_warehouse_id, COALESCE(tw.name,''),
			sm.to_bin_id,
			sm.status, COALESCE(sm.description,''),
			sm.created_by, sm.created_at, sm.posted_at, sm.posted_by
		FROM stock_movements sm
		LEFT JOIN products p ON p.id = sm.product_id
		LEFT JOIN warehouses w ON w.id = sm.warehouse_id
		LEFT JOIN warehouse_bins b ON b.id = sm.bin_id
		LEFT JOIN batches bt ON bt.id = sm.batch_id
		LEFT JOIN warehouses tw ON tw.id = sm.to_warehouse_id
		WHERE sm.id = $1
	`, id).Scan(
		&m.ID, &m.TenantID, &m.TransactionType,
		&m.ReferenceType, &m.ReferenceID, &m.ReferenceNo,
		&m.ProductID, &m.ProductSKU, &m.ProductName,
		&m.WarehouseID, &m.WarehouseName,
		&m.BinID, &m.BinCode,
		&m.BatchID, &m.BatchNo,
		&m.Quantity, &m.UnitCost, &m.TotalCost,
		&m.ToWarehouseID, &m.ToWarehouseName,
		&m.ToBinID,
		&m.Status, &m.Description,
		&m.CreatedBy, &m.CreatedAt, &m.PostedAt, &m.PostedBy,
	)
	if err != nil {
		return nil, fmt.Errorf("get movement: %w", err)
	}
	return m, nil
}

func (s *WarehouseService) ListStock(ctx context.Context, tenantID, productID, warehouseID, binID uuid.UUID, groupBySku bool, dateFrom, dateTo string) ([]*whmodels.StockItem, error) {
	args := []interface{}{tenantID}
	argIdx := 2

	// WHERE clauses
	var wheres []string
	if productID != uuid.Nil {
		wheres = append(wheres, fmt.Sprintf("si.product_id = $%d", argIdx))
		args = append(args, productID)
		argIdx++
	}
	if warehouseID != uuid.Nil {
		wheres = append(wheres, fmt.Sprintf("si.warehouse_id = $%d", argIdx))
		args = append(args, warehouseID)
		argIdx++
	}
	if binID != uuid.Nil {
		wheres = append(wheres, fmt.Sprintf("si.bin_id = $%d", argIdx))
		args = append(args, binID)
		argIdx++
	}
	if dateFrom != "" {
		wheres = append(wheres, fmt.Sprintf("si.last_movement_at >= $%d::timestamptz", argIdx))
		args = append(args, dateFrom)
		argIdx++
	}
	if dateTo != "" {
		wheres = append(wheres, fmt.Sprintf("si.last_movement_at <= $%d::timestamptz", argIdx))
		args = append(args, dateTo)
		argIdx++
	}

	whereClause := ""
	if len(wheres) > 0 {
		whereClause = "WHERE si.tenant_id = $1 AND " + strings.Join(wheres, " AND ")
	} else {
		whereClause = "WHERE si.tenant_id = $1"
	}

	var rows pgx.Rows
	var err error

	if groupBySku {
		// Aggregated by product — each SKU appears once
		groupedQuery := fmt.Sprintf(`
            SELECT p.id, COALESCE(p.sku,''), COALESCE(p.name,''),
                   SUM(si.quantity_on_hand), SUM(si.quantity_reserved), SUM(si.quantity_in_transit),
                   CASE WHEN SUM(si.quantity_on_hand) > 0
                       THEN SUM(si.total_cost) / NULLIF(SUM(si.quantity_on_hand), 0)
                       ELSE 0 END,
                   SUM(si.total_cost),
                   MAX(si.last_movement_at)
            FROM stock_items si
            JOIN products p ON p.id = si.product_id
            %s
            GROUP BY p.id, p.sku, p.name
            ORDER BY p.sku
        `, whereClause)
		rows, err = s.db.Query(ctx, groupedQuery, args...)
		if err != nil {
			return nil, fmt.Errorf("list stock grouped: %w", err)
		}
		defer rows.Close()

		var items []*whmodels.StockItem
		for rows.Next() {
			item := &whmodels.StockItem{}
			if err := rows.Scan(
				&item.ProductID, &item.ProductSKU, &item.ProductName,
				&item.QuantityOnHand, &item.QuantityReserved, &item.QuantityInTransit,
				&item.UnitCost, &item.TotalCost,
				&item.LastMovementAt,
			); err != nil {
				return nil, fmt.Errorf("scan grouped stock: %w", err)
			}
			items = append(items, item)
		}
		return items, nil
	}

	// Detailed (non-grouped) — individual bin-level records
	detailQuery := fmt.Sprintf(`
        SELECT si.id, si.tenant_id, si.product_id, COALESCE(p.sku,''), COALESCE(p.name,''),
               si.warehouse_id, COALESCE(w.name,''),
               si.bin_id, COALESCE(b.code,''),
               si.batch_id, COALESCE(bt.batch_no,''),
               COALESCE(si.lot_no,''),
               si.quantity_on_hand, si.quantity_reserved, si.quantity_in_transit,
               si.unit_cost, si.total_cost,
               si.last_movement_at, si.last_counted_at,
               si.created_at, si.updated_at
        FROM stock_items si
        LEFT JOIN products p ON p.id = si.product_id
        LEFT JOIN warehouses w ON w.id = si.warehouse_id
        LEFT JOIN warehouse_bins b ON b.id = si.bin_id
        LEFT JOIN batches bt ON bt.id = si.batch_id
        %s
        ORDER BY p.sku, w.code, b.code
    `, whereClause)
	rows, err = s.db.Query(ctx, detailQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("list stock detail: %w", err)
	}
	defer rows.Close()

	var items []*whmodels.StockItem
	for rows.Next() {
		item := &whmodels.StockItem{}
		if err := rows.Scan(
			&item.ID, &item.TenantID, &item.ProductID, &item.ProductSKU, &item.ProductName,
			&item.WarehouseID, &item.WarehouseName,
			&item.BinID, &item.BinCode,
			&item.BatchID, &item.BatchNo,
			&item.LotNo,
			&item.QuantityOnHand, &item.QuantityReserved, &item.QuantityInTransit,
			&item.UnitCost, &item.TotalCost,
			&item.LastMovementAt, &item.LastCountedAt,
			&item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan stock: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

// ── Barcodes ──

func (s *WarehouseService) ListBarcodes(ctx context.Context, productID uuid.UUID) ([]*whmodels.ProductBarcode, error) {
	return s.productRepo.ListBarcodes(ctx, productID)
}

func (s *WarehouseService) CreateBarcode(ctx context.Context, productID uuid.UUID, barcode, barcodeType string) (*whmodels.ProductBarcode, error) {
	return s.productRepo.CreateBarcode(ctx, productID, barcode, barcodeType)
}

func (s *WarehouseService) DeleteBarcode(ctx context.Context, id uuid.UUID) error {
	return s.productRepo.DeleteBarcode(ctx, id)
}

// ── Photos ──

func (s *WarehouseService) ListPhotos(ctx context.Context, productID uuid.UUID) ([]*whmodels.ProductPhoto, error) {
	return s.productRepo.ListPhotos(ctx, productID)
}

func (s *WarehouseService) UploadPhoto(ctx context.Context, productID uuid.UUID, fileName, filePath string, fileSize int, mimeType string) (*whmodels.ProductPhoto, error) {
	return s.productRepo.CreatePhoto(ctx, productID, fileName, filePath, fileSize, mimeType)
}

func (s *WarehouseService) DeletePhoto(ctx context.Context, id uuid.UUID) error {
	return s.productRepo.DeletePhoto(ctx, id)
}

// ═══════════════════════════════════════════════════════════════
// Goods Receipt (REQ-IB-005~014)
// ═══════════════════════════════════════════════════════════════

func (s *WarehouseService) CreateGR(ctx context.Context, tenantID, userID uuid.UUID, req *whmodels.CreateGRRequest) (*whmodels.GoodsReceipt, error) {
	return s.warehouseRepo.CreateGR(ctx, tenantID, userID, req)
}

func (s *WarehouseService) ListGRs(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.GoodsReceipt, error) {
	return s.warehouseRepo.ListGRs(ctx, tenantID)
}

func (s *WarehouseService) PostGR(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	return s.warehouseRepo.PostGR(ctx, id, tenantID, userID)
}

// ═══════════════════════════════════════════════════════════════
// Outbound Order (REQ-OB-001~018)
// ═══════════════════════════════════════════════════════════════

func (s *WarehouseService) CreateOutbound(ctx context.Context, tenantID, userID uuid.UUID, req *whmodels.CreateOutboundRequest) (*whmodels.OutboundOrder, error) {
	return s.warehouseRepo.CreateOutbound(ctx, tenantID, userID, req)
}

func (s *WarehouseService) ListOutbound(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.OutboundOrder, error) {
	return s.warehouseRepo.ListOutbound(ctx, tenantID)
}

func (s *WarehouseService) UpdateOutbound(ctx context.Context, id, tenantID uuid.UUID, req *whmodels.CreateOutboundRequest) error {
	return s.warehouseRepo.UpdateOutbound(ctx, id, tenantID, req)
}

func (s *WarehouseService) ShipOutbound(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	if err := s.warehouseRepo.ShipOutbound(ctx, id, tenantID, userID); err != nil {
		return err
	}
	if s.glSvc == nil {
		return nil
	}
	ob, err := s.warehouseRepo.GetOutboundByID(ctx, id, tenantID)
	if err != nil {
		return err
	}
	if ob.GLJEID != nil {
		return nil
	}
	return s.createOutboundJournalEntry(ctx, tenantID, userID, ob)
}

func (s *WarehouseService) ReverseOutbound(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	jeID, err := s.warehouseRepo.ReverseOutbound(ctx, id, tenantID, userID)
	if err != nil {
		return err
	}
	if s.glSvc != nil && jeID != nil && *jeID != uuid.Nil {
		if _, err := s.glSvc.ReverseJournalEntry(ctx, tenantID, userID, *jeID, "negative"); err != nil {
			return fmt.Errorf("reverse goods issue journal entry: %w", err)
		}
	}
	return nil
}

// ═══════════════════════════════════════════════════════════════
// Cycle Count (REQ-CC-001~008)
// ═══════════════════════════════════════════════════════════════

func (s *WarehouseService) GetOutboundJournalEntry(ctx context.Context, id, tenantID, userID uuid.UUID) (map[string]interface{}, error) {
	ob, err := s.warehouseRepo.GetOutboundByID(ctx, id, tenantID)
	if err != nil {
		return nil, err
	}
	if s.glSvc == nil {
		return nil, fmt.Errorf("gl service not available")
	}

	jeID := ob.GLJEID
	if jeID == nil || *jeID == uuid.Nil {
		var recoveredID uuid.UUID
		err := s.db.QueryRow(ctx, `
			SELECT id
			FROM gl_journal_entries
			WHERE tenant_id = $1
			  AND reference = $2
			  AND source = 'warehouse'
			ORDER BY created_at DESC
			LIMIT 1
		`, tenantID, ob.OrderNo).Scan(&recoveredID)
		if err != nil {
			if err == pgx.ErrNoRows {
				if ob.Status != "issued" && ob.Status != "shipped" {
					return nil, fmt.Errorf("no journal entry found for goods issue")
				}
				if err := s.repairOutboundIssueCosts(ctx, tenantID, ob.ID); err != nil {
					return nil, err
				}
				ob, err = s.warehouseRepo.GetOutboundByID(ctx, id, tenantID)
				if err != nil {
					return nil, err
				}
				if err := s.createOutboundJournalEntry(ctx, tenantID, userID, ob); err != nil {
					return nil, err
				}
				ob, err = s.warehouseRepo.GetOutboundByID(ctx, id, tenantID)
				if err != nil {
					return nil, err
				}
				if ob.GLJEID == nil || *ob.GLJEID == uuid.Nil {
					return nil, fmt.Errorf("no journal entry found for goods issue")
				}
				jeID = ob.GLJEID
				goto loadJournalEntry
			}
			return nil, fmt.Errorf("find goods issue journal entry: %w", err)
		}
		if recoveredID == uuid.Nil {
			return nil, fmt.Errorf("no journal entry found for goods issue")
		}
		if err := s.warehouseRepo.LinkOutboundJournalEntry(ctx, ob.ID, tenantID, recoveredID); err != nil {
			return nil, fmt.Errorf("link goods issue journal entry: %w", err)
		}
		jeID = &recoveredID
	}

loadJournalEntry:
	je, err := s.glSvc.GetJournalEntry(ctx, *jeID, tenantID)
	if err != nil {
		return nil, err
	}
	return map[string]interface{}{"journal_entry": je}, nil
}

func (s *WarehouseService) createOutboundJournalEntry(ctx context.Context, tenantID, userID uuid.UUID, ob *whmodels.OutboundOrder) error {
	totalByAccount := map[uuid.UUID]float64{}
	totalCost := 0.0
	for _, line := range ob.Lines {
		if line.TotalCost <= 0 {
			continue
		}
		var materialType string
		if err := s.db.QueryRow(ctx, `SELECT COALESCE(material_type,'') FROM products WHERE id = $1`, line.ProductID).Scan(&materialType); err != nil {
			return fmt.Errorf("load product material type: %w", err)
		}
		inventoryType := warehouseInventoryAccountTypeForMaterialType(materialType)
		if inventoryType == "" {
			return fmt.Errorf("product %s has no material_type; cannot resolve inventory account type", line.ProductSKU)
		}
		orgID, err := s.resolveOrgForAccountTypes(ctx, tenantID, "DM_CONS", inventoryType)
		if err != nil {
			return err
		}
		accountID, err := s.accountForType(ctx, orgID, inventoryType)
		if err != nil {
			return err
		}
		totalByAccount[accountID] += line.TotalCost
		totalCost += line.TotalCost
	}
	if totalCost <= 0 {
		return fmt.Errorf("goods issue %s has zero total cost; maintain inventory or material cost before posting", ob.OrderNo)
	}

	orgID, err := s.resolveOrgForAccountTypes(ctx, tenantID, "DM_CONS")
	if err != nil {
		return err
	}
	dmConsAccountID, err := s.accountForType(ctx, orgID, "DM_CONS")
	if err != nil {
		return err
	}

	lines := []glmodels.CreateJournalLineRequest{{
		AccountID:   dmConsAccountID,
		Debit:       totalCost,
		Credit:      0,
		Description: fmt.Sprintf("Goods Issue %s", ob.OrderNo),
	}}
	for accountID, amount := range totalByAccount {
		lines = append(lines, glmodels.CreateJournalLineRequest{
			AccountID:   accountID,
			Debit:       0,
			Credit:      amount,
			Description: fmt.Sprintf("Goods Issue inventory credit %s", ob.OrderNo),
		})
	}
	entry, err := s.glSvc.CreateJournalEntry(ctx, tenantID, userID, &glmodels.CreateJournalEntryRequest{
		PostingDate:    time.Now(),
		Description:    fmt.Sprintf("Goods Issue - %s", ob.OrderNo),
		Reference:      ob.OrderNo,
		EntryType:      "normal",
		Source:         "warehouse",
		OrganizationID: &orgID,
		Lines:          lines,
	})
	if err != nil {
		return fmt.Errorf("create goods issue journal entry: %w", err)
	}
	if _, err := s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, tenantID, userID, "posted"); err != nil {
		return fmt.Errorf("post goods issue journal entry: %w", err)
	}
	return s.warehouseRepo.LinkOutboundJournalEntry(ctx, ob.ID, tenantID, entry.ID)
}

func (s *WarehouseService) repairOutboundIssueCosts(ctx context.Context, tenantID, outboundID uuid.UUID) error {
	rows, err := s.db.Query(ctx, `
		SELECT l.id, l.product_id, COALESCE(p.sku,''), l.shipped_qty,
			COALESCE(
				NULLIF(si.unit_cost, 0),
				NULLIF(si.total_cost / NULLIF(si.quantity_on_hand, 0), 0),
				NULLIF(p.standard_cost, 0),
				NULLIF(p.moving_avg_cost, 0),
				NULLIF(p.last_cost, 0),
				0
			)
		FROM outbound_orders o
		JOIN outbound_order_lines l ON l.order_id = o.id
		JOIN products p ON p.id = l.product_id
		LEFT JOIN stock_items si ON si.tenant_id = o.tenant_id
			AND si.product_id = l.product_id
			AND si.warehouse_id = COALESCE(l.warehouse_id, o.warehouse_id)
			AND ((l.from_bin_id IS NULL AND si.bin_id IS NULL) OR si.bin_id = l.from_bin_id)
		WHERE o.id = $1
		  AND o.tenant_id = $2
		  AND o.status IN ('issued', 'shipped')
		  AND COALESCE(l.shipped_qty, 0) > 0
		  AND COALESCE(l.total_cost, 0) <= 0
	`, outboundID, tenantID)
	if err != nil {
		return fmt.Errorf("load goods issue costs: %w", err)
	}
	defer rows.Close()

	type costLine struct {
		id        uuid.UUID
		productID uuid.UUID
		sku       string
		qty       float64
		unitCost  float64
	}
	var lines []costLine
	for rows.Next() {
		var line costLine
		if err := rows.Scan(&line.id, &line.productID, &line.sku, &line.qty, &line.unitCost); err != nil {
			return fmt.Errorf("scan goods issue cost: %w", err)
		}
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("scan goods issue costs: %w", err)
	}
	for _, line := range lines {
		if line.unitCost <= 0 {
			return fmt.Errorf("cost is required before creating journal for product %s", line.sku)
		}
		if _, err := s.db.Exec(ctx, `
			UPDATE outbound_order_lines
			SET unit_cost = $1, total_cost = $2
			WHERE id = $3
		`, line.unitCost, line.qty*line.unitCost, line.id); err != nil {
			return fmt.Errorf("repair goods issue cost: %w", err)
		}
	}
	return nil
}

func warehouseInventoryAccountTypeForMaterialType(materialType string) string {
	normalized := strings.TrimSpace(materialType)
	if normalized == "" {
		return ""
	}
	key := strings.ToLower(strings.ReplaceAll(normalized, "-", "_"))
	key = strings.ReplaceAll(key, " ", "_")
	switch key {
	case "raw_material", "raw_mat", "raw":
		return "RAW_MAT"
	case "finished_goods", "finished_good", "fg", "fgs":
		return "FGS"
	case "semi_finished_goods", "semi_finished_good", "half_finished_goods", "half_finished_good":
		return "SFGS"
	case "wip", "work_in_process", "work_in_progress":
		return "WIP"
	case "other", "other_inv", "other_inventory":
		return "Other_Inv"
	default:
		return normalized
	}
}

func (s *WarehouseService) resolveOrgForAccountTypes(ctx context.Context, tenantID uuid.UUID, accountTypes ...string) (uuid.UUID, error) {
	args := []interface{}{tenantID}
	query := `SELECT o.id FROM organizations o WHERE o.tenant_id = $1 AND o.is_active = true`
	for i, accountType := range accountTypes {
		args = append(args, accountType)
		query += fmt.Sprintf(` AND EXISTS (
			SELECT 1 FROM org_reconciliation_accounts ra
			WHERE ra.org_id = o.id AND LOWER(ra.account_type) = LOWER($%d)
		)`, i+2)
	}
	query += ` LIMIT 1`

	var orgID uuid.UUID
	if err := s.db.QueryRow(ctx, query, args...).Scan(&orgID); err == nil && orgID != uuid.Nil {
		return orgID, nil
	}
	if err := s.db.QueryRow(ctx, `SELECT id FROM organizations WHERE tenant_id = $1 AND is_active = true LIMIT 1`, tenantID).Scan(&orgID); err == nil && orgID != uuid.Nil {
		return orgID, nil
	}
	return uuid.Nil, fmt.Errorf("no active organization found for tenant %s", tenantID)
}

func (s *WarehouseService) accountForType(ctx context.Context, orgID uuid.UUID, accountType string) (uuid.UUID, error) {
	var accountID uuid.UUID
	err := s.db.QueryRow(ctx, `
		SELECT account_id
		FROM org_reconciliation_accounts
		WHERE org_id = $1 AND LOWER(account_type) = LOWER($2)
		LIMIT 1
	`, orgID, accountType).Scan(&accountID)
	if err != nil || accountID == uuid.Nil {
		return uuid.Nil, fmt.Errorf("account type %s not configured for org %s", accountType, orgID)
	}
	return accountID, nil
}

func (s *WarehouseService) CreateCycleCount(ctx context.Context, tenantID uuid.UUID, req *whmodels.CreateCycleCountRequest) (*whmodels.CycleCount, error) {
	return s.warehouseRepo.CreateCycleCount(ctx, tenantID, req)
}

func (s *WarehouseService) ListCycleCounts(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.CycleCount, error) {
	return s.warehouseRepo.ListCycleCounts(ctx, tenantID)
}

func (s *WarehouseService) AISuggestCycleCounts(ctx context.Context, tenantID uuid.UUID, count int) ([]*whmodels.CycleCount, error) {
	return s.warehouseRepo.AISuggestCycleCounts(ctx, tenantID, count)
}

// ═══════════════════════════════════════════════════════════════
// Warehouse Tasks (REQ-IO-014~018)
// ═══════════════════════════════════════════════════════════════

func (s *WarehouseService) ListTasks(ctx context.Context, tenantID uuid.UUID, status string) ([]*whmodels.WarehouseTask, error) {
	return s.warehouseRepo.ListTasks(ctx, tenantID, status)
}

func (s *WarehouseService) CompleteTask(ctx context.Context, id, userID uuid.UUID) error {
	return s.warehouseRepo.CompleteTask(ctx, id, userID)
}
