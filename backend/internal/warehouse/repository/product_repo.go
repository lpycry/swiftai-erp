package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	whmodels "github.com/swiftai-erp/backend/internal/warehouse/models"
)

// ProductRepo handles product master CRUD (REQ-WM-002).
type ProductRepo struct {
	db *pgxpool.Pool
}

func NewProductRepo(db *pgxpool.Pool) *ProductRepo {
	return &ProductRepo{db: db}
}

// ── Products ──

func (r *ProductRepo) Create(ctx context.Context, tenantID, userID uuid.UUID, req *whmodels.CreateProductRequest) (*whmodels.Product, error) {
	// Convert empty barcode to nil to avoid unique constraint on (tenant_id, barcode)
	// PostgreSQL UNIQUE treats NULLs as distinct, but empty strings as equal
	var barcodePtr *string
	if req.Barcode != "" {
		barcodePtr = &req.Barcode
	}
	mrpType, err := normalizeMRPType(req.MRPType)
	if err != nil {
		return nil, err
	}

	p := &whmodels.Product{
		ID:                    uuid.New(),
		TenantID:              tenantID,
		CategoryID:            req.CategoryID,
		SKU:                   req.SKU,
		Barcode:               barcodePtr,
		Name:                  req.Name,
		Description:           req.Description,
		UnitOfMeasure:         req.UnitOfMeasure,
		BatchTracked:          req.BatchTracked,
		SerialTracked:         req.SerialTracked,
		ShelfLifeDays:         req.ShelfLifeDays,
		TaxCategory:           "STANDARD",
		TaxType:               "SALES_TAX",
		DimensionLength:       req.DimensionLength,
		DimensionWidth:        req.DimensionWidth,
		DimensionHeight:       req.DimensionHeight,
		DimensionUnit:         req.DimensionUnit,
		GrossWeight:           req.GrossWeight,
		NetWeight:             req.NetWeight,
		WeightUnit:            req.WeightUnit,
		StandardCost:          req.StandardCost,
		MovingAvgCost:         req.MovingAvgCost,
		LastCost:              req.LastCost,
		AvgCost:               req.AvgCost,
		WeightKg:              req.WeightKg,
		VolumeM3:              req.VolumeM3,
		ABCClassification:     req.ABCClassification,
		ValuationClass:        req.ValuationClass,
		HSCode:                req.HSCode,
		CountryOfOrigin:       req.CountryOfOrigin,
		StorageCondition:      req.StorageCondition,
		ProcurementType:       req.ProcurementType,
		MinStockQty:           req.SafetyStock,
		MaxStockQty:           req.MaxStockQty,
		ReorderPoint:          req.ReorderPoint,
		ReorderQty:            req.ReorderQty,
		LeadTimeDays:          req.LeadTimeDays,
		IsSerialized:          req.IsSerialized,
		IsActive:              true,
		MaterialType:          req.MaterialType,
		MRPEnabled:            req.MRPEnabled,
		MRPType:               mrpType,
		PhantomAssembly:       req.PhantomAssembly,
		ProductionLeadTime:    req.ProductionLeadTime,
		InHouseProductionDays: req.InHouseProductionDays,
		CreatedAt:             time.Now(),
		UpdatedAt:             time.Now(),
	}
	if p.UnitOfMeasure == "" {
		p.UnitOfMeasure = "EA"
	}
	if p.DimensionUnit == "" {
		p.DimensionUnit = "cm"
	}
	if p.WeightUnit == "" {
		p.WeightUnit = "kg"
	}
	if req.TaxCategory != "" {
		p.TaxCategory = req.TaxCategory
	}
	if req.TaxType != "" {
		p.TaxType = req.TaxType
	}
	if req.DefaultTaxJurisdictionID != nil && *req.DefaultTaxJurisdictionID != "" {
		if id, err := uuid.Parse(*req.DefaultTaxJurisdictionID); err == nil {
			p.DefaultTaxJurisdictionID = &id
		}
	}

	// Default UOM group to base UOM if not set
	uomGroup := req.UOMGroup
	if uomGroup == "" {
		uomGroup = p.UnitOfMeasure
	}

	_, err = r.db.Exec(ctx, `
		INSERT INTO products (
			id, tenant_id, category_id, sku, barcode, name, description,
			unit_of_measure, uom_group, batch_tracked, serial_tracked, shelf_life_days,
			dimension_length, dimension_width, dimension_height, dimension_unit,
			gross_weight, net_weight, weight_unit,
			standard_cost, moving_avg_cost, last_cost, avg_cost,
			weight_kg, volume_m3,
			abc_classification, valuation_class, hs_code, country_of_origin,
			storage_condition, procurement_type,
			min_stock_qty, max_stock_qty, reorder_point, reorder_qty, lead_time_days,
			is_serialized, is_active, material_type,
			tax_category, tax_rate, tax_type, tax_exempt_reason, default_tax_jurisdiction_id,
			mrp_enabled, mrp_type, phantom_assembly, production_lead_time, in_house_production_days,
			created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,
			$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,
			$40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$50,$51)
	`, p.ID, p.TenantID, p.CategoryID, p.SKU, p.Barcode, p.Name, p.Description,
		p.UnitOfMeasure, uomGroup, p.BatchTracked, p.SerialTracked, p.ShelfLifeDays,
		p.DimensionLength, p.DimensionWidth, p.DimensionHeight, p.DimensionUnit,
		p.GrossWeight, p.NetWeight, p.WeightUnit,
		p.StandardCost, p.MovingAvgCost, p.LastCost, p.AvgCost,
		p.WeightKg, p.VolumeM3,
		p.ABCClassification, p.ValuationClass, p.HSCode, p.CountryOfOrigin,
		p.StorageCondition, p.ProcurementType,
		p.MinStockQty, p.MaxStockQty, p.ReorderPoint, p.ReorderQty, p.LeadTimeDays,
		p.IsSerialized, p.IsActive, p.MaterialType,
		p.TaxCategory, p.TaxRate, p.TaxType, p.TaxExemptReason, p.DefaultTaxJurisdictionID,
		p.MRPEnabled, p.MRPType, p.PhantomAssembly, p.ProductionLeadTime, p.InHouseProductionDays,
		p.CreatedAt, p.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert product: %w", err)
	}
	if err := r.syncProductPlantData(ctx, p.ID, tenantID, alignProductPlantData(req.PlantData, mrpType, p.ProcurementType)); err != nil {
		return nil, err
	}
	p.PlantData, _ = r.loadProductPlantData(ctx, tenantID, p.ID)
	return p, nil
}

func (r *ProductRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*whmodels.Product, error) {
	p := &whmodels.Product{}
	err := r.db.QueryRow(ctx, `
		SELECT p.id, p.tenant_id, p.category_id, COALESCE(pc.name,''), p.sku, p.barcode,
		       p.name, COALESCE(p.description,''), p.unit_of_measure,
		       p.batch_tracked, p.serial_tracked, p.shelf_life_days,
		       p.dimension_length, p.dimension_width, p.dimension_height, p.dimension_unit,
		       p.gross_weight, p.net_weight, p.weight_unit,
		       p.standard_cost, p.moving_avg_cost, p.last_cost, p.avg_cost,
		       p.weight_kg, p.volume_m3,
		       COALESCE(p.abc_classification,''), COALESCE(p.valuation_class,''),
		       COALESCE(p.hs_code,''), COALESCE(p.country_of_origin,''),
		       COALESCE(p.storage_condition,''), COALESCE(p.procurement_type,''),
		       p.min_stock_qty, p.max_stock_qty, p.reorder_point, p.reorder_qty, p.lead_time_days,
		       p.is_serialized, p.is_active,
		       p.tax_category, p.tax_rate, p.tax_type, COALESCE(p.tax_exempt_reason,''), p.default_tax_jurisdiction_id,
		       p.mrp_enabled, COALESCE(p.mrp_type,'MPS'), p.phantom_assembly, p.production_lead_time, p.in_house_production_days,
		       COALESCE(p.material_type,''),
		       p.created_at, p.updated_at
		FROM products p
		LEFT JOIN product_categories pc ON pc.id = p.category_id
		WHERE p.id = $1 AND p.tenant_id = $2
	`, id, tenantID).Scan(
		&p.ID, &p.TenantID, &p.CategoryID, &p.CategoryName,
		&p.SKU, &p.Barcode, &p.Name, &p.Description, &p.UnitOfMeasure,
		&p.BatchTracked, &p.SerialTracked, &p.ShelfLifeDays,
		&p.DimensionLength, &p.DimensionWidth, &p.DimensionHeight, &p.DimensionUnit,
		&p.GrossWeight, &p.NetWeight, &p.WeightUnit,
		&p.StandardCost, &p.MovingAvgCost, &p.LastCost, &p.AvgCost,
		&p.WeightKg, &p.VolumeM3,
		&p.ABCClassification, &p.ValuationClass,
		&p.HSCode, &p.CountryOfOrigin,
		&p.StorageCondition, &p.ProcurementType,
		&p.MinStockQty, &p.MaxStockQty, &p.ReorderPoint, &p.ReorderQty, &p.LeadTimeDays,
		&p.IsSerialized, &p.IsActive,
		&p.TaxCategory, &p.TaxRate, &p.TaxType, &p.TaxExemptReason, &p.DefaultTaxJurisdictionID,
		&p.MRPEnabled, &p.MRPType, &p.PhantomAssembly, &p.ProductionLeadTime, &p.InHouseProductionDays,
		&p.MaterialType,
		&p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get product: %w", err)
	}
	p.PlantData, _ = r.loadProductPlantData(ctx, tenantID, p.ID)
	return p, nil
}

