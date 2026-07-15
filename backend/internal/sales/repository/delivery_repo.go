package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
)

func (r *SalesRepo) ensureDeliveryTables(ctx context.Context) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS sales_delivery_notes (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			delivery_no VARCHAR(30) NOT NULL,
			sales_order_id UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
			customer_id UUID NOT NULL REFERENCES customers(id),
			warehouse_id UUID NOT NULL REFERENCES warehouses(id),
			selection_date DATE NOT NULL DEFAULT CURRENT_DATE,
			ship_to_name VARCHAR(200) DEFAULT '',
			ship_to_phone VARCHAR(80) DEFAULT '',
			ship_to_address TEXT DEFAULT '',
			shipping_method VARCHAR(80) DEFAULT '',
			route VARCHAR(120) DEFAULT '',
			status VARCHAR(30) NOT NULL DEFAULT 'CREATED',
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			pgi_at TIMESTAMPTZ,
			UNIQUE(tenant_id, delivery_no)
		)`,
		`CREATE TABLE IF NOT EXISTS sales_delivery_note_items (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			delivery_id UUID NOT NULL REFERENCES sales_delivery_notes(id) ON DELETE CASCADE,
			so_item_id UUID NOT NULL REFERENCES sales_order_items(id),
			item_no INT NOT NULL,
			product_id UUID NOT NULL REFERENCES products(id),
			order_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			delivery_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			picked_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			unit_of_measure VARCHAR(20) DEFAULT 'EA',
			stock_loc VARCHAR(120) DEFAULT '',
			pgi_status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`,
		`CREATE TABLE IF NOT EXISTS sales_billing_queue (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			delivery_id UUID NOT NULL REFERENCES sales_delivery_notes(id) ON DELETE CASCADE,
			sales_order_id UUID NOT NULL REFERENCES sales_orders(id),
			customer_id UUID NOT NULL REFERENCES customers(id),
			status VARCHAR(30) NOT NULL DEFAULT 'READY',
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`,
	}
	for _, stmt := range stmts {
		if _, err := r.db.Exec(ctx, stmt); err != nil {
			return err
		}
	}
	return nil
}

func (r *SalesRepo) nextDeliveryNo(ctx context.Context, tenantID uuid.UUID) string {
	prefix := "DO" + time.Now().Format("20060102")
	var seq int
	_ = r.db.QueryRow(ctx, `SELECT COALESCE(MAX(SUBSTRING(delivery_no FROM '.{4}$')::int),0)+1
		FROM sales_delivery_notes WHERE tenant_id=$1 AND delivery_no LIKE $2`, tenantID, prefix+"%").Scan(&seq)
	if seq < 1 {
		seq = 1
	}
	return fmt.Sprintf("%s%04d", prefix, seq)
}

func (r *SalesRepo) CreateDeliveryNote(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateDeliveryNoteRequest) (*salesmodels.DeliveryNote, error) {
	if err := r.ensureDeliveryTables(ctx); err != nil {
		return nil, err
	}
	if len(req.Items) == 0 {
		return nil, fmt.Errorf("please select at least one sales order item for the delivery note")
	}
	warehouseID, err := uuid.Parse(req.WarehouseID)
	if err != nil {
		return nil, fmt.Errorf("invalid warehouse")
	}
	selectionDate := time.Now().AddDate(0, 0, 2)
	if req.SelectionDate != "" {
		if parsed, err := time.Parse("2006-01-02", req.SelectionDate); err == nil {
			selectionDate = parsed
		}
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var soID, customerID uuid.UUID
	var shipToName, shipToPhone, shipToAddress, shippingMethod, route string
	err = tx.QueryRow(ctx, `SELECT so.id, so.customer_id, COALESCE(c.name,''), COALESCE(c.contact_phone,''),
			TRIM(CONCAT_WS(', ', NULLIF(c.shipping_street,''), NULLIF(c.shipping_city,''), NULLIF(c.shipping_state,''), NULLIF(c.shipping_zip,''), NULLIF(c.shipping_country,''))),
			COALESCE(so.shipping_method,''), COALESCE(so.transportation_to,'')
		FROM sales_orders so
		JOIN customers c ON c.id = so.customer_id
		WHERE so.tenant_id=$1 AND so.so_number=$2
			AND so.status IN ('CONFIRMED','PARTIALLY_DELIVERED')
		FOR UPDATE OF so`, tenantID, req.ReferenceNo).
		Scan(&soID, &customerID, &shipToName, &shipToPhone, &shipToAddress, &shippingMethod, &route)
	if err != nil {
		return nil, fmt.Errorf("load deliverable sales order: %w", err)
	}

	deliveryID := uuid.New()
	deliveryNo := r.nextDeliveryNo(ctx, tenantID)
	_, err = tx.Exec(ctx, `INSERT INTO sales_delivery_notes
		(id, tenant_id, delivery_no, sales_order_id, customer_id, warehouse_id, selection_date, ship_to_name, ship_to_phone, ship_to_address, shipping_method, route)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
		deliveryID, tenantID, deliveryNo, soID, customerID, warehouseID, selectionDate, shipToName, shipToPhone, shipToAddress, shippingMethod, route)
	if err != nil {
		return nil, fmt.Errorf("insert delivery: %w", err)
	}

	rows, err := tx.Query(ctx, `SELECT soi.id, soi.line_no, soi.product_id, soi.quantity, soi.unit_of_measure,
			COALESCE((SELECT SUM(dni.delivery_qty) FROM sales_delivery_note_items dni JOIN sales_delivery_notes dn ON dn.id=dni.delivery_id
				WHERE dni.so_item_id=soi.id AND dn.status <> 'CANCELLED'),0) AS delivered_qty
		FROM sales_order_items soi
		WHERE soi.so_id=$1 AND COALESCE(soi.delivery_date, CURRENT_DATE) <= $2
		ORDER BY soi.line_no
		FOR UPDATE OF soi`, soID, selectionDate)
	if err != nil {
		return nil, err
	}
	type deliverableLine struct {
		soItemID     uuid.UUID
		productID    uuid.UUID
		lineNo       int
		orderQty     float64
		deliveredQty float64
		uom          string
		requestQty   float64
	}
	requested := map[uuid.UUID]float64{}
	hasExplicitItems := len(req.Items) > 0
	if hasExplicitItems {
		for i, item := range req.Items {
			soItemID, err := uuid.Parse(item.SOItemID)
			if err != nil {
				return nil, fmt.Errorf("invalid so_item_id on delivery line %d", i+1)
			}
			if item.DeliveryQty <= 0 {
				return nil, fmt.Errorf("delivery qty must be greater than zero on line %d", i+1)
			}
			requested[soItemID] += item.DeliveryQty
		}
	}
	var lines []deliverableLine
	for rows.Next() {
		var line deliverableLine
		if err := rows.Scan(&line.soItemID, &line.lineNo, &line.productID, &line.orderQty, &line.uom, &line.deliveredQty); err != nil {
			rows.Close()
			return nil, err
		}
		if hasExplicitItems {
			qty, ok := requested[line.soItemID]
			if !ok {
				continue
			}
			line.requestQty = qty
			delete(requested, line.soItemID)
		}
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return nil, err
	}
	rows.Close()
	if len(requested) > 0 {
		return nil, fmt.Errorf("one or more selected sales order items are not deliverable for this order/date")
	}

	lineCount := 0
	for _, line := range lines {
		openQty := line.orderQty - line.deliveredQty
		if openQty <= 0 {
			continue
		}
		deliveryQty := openQty
		if line.requestQty > 0 {
			if line.requestQty > openQty {
				return nil, fmt.Errorf("line %d delivery qty %.2f exceeds open qty %.2f", line.lineNo, line.requestQty, openQty)
			}
			deliveryQty = line.requestQty
		}
		var available float64
		if err := tx.QueryRow(ctx, `SELECT COALESCE(SUM(quantity_on_hand - quantity_reserved),0)::float8
			FROM stock_items WHERE tenant_id=$1 AND product_id=$2 AND warehouse_id=$3`,
			tenantID, line.productID, warehouseID).Scan(&available); err != nil {
			return nil, fmt.Errorf("check available stock for line %d: %w", line.lineNo, err)
		}
		if available < deliveryQty && line.requestQty <= 0 {
			deliveryQty = available
		}
		if available < deliveryQty {
			return nil, fmt.Errorf("insufficient available stock for line %d: requested %.2f available %.2f", line.lineNo, deliveryQty, available)
		}
		if deliveryQty <= 0 {
			return nil, fmt.Errorf("insufficient available stock for line %d", line.lineNo)
		}
		var allocatedLoc string
		err = tx.QueryRow(ctx, `WITH target AS (
				SELECT si.id FROM stock_items si
				WHERE si.tenant_id=$1 AND si.product_id=$2 AND si.warehouse_id=$3 AND si.quantity_on_hand - si.quantity_reserved >= $4
				ORDER BY si.last_movement_at NULLS LAST, si.created_at
				LIMIT 1
			)
			UPDATE stock_items si SET quantity_reserved = quantity_reserved + $4, updated_at=NOW()
			WHERE si.id IN (SELECT id FROM target)
			RETURNING COALESCE(bin_id::text, warehouse_id::text)`, tenantID, line.productID, warehouseID, deliveryQty).Scan(&allocatedLoc)
		if err != nil {
			return nil, fmt.Errorf("soft allocate stock: %w", err)
		}
		_, err = tx.Exec(ctx, `INSERT INTO sales_delivery_note_items
			(id, delivery_id, so_item_id, item_no, product_id, order_qty, delivery_qty, unit_of_measure, stock_loc)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
			uuid.New(), deliveryID, line.soItemID, line.lineNo, line.productID, line.orderQty, deliveryQty, line.uom, allocatedLoc)
		if err != nil {
			return nil, fmt.Errorf("insert delivery item: %w", err)
		}
		lineCount++
	}
	if lineCount == 0 {
		return nil, fmt.Errorf("no open deliverable sales order items found")
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.GetDeliveryNote(ctx, deliveryID, tenantID)
}

func (r *SalesRepo) DeleteDeliveryNote(ctx context.Context, id, tenantID uuid.UUID) error {
	if err := r.ensureDeliveryTables(ctx); err != nil {
		return err
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var status string
	var warehouseID uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT status, warehouse_id FROM sales_delivery_notes
		WHERE id=$1 AND tenant_id=$2 FOR UPDATE`, id, tenantID).Scan(&status, &warehouseID); err != nil {
		return fmt.Errorf("load delivery note: %w", err)
	}
	if status == "PGI_POSTED" {
		return fmt.Errorf("cannot delete a PGI posted delivery note")
	}
	var pickedQty float64
	if err := tx.QueryRow(ctx, `SELECT COALESCE(SUM(picked_qty),0)::float8
		FROM sales_delivery_note_items WHERE delivery_id=$1`, id).Scan(&pickedQty); err != nil {
		return err
	}
	if pickedQty > 0 {
		return fmt.Errorf("cannot delete delivery note after picked qty has been entered")
	}

	rows, err := tx.Query(ctx, `SELECT product_id, delivery_qty, COALESCE(stock_loc,'')
		FROM sales_delivery_note_items WHERE delivery_id=$1`, id)
	if err != nil {
		return err
	}
	type releaseLine struct {
		productID   uuid.UUID
		deliveryQty float64
		stockLoc    string
	}
	var releases []releaseLine
	for rows.Next() {
		var line releaseLine
		if err := rows.Scan(&line.productID, &line.deliveryQty, &line.stockLoc); err != nil {
			rows.Close()
			return err
		}
		releases = append(releases, line)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return err
	}
	rows.Close()

	for _, line := range releases {
		locID, parseErr := uuid.Parse(strings.TrimSpace(line.stockLoc))
		released := int64(0)
		if parseErr == nil {
			tag, err := tx.Exec(ctx, `UPDATE stock_items
				SET quantity_reserved = GREATEST(quantity_reserved - $4, 0), updated_at=NOW()
				WHERE tenant_id=$1 AND product_id=$2 AND warehouse_id=$3 AND bin_id=$5`,
				tenantID, line.productID, warehouseID, line.deliveryQty, locID)
			if err != nil {
				return fmt.Errorf("release reserved stock: %w", err)
			}
			released = tag.RowsAffected()
			if released == 0 {
				tag, err = tx.Exec(ctx, `UPDATE stock_items
					SET quantity_reserved = GREATEST(quantity_reserved - $4, 0), updated_at=NOW()
					WHERE tenant_id=$1 AND product_id=$2 AND warehouse_id=$3`,
					tenantID, line.productID, warehouseID, line.deliveryQty)
				if err != nil {
					return fmt.Errorf("release reserved stock: %w", err)
				}
				released = tag.RowsAffected()
			}
		}
		if parseErr != nil || released == 0 {
			if _, err := tx.Exec(ctx, `UPDATE stock_items
				SET quantity_reserved = GREATEST(quantity_reserved - $4, 0), updated_at=NOW()
				WHERE tenant_id=$1 AND product_id=$2 AND warehouse_id=$3`,
				tenantID, line.productID, warehouseID, line.deliveryQty); err != nil {
				return fmt.Errorf("release reserved stock: %w", err)
			}
		}
	}
	if _, err := tx.Exec(ctx, `DELETE FROM sales_delivery_notes WHERE id=$1 AND tenant_id=$2`, id, tenantID); err != nil {
		return fmt.Errorf("delete delivery note: %w", err)
	}
	return tx.Commit(ctx)
}

func (r *SalesRepo) ListDeliveryNotes(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.DeliveryNote, error) {
	if err := r.ensureDeliveryTables(ctx); err != nil {
		return nil, err
	}
	query := `SELECT dn.id, dn.tenant_id, dn.delivery_no, so.so_number, COALESCE(so.customer_po_no,''), COALESCE(NULLIF(CONCAT_WS(', ', NULLIF(org.org_code,''), NULLIF(org.org_name,'')), ''), t.name, ''),
		dn.sales_order_id, dn.customer_id,
		COALESCE(c.customer_code,''), COALESCE(c.name,''), dn.warehouse_id, COALESCE(w.code,''), COALESCE(w.name,''), COALESCE(w.address,''),
		dn.selection_date, COALESCE(dn.ship_to_name,''), COALESCE(dn.ship_to_phone,''), COALESCE(dn.ship_to_address,''),
		COALESCE(dn.shipping_method,''), COALESCE(dn.route,''), dn.status, dn.created_at, dn.updated_at, dn.pgi_at
		FROM sales_delivery_notes dn
		JOIN sales_orders so ON so.id=dn.sales_order_id
		LEFT JOIN tenants t ON t.id=dn.tenant_id
		LEFT JOIN customers c ON c.id=dn.customer_id
		LEFT JOIN warehouses w ON w.id=dn.warehouse_id
		LEFT JOIN organizations org ON org.id=w.organization_id
		WHERE dn.tenant_id=$1`
	args := []interface{}{tenantID}
	if status != "" {
		query += " AND dn.status=$2"
		args = append(args, status)
	}
	query += " ORDER BY dn.created_at DESC"
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.DeliveryNote
	for rows.Next() {
		dn := &salesmodels.DeliveryNote{}
		if err := rows.Scan(&dn.ID, &dn.TenantID, &dn.DeliveryNo, &dn.SONumber, &dn.CustomerPONo, &dn.CompanyName, &dn.SalesOrderID, &dn.CustomerID,
			&dn.CustomerCode, &dn.CustomerName, &dn.WarehouseID, &dn.WarehouseCode, &dn.WarehouseName, &dn.WarehouseAddress,
			&dn.SelectionDate, &dn.ShipToName, &dn.ShipToPhone, &dn.ShipToAddress, &dn.ShippingMethod, &dn.Route,
			&dn.Status, &dn.CreatedAt, &dn.UpdatedAt, &dn.PGIAt); err != nil {
			return nil, err
		}
		list = append(list, dn)
	}
	return list, nil
}

func (r *SalesRepo) GetDeliveryNote(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.DeliveryNote, error) {
	if err := r.ensureInvoiceTables(ctx); err != nil {
		return nil, err
	}
	list, err := r.ListDeliveryNotes(ctx, tenantID, "")
	if err != nil {
		return nil, err
	}
	var dn *salesmodels.DeliveryNote
	for _, row := range list {
		if row.ID == id {
			dn = row
			break
		}
	}
	if dn == nil {
		return nil, pgx.ErrNoRows
	}
	rows, err := r.db.Query(ctx, `SELECT dni.id, dni.delivery_id, dni.so_item_id, dni.item_no, dni.product_id,
			COALESCE(p.sku,''), COALESCE(p.name,''), dni.order_qty, dni.delivery_qty, dni.picked_qty,
			COALESCE(billed.billed_qty,0)::float8,
			GREATEST(dni.delivery_qty - COALESCE(billed.billed_qty,0), 0)::float8,
			dni.unit_of_measure,
			COALESCE(
				NULLIF(b.code,''),
				(SELECT wb.code FROM stock_items si JOIN warehouse_bins wb ON wb.id=si.bin_id
				 WHERE si.tenant_id=dn.tenant_id AND si.product_id=dni.product_id AND si.warehouse_id=dn.warehouse_id AND wb.code IS NOT NULL
				 ORDER BY si.quantity_on_hand DESC, wb.code LIMIT 1),
				NULLIF(w.code,''),
				dni.stock_loc,
				''
			),
			dni.pgi_status, dni.created_at, dni.updated_at
		FROM sales_delivery_note_items dni
		JOIN sales_delivery_notes dn ON dn.id=dni.delivery_id
		LEFT JOIN products p ON p.id=dni.product_id
		LEFT JOIN warehouses w ON w.id::text=dni.stock_loc
		LEFT JOIN warehouse_bins b ON b.id::text=dni.stock_loc
		LEFT JOIN (
			SELECT sii.delivery_item_id, SUM(sii.quantity) AS billed_qty
			FROM sales_invoice_items sii
			JOIN sales_invoices si ON si.id=sii.invoice_id
			WHERE si.tenant_id=$2 AND si.status <> 'CANCELLED'
			GROUP BY sii.delivery_item_id
		) billed ON billed.delivery_item_id=dni.id
		WHERE dni.delivery_id=$1 ORDER BY dni.item_no`, id, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var item salesmodels.DeliveryNoteItem
		if err := rows.Scan(&item.ID, &item.DeliveryID, &item.SOItemID, &item.ItemNo, &item.ProductID,
			&item.SKUCode, &item.GoodsName, &item.OrderQty, &item.DeliveryQty, &item.PickedQty,
			&item.BilledQty, &item.OpenBillingQty, &item.UnitOfMeasure, &item.StockLoc, &item.PGIStatus, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		dn.Items = append(dn.Items, item)
	}
	return dn, nil
}

func (r *SalesRepo) UpdateDeliveryPicking(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateDeliveryPickingRequest) (*salesmodels.DeliveryNote, error) {
	for _, item := range req.Items {
		itemID, err := uuid.Parse(item.ID)
		if err != nil {
			return nil, fmt.Errorf("invalid item id")
		}
		_, err = r.db.Exec(ctx, `UPDATE sales_delivery_note_items dni SET picked_qty=$3, stock_loc=COALESCE(NULLIF($4,''), stock_loc), updated_at=NOW()
			FROM sales_delivery_notes dn
			WHERE dni.id=$1 AND dni.delivery_id=dn.id AND dn.id=$2 AND dn.tenant_id=$5 AND dn.status IN ('CREATED','PICKING','PICKED')`,
			itemID, id, item.PickedQty, item.StockLoc, tenantID)
		if err != nil {
			return nil, err
		}
	}
	_, _ = r.db.Exec(ctx, `UPDATE sales_delivery_notes SET status = CASE
			WHEN NOT EXISTS (SELECT 1 FROM sales_delivery_note_items WHERE delivery_id=$1 AND picked_qty < delivery_qty) THEN 'PICKED'
			ELSE 'PICKING' END, updated_at=NOW()
		WHERE id=$1 AND tenant_id=$2 AND status <> 'PGI_POSTED'`, id, tenantID)
	return r.GetDeliveryNote(ctx, id, tenantID)
}

type salesPGIItem struct {
	itemID       uuid.UUID
	productID    uuid.UUID
	itemNo       int
	productSKU   string
	materialType string
	deliveryQty  float64
	pickedQty    float64
}

type salesJournalLine struct {
	accountID   uuid.UUID
	debit       float64
	credit      float64
	description string
}

func (r *SalesRepo) PostDeliveryPGI(ctx context.Context, id, tenantID, userID uuid.UUID) (*salesmodels.DeliveryNote, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	var status, deliveryNo string
	var soID, warehouseID, customerID uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT status, delivery_no, sales_order_id, warehouse_id, customer_id FROM sales_delivery_notes
		WHERE id=$1 AND tenant_id=$2 FOR UPDATE`, id, tenantID).Scan(&status, &deliveryNo, &soID, &warehouseID, &customerID); err != nil {
		return nil, err
	}
	if status == "PGI_POSTED" {
		return nil, fmt.Errorf("delivery already posted")
	}
	rows, err := tx.Query(ctx, `SELECT dni.id, dni.item_no, dni.product_id, COALESCE(p.sku,''), COALESCE(p.material_type,''),
			dni.delivery_qty, dni.picked_qty
		FROM sales_delivery_note_items dni
		JOIN products p ON p.id = dni.product_id
		WHERE dni.delivery_id=$1
		ORDER BY dni.item_no`, id)
	if err != nil {
		return nil, err
	}
	var items []salesPGIItem
	for rows.Next() {
		var item salesPGIItem
		if err := rows.Scan(&item.itemID, &item.itemNo, &item.productID, &item.productSKU, &item.materialType, &item.deliveryQty, &item.pickedQty); err != nil {
			rows.Close()
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return nil, err
	}
	rows.Close()
	if len(items) == 0 {
		return nil, fmt.Errorf("delivery has no items")
	}

	orgID, err := salesResolveOrgForWarehouseTx(ctx, tx, tenantID, warehouseID)
	if err != nil {
		return nil, err
	}
	cogsAccountID, err := salesAccountForTypeTx(ctx, tx, orgID, "COGS")
	if err != nil {
		return nil, fmt.Errorf("no COGS account configured in Finance Settings (Account Types tab) for org %s; cannot create PGI journal entry", orgID)
	}

	totalCost := 0.0
	inventoryCredits := map[uuid.UUID]float64{}
	inventoryDescriptions := map[uuid.UUID]string{}
	for _, item := range items {
		if item.pickedQty < item.deliveryQty {
			return nil, fmt.Errorf("line %d picking incomplete, shortage %.2f", item.itemNo, item.deliveryQty-item.pickedQty)
		}
		if strings.TrimSpace(item.materialType) == "" {
			return nil, fmt.Errorf("material %s has no material_type; cannot resolve inventory account type for PGI", item.productSKU)
		}
		inventoryAccountType := salesInventoryAccountTypeForMaterialType(item.materialType)
		inventoryAccountID, err := salesAccountForTypeTx(ctx, tx, orgID, inventoryAccountType)
		if err != nil {
			return nil, fmt.Errorf("no %s account configured for material %s (material_type=%s) in Finance Settings (Account Types tab) for org %s; cannot create PGI journal entry", inventoryAccountType, item.productSKU, item.materialType, orgID)
		}
		var unitCost float64
		var binID pgtype.UUID
		err = tx.QueryRow(ctx, `WITH target AS (
				SELECT si.id, si.bin_id,
					COALESCE(
						NULLIF(si.unit_cost, 0),
						NULLIF(si.total_cost / NULLIF(si.quantity_on_hand, 0), 0),
						NULLIF(p.standard_cost, 0),
						NULLIF(p.moving_avg_cost, 0),
						NULLIF(p.last_cost, 0),
						0
					)::float8 AS unit_cost
				FROM stock_items si
				JOIN products p ON p.id = si.product_id
				WHERE si.tenant_id=$1 AND si.product_id=$2 AND si.warehouse_id=$3 AND si.quantity_on_hand >= $4
				ORDER BY si.last_movement_at NULLS LAST, si.created_at
				LIMIT 1
			), updated AS (
				UPDATE stock_items si
				SET quantity_on_hand = si.quantity_on_hand - $4,
					quantity_reserved = GREATEST(si.quantity_reserved - $4, 0),
					total_cost = GREATEST(si.total_cost - (target.unit_cost * $4), 0),
					unit_cost = CASE
						WHEN si.quantity_on_hand - $4 > 0 THEN GREATEST(si.total_cost - (target.unit_cost * $4), 0) / NULLIF(si.quantity_on_hand - $4, 0)
						ELSE target.unit_cost
					END,
					updated_at=NOW()
				FROM target
				WHERE si.id = target.id
				RETURNING target.bin_id, target.unit_cost
			)
			SELECT bin_id, unit_cost FROM updated`, tenantID, item.productID, warehouseID, item.deliveryQty).Scan(&binID, &unitCost)
		if err != nil {
			if err == pgx.ErrNoRows {
				return nil, fmt.Errorf("insufficient stock for line %d", item.itemNo)
			}
			return nil, err
		}
		if unitCost <= 0 {
			return nil, fmt.Errorf("material %s has no inventory cost; cannot create PGI journal entry", item.productSKU)
		}
		lineCost := unitCost * item.deliveryQty
		totalCost += lineCost
		inventoryCredits[inventoryAccountID] += lineCost
		inventoryDescriptions[inventoryAccountID] = fmt.Sprintf("PGI inventory credit %s", deliveryNo)
		_, err = tx.Exec(ctx, `INSERT INTO stock_movements
			(id, tenant_id, transaction_type, reference_type, reference_id, reference_no,
			 product_id, warehouse_id, bin_id, quantity, unit_cost, total_cost,
			 description, status, created_by, created_at, posted_at, posted_by)
			VALUES ($1,$2,'goods_issue','delivery_note',$3,$4,$5,$6,$7,$8,$9,$10,$11,'posted',$12,NOW(),NOW(),$12)`,
			uuid.New(), tenantID, id, deliveryNo, item.productID, warehouseID, binID,
			-item.deliveryQty, unitCost, lineCost,
			fmt.Sprintf("Post Goods Issue %s item %d", deliveryNo, item.itemNo), userID)
		if err != nil {
			return nil, fmt.Errorf("insert PGI stock movement for line %d: %w", item.itemNo, err)
		}
		_, _ = tx.Exec(ctx, `UPDATE sales_delivery_note_items SET pgi_status='PGI_POSTED', updated_at=NOW() WHERE id=$1`, item.itemID)
	}
	if totalCost <= 0 {
		return nil, fmt.Errorf("PGI journal amount is zero")
	}
	lines := []salesJournalLine{{
		accountID:   cogsAccountID,
		debit:       totalCost,
		description: fmt.Sprintf("PGI cost of sales %s", deliveryNo),
	}}
	for accountID, amount := range inventoryCredits {
		lines = append(lines, salesJournalLine{
			accountID:   accountID,
			credit:      amount,
			description: inventoryDescriptions[accountID],
		})
	}
	description := fmt.Sprintf("Post Goods Issue - %s", deliveryNo)
	if _, err := salesInsertPostedJournalTx(ctx, tx, tenantID, userID, orgID, time.Now(), description, deliveryNo, lines); err != nil {
		return nil, err
	}
	_, err = tx.Exec(ctx, `UPDATE sales_delivery_notes SET status='PGI_POSTED', pgi_at=NOW(), updated_at=NOW() WHERE id=$1`, id)
	if err != nil {
		return nil, err
	}
	_, _ = tx.Exec(ctx, `UPDATE sales_orders SET status = CASE
			WHEN NOT EXISTS (
				SELECT 1 FROM sales_order_items soi
				WHERE soi.so_id=$1 AND soi.quantity > COALESCE((SELECT SUM(dni.delivery_qty) FROM sales_delivery_note_items dni JOIN sales_delivery_notes dn ON dn.id=dni.delivery_id WHERE dni.so_item_id=soi.id AND dn.status='PGI_POSTED'),0)
			) THEN 'COMPLETED' ELSE 'PARTIALLY_DELIVERED' END, updated_at=NOW()
		WHERE id=$1 AND tenant_id=$2`, soID, tenantID)
	_, _ = tx.Exec(ctx, `INSERT INTO sales_billing_queue(tenant_id, delivery_id, sales_order_id, customer_id)
		VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`, tenantID, id, soID, customerID)
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.GetDeliveryNote(ctx, id, tenantID)
}

func salesInventoryAccountTypeForMaterialType(materialType string) string {
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

func salesResolveOrgForWarehouseTx(ctx context.Context, tx pgx.Tx, tenantID, warehouseID uuid.UUID) (uuid.UUID, error) {
	var orgID uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT o.id
		FROM warehouses w
		JOIN organizations o ON o.id = w.organization_id
		WHERE w.id=$1 AND w.tenant_id=$2 AND o.is_active=true
		LIMIT 1`, warehouseID, tenantID).Scan(&orgID); err == nil && orgID != uuid.Nil {
		return orgID, nil
	}
	if err := tx.QueryRow(ctx, `SELECT id FROM organizations WHERE tenant_id=$1 AND is_active=true LIMIT 1`, tenantID).Scan(&orgID); err == nil && orgID != uuid.Nil {
		return orgID, nil
	}
	return uuid.Nil, fmt.Errorf("no active organization found for tenant %s", tenantID)
}

func salesAccountForTypeTx(ctx context.Context, tx pgx.Tx, orgID uuid.UUID, accountType string) (uuid.UUID, error) {
	var accountID uuid.UUID
	err := tx.QueryRow(ctx, `SELECT account_id
		FROM org_reconciliation_accounts
		WHERE org_id=$1 AND LOWER(account_type)=LOWER($2)
		LIMIT 1`, orgID, accountType).Scan(&accountID)
	if err != nil || accountID == uuid.Nil {
		return uuid.Nil, fmt.Errorf("account type %s not configured for org %s", accountType, orgID)
	}
	return accountID, nil
}

func salesDerivePeriodTx(ctx context.Context, tx pgx.Tx, tenantID, orgID uuid.UUID, postingDate time.Time) (uuid.UUID, error) {
	var periodID uuid.UUID
	if orgID != uuid.Nil {
		err := tx.QueryRow(ctx, `SELECT id FROM gl_periods
			WHERE tenant_id=$1 AND organization_id=$2 AND start_date <= $3 AND end_date >= $3 AND is_open=true AND is_locked=false
			LIMIT 1`, tenantID, orgID, postingDate).Scan(&periodID)
		if err == nil {
			return periodID, nil
		}
	}
	err := tx.QueryRow(ctx, `SELECT id FROM gl_periods
		WHERE tenant_id=$1 AND organization_id IS NULL AND start_date <= $2 AND end_date >= $2 AND is_open=true AND is_locked=false
		LIMIT 1`, tenantID, postingDate).Scan(&periodID)
	if err == nil {
		return periodID, nil
	}
	err = tx.QueryRow(ctx, `SELECT id FROM gl_periods
		WHERE tenant_id=$1 AND start_date <= $2 AND end_date >= $2 AND is_open=true AND is_locked=false
		LIMIT 1`, tenantID, postingDate).Scan(&periodID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("no open period found for %s: %w", postingDate.Format("2006-01-02"), err)
	}
	return periodID, nil
}

func salesNextGLDocumentNoTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID) string {
	now := time.Now()
	prefix := fmt.Sprintf("GL-%s-", now.Format("200601"))
	var seq int
	err := tx.QueryRow(ctx, `INSERT INTO gl_document_seq (tenant_id, prefix, seq)
		VALUES ($1, $2, 1)
		ON CONFLICT (tenant_id, prefix) DO UPDATE SET seq = gl_document_seq.seq + 1
		RETURNING gl_document_seq.seq`, tenantID, prefix).Scan(&seq)
	if err != nil {
		return fmt.Sprintf("%s%04d", prefix, now.UnixMilli()%10000)
	}
	return fmt.Sprintf("%s%04d", prefix, seq)
}

