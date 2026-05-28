package service

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	whrepo "github.com/swiftai-erp/backend/internal/warehouse/repository"

	whmodels "github.com/swiftai-erp/backend/internal/warehouse/models"
)

// WarehouseService coordinates warehouse operations.
type WarehouseService struct {
	db         *pgxpool.Pool
	productRepo *whrepo.ProductRepo
	warehouseRepo *whrepo.WarehouseRepo
}

func NewWarehouseService(db *pgxpool.Pool, productRepo *whrepo.ProductRepo, warehouseRepo *whrepo.WarehouseRepo) *WarehouseService {
	return &WarehouseService{
		db:            db,
		productRepo:   productRepo,
		warehouseRepo: warehouseRepo,
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
        if err != nil { return nil, fmt.Errorf("list stock grouped: %w", err) }
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
    if err != nil { return nil, fmt.Errorf("list stock detail: %w", err) }
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

func (s *WarehouseService) ShipOutbound(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	return s.warehouseRepo.ShipOutbound(ctx, id, tenantID, userID)
}

// ═══════════════════════════════════════════════════════════════
// Cycle Count (REQ-CC-001~008)
// ═══════════════════════════════════════════════════════════════

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