func (r *ProductRepo) List(ctx context.Context, tenantID uuid.UUID, search string) ([]*whmodels.Product, error) {
	query := `
		SELECT p.id, p.tenant_id, p.category_id, COALESCE(pc.name,''), p.sku, p.barcode,
		       p.name, COALESCE(p.description,''), p.unit_of_measure,
		       p.batch_tracked, p.serial_tracked, p.shelf_life_days,
		       p.dimension_length, p.dimension_width, p.dimension_height, p.dimension_unit,
		       p.gross_weight, p.net_weight, p.weight_unit,
		       p.standard_cost, p.moving_avg_cost, p.last_cost, p.avg_cost,
		       p.weight_kg, p.volume_m3,
		       COALESCE(p.abc_classification,''), COALESCE(p.valuation_class,''),
		       COALESCE(p.hs_code,''), COALESCE(p.country_of_origin,''),
		       COALESCE(p.storage_condition,''), COALESCE(p.procurement_type,''),
		       p.min_stock_qty, p.max_stock_qty, p.reorder_point, p.reorder_qty, p.lead_time_days,
		       p.is_serialized, p.is_active,
		       p.tax_category, p.tax_rate, p.tax_type, COALESCE(p.tax_exempt_reason,''), p.default_tax_jurisdiction_id,
		       p.mrp_enabled, COALESCE(p.mrp_type,'MPS'), p.phantom_assembly, p.production_lead_time, p.in_house_production_days,
		       COALESCE(p.material_type,''),
		       p.created_at, p.updated_at
		FROM products p
		LEFT JOIN product_categories pc ON pc.id = p.category_id
		WHERE p.tenant_id = $1
	`
	args := []interface{}{tenantID}
	argIdx := 2

	if search != "" {
		query += fmt.Sprintf(` AND (p.sku ILIKE $%d OR p.name ILIKE $%d OR p.barcode ILIKE $%d)`, argIdx, argIdx, argIdx)
		args = append(args, "%"+search+"%")
		argIdx++
	}
	query += " ORDER BY p.sku"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list products: %w", err)
	}
	defer rows.Close()

	var products []*whmodels.Product
	for rows.Next() {
		p := &whmodels.Product{}
		err := rows.Scan(
			&p.ID, &p.TenantID, &p.CategoryID, &p.CategoryName,
			&p.SKU, &p.Barcode, &p.Name, &p.Description, &p.UnitOfMeasure,
			&p.BatchTracked, &p.SerialTracked, &p.ShelfLifeDays,
			&p.DimensionLength, &p.DimensionWidth, &p.DimensionHeight, &p.DimensionUnit,
			&p.GrossWeight, &p.NetWeight, &p.WeightUnit,
			&p.StandardCost, &p.MovingAvgCost, &p.LastCost, &p.AvgCost,
			&p.WeightKg, &p.VolumeM3,
			&p.ABCClassification, &p.ValuationClass,
			&p.HSCode, &p.CountryOfOrigin,
			&p.StorageCondition, &p.ProcurementType,
			&p.MinStockQty, &p.MaxStockQty, &p.ReorderPoint, &p.ReorderQty, &p.LeadTimeDays,
			&p.IsSerialized, &p.IsActive,
			&p.TaxCategory, &p.TaxRate, &p.TaxType, &p.TaxExemptReason, &p.DefaultTaxJurisdictionID,
			&p.MRPEnabled, &p.MRPType, &p.PhantomAssembly, &p.ProductionLeadTime, &p.InHouseProductionDays,
			&p.MaterialType,
			&p.CreatedAt, &p.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan product: %w", err)
		}
		products = append(products, p)
	}
	for _, p := range products {
		p.PlantData, _ = r.loadProductPlantData(ctx, tenantID, p.ID)
	}
	return products, nil
}

// ── Warehouses ──

type WarehouseRepo struct {
	db *pgxpool.Pool
}

func NewWarehouseRepo(db *pgxpool.Pool) *WarehouseRepo {
	return &WarehouseRepo{db: db}
}

func (r *WarehouseRepo) Create(ctx context.Context, tenantID uuid.UUID, req *whmodels.CreateWarehouseRequest) (*whmodels.Warehouse, error) {
	w := &whmodels.Warehouse{
		ID:             uuid.New(),
		TenantID:       tenantID,
		OrganizationID: req.OrganizationID,
		SiteID:         req.SiteID,
		Code:           req.Code,
		Name:           req.Name,
		Address:        req.Address,
		IsActive:       true,
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO warehouses (id, tenant_id, organization_id, site_id, code, name, address, is_active, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW(),NOW())
	`, w.ID, w.TenantID, w.OrganizationID, w.SiteID, w.Code, w.Name, w.Address, w.IsActive)
	if err != nil {
		return nil, fmt.Errorf("insert warehouse: %w", err)
	}
	return w, nil
}

func (r *WarehouseRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*whmodels.Warehouse, error) {
	w := &whmodels.Warehouse{}
	err := r.db.QueryRow(ctx, `
		SELECT w.id, w.tenant_id, w.organization_id, COALESCE(o.org_code,''), COALESCE(o.org_name,''),
			w.site_id, COALESCE(s.site_code,''), COALESCE(s.site_name,''),
			w.code, w.name, COALESCE(w.address,''), w.is_active, w.created_at, w.updated_at
		FROM warehouses w
		LEFT JOIN organizations o ON o.id = w.organization_id
		LEFT JOIN sites s ON s.id = w.site_id
		WHERE w.id = $1 AND w.tenant_id = $2
	`, id, tenantID).Scan(
		&w.ID, &w.TenantID, &w.OrganizationID, &w.OrgCode, &w.OrgName,
		&w.SiteID, &w.SiteCode, &w.SiteName,
		&w.Code, &w.Name, &w.Address, &w.IsActive, &w.CreatedAt, &w.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get warehouse: %w", err)
	}
	return w, nil
}

func (r *WarehouseRepo) List(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.Warehouse, error) {
	rows, err := r.db.Query(ctx, `
		SELECT w.id, w.tenant_id, w.organization_id, COALESCE(o.org_code,''), COALESCE(o.org_name,''),
			w.site_id, COALESCE(s.site_code,''), COALESCE(s.site_name,''),
			w.code, w.name, COALESCE(w.address,''), w.is_active, w.created_at, w.updated_at
		FROM warehouses w
		LEFT JOIN organizations o ON o.id = w.organization_id
		LEFT JOIN sites s ON s.id = w.site_id
		WHERE w.tenant_id = $1 ORDER BY w.code
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*whmodels.Warehouse
	for rows.Next() {
		w := &whmodels.Warehouse{}
		err := rows.Scan(&w.ID, &w.TenantID, &w.OrganizationID, &w.OrgCode, &w.OrgName,
			&w.SiteID, &w.SiteCode, &w.SiteName,
			&w.Code, &w.Name, &w.Address, &w.IsActive, &w.CreatedAt, &w.UpdatedAt)
		if err != nil {
			return nil, err
		}
		list = append(list, w)
	}
	return list, nil
}

func (r *WarehouseRepo) UpdateWarehouse(ctx context.Context, id, tenantID uuid.UUID, req *whmodels.UpdateWarehouseRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE warehouses SET
			code            = COALESCE($3, code),
			name            = COALESCE($4, name),
			address         = COALESCE($5, address),
			organization_id = COALESCE($6, organization_id),
			site_id         = COALESCE($7, site_id),
			is_active       = COALESCE($8, is_active),
			updated_at      = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.Code, req.Name, req.Address, req.OrganizationID, req.SiteID, req.IsActive)
	if err != nil {
		return err
	}
	return nil
}

func (r *WarehouseRepo) DeleteWarehouse(ctx context.Context, id, tenantID uuid.UUID) error {
	// Check for existing stock before delete
	var stockCount int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM stock_items WHERE warehouse_id = $1
	`, id).Scan(&stockCount)
	if err != nil {
		return fmt.Errorf("check stock: %w", err)
	}
	if stockCount > 0 {
		return fmt.Errorf("warehouse has %d stock item(s); remove stock first", stockCount)
	}
	_, err = r.db.Exec(ctx, `DELETE FROM warehouses WHERE id = $1 AND tenant_id = $2`, id, tenantID)
	if err != nil {
		return err
	}
	return nil
}

// ── Helpers ──

func (r *ProductRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM products WHERE id = $1 AND tenant_id = $2`, id, tenantID)
	return err
}