func salesInsertPostedJournalTx(ctx context.Context, tx pgx.Tx, tenantID, userID, orgID uuid.UUID, postingDate time.Time, description, reference string, lines []salesJournalLine) (uuid.UUID, error) {
	periodID, err := salesDerivePeriodTx(ctx, tx, tenantID, orgID, postingDate)
	if err != nil {
		return uuid.Nil, err
	}
	totalDebit := 0.0
	totalCredit := 0.0
	for _, line := range lines {
		totalDebit += line.debit
		totalCredit += line.credit
	}
	if totalDebit-totalCredit > 0.01 || totalCredit-totalDebit > 0.01 {
		return uuid.Nil, fmt.Errorf("journal is not balanced: debit %.2f credit %.2f", totalDebit, totalCredit)
	}
	entryID := uuid.New()
	documentNo := salesNextGLDocumentNoTx(ctx, tx, tenantID)
	_, err = tx.Exec(ctx, `INSERT INTO gl_journal_entries
		(id, tenant_id, organization_id, document_no, posting_date, document_date, period_id,
		 description, reference, entry_type, status, source, created_by, created_at, posted_at, posted_by)
		VALUES ($1,$2,$3,$4,$5,$5,$6,$7,$8,'normal','posted','sales',$9,NOW(),NOW(),$9)`,
		entryID, tenantID, orgID, documentNo, postingDate, periodID, description, reference, userID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert PGI journal entry: %w", err)
	}
	for _, line := range lines {
		_, err = tx.Exec(ctx, `INSERT INTO gl_journal_lines
			(id, entry_id, account_id, account_code, account_name, debit, credit, description)
			VALUES ($1,$2,$3,
				(SELECT account_code FROM gl_accounts WHERE id=$3),
				(SELECT account_name FROM gl_accounts WHERE id=$3),
				$4,$5,$6)`,
			uuid.New(), entryID, line.accountID, line.debit, line.credit, line.description)
		if err != nil {
			return uuid.Nil, fmt.Errorf("insert PGI journal line: %w", err)
		}
		if err := salesUpdateAccountBalanceTx(ctx, tx, tenantID, line.accountID, periodID, line.debit, line.credit); err != nil {
			return uuid.Nil, err
		}
	}
	return entryID, nil
}