func (r *ProductRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *whmodels.UpdateProductRequest) error {
	var mrpType *string
	if req.MRPType != nil {
		normalized, err := normalizeMRPType(*req.MRPType)
		if err != nil {
			return err
		}
		mrpType = &normalized
	} else if len(req.PlantData) > 0 {
		normalized, err := normalizeMRPType(req.PlantData[0].MRPType)
		if err != nil {
			return err
		}
		mrpType = &normalized
	}

	_, err := r.db.Exec(ctx, `
		UPDATE products SET
			category_id      = COALESCE($3, category_id),
			barcode          = COALESCE($4, barcode),
			name             = COALESCE($5, name),
			description      = COALESCE($6, description),
			unit_of_measure  = COALESCE($7, unit_of_measure),
			batch_tracked    = COALESCE($8, batch_tracked),
			serial_tracked   = COALESCE($9, serial_tracked),
			shelf_life_days  = COALESCE($10, shelf_life_days),
			dimension_length = COALESCE($11, dimension_length),
			dimension_width  = COALESCE($12, dimension_width),
			dimension_height = COALESCE($13, dimension_height),
			dimension_unit   = COALESCE($14, dimension_unit),
			gross_weight     = COALESCE($15, gross_weight),
			net_weight       = COALESCE($16, net_weight),
			weight_unit      = COALESCE($17, weight_unit),
			standard_cost    = COALESCE($18, standard_cost),
			moving_avg_cost  = COALESCE($19, moving_avg_cost),
			last_cost        = COALESCE($20, last_cost),
			avg_cost         = COALESCE($21, avg_cost),
			weight_kg        = COALESCE($22, weight_kg),
			volume_m3        = COALESCE($23, volume_m3),
			abc_classification = COALESCE($24, abc_classification),
			valuation_class  = COALESCE($25, valuation_class),
			hs_code          = COALESCE($26, hs_code),
			country_of_origin = COALESCE($27, country_of_origin),
			storage_condition = COALESCE($28, storage_condition),
			procurement_type = COALESCE($29, procurement_type),
			min_stock_qty    = COALESCE($30, min_stock_qty),
			max_stock_qty    = COALESCE($31, max_stock_qty),
			reorder_point    = COALESCE($32, reorder_point),
			reorder_qty      = COALESCE($33, reorder_qty),
			lead_time_days   = COALESCE($34, lead_time_days),
			is_serialized                 = COALESCE($35, is_serialized),
			is_active                     = COALESCE($36, is_active),
			tax_category                  = COALESCE($37, tax_category),
			tax_rate                      = COALESCE($38, tax_rate),
			tax_type                      = COALESCE($39, tax_type),
			tax_exempt_reason             = COALESCE($40, tax_exempt_reason),
			default_tax_jurisdiction_id   = COALESCE($41, default_tax_jurisdiction_id),
			material_type                 = COALESCE($42, material_type),
			mrp_enabled                   = COALESCE($43, mrp_enabled),
			mrp_type                      = COALESCE($44, mrp_type),
			phantom_assembly              = COALESCE($45, phantom_assembly),
			production_lead_time          = COALESCE($46, production_lead_time),
			in_house_production_days      = COALESCE($47, in_house_production_days),
			updated_at                    = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID,
		req.CategoryID,
		nullIfEmpty(req.Barcode),
		nullIfEmpty(req.Name),
		nullIfEmpty(req.Description),
		nullIfEmpty(req.UnitOfMeasure),
		req.BatchTracked,
		req.SerialTracked,
		req.ShelfLifeDays,
		req.DimensionLength,
		req.DimensionWidth,
		req.DimensionHeight,
		req.DimensionUnit,
		req.GrossWeight,
		req.NetWeight,
		req.WeightUnit,
		req.StandardCost,
		req.MovingAvgCost,
		req.LastCost,
		req.AvgCost,
		req.WeightKg,
		req.VolumeM3,
		req.ABCClassification,
		req.ValuationClass,
		req.HSCode,
		req.CountryOfOrigin,
		req.StorageCondition,
		req.ProcurementType,
		req.SafetyStock,
		req.MaxStockQty,
		req.ReorderPoint,
		req.ReorderQty,
		req.LeadTimeDays,
		req.IsSerialized,
		req.IsActive,
		req.TaxCategory,
		req.TaxRate,
		req.TaxType,
		req.TaxExemptReason,
		req.DefaultTaxJurisdictionID,
		req.MaterialType,
		req.MRPEnabled,
		mrpType,
		req.PhantomAssembly,
		req.ProductionLeadTime,
		req.InHouseProductionDays)
	if err != nil {
		return err
	}
	if req.PlantData != nil {
		effectiveMRPType := ""
		if mrpType != nil {
			effectiveMRPType = *mrpType
		}
		procurementType := ""
		if req.ProcurementType != nil {
			procurementType = *req.ProcurementType
		}
		return r.syncProductPlantData(ctx, id, tenantID, alignProductPlantData(req.PlantData, effectiveMRPType, procurementType))
	}
	return nil
}

// ── Stock Movements ──

func (r *ProductRepo) ListMovements(ctx context.Context, tenantID uuid.UUID, limit int, warehouseID uuid.UUID, binID uuid.UUID, dateFrom, dateTo string) ([]*whmodels.StockMovement, error) {
	if limit <= 0 {
		limit = 200
	}
	baseQuery := `SELECT sm.id, sm.tenant_id, sm.transaction_type,
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
	WHERE sm.tenant_id = $1`
	args := []interface{}{tenantID}
	argIdx := 2

	if warehouseID != uuid.Nil {
		baseQuery += fmt.Sprintf(" AND (sm.warehouse_id = $%d OR sm.to_warehouse_id = $%d)", argIdx, argIdx)
		args = append(args, warehouseID)
		argIdx++
	}
	if binID != uuid.Nil {
		baseQuery += fmt.Sprintf(" AND (sm.bin_id = $%d OR sm.to_bin_id = $%d)", argIdx, argIdx)
		args = append(args, binID)
		argIdx++
	}
	if dateFrom != "" {
		baseQuery += fmt.Sprintf(" AND sm.created_at >= $%d::date", argIdx)
		args = append(args, dateFrom)
		argIdx++
	}
	if dateTo != "" {
		baseQuery += fmt.Sprintf(" AND sm.created_at < ($%d::date + INTERVAL '1 day')", argIdx)
		args = append(args, dateTo)
		argIdx++
	}

	baseQuery += " ORDER BY sm.created_at DESC"
	baseQuery += fmt.Sprintf(" LIMIT $%d", argIdx)
	args = append(args, limit)

	rows, err := r.db.Query(ctx, baseQuery, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*whmodels.StockMovement
	for rows.Next() {
		m := &whmodels.StockMovement{}
		if err := rows.Scan(&m.ID, &m.TenantID, &m.TransactionType,
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
		); err != nil {
			return nil, err
		}
		list = append(list, m)
	}
	return list, nil
}

// ── Warehouse Zones ──

func (r *ProductRepo) ListZones(ctx context.Context, warehouseID uuid.UUID) ([]*whmodels.WarehouseZone, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, warehouse_id, code, name, zone_type, is_active, created_at, updated_at
		FROM warehouse_zones WHERE warehouse_id = $1 ORDER BY code
	`, warehouseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*whmodels.WarehouseZone
	for rows.Next() {
		z := &whmodels.WarehouseZone{}
		if err := rows.Scan(&z.ID, &z.WarehouseID, &z.Code, &z.Name, &z.ZoneType, &z.IsActive, &z.CreatedAt, &z.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, z)
	}
	return list, nil
}

func (r *ProductRepo) CreateZone(ctx context.Context, req *whmodels.CreateZoneRequest) (*whmodels.WarehouseZone, error) {
	z := &whmodels.WarehouseZone{ID: uuid.New(), WarehouseID: req.WarehouseID, Code: req.Code, Name: req.Name,
		ZoneType: req.ZoneType, IsActive: true}
	if z.ZoneType == "" {
		z.ZoneType = "storage"
	}
	_, err := r.db.Exec(ctx, `INSERT INTO warehouse_zones(id,warehouse_id,code,name,zone_type,is_active,created_at,updated_at)
		VALUES($1,$2,$3,$4,$5,$6,NOW(),NOW())`,
		z.ID, z.WarehouseID, z.Code, z.Name, z.ZoneType, z.IsActive)
	if err != nil {
		return nil, fmt.Errorf("create zone: %w", err)
	}
	return z, nil
}

// ── Warehouse Bins ──

// Shared bin query helper — includes warehouse_id + site + warehouse joins
func (r *ProductRepo) queryBins(ctx context.Context, whereClause string, args []interface{}) ([]*whmodels.WarehouseBin, error) {
	query := fmt.Sprintf(`
		SELECT b.id, b.zone_id, b.site_id, b.warehouse_id, b.code, COALESCE(b.name,''), COALESCE(b.barcode,''),
		       COALESCE(bin_type,''), COALESCE(bin_status,''),
		       b.max_weight_kg, b.max_volume_m3, b.is_active, b.created_at, b.updated_at,
		       COALESCE(s.site_code,''), COALESCE(s.site_name,''),
		       COALESCE(wh.code,''), COALESCE(wh.name,'')
		FROM warehouse_bins b
		LEFT JOIN sites s ON s.id = b.site_id
		LEFT JOIN warehouses wh ON wh.id = b.warehouse_id
		%s ORDER BY COALESCE(wh.code,''), COALESCE(s.site_code,''), b.code
	`, whereClause)
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*whmodels.WarehouseBin
	for rows.Next() {
		b := &whmodels.WarehouseBin{}
		if err := rows.Scan(&b.ID, &b.ZoneID, &b.SiteID, &b.WarehouseID, &b.Code, &b.Name, &b.Barcode,
			&b.BinType, &b.BinStatus,
			&b.MaxWeightKg, &b.MaxVolumeM3, &b.IsActive, &b.CreatedAt, &b.UpdatedAt,
			&b.SiteCode, &b.SiteName,
			&b.WarehouseCode, &b.WarehouseName); err != nil {
			return nil, err
		}
		list = append(list, b)
	}
	return list, nil
}

func (r *ProductRepo) ListBins(ctx context.Context, zoneID uuid.UUID) ([]*whmodels.WarehouseBin, error) {
	return r.queryBins(ctx, "WHERE b.zone_id = $1", []interface{}{zoneID})
}

func (r *ProductRepo) ListBinsBySite(ctx context.Context, siteID uuid.UUID) ([]*whmodels.WarehouseBin, error) {
	return r.queryBins(ctx, "WHERE b.site_id = $1", []interface{}{siteID})
}

func (r *ProductRepo) ListBinsByWarehouse(ctx context.Context, warehouseID uuid.UUID) ([]*whmodels.WarehouseBin, error) {
	return r.queryBins(ctx, "WHERE b.warehouse_id = $1", []interface{}{warehouseID})
}

func (r *ProductRepo) ListAllBins(ctx context.Context, tenantID uuid.UUID, search string) ([]*whmodels.WarehouseBin, error) {
	var conditions []string
	var args []interface{}
	argIdx := 1

	if search != "" {
		searchPattern := "%" + search + "%"
		conditions = append(conditions, fmt.Sprintf("(b.code ILIKE $%d OR COALESCE(b.name,'') ILIKE $%d OR COALESCE(b.barcode,'') ILIKE $%d OR COALESCE(s.site_code,'') ILIKE $%d OR COALESCE(s.site_name,'') ILIKE $%d OR COALESCE(wh.code,'') ILIKE $%d OR COALESCE(wh.name,'') ILIKE $%d)",
			argIdx, argIdx, argIdx, argIdx, argIdx, argIdx, argIdx))
		args = append(args, searchPattern)
		argIdx++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}
	return r.queryBins(ctx, whereClause, args)
}

func (r *ProductRepo) GetBin(ctx context.Context, id uuid.UUID) (*whmodels.WarehouseBin, error) {
	list, err := r.queryBins(ctx, "WHERE b.id = $1", []interface{}{id})
	if err != nil {
		return nil, err
	}
	if len(list) == 0 {
		return nil, fmt.Errorf("bin not found")
	}
	return list[0], nil
}

func (r *ProductRepo) CreateBin(ctx context.Context, req *whmodels.CreateBinRequest) (*whmodels.WarehouseBin, error) {
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	b := &whmodels.WarehouseBin{
		ID: uuid.New(), ZoneID: req.ZoneID, SiteID: req.SiteID, WarehouseID: req.WarehouseID,
		Code: req.Code, Name: req.Name, Barcode: req.Barcode,
		MaxWeightKg: req.MaxWeightKg, MaxVolumeM3: req.MaxVolumeM3,
		IsActive: isActive, BinType: "storage", BinStatus: "available",
	}
	_, err := r.db.Exec(ctx, `INSERT INTO warehouse_bins(id,zone_id,site_id,warehouse_id,code,name,bin_type,bin_status,barcode,max_weight_kg,max_volume_m3,is_active,created_at,updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW(),NOW())`,
		b.ID, b.ZoneID, b.SiteID, b.WarehouseID, b.Code, b.Name, b.BinType, b.BinStatus, b.Barcode,
		b.MaxWeightKg, b.MaxVolumeM3, b.IsActive)
	if err != nil {
		return nil, fmt.Errorf("create bin: %w", err)
	}
	return b, nil
}

func (r *ProductRepo) UpdateBin(ctx context.Context, id uuid.UUID, req *whmodels.UpdateBinRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE warehouse_bins SET
			name        = COALESCE(NULLIF($2, ''), name),
			barcode     = COALESCE(NULLIF($3, ''), barcode),
			max_weight_kg = COALESCE($4, max_weight_kg),
			max_volume_m3 = COALESCE($5, max_volume_m3),
			is_active   = COALESCE($6, is_active),
			updated_at  = NOW()
		WHERE id = $1
	`, id, req.Name, req.Barcode, req.MaxWeightKg, req.MaxVolumeM3, req.IsActive)
	return err
}

func (r *ProductRepo) DeleteBinByID(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM warehouse_bins WHERE id = $1`, id)
	return err
}