func salesUpdateAccountBalanceTx(ctx context.Context, tx pgx.Tx, tenantID, accountID, periodID uuid.UUID, debit, credit float64) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO gl_account_balances (tenant_id, account_id, period_id, opening_balance, period_debit, period_credit, closing_balance, updated_at)
		SELECT $1, $2, $3,
		       COALESCE((SELECT ab.closing_balance
		                 FROM gl_account_balances ab
		                 JOIN gl_periods p ON p.id = ab.period_id
		                 WHERE ab.tenant_id = $1 AND ab.account_id = $2
		                   AND (p.fiscal_year < cur.fiscal_year OR
		                        (p.fiscal_year = cur.fiscal_year AND p.period_no < cur.period_no))
		                 ORDER BY p.fiscal_year DESC, p.period_no DESC
		                 LIMIT 1), 0),
		       COALESCE(ab2.period_debit, 0) + $4,
		       COALESCE(ab2.period_credit, 0) + $5,
		       COALESCE((SELECT ab.closing_balance
		                 FROM gl_account_balances ab
		                 JOIN gl_periods p ON p.id = ab.period_id
		                 WHERE ab.tenant_id = $1 AND ab.account_id = $2
		                   AND (p.fiscal_year < cur.fiscal_year OR
		                        (p.fiscal_year = cur.fiscal_year AND p.period_no < cur.period_no))
		                 ORDER BY p.fiscal_year DESC, p.period_no DESC
		                 LIMIT 1), 0) +
		       COALESCE(ab2.period_debit, 0) + $4 -
		       COALESCE(ab2.period_credit, 0) - $5,
		       NOW()
		FROM gl_periods cur
		LEFT JOIN gl_account_balances ab2 ON ab2.period_id = cur.id AND ab2.account_id = $2 AND ab2.tenant_id = $1
		WHERE cur.id = $3
		ON CONFLICT (tenant_id, account_id, period_id) DO UPDATE SET
		    period_debit  = gl_account_balances.period_debit + $4,
		    period_credit = gl_account_balances.period_credit + $5,
		    closing_balance = gl_account_balances.opening_balance +
		                      (gl_account_balances.period_debit + $4) -
		                      (gl_account_balances.period_credit + $5),
		    updated_at = NOW()
	`, tenantID, accountID, periodID, debit, credit)
	if err != nil {
		return fmt.Errorf("update balance for account %s: %w", accountID, err)
	}
	return nil
}