// ── Barcodes (REQ-MM-031) ──

func (r *ProductRepo) ListBarcodes(ctx context.Context, productID uuid.UUID) ([]*whmodels.ProductBarcode, error) {
	rows, err := r.db.Query(ctx, `SELECT id, product_id, barcode, barcode_type, is_primary, created_at FROM product_barcodes WHERE product_id = $1 ORDER BY is_primary DESC, created_at`, productID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*whmodels.ProductBarcode
	for rows.Next() {
		b := &whmodels.ProductBarcode{}
		if err := rows.Scan(&b.ID, &b.ProductID, &b.Barcode, &b.BarcodeType, &b.IsPrimary, &b.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, b)
	}
	return list, nil
}

func (r *ProductRepo) CreateBarcode(ctx context.Context, productID uuid.UUID, barcode, barcodeType string) (*whmodels.ProductBarcode, error) {
	b := &whmodels.ProductBarcode{ID: uuid.New(), ProductID: productID, Barcode: barcode, BarcodeType: barcodeType}
	if b.BarcodeType == "" {
		b.BarcodeType = "EAN-13"
	}
	_, err := r.db.Exec(ctx, `INSERT INTO product_barcodes(id,product_id,barcode,barcode_type,is_primary,created_at) VALUES($1,$2,$3,$4,$5,NOW())`,
		b.ID, b.ProductID, b.Barcode, b.BarcodeType, false)
	if err != nil {
		return nil, fmt.Errorf("create barcode: %w", err)
	}
	return b, nil
}

func (r *ProductRepo) DeleteBarcode(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM product_barcodes WHERE id = $1`, id)
	return err
}

// ── Photos (REQ-MM-001~010) ──

func (r *ProductRepo) ListPhotos(ctx context.Context, productID uuid.UUID) ([]*whmodels.ProductPhoto, error) {
	rows, err := r.db.Query(ctx, `SELECT id, product_id, is_primary, sort_order, file_path, file_name, file_size, mime_type, ai_tags, created_at FROM product_photos WHERE product_id = $1 ORDER BY sort_order, created_at`, productID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*whmodels.ProductPhoto
	for rows.Next() {
		p := &whmodels.ProductPhoto{}
		if err := rows.Scan(&p.ID, &p.ProductID, &p.IsPrimary, &p.SortOrder, &p.FilePath, &p.FileName, &p.FileSize, &p.MimeType, &p.AITags, &p.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, p)
	}
	return list, nil
}

func (r *ProductRepo) CreatePhoto(ctx context.Context, productID uuid.UUID, fileName, filePath string, fileSize int, mimeType string) (*whmodels.ProductPhoto, error) {
	p := &whmodels.ProductPhoto{ID: uuid.New(), ProductID: productID, FilePath: filePath, FileName: fileName, FileSize: fileSize, MimeType: mimeType, SortOrder: 0}
	_, err := r.db.Exec(ctx, `INSERT INTO product_photos(id,product_id,is_primary,sort_order,file_path,file_name,file_size,mime_type,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,NOW())`,
		p.ID, p.ProductID, false, 0, p.FilePath, p.FileName, p.FileSize, p.MimeType)
	if err != nil {
		return nil, fmt.Errorf("create photo: %w", err)
	}
	return p, nil
}

func (r *ProductRepo) DeletePhoto(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM product_photos WHERE id = $1`, id)
	return err
}

// ═══════════════════════════════════════════════════════════════
// Goods Receipt (REQ-IB-005~014)
// ═══════════════════════════════════════════════════════════════

func (r *WarehouseRepo) CreateGR(ctx context.Context, tenantID, userID uuid.UUID, req *whmodels.CreateGRRequest) (*whmodels.GoodsReceipt, error) {
	now := time.Now()
	gr := &whmodels.GoodsReceipt{
		ID:           uuid.New(),
		TenantID:     tenantID,
		GRNo:         fmt.Sprintf("GR-%s", uuid.New().String()[:8]),
		ReceiptType:  req.ReceiptType,
		ReferenceNo:  req.ReferenceNo,
		WarehouseID:  req.WarehouseID,
		SupplierName: req.SupplierName,
		ReceiptDate:  now,
		Status:       "draft",
		CreatedBy:    userID,
		CreatedAt:    now,
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO goods_receipts (id, tenant_id, gr_no, receipt_type, reference_no,
			warehouse_id, supplier_name, receipt_date, status, created_by, created_at, posted_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,NULL)
	`, gr.ID, gr.TenantID, gr.GRNo, gr.ReceiptType, gr.ReferenceNo,
		gr.WarehouseID, gr.SupplierName, gr.ReceiptDate, gr.Status, gr.CreatedBy, gr.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert gr: %w", err)
	}

	for _, line := range req.Lines {
		lineID := uuid.New()
		totalCost := line.ReceivedQty * line.UnitCost
		_, err = tx.Exec(ctx, `
			INSERT INTO goods_receipt_lines (id, gr_id, product_id,
				expected_qty, received_qty, accepted_qty, rejected_qty,
				unit_cost, total_cost, batch_no, expiry_date, putaway_status)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		`, lineID, gr.ID, line.ProductID,
			line.ReceivedQty, line.ReceivedQty, line.ReceivedQty, 0,
			line.UnitCost, totalCost, nullIfEmpty(line.BatchNo), line.ExpiryDate, "pending")
		if err != nil {
			return nil, fmt.Errorf("insert gr line: %w", err)
		}
		grLine := whmodels.GoodsReceiptLine{
			ID: lineID, GRID: gr.ID, ProductID: line.ProductID,
			ReceivedQty: line.ReceivedQty, UnitCost: line.UnitCost,
			TotalCost: totalCost, BatchNo: line.BatchNo, ExpiryDate: line.ExpiryDate,
		}
		gr.Lines = append(gr.Lines, grLine)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit gr: %w", err)
	}
	return gr, nil
}

func (r *WarehouseRepo) ListGRs(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.GoodsReceipt, error) {
	rows, err := r.db.Query(ctx, `
		SELECT g.id, g.tenant_id, g.gr_no, g.receipt_type,
			COALESCE(g.reference_no,''), g.warehouse_id, COALESCE(w.name,''),
			COALESCE(g.supplier_name,''), g.receipt_date, g.status,
			COALESCE(g.notes,''), g.created_by, g.created_at, g.posted_at, g.posted_by
		FROM goods_receipts g
		LEFT JOIN warehouses w ON w.id = g.warehouse_id
		WHERE g.tenant_id = $1
		ORDER BY g.created_at DESC
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*whmodels.GoodsReceipt
	for rows.Next() {
		g := &whmodels.GoodsReceipt{}
		if err := rows.Scan(
			&g.ID, &g.TenantID, &g.GRNo, &g.ReceiptType,
			&g.ReferenceNo, &g.WarehouseID, &g.WarehouseName,
			&g.SupplierName, &g.ReceiptDate, &g.Status,
			&g.Notes, &g.CreatedBy, &g.CreatedAt, &g.PostedAt, &g.PostedBy,
		); err != nil {
			return nil, err
		}
		// Fetch lines for each GR
		lines, err := r.getGRLines(ctx, g.ID)
		if err != nil {
			return nil, err
		}
		g.Lines = lines
		list = append(list, g)
	}
	return list, nil
}

func (r *WarehouseRepo) getGRLines(ctx context.Context, grID uuid.UUID) ([]whmodels.GoodsReceiptLine, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, gr_id, product_id, received_qty, rejected_qty,
			unit_cost, total_cost, COALESCE(batch_no,''), expiry_date
		FROM goods_receipt_lines WHERE gr_id = $1 ORDER BY id
	`, grID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var lines []whmodels.GoodsReceiptLine
	for rows.Next() {
		var l whmodels.GoodsReceiptLine
		if err := rows.Scan(&l.ID, &l.GRID, &l.ProductID, &l.ReceivedQty, &l.RejectedQty,
			&l.UnitCost, &l.TotalCost, &l.BatchNo, &l.ExpiryDate); err != nil {
			return nil, err
		}
		lines = append(lines, l)
	}
	return lines, nil
}

func (r *WarehouseRepo) PostGR(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	now := time.Now()

	// Update GR status
	_, err = tx.Exec(ctx, `UPDATE goods_receipts SET status = 'posted', posted_at = $1, posted_by = $2 WHERE id = $3 AND tenant_id = $4`,
		now, userID, id, tenantID)
	if err != nil {
		return fmt.Errorf("update gr status: %w", err)
	}

	// Get GR info
	var warehouseID uuid.UUID
	var grNo string
	err = tx.QueryRow(ctx, `SELECT warehouse_id, gr_no FROM goods_receipts WHERE id = $1 AND tenant_id = $2`, id, tenantID).Scan(&warehouseID, &grNo)
	if err != nil {
		return fmt.Errorf("get gr: %w", err)
	}

	// Get lines directly via tx
	lineRows, err := tx.Query(ctx, `
		SELECT id, product_id, received_qty, unit_cost, total_cost, COALESCE(batch_no,'')
		FROM goods_receipt_lines WHERE gr_id = $1 ORDER BY id
	`, id)
	if err != nil {
		return fmt.Errorf("query gr lines: %w", err)
	}
	defer lineRows.Close()

	type grLineBrief struct {
		ProductID   uuid.UUID
		ReceivedQty float64
		UnitCost    float64
		TotalCost   float64
		BatchNo     string
	}
	var lines []grLineBrief
	for lineRows.Next() {
		var l grLineBrief
		if err := lineRows.Scan(&l.ProductID, &l.ReceivedQty, &l.UnitCost, &l.TotalCost, &l.BatchNo); err != nil {
			return fmt.Errorf("scan gr line: %w", err)
		}
		lines = append(lines, l)
	}
	lineRows.Close()

	for _, line := range lines {
		// Create stock movement
		movementID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO stock_movements (id, tenant_id, transaction_type,
				reference_type, reference_id, reference_no,
				product_id, warehouse_id, quantity, unit_cost, total_cost,
				status, created_by, created_at, posted_at, posted_by)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
		`, movementID, tenantID, "goods_receipt",
			"goods_receipt", &id, grNo,
			line.ProductID, warehouseID, line.ReceivedQty, line.UnitCost, line.TotalCost,
			"posted", userID, now, now, userID)
		if err != nil {
			return fmt.Errorf("insert movement: %w", err)
		}

		// Update stock_items (upsert)
		_, err = tx.Exec(ctx, `
			INSERT INTO stock_items (id, tenant_id, product_id, warehouse_id,
				quantity_on_hand, unit_cost, total_cost, created_at, updated_at)
			VALUES (uuid_generate_v4(), $1, $2, $3, $4, $5, $6, NOW(), NOW())
			ON CONFLICT (tenant_id, product_id, warehouse_id, bin_id) DO UPDATE SET
				quantity_on_hand = stock_items.quantity_on_hand + $4,
				unit_cost = $5,
				total_cost = stock_items.total_cost + $6,
				last_movement_at = NOW(),
				updated_at = NOW()
		`, tenantID, line.ProductID, warehouseID, line.ReceivedQty, line.UnitCost, line.TotalCost)
		if err != nil {
			return fmt.Errorf("upsert stock: %w", err)
		}
	}

	return tx.Commit(ctx)
}

// ═══════════════════════════════════════════════════════════════
// Outbound Order (REQ-OB-001~018)
// ═══════════════════════════════════════════════════════════════

func (r *WarehouseRepo) CreateOutbound(ctx context.Context, tenantID, userID uuid.UUID, req *whmodels.CreateOutboundRequest) (*whmodels.OutboundOrder, error) {
	now := time.Now()
	headerWarehouseID := uuid.Nil
	if req.WarehouseID != nil {
		headerWarehouseID = *req.WarehouseID
	}
	if headerWarehouseID == uuid.Nil {
		for _, line := range req.Lines {
			if line.WarehouseID != nil && *line.WarehouseID != uuid.Nil {
				headerWarehouseID = *line.WarehouseID
				break
			}
		}
	}
	if headerWarehouseID == uuid.Nil {
		return nil, fmt.Errorf("warehouse is required on outbound header or item line")
	}
	ob := &whmodels.OutboundOrder{
		ID:           uuid.New(),
		TenantID:     tenantID,
		OrderNo:      fmt.Sprintf("OB-%s", uuid.New().String()[:8]),
		OrderType:    req.OrderType,
		ReferenceNo:  req.ReferenceNo,
		WarehouseID:  headerWarehouseID,
		CustomerName: req.CustomerName,
		Status:       "draft",
		Priority:     "normal",
		CreatedBy:    userID,
		CreatedAt:    now,
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO outbound_orders (id, tenant_id, order_no, order_type, reference_no,
			warehouse_id, customer_name, status, priority, notes, created_by, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
	`, ob.ID, ob.TenantID, ob.OrderNo, ob.OrderType, ob.ReferenceNo,
		ob.WarehouseID, ob.CustomerName, ob.Status, ob.Priority, "", ob.CreatedBy, ob.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert outbound: %w", err)
	}

	for _, line := range req.Lines {
		lineID := uuid.New()
		lineWarehouseID := headerWarehouseID
		if line.WarehouseID != nil && *line.WarehouseID != uuid.Nil {
			lineWarehouseID = *line.WarehouseID
		}
		_, err = tx.Exec(ctx, `
			INSERT INTO outbound_order_lines (id, order_id, product_id, warehouse_id, from_bin_id, ordered_qty, picked_qty, shipped_qty, pick_status)
			VALUES ($1,$2,$3,$4,$5,$6,0,0,'pending')
		`, lineID, ob.ID, line.ProductID, lineWarehouseID, line.BinID, line.OrderedQty)
		if err != nil {
			return nil, fmt.Errorf("insert outbound line: %w", err)
		}
		obLine := whmodels.OutboundOrderLine{
			ID: lineID, OrderID: ob.ID, ProductID: line.ProductID, WarehouseID: &lineWarehouseID, BinID: line.BinID,
			OrderedQty: line.OrderedQty,
		}
		ob.Lines = append(ob.Lines, obLine)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit outbound: %w", err)
	}
	return ob, nil
}

func (r *WarehouseRepo) ListOutbound(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.OutboundOrder, error) {
	rows, err := r.db.Query(ctx, `
        SELECT o.id, o.tenant_id, o.order_no, o.order_type,
            COALESCE(o.reference_no,''), o.warehouse_id, COALESCE(w.name,''),
            COALESCE(o.customer_name,''), o.status, o.priority,
            COALESCE(o.notes,''), o.created_by, o.created_at, o.shipped_at, o.delivered_at,
            o.gl_je_id, COALESCE(o.is_reversed, false), o.reversed_at
        FROM outbound_orders o
        LEFT JOIN warehouses w ON w.id = o.warehouse_id
        WHERE o.tenant_id = $1
        ORDER BY o.created_at DESC
    `, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*whmodels.OutboundOrder
	for rows.Next() {
		ob := &whmodels.OutboundOrder{}
		if err := rows.Scan(
			&ob.ID, &ob.TenantID, &ob.OrderNo, &ob.OrderType,
			&ob.ReferenceNo, &ob.WarehouseID, &ob.WarehouseName,
			&ob.CustomerName, &ob.Status, &ob.Priority,
			&ob.Notes, &ob.CreatedBy, &ob.CreatedAt, &ob.ShippedAt, &ob.DeliveredAt,
			&ob.GLJEID, &ob.IsReversed, &ob.ReversedAt,
		); err != nil {
			return nil, err
		}
		lines, err := r.getOutboundLines(ctx, ob.ID)
		if err != nil {
			return nil, err
		}
		ob.Lines = lines
		list = append(list, ob)
	}
	return list, nil
}

func (r *WarehouseRepo) getOutboundLines(ctx context.Context, orderID uuid.UUID) ([]whmodels.OutboundOrderLine, error) {
	rows, err := r.db.Query(ctx, `
        SELECT l.id, l.order_id, l.product_id,
            l.warehouse_id, COALESCE(w.name,''), l.from_bin_id, COALESCE(b.code,''),
            COALESCE(p.sku,''), COALESCE(p.name,''),
            l.ordered_qty, l.picked_qty, l.shipped_qty,
            COALESCE(l.unit_cost, 0), COALESCE(l.total_cost, 0), COALESCE(l.batch_no,'')
        FROM outbound_order_lines l
        LEFT JOIN products p ON p.id = l.product_id
        LEFT JOIN warehouses w ON w.id = l.warehouse_id
        LEFT JOIN warehouse_bins b ON b.id = l.from_bin_id
        WHERE l.order_id = $1 ORDER BY l.id
    `, orderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var lines []whmodels.OutboundOrderLine
	for rows.Next() {
		var l whmodels.OutboundOrderLine
		if err := rows.Scan(&l.ID, &l.OrderID, &l.ProductID,
			&l.WarehouseID, &l.WarehouseName, &l.BinID, &l.BinCode,
			&l.ProductSKU, &l.ProductName,
			&l.OrderedQty, &l.PickedQty, &l.ShippedQty, &l.UnitCost, &l.TotalCost, &l.BatchNo); err != nil {
			return nil, err
		}
		lines = append(lines, l)
	}
	return lines, nil
}

func (r *WarehouseRepo) ShipOutbound(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	now := time.Now()

	// Update status
	// Get info
	var warehouseID uuid.UUID
	var orderNo, orderType, referenceNo, status string
	var isReversed bool
	err = tx.QueryRow(ctx, `
		SELECT warehouse_id, order_no, order_type, COALESCE(reference_no,''), status, COALESCE(is_reversed, false)
		FROM outbound_orders
		WHERE id = $1 AND tenant_id = $2
		FOR UPDATE
	`, id, tenantID).Scan(&warehouseID, &orderNo, &orderType, &referenceNo, &status, &isReversed)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}
	if isReversed {
		return fmt.Errorf("outbound order %s is reversed", orderNo)
	}
	if status == "issued" || status == "shipped" {
		return fmt.Errorf("outbound order %s is already issued", orderNo)
	}

	// Get lines directly via tx
	lineRows, err := tx.Query(ctx, `
        SELECT l.id, l.product_id, COALESCE(l.warehouse_id, $2), l.from_bin_id,
            l.ordered_qty, l.shipped_qty, COALESCE(l.batch_no,''),
            COALESCE(
                NULLIF(si.unit_cost, 0),
                NULLIF(si.total_cost / NULLIF(si.quantity_on_hand, 0), 0),
                NULLIF(p.standard_cost, 0),
                NULLIF(p.moving_avg_cost, 0),
                NULLIF(p.last_cost, 0),
                0
            )
        FROM outbound_order_lines l
        JOIN products p ON p.id = l.product_id
        LEFT JOIN stock_items si ON si.tenant_id = $3
            AND si.product_id = l.product_id
            AND si.warehouse_id = COALESCE(l.warehouse_id, $2)
            AND ((l.from_bin_id IS NULL AND si.bin_id IS NULL) OR si.bin_id = l.from_bin_id)
        WHERE l.order_id = $1 ORDER BY l.id
    `, id, warehouseID, tenantID)
	if err != nil {
		return fmt.Errorf("query lines: %w", err)
	}
	defer lineRows.Close()

	type obLineBrief struct {
		ID          uuid.UUID
		ProductID   uuid.UUID
		WarehouseID uuid.UUID
		BinID       *uuid.UUID
		OrderedQty  float64
		ShippedQty  float64
		BatchNo     string
		UnitCost    float64
	}
	var lines []obLineBrief
	for lineRows.Next() {
		var l obLineBrief
		if err := lineRows.Scan(&l.ID, &l.ProductID, &l.WarehouseID, &l.BinID, &l.OrderedQty, &l.ShippedQty, &l.BatchNo, &l.UnitCost); err != nil {
			return fmt.Errorf("scan line: %w", err)
		}
		lines = append(lines, l)
	}
	lineRows.Close()

	for _, line := range lines {
		shipQty := line.ShippedQty
		if shipQty <= 0 {
			shipQty = line.OrderedQty
		}
		if line.UnitCost <= 0 {
			return fmt.Errorf("cost is required before issuing product %s", line.ProductID)
		}

		// Update shipped quantity
		totalCost := shipQty * line.UnitCost
		_, err = tx.Exec(ctx, `UPDATE outbound_order_lines SET shipped_qty = $1, unit_cost = $2, total_cost = $3 WHERE id = $4`,
			shipQty, line.UnitCost, totalCost, line.ID)
		if err != nil {
			return fmt.Errorf("update line: %w", err)
		}

		// Create stock movement
		movementID := uuid.New()
		_, err = tx.Exec(ctx, `
            INSERT INTO stock_movements (id, tenant_id, transaction_type,
                reference_type, reference_id, reference_no,
                product_id, warehouse_id, bin_id, quantity, unit_cost, total_cost,
                status, created_by, created_at, posted_at, posted_by)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
        `, movementID, tenantID, "goods_issue",
			"outbound_order", &id, orderNo,
			line.ProductID, line.WarehouseID, line.BinID, -shipQty, line.UnitCost, -totalCost,
			"posted", userID, now, now, userID)
		if err != nil {
			return fmt.Errorf("insert movement: %w", err)
		}

		// Update stock_items (decrease)
		_, err = tx.Exec(ctx, `
            UPDATE stock_items
            SET quantity_on_hand = GREATEST(quantity_on_hand - $1, 0),
                last_movement_at = NOW(),
                updated_at = NOW()
            WHERE tenant_id = $2 AND product_id = $3 AND warehouse_id = $4
              AND (($5::uuid IS NULL AND bin_id IS NULL) OR bin_id = $5)
        `, shipQty, tenantID, line.ProductID, line.WarehouseID, line.BinID)
		if err != nil {
			return fmt.Errorf("update stock: %w", err)
		}
		if orderType == "work_order" && referenceNo != "" {
			_, err = tx.Exec(ctx, `
				UPDATE production_order_materials pom
				SET issue_qty = issue_qty + $1, updated_at = NOW()
				FROM production_orders po
				WHERE pom.production_order_id = po.id
				  AND pom.tenant_id = $2
				  AND po.tenant_id = $2
				  AND po.order_number = $3
				  AND pom.component_id = $4
			`, shipQty, tenantID, referenceNo, line.ProductID)
			if err != nil {
				return fmt.Errorf("update work order issued material qty: %w", err)
			}
		}
	}

	_, err = tx.Exec(ctx, `UPDATE outbound_orders SET status = 'issued', shipped_at = $1 WHERE id = $2 AND tenant_id = $3`,
		now, id, tenantID)
	if err != nil {
		return fmt.Errorf("update status: %w", err)
	}

	return tx.Commit(ctx)
}

// ═══════════════════════════════════════════════════════════════
// Cycle Count (REQ-CC-001~008)
// ═══════════════════════════════════════════════════════════════

func (r *WarehouseRepo) UpdateOutbound(ctx context.Context, id, tenantID uuid.UUID, req *whmodels.CreateOutboundRequest) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin outbound update tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var status string
	if err := tx.QueryRow(ctx, `
		SELECT status FROM outbound_orders WHERE id = $1 AND tenant_id = $2 FOR UPDATE
	`, id, tenantID).Scan(&status); err != nil {
		return fmt.Errorf("load outbound order: %w", err)
	}
	if status != "draft" {
		return fmt.Errorf("only draft outbound orders can be edited")
	}

	headerWarehouseID := uuid.Nil
	if req.WarehouseID != nil {
		headerWarehouseID = *req.WarehouseID
	}
	if headerWarehouseID == uuid.Nil {
		for _, line := range req.Lines {
			if line.WarehouseID != nil && *line.WarehouseID != uuid.Nil {
				headerWarehouseID = *line.WarehouseID
				break
			}
		}
	}
	if headerWarehouseID == uuid.Nil {
		return fmt.Errorf("warehouse is required on outbound header or item line")
	}

	_, err = tx.Exec(ctx, `
		UPDATE outbound_orders
		SET order_type = $1, reference_no = $2, warehouse_id = $3, customer_name = $4
		WHERE id = $5 AND tenant_id = $6
	`, req.OrderType, req.ReferenceNo, headerWarehouseID, req.CustomerName, id, tenantID)
	if err != nil {
		return fmt.Errorf("update outbound order: %w", err)
	}

	_, err = tx.Exec(ctx, `DELETE FROM outbound_order_lines WHERE order_id = $1`, id)
	if err != nil {
		return fmt.Errorf("replace outbound lines: %w", err)
	}
	for _, line := range req.Lines {
		lineWarehouseID := headerWarehouseID
		if line.WarehouseID != nil && *line.WarehouseID != uuid.Nil {
			lineWarehouseID = *line.WarehouseID
		}
		_, err = tx.Exec(ctx, `
			INSERT INTO outbound_order_lines (id, order_id, product_id, warehouse_id, from_bin_id, ordered_qty, picked_qty, shipped_qty, pick_status)
			VALUES ($1,$2,$3,$4,$5,$6,0,0,'pending')
		`, uuid.New(), id, line.ProductID, lineWarehouseID, line.BinID, line.OrderedQty)
		if err != nil {
			return fmt.Errorf("insert outbound line: %w", err)
		}
	}
	return tx.Commit(ctx)
}

func (r *WarehouseRepo) LinkOutboundJournalEntry(ctx context.Context, id, tenantID, jeID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE outbound_orders SET gl_je_id = $1 WHERE id = $2 AND tenant_id = $3`, jeID, id, tenantID)
	return err
}

func (r *WarehouseRepo) GetOutboundByID(ctx context.Context, id, tenantID uuid.UUID) (*whmodels.OutboundOrder, error) {
	list, err := r.ListOutbound(ctx, tenantID)
	if err != nil {
		return nil, err
	}
	for _, ob := range list {
		if ob.ID == id {
			return ob, nil
		}
	}
	return nil, fmt.Errorf("outbound order not found")
}

func (r *WarehouseRepo) ReverseOutbound(ctx context.Context, id, tenantID, userID uuid.UUID) (*uuid.UUID, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin outbound reverse tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var warehouseID uuid.UUID
	var orderNo, orderType, referenceNo, status string
	var glJEID *uuid.UUID
	var isReversed bool
	err = tx.QueryRow(ctx, `
		SELECT warehouse_id, order_no, order_type, COALESCE(reference_no,''), status, gl_je_id, COALESCE(is_reversed, false)
		FROM outbound_orders
		WHERE id = $1 AND tenant_id = $2
		FOR UPDATE
	`, id, tenantID).Scan(&warehouseID, &orderNo, &orderType, &referenceNo, &status, &glJEID, &isReversed)
	if err != nil {
		return nil, fmt.Errorf("load outbound order: %w", err)
	}
	if isReversed {
		return nil, fmt.Errorf("outbound order %s is already reversed", orderNo)
	}
	if status != "issued" && status != "shipped" {
		return nil, fmt.Errorf("only issued outbound orders can be reversed")
	}

	rows, err := tx.Query(ctx, `
		SELECT id, product_id, COALESCE(warehouse_id, $2), from_bin_id,
			shipped_qty, COALESCE(unit_cost, 0), COALESCE(total_cost, 0)
		FROM outbound_order_lines
		WHERE order_id = $1
	`, id, warehouseID)
	if err != nil {
		return nil, fmt.Errorf("load outbound lines: %w", err)
	}
	type lineBrief struct {
		ID          uuid.UUID
		ProductID   uuid.UUID
		WarehouseID uuid.UUID
		BinID       *uuid.UUID
		Qty         float64
		UnitCost    float64
		TotalCost   float64
	}
	var lines []lineBrief
	for rows.Next() {
		var l lineBrief
		if err := rows.Scan(&l.ID, &l.ProductID, &l.WarehouseID, &l.BinID, &l.Qty, &l.UnitCost, &l.TotalCost); err != nil {
			rows.Close()
			return nil, err
		}
		lines = append(lines, l)
	}
	rows.Close()

	now := time.Now()
	for _, line := range lines {
		if line.Qty <= 0 {
			continue
		}
		_, err = tx.Exec(ctx, `
			UPDATE stock_items
			SET quantity_on_hand = quantity_on_hand + $1,
				total_cost = total_cost + $2,
				last_movement_at = NOW(),
				updated_at = NOW()
			WHERE tenant_id = $3 AND product_id = $4 AND warehouse_id = $5
			  AND (($6::uuid IS NULL AND bin_id IS NULL) OR bin_id = $6)
		`, line.Qty, line.TotalCost, tenantID, line.ProductID, line.WarehouseID, line.BinID)
		if err != nil {
			return nil, fmt.Errorf("reverse outbound stock: %w", err)
		}
		_, err = tx.Exec(ctx, `
			INSERT INTO stock_movements (id, tenant_id, transaction_type,
				reference_type, reference_id, reference_no,
				product_id, warehouse_id, bin_id, quantity, unit_cost, total_cost,
				description, status, created_by, created_at, posted_at, posted_by)
			VALUES ($1,$2,'goods_issue','outbound_order',$3,$4,$5,$6,$7,$8,$9,$10,
				'Goods Issue Reversal','posted',$11,$12,$12,$11)
		`, uuid.New(), tenantID, id, orderNo, line.ProductID, line.WarehouseID, line.BinID, line.Qty,
			line.UnitCost, line.TotalCost, userID, now)
		if err != nil {
			return nil, fmt.Errorf("insert outbound reversal movement: %w", err)
		}
		_, err = tx.Exec(ctx, `UPDATE outbound_order_lines SET shipped_qty = 0 WHERE id = $1`, line.ID)
		if err != nil {
			return nil, fmt.Errorf("reset outbound line shipped qty: %w", err)
		}
		if orderType == "work_order" && referenceNo != "" {
			_, err = tx.Exec(ctx, `
				UPDATE production_order_materials pom
				SET issue_qty = GREATEST(0, issue_qty - $1), updated_at = NOW()
				FROM production_orders po
				WHERE pom.production_order_id = po.id
				  AND pom.tenant_id = $2
				  AND po.tenant_id = $2
				  AND po.order_number = $3
				  AND pom.component_id = $4
			`, line.Qty, tenantID, referenceNo, line.ProductID)
			if err != nil {
				return nil, fmt.Errorf("reverse work order issued material qty: %w", err)
			}
		}
	}

	_, err = tx.Exec(ctx, `
		UPDATE outbound_orders
		SET status = 'reversed', is_reversed = true, reversed_at = $1
		WHERE id = $2 AND tenant_id = $3
	`, now, id, tenantID)
	if err != nil {
		return nil, fmt.Errorf("mark outbound reversed: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit outbound reverse tx: %w", err)
	}
	return glJEID, nil
}

func (r *WarehouseRepo) CreateCycleCount(ctx context.Context, tenantID uuid.UUID, req *whmodels.CreateCycleCountRequest) (*whmodels.CycleCount, error) {
	cc := &whmodels.CycleCount{
		ID:          uuid.New(),
		TenantID:    tenantID,
		CountNo:     fmt.Sprintf("CC-%s", uuid.New().String()[:8]),
		WarehouseID: req.WarehouseID,
		ProductID:   req.ProductID,
		BinID:       req.BinID,
		Status:      "open",
		CreatedAt:   time.Now(),
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO cycle_counts (id, tenant_id, count_no, count_type,
			warehouse_id, zone_id, bin_id, product_id, status, ai_suggested, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
	`, cc.ID, cc.TenantID, cc.CountNo, req.CountType,
		cc.WarehouseID, req.ZoneID, req.BinID, req.ProductID, cc.Status, false, cc.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("create cycle count: %w", err)
	}
	return cc, nil
}

func (r *WarehouseRepo) ListCycleCounts(ctx context.Context, tenantID uuid.UUID) ([]*whmodels.CycleCount, error) {
	rows, err := r.db.Query(ctx, `
		SELECT cc.id, cc.tenant_id, cc.count_no, COALESCE(cc.count_type,'cycle'),
			cc.warehouse_id, cc.product_id, cc.bin_id,
			cc.status, cc.ai_suggested, cc.created_at,
			COALESCE(p.name,''), COALESCE(b.code,'')
		FROM cycle_counts cc
		LEFT JOIN products p ON p.id = cc.product_id
		LEFT JOIN warehouse_bins b ON b.id = cc.bin_id
		WHERE cc.tenant_id = $1
		ORDER BY cc.created_at DESC
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*whmodels.CycleCount
	for rows.Next() {
		ec := &whmodels.CycleCount{}
		if err := rows.Scan(
			&ec.ID, &ec.TenantID, &ec.CountNo, &ec.CountType,
			&ec.WarehouseID, &ec.ProductID, &ec.BinID,
			&ec.Status, &ec.AISuggested, &ec.CreatedAt,
			&ec.ProductName, &ec.BinCode,
		); err != nil {
			return nil, err
		}
		list = append(list, ec)
	}
	return list, nil
}

func (r *WarehouseRepo) AISuggestCycleCounts(ctx context.Context, tenantID uuid.UUID, count int) ([]*whmodels.CycleCount, error) {
	// Select random products for cycle count suggestion
	rows, err := r.db.Query(ctx, `
		SELECT p.id, p.name, p.sku
		FROM products p
		WHERE p.tenant_id = $1 AND p.is_active = true
		ORDER BY RANDOM()
		LIMIT $2
	`, tenantID, count)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type candidate struct {
		ID   uuid.UUID
		Name string
		SKU  string
	}
	var candidates []candidate
	for rows.Next() {
		var c candidate
		if err := rows.Scan(&c.ID, &c.Name, &c.SKU); err != nil {
			return nil, err
		}
		candidates = append(candidates, c)
	}

	if len(candidates) == 0 {
		return nil, nil
	}

	// Find a warehouse for this tenant
	var warehouseID uuid.UUID
	err = r.db.QueryRow(ctx, `SELECT id FROM warehouses WHERE tenant_id = $1 LIMIT 1`, tenantID).Scan(&warehouseID)
	if err != nil {
		// No warehouse exists; use a nil UUID - let it fail gracefully
		warehouseID = uuid.Nil
	}

	var results []*whmodels.CycleCount
	for _, c := range candidates {
		cc := &whmodels.CycleCount{
			ID:          uuid.New(),
			TenantID:    tenantID,
			CountNo:     fmt.Sprintf("CC-%s", uuid.New().String()[:8]),
			WarehouseID: warehouseID,
			ProductID:   &c.ID,
			Status:      "open",
			AISuggested: true,
			CreatedAt:   time.Now(),
		}
		_, err := r.db.Exec(ctx, `
			INSERT INTO cycle_counts (id, tenant_id, count_no, count_type,
				warehouse_id, product_id, status, ai_suggested, created_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		`, cc.ID, cc.TenantID, cc.CountNo, "aiprompted",
			cc.WarehouseID, cc.ProductID, cc.Status, true, cc.CreatedAt)
		if err != nil {
			continue
		}
		results = append(results, cc)
	}
	return results, nil
}

// ═══════════════════════════════════════════════════════════════
// Warehouse Tasks (REQ-IO-014~018)
// ═══════════════════════════════════════════════════════════════

func (r *WarehouseRepo) ListTasks(ctx context.Context, tenantID uuid.UUID, status string) ([]*whmodels.WarehouseTask, error) {
	query := `
		SELECT t.id, t.tenant_id, t.task_type,
			COALESCE(t.reference_type,''), t.reference_id,
			t.product_id, COALESCE(p.name,''),
			t.from_warehouse_id, t.from_bin_id,
			t.to_warehouse_id, t.to_bin_id,
			t.quantity, COALESCE(t.uom,'EA'),
			COALESCE(t.batch_no,''),
			t.status, t.priority, t.assigned_to,
			COALESCE(t.notes,''), t.created_by, t.created_at
		FROM warehouse_tasks t
		LEFT JOIN products p ON p.id = t.product_id
		WHERE t.tenant_id = $1
	`
	args := []interface{}{tenantID}
	argIdx := 2

	if status != "" {
		query += fmt.Sprintf(" AND t.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	query += " ORDER BY t.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*whmodels.WarehouseTask
	for rows.Next() {
		t := &whmodels.WarehouseTask{}
		if err := rows.Scan(
			&t.ID, &t.TenantID, &t.TaskType,
			&t.ReferenceType, &t.ReferenceID,
			&t.ProductID, &t.ProductName,
			&t.FromWarehouseID, &t.FromBinID,
			&t.ToWarehouseID, &t.ToBinID,
			&t.Quantity, &t.UOM,
			&t.BatchNo,
			&t.Status, &t.Priority, &t.AssignedTo,
			&t.Notes, &t.CreatedBy, &t.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, t)
	}
	return list, nil
}

func (r *WarehouseRepo) CompleteTask(ctx context.Context, id, userID uuid.UUID) error {
	now := time.Now()
	_, err := r.db.Exec(ctx, `
		UPDATE warehouse_tasks SET status = 'completed', completed_at = $1, updated_at = $1
		WHERE id = $2
	`, now, id)
	return err
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func normalizeMRPType(value string) (string, error) {
	normalized := strings.ToUpper(strings.TrimSpace(value))
	if normalized == "" {
		return "MPS", nil
	}
	switch normalized {
	case "MPS", "MRP", "NO":
		return normalized, nil
	default:
		return "", fmt.Errorf("invalid mrp_type %q; expected MPS, MRP, or NO", value)
	}
}

func normalizeProcurementType(value string) string {
	normalized := strings.ToLower(strings.TrimSpace(value))
	switch normalized {
	case "purchase", "mixed":
		return normalized
	default:
		return "in-house"
	}
}

func alignProductPlantData(rows []whmodels.ProductPlantData, mrpType, procurementType string) []whmodels.ProductPlantData {
	if rows == nil {
		return nil
	}
	normalizedMRPType, err := normalizeMRPType(mrpType)
	if err != nil {
		normalizedMRPType = "MPS"
	}
	normalizedProcurementType := normalizeProcurementType(procurementType)
	aligned := make([]whmodels.ProductPlantData, len(rows))
	for i, row := range rows {
		row.MRPType = normalizedMRPType
		if strings.TrimSpace(row.ProcurementType) == "" {
			row.ProcurementType = normalizedProcurementType
		}
		aligned[i] = row
	}
	return aligned
}

func (r *ProductRepo) loadProductPlantData(ctx context.Context, tenantID, productID uuid.UUID) ([]whmodels.ProductPlantData, error) {
	rows, err := r.db.Query(ctx, `SELECT ppd.id, ppd.tenant_id, ppd.product_id, ppd.site_id,
			COALESCE(s.site_code,''), COALESCE(s.site_name,''),
			ppd.mrp_type, ppd.procurement_type, ppd.safety_stock, ppd.reorder_point, ppd.reorder_qty,
			ppd.lead_time_days, ppd.planning_time_fence_days,
			ppd.default_production_warehouse_id, ppd.default_receiving_warehouse_id,
			ppd.standard_cost, ppd.moving_avg_cost, COALESCE(ppd.valuation_class,''), ppd.is_active
		FROM product_plant_data ppd
		LEFT JOIN sites s ON s.id = ppd.site_id
		WHERE ppd.tenant_id = $1 AND ppd.product_id = $2
		ORDER BY s.site_code`, tenantID, productID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []whmodels.ProductPlantData
	for rows.Next() {
		var row whmodels.ProductPlantData
		if err := rows.Scan(&row.ID, &row.TenantID, &row.ProductID, &row.SiteID,
			&row.SiteCode, &row.SiteName, &row.MRPType, &row.ProcurementType,
			&row.SafetyStock, &row.ReorderPoint, &row.ReorderQty, &row.LeadTimeDays,
			&row.PlanningTimeFenceDays, &row.DefaultProductionWarehouseID, &row.DefaultReceivingWarehouseID,
			&row.StandardCost, &row.MovingAvgCost, &row.ValuationClass, &row.IsActive); err != nil {
			return nil, err
		}
		list = append(list, row)
	}
	return list, nil
}

func (r *ProductRepo) syncProductPlantData(ctx context.Context, productID, tenantID uuid.UUID, rows []whmodels.ProductPlantData) error {
	for _, row := range rows {
		if row.SiteID == uuid.Nil {
			continue
		}
		mrpType, err := normalizeMRPType(row.MRPType)
		if err != nil {
			return err
		}
		procurementType := normalizeProcurementType(row.ProcurementType)
		fenceDays := row.PlanningTimeFenceDays
		if fenceDays <= 0 {
			fenceDays = 5
		}
		_, err = r.db.Exec(ctx, `INSERT INTO product_plant_data
			(id, tenant_id, product_id, site_id, mrp_type, procurement_type, safety_stock,
			 reorder_point, reorder_qty, lead_time_days, planning_time_fence_days,
			 default_production_warehouse_id, default_receiving_warehouse_id,
			 standard_cost, moving_avg_cost, valuation_class, is_active, updated_at)
			VALUES (gen_random_uuid(), $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,NOW())
			ON CONFLICT (tenant_id, product_id, site_id) DO UPDATE SET
				mrp_type = EXCLUDED.mrp_type,
				procurement_type = EXCLUDED.procurement_type,
				safety_stock = EXCLUDED.safety_stock,
				reorder_point = EXCLUDED.reorder_point,
				reorder_qty = EXCLUDED.reorder_qty,
				lead_time_days = EXCLUDED.lead_time_days,
				planning_time_fence_days = EXCLUDED.planning_time_fence_days,
				default_production_warehouse_id = EXCLUDED.default_production_warehouse_id,
				default_receiving_warehouse_id = EXCLUDED.default_receiving_warehouse_id,
				standard_cost = EXCLUDED.standard_cost,
				moving_avg_cost = EXCLUDED.moving_avg_cost,
				valuation_class = EXCLUDED.valuation_class,
				is_active = EXCLUDED.is_active,
				updated_at = NOW()`,
			tenantID, productID, row.SiteID, mrpType, procurementType, row.SafetyStock,
			row.ReorderPoint, row.ReorderQty, row.LeadTimeDays, fenceDays,
			row.DefaultProductionWarehouseID, row.DefaultReceivingWarehouseID,
			row.StandardCost, row.MovingAvgCost, nullIfEmpty(row.ValuationClass), row.IsActive)
		if err != nil {
			return fmt.Errorf("sync product plant data: %w", err)
		}
	}
	return nil
}

func nullIfEmptyP(s *string) *string {
	if s == nil {
		return nil
	}
	if *s == "" {
		return nil
	}
	return s
}
