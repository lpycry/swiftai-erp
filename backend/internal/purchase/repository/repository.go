package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	purchasemodels "github.com/swiftai-erp/backend/internal/purchase/models"
)

type PurchaseRepo struct {
	db *pgxpool.Pool
}

func NewPurchaseRepo(db *pgxpool.Pool) *PurchaseRepo {
	return &PurchaseRepo{db: db}
}

// ══════════════════════════════════════════
//  VENDORS
// ══════════════════════════════════════════

func (r *PurchaseRepo) CreateVendor(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateVendorRequest) (*purchasemodels.Vendor, error) {
	v := &purchasemodels.Vendor{
		ID:            uuid.New(),
		OrgID:         orgID,
		VendorCode:    req.VendorCode,
		Name:          req.Name,
		TaxNumber:     req.TaxNumber,
		Currency:      req.Currency,
		PaymentTerms:  req.PaymentTerms,
		Status:        "active",
		LeadTimeDays:  req.LeadTimeDays,
		Address:       req.Address,
		ContactPerson: req.ContactPerson,
		ContactEmail:  req.ContactEmail,
		ContactPhone:  req.ContactPhone,

		IsActive:  true,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	if v.Currency == "" {
		v.Currency = "USD"
	}
	if v.PaymentTerms == "" {
		v.PaymentTerms = "Net 30"
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO vendors(id, org_id, vendor_code, name, tax_number, currency, payment_terms, status,
			lead_time_days, address, contact_person, contact_email, contact_phone, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
	`, v.ID, v.OrgID, v.VendorCode, v.Name, v.TaxNumber, v.Currency, v.PaymentTerms, v.Status,
		v.LeadTimeDays, v.Address, v.ContactPerson, v.ContactEmail, v.ContactPhone, v.IsActive, v.CreatedAt, v.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create vendor: %w", err)
	}
	return v, nil
}

func (r *PurchaseRepo) GetVendor(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.Vendor, error) {
	v := &purchasemodels.Vendor{}
	err := r.db.QueryRow(ctx, `
		SELECT v.id, v.org_id, v.vendor_code, v.name, COALESCE(v.tax_number,''), v.currency, v.payment_terms, v.status,
			v.ai_rating, v.lead_time_days, COALESCE(v.address,''), COALESCE(v.contact_person,''),
			COALESCE(v.contact_email,''), COALESCE(v.contact_phone,''), v.is_active, v.created_at, v.updated_at
		FROM vendors v
		WHERE v.id = $1 AND v.org_id = $2
	`, id, orgID).Scan(
		&v.ID, &v.OrgID, &v.VendorCode, &v.Name, &v.TaxNumber, &v.Currency, &v.PaymentTerms, &v.Status, &v.AIRating, &v.LeadTimeDays, &v.Address, &v.ContactPerson, &v.ContactEmail, &v.ContactPhone, &v.IsActive, &v.CreatedAt, &v.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get vendor: %w", err)
	}
	return v, nil
}

func (r *PurchaseRepo) ListVendors(ctx context.Context, orgID uuid.UUID, search string) ([]*purchasemodels.Vendor, error) {
	query := `SELECT v.id, v.org_id, v.vendor_code, v.name, COALESCE(v.tax_number,''), v.currency, v.payment_terms, v.status,
		v.ai_rating, v.lead_time_days, COALESCE(v.address,''), COALESCE(v.contact_person,''),
		COALESCE(v.contact_email,''), COALESCE(v.contact_phone,''), 
		v.is_active, v.created_at, v.updated_at
		FROM vendors v
		
		WHERE v.org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2
	if search != "" {
		query += fmt.Sprintf(` AND (v.vendor_code ILIKE $%d OR v.name ILIKE $%d OR v.tax_number ILIKE $%d)`, argIdx, argIdx, argIdx)
		args = append(args, "%"+search+"%")
		argIdx++
	}
	query += " ORDER BY v.vendor_code"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.Vendor
	for rows.Next() {
		v := &purchasemodels.Vendor{}
		if err := rows.Scan(&v.ID, &v.OrgID, &v.VendorCode, &v.Name, &v.TaxNumber, &v.Currency,
			&v.PaymentTerms, &v.Status, &v.AIRating, &v.LeadTimeDays, &v.Address, &v.ContactPerson,
			&v.ContactEmail, &v.ContactPhone, &v.IsActive, &v.CreatedAt, &v.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, v)
	}
	return list, nil
}

func (r *PurchaseRepo) UpdateVendor(ctx context.Context, id, orgID uuid.UUID, req *purchasemodels.UpdateVendorRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE vendors SET
			name         = COALESCE($3, name),
			tax_number   = COALESCE($4, tax_number),
			currency     = COALESCE($5, currency),
			payment_terms = COALESCE($6, payment_terms),
			status       = COALESCE($7, status),
			lead_time_days = COALESCE($8, lead_time_days),
			address      = COALESCE($9, address),
			contact_person = COALESCE($10, contact_person),
			contact_email = COALESCE($11, contact_email),
			contact_phone = COALESCE($12, contact_phone),

			is_active    = COALESCE($13, is_active),
			updated_at   = NOW()
		WHERE id = $1 AND org_id = $2
	`, id, orgID, req.Name, req.TaxNumber, req.Currency, req.PaymentTerms, req.Status,
		req.LeadTimeDays, req.Address, req.ContactPerson, req.ContactEmail, req.ContactPhone, req.IsActive)
	return err
}

// HasTransactions checks if vendor has any purchase orders, receipts, or invoices.
func (r *PurchaseRepo) HasTransactions(ctx context.Context, id, orgID uuid.UUID) (bool, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM (
			SELECT id FROM purchase_orders WHERE vendor_id = $1 AND org_id = $2
			UNION ALL
			SELECT pr.id FROM purchase_receipts pr
			JOIN purchase_orders po ON po.id = pr.po_id AND po.vendor_id = $1 AND po.org_id = $2
			UNION ALL
			SELECT id FROM purchase_invoices WHERE vendor_id = $1 AND org_id = $2
		) t
	`, id, orgID).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("check vendor transactions: %w", err)
	}
	return count > 0, nil
}

func (r *PurchaseRepo) DeleteVendor(ctx context.Context, id, orgID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM vendors WHERE id = $1 AND org_id = $2`, id, orgID)
	return err
}

// ══════════════════════════════════════════
//  PURCHASE ORDERS
// ══════════════════════════════════════════

func (r *PurchaseRepo) CreatePO(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreatePORequest, createdBy *uuid.UUID) (*purchasemodels.PurchaseOrder, error) {
	poID := uuid.New()
	poNumber := r.generatePONumber(ctx)
	totalAmount := 0.0
	for _, it := range req.Items {
		totalAmount += it.Quantity * it.UnitPrice
	}

	currency := req.Currency
	if currency == "" {
		currency = "USD"
	}

	poDate := time.Now()
	if req.PODate != "" {
		if parsed, err := time.Parse("2006-01-02", req.PODate); err == nil {
			poDate = parsed
		}
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO purchase_orders (id, org_id, po_number, vendor_id, total_amount, currency, status, notes,
			organization_id, po_date, payment_term_code, delivery_address, incoterm_code, created_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,'DRAFT',$7,$8,$9,$10,$11,$12,$13,NOW(),NOW())
	`, poID, orgID, poNumber, req.VendorID, totalAmount, currency, req.Notes,
		req.OrganizationID, poDate, req.PaymentTermCode, req.DeliveryAddress, req.IncotermCode, createdBy)
	if err != nil {
		return nil, fmt.Errorf("insert po: %w", err)
	}

	for _, it := range req.Items {
		uom := it.UOM
		if uom == "" {
			uom = "EA"
		}
		lineTotal := it.Quantity * it.UnitPrice

		var deliveryDate *time.Time
		if it.ExpectedDeliveryDate != "" {
			if parsed, err := time.Parse("2006-01-02", it.ExpectedDeliveryDate); err == nil {
				deliveryDate = &parsed
			}
		}

		_, err = tx.Exec(ctx, `
			INSERT INTO purchase_order_items (id, po_id, item_id, quantity, unit_price, received_quantity, unit_of_measure, line_total, expected_delivery_date, delivery_address)
			VALUES ($1,$2,$3,$4,$5,0,$6,$7,$8,$9)
		`, uuid.New(), poID, it.ItemID, it.Quantity, it.UnitPrice, uom, lineTotal, deliveryDate, it.DeliveryAddress)
		if err != nil {
			return nil, fmt.Errorf("insert po item: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit po: %w", err)
	}

	return r.GetPO(ctx, poID, orgID)
}

func (r *PurchaseRepo) GetPO(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.PurchaseOrder, error) {
	po := &purchasemodels.PurchaseOrder{}
	err := r.db.QueryRow(ctx, `
		SELECT po.id, po.org_id, po.po_number, po.vendor_id, COALESCE(v.name,''), COALESCE(v.vendor_code,''),
			po.total_amount, po.currency, po.status, COALESCE(po.notes,''), po.created_by, po.created_at, po.updated_at,
			po.organization_id, COALESCE(o.org_code,''), COALESCE(o.org_name,''), po.po_date,
			COALESCE(po.payment_term_code,''), COALESCE(po.delivery_address,''), COALESCE(po.incoterm_code,'')
		FROM purchase_orders po
		LEFT JOIN vendors v ON v.id = po.vendor_id
		LEFT JOIN organizations o ON o.id = po.organization_id
		WHERE po.id = $1 AND po.org_id = $2
	`, id, orgID).Scan(
		&po.ID, &po.OrgID, &po.PONumber, &po.VendorID, &po.VendorName, &po.VendorCode,
		&po.TotalAmount, &po.Currency, &po.Status, &po.Notes, &po.CreatedBy, &po.CreatedAt, &po.UpdatedAt,
		&po.OrganizationID, &po.OrgCode, &po.OrgName, &po.PODate,
		&po.PaymentTermCode, &po.DeliveryAddress, &po.IncotermCode)
	if err != nil {
		return nil, fmt.Errorf("get po: %w", err)
	}

	// Load items
	items, err := r.getPOItems(ctx, id)
	if err != nil {
		return nil, err
	}
	po.Items = items
	return po, nil
}

func (r *PurchaseRepo) ListPOs(ctx context.Context, orgID uuid.UUID, status string, vendorID uuid.UUID) ([]*purchasemodels.PurchaseOrder, error) {
	query := `SELECT po.id, po.org_id, po.po_number, po.vendor_id, COALESCE(v.name,''), COALESCE(v.vendor_code,''),
		po.total_amount, po.currency, po.status, COALESCE(po.notes,''), po.created_by, po.created_at, po.updated_at,
		po.organization_id, COALESCE(o.org_code,''), COALESCE(o.org_name,''), po.po_date,
		COALESCE(po.payment_term_code,''), COALESCE(po.delivery_address,''), COALESCE(po.incoterm_code,'')
		FROM purchase_orders po
		LEFT JOIN vendors v ON v.id = po.vendor_id
		LEFT JOIN organizations o ON o.id = po.organization_id
		WHERE po.org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if status != "" {
		query += fmt.Sprintf(" AND po.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	if vendorID != uuid.Nil {
		query += fmt.Sprintf(" AND po.vendor_id = $%d", argIdx)
		args = append(args, vendorID)
		argIdx++
	}
	query += " ORDER BY po.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.PurchaseOrder
	for rows.Next() {
		po := &purchasemodels.PurchaseOrder{}
		if err := rows.Scan(&po.ID, &po.OrgID, &po.PONumber, &po.VendorID, &po.VendorName, &po.VendorCode,
			&po.TotalAmount, &po.Currency, &po.Status, &po.Notes, &po.CreatedBy, &po.CreatedAt, &po.UpdatedAt,
			&po.OrganizationID, &po.OrgCode, &po.OrgName, &po.PODate,
			&po.PaymentTermCode, &po.DeliveryAddress, &po.IncotermCode); err != nil {
			return nil, err
		}
		list = append(list, po)
	}
	return list, nil
}

func (r *PurchaseRepo) UpdatePOStatus(ctx context.Context, id, orgID uuid.UUID, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE purchase_orders SET status = $3, updated_at = NOW() WHERE id = $1 AND org_id = $2`,
		id, orgID, status)
	return err
}

func (r *PurchaseRepo) getPOItems(ctx context.Context, poID uuid.UUID) ([]purchasemodels.PurchaseOrderItem, error) {
	rows, err := r.db.Query(ctx, `
		SELECT poi.id, poi.po_id, poi.item_id, COALESCE(p.sku,''), COALESCE(p.name,''),
			poi.quantity, poi.unit_price, poi.received_quantity, COALESCE(poi.invoiced_quantity,0),
			poi.unit_of_measure, poi.line_total,
			poi.expected_delivery_date, COALESCE(poi.delivery_address,'')
		FROM purchase_order_items poi
		LEFT JOIN products p ON p.id = poi.item_id
		WHERE poi.po_id = $1 ORDER BY poi.id
	`, poID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []purchasemodels.PurchaseOrderItem
	for rows.Next() {
		it := purchasemodels.PurchaseOrderItem{}
		if err := rows.Scan(&it.ID, &it.POID, &it.ItemID, &it.ItemSKU, &it.ItemName,
			&it.Quantity, &it.UnitPrice, &it.ReceivedQuantity, &it.InvoicedQuantity,
			&it.UnitOfMeasure, &it.LineTotal,
			&it.ExpectedDeliveryDate, &it.DeliveryAddress); err != nil {
			return nil, err
		}
		it.OpenInvoiceQty = it.ReceivedQuantity - it.InvoicedQuantity
		if it.OpenInvoiceQty < 0 {
			it.OpenInvoiceQty = 0
		}
		items = append(items, it)
	}
	return items, nil
}

// ══════════════════════════════════════════
//  PENDING INVOICE POs — received but not fully invoiced
// ══════════════════════════════════════════

func (r *PurchaseRepo) ListPendingInvoicePOs(ctx context.Context, orgID uuid.UUID) ([]*purchasemodels.PurchaseOrder, error) {
	query := `SELECT po.id, po.org_id, po.po_number, po.vendor_id, COALESCE(v.name,''), COALESCE(v.vendor_code,''),
		po.total_amount, po.currency, po.status, COALESCE(po.notes,''), po.created_by, po.created_at, po.updated_at,
		po.organization_id, COALESCE(o.org_code,''), COALESCE(o.org_name,''), po.po_date,
		COALESCE(po.payment_term_code,''), COALESCE(po.delivery_address,''), COALESCE(po.incoterm_code,'')
		FROM purchase_orders po
		LEFT JOIN vendors v ON v.id = po.vendor_id
		LEFT JOIN organizations o ON o.id = po.organization_id
		WHERE po.org_id = $1
		AND po.status IN ('RECEIVED', 'PARTIALLY_INVOICED')
		AND EXISTS (
			SELECT 1 FROM purchase_order_items poi
			WHERE poi.po_id = po.id
			AND poi.received_quantity > COALESCE(poi.invoiced_quantity,0)
		)
		ORDER BY po.created_at DESC`

	rows, err := r.db.Query(ctx, query, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.PurchaseOrder
	for rows.Next() {
		po := &purchasemodels.PurchaseOrder{}
		if err := rows.Scan(&po.ID, &po.OrgID, &po.PONumber, &po.VendorID, &po.VendorName, &po.VendorCode,
			&po.TotalAmount, &po.Currency, &po.Status, &po.Notes, &po.CreatedBy, &po.CreatedAt, &po.UpdatedAt,
			&po.OrganizationID, &po.OrgCode, &po.OrgName, &po.PODate,
			&po.PaymentTermCode, &po.DeliveryAddress, &po.IncotermCode); err != nil {
			return nil, err
		}
		// Load items with open invoice qty
		items, err := r.getPOItems(ctx, po.ID)
		if err == nil {
			po.Items = items
		}
		list = append(list, po)
	}
	return list, nil
}

// ══════════════════════════════════════════
//  PURCHASE RECEIPTS  (核心：联动仓库+财务事件)
// ══════════════════════════════════════════

func (r *PurchaseRepo) ExecuteGoodsReceipt(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateReceiptRequest, userID *uuid.UUID, poStatus string) (*purchasemodels.PurchaseReceipt, *purchasemodels.BusinessEvent, error) {
	receiptID := uuid.New()
	now := time.Now()

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	totalCost := req.Quantity * req.UnitCost

	// Determine warehouse ID for stock upsert
	// Priority: explicit warehouse_id > bin.warehouse_id > site → org → tenant → warehouse
	warehouseID := uuid.Nil
	if req.WarehouseID != nil {
		warehouseID = *req.WarehouseID
	}

	// Fallback: resolve from bin's warehouse_id
	if warehouseID == uuid.Nil && req.BinID != nil {
		_ = tx.QueryRow(ctx, `SELECT warehouse_id FROM warehouse_bins WHERE id = $1`, req.BinID).Scan(&warehouseID)
	}

	// Fallback: resolve from site
	if warehouseID == uuid.Nil && req.SiteID != uuid.Nil {
		// Prefer warehouses directly linked to this site's org
		err := tx.QueryRow(ctx, `
			SELECT w.id FROM warehouses w
			WHERE w.organization_id = (SELECT organization_id FROM sites WHERE id = $1)
			LIMIT 1
		`, req.SiteID).Scan(&warehouseID)
		if err != nil {
			// Fallback2: any warehouse in the org's tenant
			err = tx.QueryRow(ctx, `
				SELECT w.id FROM warehouses w
				WHERE w.tenant_id = (SELECT tenant_id FROM organizations WHERE id = $1)
				LIMIT 1
			`, orgID).Scan(&warehouseID)
		}
	}

	// If still no warehouse, record receipt but warn about missing stock update
	warehouseResolved := warehouseID != uuid.Nil

	// 1. Insert purchase receipt (with warehouse_id if resolved)
	_, err = tx.Exec(ctx, `
		INSERT INTO purchase_receipts (id, org_id, po_id, item_id, site_id, bin_id, warehouse_id, quantity, unit_cost, total_cost, batch_no, receipt_date, received_by, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
	`, receiptID, orgID, req.POID, req.ItemID, req.SiteID, req.BinID, nilIfUUID(warehouseID), req.Quantity, req.UnitCost, totalCost,
		req.BatchNo, now, userID, now)
	if err != nil {
		return nil, nil, fmt.Errorf("insert receipt: %w", err)
	}

	// 2. Update PO item received_quantity
	_, err = tx.Exec(ctx, `
		UPDATE purchase_order_items SET received_quantity = received_quantity + $1 WHERE po_id = $2 AND item_id = $3
	`, req.Quantity, req.POID, req.ItemID)
	if err != nil {
		return nil, nil, fmt.Errorf("update po item: %w", err)
	}

	// 3. Update PO status to RECEIVED if not already
	if poStatus != "RECEIVED" && poStatus != "INVOICED" {
		_, err = tx.Exec(ctx, `UPDATE purchase_orders SET status = 'RECEIVED', updated_at = NOW() WHERE id = $1`, req.POID)
		if err != nil {
			return nil, nil, fmt.Errorf("update po status: %w", err)
		}
	}

	// 4. Update warehouse stock (stock_items upsert) — skip if no warehouse resolved
	moveID := uuid.Nil
	if warehouseResolved {
		_, err = tx.Exec(ctx, `
			INSERT INTO stock_items (id, tenant_id, product_id, warehouse_id, bin_id, batch_id, quantity_on_hand, unit_cost, total_cost, created_at, updated_at)
			VALUES (uuid_generate_v4(), $1, $2, $3, $4, NULL, $5, $6, $7, NOW(), NOW())
			ON CONFLICT (tenant_id, product_id, warehouse_id, bin_id) DO UPDATE SET
				quantity_on_hand = stock_items.quantity_on_hand + $5,
				unit_cost = $6,
				total_cost = stock_items.total_cost + $7,
				last_movement_at = NOW(),
				updated_at = NOW()
		`, orgID, req.ItemID, warehouseID, req.BinID, req.Quantity, req.UnitCost, totalCost)
		if err != nil {
			return nil, nil, fmt.Errorf("upsert stock: %w", err)
		}

		// 5. Record stock movement
		moveID = uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO stock_movements (id, tenant_id, transaction_type, reference_type, reference_id, reference_no,
				product_id, warehouse_id, bin_id, quantity, unit_cost, total_cost, description, status, created_by, created_at, posted_at, posted_by)
			VALUES ($1,$2,'goods_receipt','purchase_receipt',$3, $4, $5,$6,$7,$8,$9,$10,'PO Goods Receipt','posted',$11,NOW(),NOW(),$11)
		`, moveID, orgID, receiptID, req.POID.String(), req.ItemID, warehouseID, req.BinID,
			req.Quantity, req.UnitCost, totalCost, userID)
		if err != nil {
			return nil, nil, fmt.Errorf("insert movement: %w", err)
		}
	}

	// 6. Create business event for AI GL posting
	eventData, _ := json.Marshal(map[string]interface{}{
		"receipt_id":  receiptID.String(),
		"po_id":       req.POID.String(),
		"item_id":     req.ItemID.String(),
		"site_id":     req.SiteID.String(),
		"quantity":    req.Quantity,
		"unit_cost":   req.UnitCost,
		"total_cost":  totalCost,
		"movement_id": moveID.String(),
	})
	eventID := uuid.New()
	_, err = tx.Exec(ctx, `
		INSERT INTO business_events (id, org_id, event_type, source_id, source_type, event_data, status, created_at)
		VALUES ($1,$2,'PO_GOODS_RECEIVED',$3,'purchase_receipt',$4,'PENDING',NOW())
	`, eventID, orgID, receiptID, eventData)
	if err != nil {
		return nil, nil, fmt.Errorf("insert business event: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, fmt.Errorf("commit receipt: %w", err)
	}

	// Build receipt
	warehouseIDForReceipt := warehouseID
	if warehouseIDForReceipt == uuid.Nil {
		warehouseIDForReceipt = uuid.Nil
	}
	receipt := &purchasemodels.PurchaseReceipt{
		ID: receiptID, OrgID: orgID, POID: req.POID, ItemID: req.ItemID,
		SiteID: req.SiteID, BinID: req.BinID, WarehouseID: nilIfUUID(warehouseIDForReceipt),
		Quantity: req.Quantity, UnitCost: req.UnitCost, TotalCost: totalCost, BatchNo: req.BatchNo,
		ReceiptDate: now, ReceivedBy: userID, CreatedAt: now,
	}

	event := &purchasemodels.BusinessEvent{
		ID: eventID, OrgID: orgID, EventType: "PO_GOODS_RECEIVED",
		SourceID: receiptID, SourceType: "purchase_receipt", Status: "PENDING", CreatedAt: now,
	}

	return receipt, event, nil
}

func (r *PurchaseRepo) ListReceipts(ctx context.Context, orgID uuid.UUID, tenantID uuid.UUID, poID uuid.UUID) ([]*purchasemodels.PurchaseReceipt, error) {
	query := `SELECT pr.id, pr.org_id, pr.po_id, pr.item_id, pr.site_id, pr.bin_id, pr.warehouse_id,
		pr.quantity, pr.unit_cost, pr.total_cost, COALESCE(pr.batch_no,''), pr.receipt_date, pr.received_by, pr.created_at,
		pr.is_reversed, pr.reversed_at,
		COALESCE(po.po_number,''), COALESCE(p.sku,''), COALESCE(p.name,''), COALESCE(s.site_code,''), COALESCE(s.site_name,''),
		COALESCE(w.code,''), COALESCE(w.name,'')
		FROM purchase_receipts pr
		LEFT JOIN purchase_orders po ON po.id = pr.po_id
		LEFT JOIN products p ON p.id = pr.item_id
		LEFT JOIN sites s ON s.id = pr.site_id
		LEFT JOIN warehouses w ON w.id = pr.warehouse_id
		WHERE (pr.org_id = $1 OR pr.org_id = $2 OR pr.org_id IN (SELECT id FROM organizations WHERE tenant_id = $2))`
	args := []interface{}{orgID, tenantID}
	argIdx := 3
	if poID != uuid.Nil {
		query += fmt.Sprintf(" AND pr.po_id = $%d", argIdx)
		args = append(args, poID)
		argIdx++
	}
	query += " ORDER BY pr.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.PurchaseReceipt
	for rows.Next() {
		r := &purchasemodels.PurchaseReceipt{}
		if err := rows.Scan(&r.ID, &r.OrgID, &r.POID, &r.ItemID, &r.SiteID, &r.BinID, &r.WarehouseID,
			&r.Quantity, &r.UnitCost, &r.TotalCost, &r.BatchNo, &r.ReceiptDate, &r.ReceivedBy, &r.CreatedAt,
			&r.IsReversed, &r.ReversedAt,
			&r.PONumber, &r.ItemSKU, &r.ItemName, &r.SiteCode, &r.SiteName,
			&r.WhCode, &r.WhName); err != nil {
			return nil, err
		}
		r.ReceiptSource = "PO"
		list = append(list, r)
	}

	if poID == uuid.Nil {
		woRows, err := r.db.Query(ctx, `
			SELECT wor.id, wor.tenant_id, wor.production_order_id, wor.material_id, wor.site_id, wor.bin_id, wor.warehouse_id,
				wor.quantity, wor.unit_cost, wor.total_cost, COALESCE(wor.batch_no,''), wor.receipt_date, wor.received_by, wor.created_at,
				wor.is_reversed, wor.reversed_at,
				COALESCE(po.order_number,''), COALESCE(p.sku,''), COALESCE(p.name,''), COALESCE(s.site_code,''), COALESCE(s.site_name,''),
				COALESCE(w.code,''), COALESCE(w.name,'')
			FROM work_order_receipts wor
			LEFT JOIN production_orders po ON po.id = wor.production_order_id
			LEFT JOIN products p ON p.id = wor.material_id
			LEFT JOIN sites s ON s.id = wor.site_id
			LEFT JOIN warehouses w ON w.id = wor.warehouse_id
			WHERE wor.tenant_id = $1
			ORDER BY wor.created_at DESC
		`, tenantID)
		if err != nil {
			return nil, err
		}
		defer woRows.Close()
		for woRows.Next() {
			rec := &purchasemodels.PurchaseReceipt{}
			if err := woRows.Scan(&rec.ID, &rec.OrgID, &rec.POID, &rec.ItemID, &rec.SiteID, &rec.BinID, &rec.WarehouseID,
				&rec.Quantity, &rec.UnitCost, &rec.TotalCost, &rec.BatchNo, &rec.ReceiptDate, &rec.ReceivedBy, &rec.CreatedAt,
				&rec.IsReversed, &rec.ReversedAt,
				&rec.PONumber, &rec.ItemSKU, &rec.ItemName, &rec.SiteCode, &rec.SiteName,
				&rec.WhCode, &rec.WhName); err != nil {
				return nil, err
			}
			rec.ReceiptSource = "WORK_ORDER"
			list = append(list, rec)
		}
	}

	sort.SliceStable(list, func(i, j int) bool {
		return list[i].CreatedAt.After(list[j].CreatedAt)
	})
	return list, nil
}

// ══════════════════════════════════════════
//  PURCHASE RECEIPT REVERSAL
// ══════════════════════════════════════════

func (r *PurchaseRepo) ReverseGoodsReceipt(ctx context.Context, receiptID, orgID uuid.UUID, userID *uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// 1. Get the original receipt
	var rec purchasemodels.PurchaseReceipt
	err = tx.QueryRow(ctx, `
		SELECT pr.id, pr.org_id, pr.po_id, pr.item_id, pr.site_id, pr.bin_id, pr.warehouse_id,
			pr.quantity, pr.unit_cost, pr.total_cost, pr.is_reversed
		FROM purchase_receipts pr WHERE pr.id = $1 AND pr.org_id = $2 FOR UPDATE
	`, receiptID, orgID).Scan(
		&rec.ID, &rec.OrgID, &rec.POID, &rec.ItemID, &rec.SiteID, &rec.BinID, &rec.WarehouseID,
		&rec.Quantity, &rec.UnitCost, &rec.TotalCost, &rec.IsReversed)
	if err != nil {
		return fmt.Errorf("receipt not found: %w", err)
	}
	if rec.IsReversed {
		return fmt.Errorf("receipt %s is already reversed", receiptID.String()[:8])
	}

	// 2. Reverse PO item received_quantity
	res, err := tx.Exec(ctx, `
		UPDATE purchase_order_items SET received_quantity = GREATEST(0, received_quantity - $1)
		WHERE po_id = $2 AND item_id = $3
	`, rec.Quantity, rec.POID, rec.ItemID)
	if err != nil {
		return fmt.Errorf("revert po item: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("no PO item found for receipt") // should not happen
	}

	// 2b. Reverse warehouse stock (resolve from bin or site)
	var whID uuid.UUID
	if rec.BinID != nil {
		_ = tx.QueryRow(ctx, `SELECT warehouse_id FROM warehouse_bins WHERE id = $1`, rec.BinID).Scan(&whID)
	}
	if whID == uuid.Nil && rec.SiteID != uuid.Nil {
		err = tx.QueryRow(ctx, `
			SELECT w.id FROM warehouses w
			WHERE w.organization_id = (SELECT organization_id FROM sites WHERE id = $1)
			LIMIT 1
		`, rec.SiteID).Scan(&whID)
		if err != nil {
			// Fallback: any warehouse in the org's tenant
			err = tx.QueryRow(ctx, `
				SELECT w.id FROM warehouses w
				WHERE w.tenant_id = (SELECT tenant_id FROM organizations WHERE id = $1)
				LIMIT 1
			`, orgID).Scan(&whID)
		}
	}
	if err == nil && whID != uuid.Nil {
		// Decrement stock
		_, err = tx.Exec(ctx, `
			UPDATE stock_items SET
				quantity_on_hand = GREATEST(0, quantity_on_hand - $1),
				total_cost = GREATEST(0, total_cost - $2),
				last_movement_at = NOW(),
				updated_at = NOW()
			WHERE product_id = $3 AND warehouse_id = $4 AND ($5::uuid IS NULL OR bin_id = $5)
		`, rec.Quantity, rec.TotalCost, rec.ItemID, whID, rec.BinID)
		if err != nil {
			return fmt.Errorf("revert stock: %w", err)
		}

		// Record reversal movement (negative qty)
		_, err = tx.Exec(ctx, `
			INSERT INTO stock_movements (id, tenant_id, transaction_type, reference_type, reference_id, reference_no,
				product_id, warehouse_id, bin_id, quantity, unit_cost, total_cost, description, status, created_by, created_at, posted_at, posted_by)
			VALUES (uuid_generate_v4(), $1,'goods_receipt','purchase_receipt',$2, $3,
				$4,$5,$6,$7,$8,$9,'PO Goods Receipt Reversal','posted',$10,NOW(),NOW(),$10)
		`, orgID, receiptID, rec.POID.String(), rec.ItemID, whID, rec.BinID,
			-rec.Quantity, rec.UnitCost, rec.TotalCost, userID)
		if err != nil {
			return fmt.Errorf("insert reversal movement: %w", err)
		}
	}

	// 3. Check if PO now has zero received qty → revert status to CONFIRMED
	var totalReceived float64
	err = tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(received_quantity),0) FROM purchase_order_items WHERE po_id = $1
	`, rec.POID).Scan(&totalReceived)
	if err != nil {
		return fmt.Errorf("check po received: %w", err)
	}

	if totalReceived <= 0 {
		_, err = tx.Exec(ctx, `UPDATE purchase_orders SET status = 'CONFIRMED', updated_at = NOW() WHERE id = $1`, rec.POID)
		if err != nil {
			return fmt.Errorf("revert po status: %w", err)
		}
	}

	// 4. Mark receipt as reversed
	now := time.Now()
	_, err = tx.Exec(ctx, `
		UPDATE purchase_receipts SET is_reversed = true, reversed_at = $1 WHERE id = $2
	`, now, receiptID)
	if err != nil {
		return fmt.Errorf("mark reversed: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit reversal: %w", err)
	}

	return nil
}

// ══════════════════════════════════════════
//  PURCHASE INVOICES  (联动财务结算)
// ══════════════════════════════════════════

func (r *PurchaseRepo) ReverseWorkOrderReceipt(ctx context.Context, receiptID, tenantID uuid.UUID, userID *uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin work order receipt reversal tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var rec purchasemodels.PurchaseReceipt
	err = tx.QueryRow(ctx, `
		SELECT id, tenant_id, production_order_id, material_id, site_id, bin_id, warehouse_id,
			quantity, unit_cost, total_cost, is_reversed
		FROM work_order_receipts
		WHERE id = $1 AND tenant_id = $2
		FOR UPDATE
	`, receiptID, tenantID).Scan(
		&rec.ID, &rec.OrgID, &rec.POID, &rec.ItemID, &rec.SiteID, &rec.BinID, &rec.WarehouseID,
		&rec.Quantity, &rec.UnitCost, &rec.TotalCost, &rec.IsReversed,
	)
	if err != nil {
		return fmt.Errorf("work order receipt not found: %w", err)
	}
	if rec.IsReversed {
		return fmt.Errorf("work order receipt %s is already reversed", receiptID.String()[:8])
	}
	if rec.WarehouseID == nil || *rec.WarehouseID == uuid.Nil {
		return fmt.Errorf("work order receipt %s has no warehouse to reverse", receiptID.String()[:8])
	}

	_, err = tx.Exec(ctx, `
		UPDATE stock_items SET
			quantity_on_hand = GREATEST(0, quantity_on_hand - $1),
			total_cost = GREATEST(0, total_cost - $2),
			last_movement_at = NOW(),
			updated_at = NOW()
		WHERE tenant_id = $3 AND product_id = $4 AND warehouse_id = $5 AND ($6::uuid IS NULL OR bin_id = $6)
	`, rec.Quantity, rec.TotalCost, tenantID, rec.ItemID, *rec.WarehouseID, rec.BinID)
	if err != nil {
		return fmt.Errorf("revert work order stock: %w", err)
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO stock_movements (id, tenant_id, transaction_type, reference_type, reference_id, reference_no,
			product_id, warehouse_id, bin_id, quantity, unit_cost, total_cost, description, status, created_by, created_at, posted_at, posted_by)
		VALUES (uuid_generate_v4(), $1,'goods_receipt','work_order_receipt',$2,$3,
			$4,$5,$6,$7,$8,$9,'Work Order Receiving Reversal','posted',$10,NOW(),NOW(),$10)
	`, tenantID, receiptID, rec.POID.String(), rec.ItemID, *rec.WarehouseID, rec.BinID,
		-rec.Quantity, rec.UnitCost, rec.TotalCost, userID)
	if err != nil {
		return fmt.Errorf("insert work order reversal movement: %w", err)
	}

	_, err = tx.Exec(ctx, `
		UPDATE production_orders
		SET completed_qty = GREATEST(0, completed_qty - $1),
			status = CASE
				WHEN GREATEST(0, completed_qty - $1) <= 0 THEN 'RELEASED'
				WHEN GREATEST(0, completed_qty - $1) >= order_qty THEN 'COMPLETED'
				ELSE 'PARTIALLY_PRODUCED'
			END,
			updated_by = $2,
			updated_at = NOW()
		WHERE id = $3 AND tenant_id = $4
	`, rec.Quantity, userID, rec.POID, tenantID)
	if err != nil {
		return fmt.Errorf("revert production order completed qty: %w", err)
	}

	now := time.Now()
	_, err = tx.Exec(ctx, `
		UPDATE work_order_receipts
		SET is_reversed = true, reversed_at = $1, updated_at = NOW()
		WHERE id = $2 AND tenant_id = $3
	`, now, receiptID, tenantID)
	if err != nil {
		return fmt.Errorf("mark work order receipt reversed: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit work order receipt reversal: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) CreateInvoice(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateInvoiceRequest, createdBy *uuid.UUID) (*purchasemodels.PurchaseInvoice, *purchasemodels.BusinessEvent, error) {
	invoiceID := uuid.New()
	now := time.Now()

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	invoiceDate := now
	if req.InvoiceDate != "" {
		parsed, err := time.Parse("2006-01-02", req.InvoiceDate)
		if err == nil {
			invoiceDate = parsed
		}
	}
	currency := req.Currency
	if currency == "" {
		currency = "USD"
	}

	var event *purchasemodels.BusinessEvent

	// ── Duplicate check ──
	if req.POID != nil {
		var dupCount int
		err = tx.QueryRow(ctx, `SELECT COUNT(*) FROM purchase_invoices WHERE invoice_number = $1 AND po_id = $2 AND org_id = $3 AND status != 'REJECTED'`,
			req.InvoiceNumber, *req.POID, orgID).Scan(&dupCount)
		if err == nil && dupCount > 0 {
			return nil, nil, fmt.Errorf("duplicate invoice: invoice number %s already exists for this PO", req.InvoiceNumber)
		}
	}

	// Insert invoice
	_, err = tx.Exec(ctx, `
		INSERT INTO purchase_invoices (id, org_id, invoice_number, vendor_id, po_id, invoice_date, total_amount, tax_amount, currency, status, created_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'DRAFT',$10,NOW(),NOW())
	`, invoiceID, orgID, req.InvoiceNumber, req.VendorID, req.POID, invoiceDate, req.TotalAmount, req.TaxAmount, currency, createdBy)
	if err != nil {
		return nil, nil, fmt.Errorf("insert invoice: %w", err)
	}

	matchResult := "NO_MATCH"
	var totalPriceDiff float64

	// ── 3-Way Match: insert invoice items & compare ──
	if req.POID != nil && len(req.Items) > 0 {
		poItems, err := r.getPOItems(ctx, *req.POID)
		if err != nil {
			return nil, nil, fmt.Errorf("get po items: %w", err)
		}

		// Build poItem map
		poItemMap := make(map[string]purchasemodels.PurchaseOrderItem)
		for _, pi := range poItems {
			poItemMap[pi.ItemID.String()] = pi
		}

		totalQty := 0.0
		totalMatchQty := 0.0
		var matchDetails []map[string]interface{}

		for _, invItem := range req.Items {
			lineTotal := invItem.Quantity * invItem.UnitPrice

			pi, hasPO := poItemMap[invItem.ItemID.String()]
			grQty := 0.0
			poPrice := invItem.UnitPrice
			priceDiff := 0.0

			if hasPO {
				// Check invoice qty <= received qty - already invoiced
				openQty := pi.ReceivedQuantity - pi.InvoicedQuantity
				if invItem.Quantity > openQty+0.001 {
					return nil, nil, fmt.Errorf("item %s: invoice qty %.2f exceeds open GR qty %.2f (received=%.2f, invoiced=%.2f)",
						pi.ItemSKU, invItem.Quantity, openQty, pi.ReceivedQuantity, pi.InvoicedQuantity)
				}
				poPrice = pi.UnitPrice
				grQty = pi.ReceivedQuantity
				priceDiff = (invItem.UnitPrice - pi.UnitPrice) * invItem.Quantity
				totalPriceDiff += priceDiff

				// Count matched qty for partial detection
				if invItem.Quantity >= (openQty - 0.001) {
					totalMatchQty += openQty
				}
				totalQty += openQty

				// Update PO item invoiced_quantity
				_, err = tx.Exec(ctx, `UPDATE purchase_order_items SET invoiced_quantity = invoiced_quantity + $1 WHERE id = $2`,
					invItem.Quantity, pi.ID)
				if err != nil {
					return nil, nil, fmt.Errorf("update po item invoiced qty: %w", err)
				}
			}

			// Insert invoice_item
			_, err = tx.Exec(ctx, `
				INSERT INTO invoice_items (id, invoice_id, po_item_id, item_id, quantity, unit_price, line_total, gr_quantity, po_unit_price, price_diff)
				VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
			`, uuid.New(), invoiceID, nilIfUUID(pi.ID), invItem.ItemID,
				invItem.Quantity, invItem.UnitPrice, lineTotal, grQty, poPrice, priceDiff)
			if err != nil {
				return nil, nil, fmt.Errorf("insert invoice_item: %w", err)
			}

			matchDetails = append(matchDetails, map[string]interface{}{
				"item_id":    invItem.ItemID.String(),
				"quantity":   invItem.Quantity,
				"unit_price": invItem.UnitPrice,
				"po_price":   poPrice,
				"price_diff": priceDiff,
			})
		}

		// Determine match result
		if totalPriceDiff < -0.01 || totalPriceDiff > 0.01 {
			matchResult = "PRICE_MISMATCH"
		} else if totalMatchQty >= totalQty-0.001 {
			matchResult = "FULL_MATCH"
		} else {
			matchResult = "PARTIAL_MATCH"
		}

		// Determine status
		status := "MATCHED"
		if matchResult == "PRICE_MISMATCH" {
			status = "BLOCKED"
		} else if matchResult == "PARTIAL_MATCH" {
			status = "PARTIALLY_POSTED"
		}

		// Update invoice with match results
		matchJSON, _ := json.Marshal(matchDetails)
		_, err = tx.Exec(ctx, `UPDATE purchase_invoices SET match_status = $2, status = $3, match_detail = $4, updated_at = NOW() WHERE id = $1`,
			invoiceID, matchResult, status, matchJSON)
		if err != nil {
			return nil, nil, fmt.Errorf("update invoice match: %w", err)
		}

		// Update PO status (for both FULL and PARTIAL match)
		var totalOpen float64
		_ = tx.QueryRow(ctx, `SELECT COALESCE(SUM(quantity - invoiced_quantity),0) FROM purchase_order_items WHERE po_id = $1`, *req.POID).Scan(&totalOpen)
		poStatus := "PARTIALLY_INVOICED"
		if totalOpen <= 0.001 {
			poStatus = "INVOICED"
		}
		_, err = tx.Exec(ctx, `UPDATE purchase_orders SET status = $2, updated_at = NOW() WHERE id = $1`, *req.POID, poStatus)
		if err != nil {
			return nil, nil, fmt.Errorf("update po status: %w", err)
		}

		// Create business event
		eventType := "PO_INVOICE_MATCHED"
		if matchResult == "FULL_MATCH" {
			eventType = "PO_INVOICE_SETTLED"
		}
		eventData, _ := json.Marshal(map[string]interface{}{
			"invoice_id":       invoiceID.String(),
			"po_id":            req.POID.String(),
			"vendor_id":        req.VendorID.String(),
			"total_amount":     req.TotalAmount,
			"tax_amount":       req.TaxAmount,
			"match_status":     matchResult,
			"total_price_diff": totalPriceDiff,
		})
		eventID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO business_events (id, org_id, event_type, source_id, source_type, event_data, status, created_at)
			VALUES ($1,$2,$3,$4,'purchase_invoice',$5,'PENDING',NOW())
		`, eventID, orgID, eventType, invoiceID, eventData)
		if err != nil {
			return nil, nil, fmt.Errorf("insert business event: %w", err)
		}

		// Build event for return
		event = &purchasemodels.BusinessEvent{
			ID: eventID, OrgID: orgID, EventType: eventType,
			SourceID: invoiceID, SourceType: "purchase_invoice", Status: "PENDING", CreatedAt: now,
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, fmt.Errorf("commit invoice: %w", err)
	}

	invoice, _ := r.GetInvoice(ctx, invoiceID, orgID)
	return invoice, event, nil
}

func (r *PurchaseRepo) GetInvoice(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.PurchaseInvoice, error) {
	inv := &purchasemodels.PurchaseInvoice{}
	err := r.db.QueryRow(ctx, `
		SELECT pi.id, pi.org_id, pi.invoice_number, pi.vendor_id, pi.po_id, pi.invoice_date,
			pi.total_amount, pi.tax_amount, pi.currency, pi.status, COALESCE(pi.match_status,''),
			COALESCE(pi.notes,''), pi.created_by, pi.created_at, pi.updated_at,
			COALESCE(v.name,''), COALESCE(po.po_number,'')
		FROM purchase_invoices pi
		LEFT JOIN vendors v ON v.id = pi.vendor_id
		LEFT JOIN purchase_orders po ON po.id = pi.po_id
		WHERE pi.id = $1 AND pi.org_id = $2
	`, id, orgID).Scan(
		&inv.ID, &inv.OrgID, &inv.InvoiceNumber, &inv.VendorID, &inv.POID, &inv.InvoiceDate,
		&inv.TotalAmount, &inv.TaxAmount, &inv.Currency, &inv.Status, &inv.MatchStatus,
		&inv.Notes, &inv.CreatedBy, &inv.CreatedAt, &inv.UpdatedAt,
		&inv.VendorName, &inv.PONumber)
	if err != nil {
		return nil, fmt.Errorf("get invoice: %w", err)
	}
	return inv, nil
}

func (r *PurchaseRepo) GetInvoiceItems(ctx context.Context, invoiceID uuid.UUID) ([]purchasemodels.InvoiceItem, error) {
	rows, err := r.db.Query(ctx, `
		SELECT ii.id, ii.invoice_id, ii.po_item_id, ii.item_id,
			COALESCE(p.sku,''), COALESCE(p.name,''),
			ii.quantity, ii.unit_price, ii.line_total, ii.gr_quantity, ii.po_unit_price, ii.price_diff
		FROM invoice_items ii
		LEFT JOIN products p ON p.id = ii.item_id
		WHERE ii.invoice_id = $1
		ORDER BY ii.id
	`, invoiceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []purchasemodels.InvoiceItem
	for rows.Next() {
		item := purchasemodels.InvoiceItem{}
		if err := rows.Scan(&item.ID, &item.InvoiceID, &item.POItemID, &item.ItemID,
			&item.ItemSKU, &item.ItemName,
			&item.Quantity, &item.UnitPrice, &item.LineTotal, &item.GRQuantity, &item.POUnitPrice, &item.PriceDiff); err != nil {
			return nil, err
		}
		list = append(list, item)
	}
	return list, nil
}

func (r *PurchaseRepo) ListInvoices(ctx context.Context, orgID uuid.UUID, vendorID uuid.UUID) ([]*purchasemodels.PurchaseInvoice, error) {
	query := `SELECT pi.id, pi.org_id, pi.invoice_number, pi.vendor_id, pi.po_id, pi.invoice_date,
		pi.total_amount, pi.tax_amount, pi.currency, pi.status, COALESCE(pi.match_status,''),
		COALESCE(pi.notes,''), pi.created_by, pi.created_at, pi.updated_at,
		COALESCE(v.name,''), COALESCE(po.po_number,'')
		FROM purchase_invoices pi
		LEFT JOIN vendors v ON v.id = pi.vendor_id
		LEFT JOIN purchase_orders po ON po.id = pi.po_id
		WHERE pi.org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2
	if vendorID != uuid.Nil {
		query += fmt.Sprintf(" AND pi.vendor_id = $%d", argIdx)
		args = append(args, vendorID)
		argIdx++
	}
	query += " ORDER BY pi.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.PurchaseInvoice
	for rows.Next() {
		inv := &purchasemodels.PurchaseInvoice{}
		if err := rows.Scan(&inv.ID, &inv.OrgID, &inv.InvoiceNumber, &inv.VendorID, &inv.POID, &inv.InvoiceDate,
			&inv.TotalAmount, &inv.TaxAmount, &inv.Currency, &inv.Status, &inv.MatchStatus,
			&inv.Notes, &inv.CreatedBy, &inv.CreatedAt, &inv.UpdatedAt,
			&inv.VendorName, &inv.PONumber); err != nil {
			return nil, err
		}
		list = append(list, inv)
	}
	return list, nil
}

func (r *PurchaseRepo) ListOutstandingInvoices(ctx context.Context, orgID uuid.UUID, vendorID, itemID string, dateFrom, dateTo time.Time) ([]*purchasemodels.OutstandingInvoice, error) {
	query := `
		SELECT pi.id::text, pi.org_id::text, COALESCE(o.org_code,''), COALESCE(o.org_name,''),
		       pi.invoice_number, pi.invoice_date::text,
		       (pi.invoice_date + COALESCE(
		           (SELECT due_days FROM payment_terms pt WHERE pt.code = v.payment_terms AND pt.tenant_id = t.id LIMIT 1),
		           30
		       ))::text AS due_date,
		       pi.total_amount, COALESCE(pi.paid_amount, 0),
		       (pi.total_amount - COALESCE(pi.paid_amount, 0)),
		       pi.currency,
		       pi.vendor_id::text, v.vendor_code, v.name,
		       COALESCE(po.po_number,''), pi.status
		FROM purchase_invoices pi
		JOIN vendors v ON v.id = pi.vendor_id
		LEFT JOIN purchase_orders po ON po.id = pi.po_id
		LEFT JOIN organizations o ON o.id = $2
		JOIN tenants t ON t.id = pi.org_id
		WHERE pi.org_id = $1 AND pi.status NOT IN ('CANCELLED','DRAFT')
		  AND (pi.total_amount - COALESCE(pi.paid_amount, 0)) > 0.001`
	args := []interface{}{orgID, orgID}
	argIdx := 3

	if vendorID != "" {
		query += fmt.Sprintf(" AND pi.vendor_id = $%d::uuid", argIdx)
		args = append(args, vendorID)
		argIdx++
	}
	if itemID != "" {
		query += fmt.Sprintf(` AND pi.id IN (SELECT invoice_id FROM invoice_items WHERE item_id = $%d::uuid)`, argIdx)
		args = append(args, itemID)
		argIdx++
	}
	if !dateFrom.IsZero() {
		query += fmt.Sprintf(" AND pi.invoice_date >= $%d", argIdx)
		args = append(args, dateFrom)
		argIdx++
	}
	if !dateTo.IsZero() {
		query += fmt.Sprintf(" AND pi.invoice_date <= $%d", argIdx)
		args = append(args, dateTo)
		argIdx++
	}
	query += ` ORDER BY due_date ASC`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	now := time.Now()
	var list []*purchasemodels.OutstandingInvoice
	for rows.Next() {
		inv := &purchasemodels.OutstandingInvoice{}
		if err := rows.Scan(&inv.ID, &inv.OrgID, &inv.OrgCode, &inv.OrgName,
			&inv.InvoiceNumber, &inv.InvoiceDate,
			&inv.DueDate,
			&inv.TotalAmount, &inv.PaidAmount, &inv.OpenAmount,
			&inv.Currency,
			&inv.VendorID, &inv.VendorCode, &inv.VendorName,
			&inv.PONumber, &inv.Status); err != nil {
			return nil, err
		}
		// Calculate days overdue
		if dueDate, err := time.Parse("2006-01-02", inv.DueDate); err == nil {
			inv.DaysOverdue = int(now.Sub(dueDate).Hours() / 24)
		}
		list = append(list, inv)
	}
	return list, nil
}

// ══════════════════════════════════════════
//  PO ATTACHMENTS
// ══════════════════════════════════════════

func (r *PurchaseRepo) InsertAttachment(ctx context.Context, orgID, poID, attachID uuid.UUID, fileName, fileType string, fileSize int64, filePath string, userID *uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO po_attachments (id, po_id, org_id, file_name, file_type, file_size, file_path, uploaded_by, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
	`, attachID, poID, orgID, fileName, fileType, fileSize, filePath, userID)
	return err
}

func (r *PurchaseRepo) ListAttachments(ctx context.Context, orgID, poID uuid.UUID) ([]map[string]interface{}, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, file_name, file_type, file_size, description, uploaded_by, created_at
		FROM po_attachments WHERE po_id = $1 AND org_id = $2 ORDER BY created_at DESC
	`, poID, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []map[string]interface{}
	for rows.Next() {
		var id, fileName, fileType string
		var fileSize int64
		var createdAt time.Time
		var desc, uploadedBy *string
		if err := rows.Scan(&id, &fileName, &fileType, &fileSize, &desc, &uploadedBy, &createdAt); err != nil {
			return nil, err
		}
		m := map[string]interface{}{
			"id":         id,
			"file_name":  fileName,
			"file_type":  fileType,
			"file_size":  fileSize,
			"created_at": createdAt.Format("2006-01-02 15:04:05"),
		}
		if desc != nil {
			m["description"] = *desc
		}
		if uploadedBy != nil {
			m["uploaded_by"] = *uploadedBy
		}
		list = append(list, m)
	}
	return list, nil
}

func (r *PurchaseRepo) GetAttachment(ctx context.Context, orgID, poID, attachID uuid.UUID) (map[string]interface{}, error) {
	var id, fileName, fileType, filePath string
	var fileSize int64
	err := r.db.QueryRow(ctx, `
		SELECT id, file_name, file_type, file_size, file_path FROM po_attachments
		WHERE id = $1 AND po_id = $2 AND org_id = $3
	`, attachID, poID, orgID).Scan(&id, &fileName, &fileType, &fileSize, &filePath)
	if err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"id":        id,
		"file_name": fileName,
		"file_type": fileType,
		"file_size": fileSize,
		"file_path": filePath,
	}, nil
}

// ══════════════════════════════════════════
//  AI — Smart Vendor Recommendation
// ══════════════════════════════════════════

// ══════════════════════════════════════════
//  RECEIPT → JOURNAL ENTRY LINK
// ══════════════════════════════════════════

// FindJournalEntryForReceipt looks up the GL journal entry linked to a purchase receipt.
// The JE's description contains the receipt ID prefix.
func (r *PurchaseRepo) FindJournalEntryForReceipt(ctx context.Context, receiptID uuid.UUID) (map[string]interface{}, error) {
	var linkedJEID uuid.UUID
	_ = r.db.QueryRow(ctx, `SELECT gl_je_id FROM work_order_receipts WHERE id = $1 AND gl_je_id IS NOT NULL`, receiptID).Scan(&linkedJEID)
	if linkedJEID != uuid.Nil {
		var jeID, docNo, status, description string
		err := r.db.QueryRow(ctx, `
			SELECT id, document_no, status, description
			FROM gl_journal_entries
			WHERE id = $1
			LIMIT 1
		`, linkedJEID).Scan(&jeID, &docNo, &status, &description)
		if err != nil {
			return nil, err
		}
		return map[string]interface{}{
			"id":          jeID,
			"document_no": docNo,
			"status":      status,
			"description": description,
		}, nil
	}

	prefix := receiptID.String()[:8]
	// Search by description pattern — the JE description contains "Receipt XXXX..."
	var jeID, docNo, status, description string
	err := r.db.QueryRow(ctx, `
		SELECT id, document_no, status, description
		FROM gl_journal_entries
		WHERE description ILIKE $1 AND source = 'purchase'
		ORDER BY created_at DESC
		LIMIT 1
	`, "%Receipt%"+prefix+"%").Scan(&jeID, &docNo, &status, &description)
	if err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"id":          jeID,
		"document_no": docNo,
		"status":      status,
		"description": description,
	}, nil
}

func (r *PurchaseRepo) GetJournalEntryLines(ctx context.Context, jeID uuid.UUID) ([]map[string]interface{}, error) {
	rows, err := r.db.Query(ctx, `
		SELECT jl.id, jl.account_id, COALESCE(a.account_code,''), COALESCE(a.account_name,''),
			jl.debit, jl.credit, COALESCE(jl.description,''), COALESCE(jl.partner_type,''), jl.partner_id
		FROM gl_journal_lines jl
		LEFT JOIN gl_accounts a ON a.id = jl.account_id
		WHERE jl.entry_id = $1
		ORDER BY jl.id
	`, jeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var lines []map[string]interface{}
	for rows.Next() {
		var id, accID, accCode, accName, desc, pType string
		var debit, credit float64
		var partnerID *string
		if err := rows.Scan(&id, &accID, &accCode, &accName, &debit, &credit, &desc, &pType, &partnerID); err != nil {
			return nil, err
		}
		m := map[string]interface{}{
			"id":           id,
			"account_code": accCode,
			"account_name": accName,
			"debit":        debit,
			"credit":       credit,
			"description":  desc,
			"partner_type": pType,
		}
		if partnerID != nil {
			m["partner_id"] = *partnerID
		}
		lines = append(lines, m)
	}
	return lines, nil
}

func (r *PurchaseRepo) RecommendVendors(ctx context.Context, orgID uuid.UUID, productID uuid.UUID) ([]*purchasemodels.VendorRecommendation, error) {
	// AI heuristic: score active vendors by (ai_rating * 0.5 + on_time_probability * 0.3 + lead_time_score * 0.2)
	rows, err := r.db.Query(ctx, `
		SELECT v.id, v.org_id, v.vendor_code, v.name, COALESCE(v.tax_number,''), v.currency, v.payment_terms, v.status,
			v.ai_rating, v.lead_time_days, COALESCE(v.address,''), COALESCE(v.contact_person,''),
			COALESCE(v.contact_email,''), COALESCE(v.contact_phone,''), v.is_active, v.created_at, v.updated_at
		FROM vendors v
		WHERE v.org_id = $1 AND v.status = 'active' AND v.is_active = true
		ORDER BY v.ai_rating DESC, v.lead_time_days ASC
		LIMIT 5
	`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var recs []*purchasemodels.VendorRecommendation
	for rows.Next() {
		v := &purchasemodels.Vendor{}
		if err := rows.Scan(&v.ID, &v.OrgID, &v.VendorCode, &v.Name, &v.TaxNumber, &v.Currency,
			&v.PaymentTerms, &v.Status, &v.AIRating, &v.LeadTimeDays, &v.Address, &v.ContactPerson,
			&v.ContactEmail, &v.ContactPhone, &v.IsActive, &v.CreatedAt, &v.UpdatedAt); err != nil {
			return nil, err
		}
		score := v.AIRating*0.5 + 0.3 + (1.0-float64(v.LeadTimeDays)/30.0)*0.2
		if score > 5.0 {
			score = 5.0
		}
		if score < 0 {
			score = 0
		}

		reason := "Good rating"
		if v.AIRating >= 4.0 {
			reason = "Top-rated vendor with fast lead time"
		} else if v.AIRating >= 3.0 {
			reason = "Reliable vendor with competitive terms"
		} else {
			reason = "Available vendor, review before ordering"
		}

		recs = append(recs, &purchasemodels.VendorRecommendation{
			Vendor:      *v,
			Score:       score,
			Reason:      reason,
			AvgPrice:    0,
			AvgLeadTime: float64(v.LeadTimeDays),
			OnTimeRate:  0.85,
		})
	}
	return recs, nil
}

// ══════════════════════════════════════════
//  DOWN PAYMENTS
// ══════════════════════════════════════════

func (r *PurchaseRepo) EnsureDownPaymentTable(ctx context.Context) error {
	_, err := r.db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS down_payments (
			id UUID PRIMARY KEY,
			org_id UUID NOT NULL,
			dp_number VARCHAR(50) NOT NULL,
			vendor_id UUID NOT NULL,
			po_id UUID NOT NULL,
			total_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			paid_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			refunded_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			cleared_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			remaining_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			currency VARCHAR(10) NOT NULL DEFAULT 'USD',
			exchange_rate NUMERIC(18,6) NOT NULL DEFAULT 1,
			ap_dp_account_id UUID NOT NULL,
			credit_account_id UUID NOT NULL,
			status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
			payment_status VARCHAR(30) NOT NULL DEFAULT 'UNPAID',
			gl_je_id UUID,
			payment_gl_je_id UUID,
			description TEXT DEFAULT '',
			reference_no VARCHAR(100) DEFAULT '',
			special_gl_indicator VARCHAR(10) NOT NULL DEFAULT 'A',
			created_by UUID,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_by UUID,
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			posted_by UUID,
			posted_at TIMESTAMPTZ
		)
	`)
	if err != nil {
		return fmt.Errorf("create down_payments table: %w", err)
	}

	_, err = r.db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS down_payment_clearings (
			id UUID PRIMARY KEY,
			dp_id UUID NOT NULL REFERENCES down_payments(id),
			invoice_id UUID NOT NULL,
			clearing_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			currency VARCHAR(10) NOT NULL DEFAULT 'USD',
			gl_je_id UUID,
			notes TEXT DEFAULT '',
			created_by UUID,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`)
	if err != nil {
		return fmt.Errorf("create down_payment_clearings table: %w", err)
	}

	_, err = r.db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS down_payment_refunds (
			id UUID PRIMARY KEY,
			dp_id UUID NOT NULL REFERENCES down_payments(id),
			refund_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			refund_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			refund_method VARCHAR(30) NOT NULL DEFAULT 'BANK_TRANSFER',
			source_account_id UUID NOT NULL,
			gl_je_id UUID,
			payment_gl_je_id UUID,
			reason TEXT NOT NULL DEFAULT '',
			created_by UUID,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`)
	if err != nil {
		return fmt.Errorf("create down_payment_refunds table: %w", err)
	}

	_, err = r.db.Exec(ctx, `CREATE INDEX IF NOT EXISTS idx_dp_org ON down_payments(org_id)`)
	if err != nil {
		return fmt.Errorf("create index idx_dp_org: %w", err)
	}

	_, err = r.db.Exec(ctx, `CREATE INDEX IF NOT EXISTS idx_dp_vendor ON down_payments(vendor_id)`)
	if err != nil {
		return fmt.Errorf("create index idx_dp_vendor: %w", err)
	}

	_, err = r.db.Exec(ctx, `CREATE INDEX IF NOT EXISTS idx_dp_status ON down_payments(status)`)
	if err != nil {
		return fmt.Errorf("create index idx_dp_status: %w", err)
	}

	_, err = r.db.Exec(ctx, `CREATE INDEX IF NOT EXISTS idx_dpc_dp ON down_payment_clearings(dp_id)`)
	if err != nil {
		return fmt.Errorf("create index idx_dpc_dp: %w", err)
	}

	_, err = r.db.Exec(ctx, `CREATE INDEX IF NOT EXISTS idx_dpr_dp ON down_payment_refunds(dp_id)`)
	if err != nil {
		return fmt.Errorf("create index idx_dpr_dp: %w", err)
	}

	return nil
}

func (r *PurchaseRepo) CreateDownPayment(ctx context.Context, orgID uuid.UUID, dp *purchasemodels.DownPayment, tx interface{}) error {
	db := r.db
	if tx != nil {
		if pgxTx, ok := tx.(interface {
			Exec(ctx context.Context, sql string, args ...interface{}) (interface{}, error)
		}); ok {
			run := func(ctx context.Context, sql string, args ...interface{}) (interface{}, error) {
				return pgxTx.Exec(ctx, sql, args...)
			}
			_, err := run(ctx, `
				INSERT INTO down_payments (id, org_id, dp_number, vendor_id, po_id, total_amount, paid_amount, refunded_amount, cleared_amount, remaining_amount, currency, exchange_rate, ap_dp_account_id, credit_account_id, status, payment_status, gl_je_id, payment_gl_je_id, description, reference_no, special_gl_indicator, created_by, created_at, updated_by, updated_at, posted_by, posted_at)
				VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,NOW(),$23,NOW(),$24,$25)
			`, dp.ID, dp.OrgID, dp.DPNumber, dp.VendorID, dp.POID, dp.TotalAmount, dp.PaidAmount, dp.RefundedAmount, dp.ClearedAmount, dp.RemainingAmount,
				dp.Currency, dp.ExchangeRate, dp.APDPAccountID, dp.CreditAccountID, dp.Status, dp.PaymentStatus,
				dp.GLJEID, dp.PaymentGLJEID, dp.Description, dp.ReferenceNo, dp.SpecialGLIndicator,
				dp.CreatedBy, dp.UpdatedBy, dp.PostedBy, dp.PostedAt)
			if err != nil {
				return fmt.Errorf("create down payment (tx): %w", err)
			}
			return nil
		}
	}

	_, err := db.Exec(ctx, `
		INSERT INTO down_payments (id, org_id, dp_number, vendor_id, po_id, total_amount, paid_amount, refunded_amount, cleared_amount, remaining_amount, currency, exchange_rate, ap_dp_account_id, credit_account_id, status, payment_status, gl_je_id, payment_gl_je_id, description, reference_no, special_gl_indicator, created_by, created_at, updated_by, updated_at, posted_by, posted_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,NOW(),$23,NOW(),$24,$25)
	`, dp.ID, dp.OrgID, dp.DPNumber, dp.VendorID, dp.POID, dp.TotalAmount, dp.PaidAmount, dp.RefundedAmount, dp.ClearedAmount, dp.RemainingAmount,
		dp.Currency, dp.ExchangeRate, dp.APDPAccountID, dp.CreditAccountID, dp.Status, dp.PaymentStatus,
		dp.GLJEID, dp.PaymentGLJEID, dp.Description, dp.ReferenceNo, dp.SpecialGLIndicator,
		dp.CreatedBy, dp.UpdatedBy, dp.PostedBy, dp.PostedAt)
	if err != nil {
		return fmt.Errorf("create down payment: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) GetDownPayment(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.DownPayment, error) {
	dp := &purchasemodels.DownPayment{}
	err := r.db.QueryRow(ctx, `
		SELECT dp.id, dp.org_id, dp.dp_number, dp.vendor_id, COALESCE(v.vendor_code,''), COALESCE(v.name,''),
			dp.po_id, COALESCE(po.po_number,''),
			dp.total_amount, dp.paid_amount, dp.refunded_amount, dp.cleared_amount, dp.remaining_amount,
			dp.currency, dp.exchange_rate,
			dp.ap_dp_account_id, dp.credit_account_id,
			COALESCE(ap_acc.account_code,''), COALESCE(ap_acc.account_name,''),
			COALESCE(ca_acc.account_code,''), COALESCE(ca_acc.account_name,''),
			dp.status, dp.payment_status, dp.gl_je_id, dp.payment_gl_je_id,
			COALESCE(dp.description,''), COALESCE(dp.reference_no,''), dp.special_gl_indicator,
			dp.created_by, dp.created_at, dp.updated_by, dp.updated_at, dp.posted_by, dp.posted_at
		FROM down_payments dp
		LEFT JOIN vendors v ON v.id = dp.vendor_id
		LEFT JOIN purchase_orders po ON po.id = dp.po_id
		LEFT JOIN gl_accounts ca_acc ON ca_acc.id = dp.credit_account_id
		LEFT JOIN gl_accounts ap_acc ON ap_acc.id = dp.ap_dp_account_id
		WHERE dp.id = $1 AND dp.org_id = $2
	`, id, orgID).Scan(
		&dp.ID, &dp.OrgID, &dp.DPNumber, &dp.VendorID, &dp.VendorCode, &dp.VendorName,
		&dp.POID, &dp.PONumber,
		&dp.TotalAmount, &dp.PaidAmount, &dp.RefundedAmount, &dp.ClearedAmount, &dp.RemainingAmount,
		&dp.Currency, &dp.ExchangeRate,
		&dp.APDPAccountID, &dp.CreditAccountID,
		&dp.APDPAccountCode, &dp.APDPAccountName,
		&dp.CreditAccountCode, &dp.CreditAccountName,
		&dp.Status, &dp.PaymentStatus, &dp.GLJEID, &dp.PaymentGLJEID,
		&dp.Description, &dp.ReferenceNo, &dp.SpecialGLIndicator,
		&dp.CreatedBy, &dp.CreatedAt, &dp.UpdatedBy, &dp.UpdatedAt, &dp.PostedBy, &dp.PostedAt)
	if err != nil {
		return nil, fmt.Errorf("get down payment: %w", err)
	}
	return dp, nil
}

func (r *PurchaseRepo) DeleteDownPayment(ctx context.Context, id, orgID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM down_payments WHERE id = $1 AND org_id = $2 AND status = 'DRAFT'`, id, orgID)
	if err != nil {
		return fmt.Errorf("delete down payment: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) ListDownPayments(ctx context.Context, orgID uuid.UUID, vendorID uuid.UUID, status, dateFrom, dateTo string, minAmount, maxAmount float64) ([]*purchasemodels.DownPayment, error) {
	query := `SELECT dp.id, dp.org_id, dp.dp_number, dp.vendor_id, COALESCE(v.vendor_code,''), COALESCE(v.name,''),
		dp.po_id, COALESCE(po.po_number,''),
		dp.total_amount, dp.paid_amount, dp.refunded_amount, dp.cleared_amount, dp.remaining_amount,
		dp.currency, dp.exchange_rate,
		dp.ap_dp_account_id, dp.credit_account_id,
		COALESCE(ap_acc.account_code,''), COALESCE(ap_acc.account_name,''),
		COALESCE(ca_acc.account_code,''), COALESCE(ca_acc.account_name,''),
		dp.status, dp.payment_status, dp.gl_je_id, dp.payment_gl_je_id,
		COALESCE(dp.description,''), COALESCE(dp.reference_no,''), dp.special_gl_indicator,
		dp.created_by, dp.created_at, dp.updated_by, dp.updated_at, dp.posted_by, dp.posted_at
		FROM down_payments dp
		LEFT JOIN vendors v ON v.id = dp.vendor_id
		LEFT JOIN purchase_orders po ON po.id = dp.po_id
		LEFT JOIN gl_accounts ca_acc ON ca_acc.id = dp.credit_account_id
		LEFT JOIN gl_accounts ap_acc ON ap_acc.id = dp.ap_dp_account_id
		WHERE dp.org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if vendorID != uuid.Nil {
		query += fmt.Sprintf(" AND dp.vendor_id = $%d", argIdx)
		args = append(args, vendorID)
		argIdx++
	}
	if status != "" {
		query += fmt.Sprintf(" AND dp.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	if dateFrom != "" {
		query += fmt.Sprintf(" AND dp.created_at >= $%d::timestamp", argIdx)
		args = append(args, dateFrom)
		argIdx++
	}
	if dateTo != "" {
		query += fmt.Sprintf(" AND dp.created_at <= $%d::timestamp", argIdx)
		args = append(args, dateTo)
		argIdx++
	}
	if minAmount > 0 {
		query += fmt.Sprintf(" AND dp.total_amount >= $%d", argIdx)
		args = append(args, minAmount)
		argIdx++
	}
	if maxAmount > 0 {
		query += fmt.Sprintf(" AND dp.total_amount <= $%d", argIdx)
		args = append(args, maxAmount)
		argIdx++
	}

	query += " ORDER BY dp.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.DownPayment
	for rows.Next() {
		dp := &purchasemodels.DownPayment{}
		if err := rows.Scan(
			&dp.ID, &dp.OrgID, &dp.DPNumber, &dp.VendorID, &dp.VendorCode, &dp.VendorName,
			&dp.POID, &dp.PONumber,
			&dp.TotalAmount, &dp.PaidAmount, &dp.RefundedAmount, &dp.ClearedAmount, &dp.RemainingAmount,
			&dp.Currency, &dp.ExchangeRate,
			&dp.APDPAccountID, &dp.CreditAccountID,
			&dp.APDPAccountCode, &dp.APDPAccountName,
			&dp.CreditAccountCode, &dp.CreditAccountName,
			&dp.Status, &dp.PaymentStatus, &dp.GLJEID, &dp.PaymentGLJEID,
			&dp.Description, &dp.ReferenceNo, &dp.SpecialGLIndicator,
			&dp.CreatedBy, &dp.CreatedAt, &dp.UpdatedBy, &dp.UpdatedAt, &dp.PostedBy, &dp.PostedAt); err != nil {
			return nil, err
		}
		list = append(list, dp)
	}
	return list, nil
}

func (r *PurchaseRepo) UpdateDownPaymentStatus(ctx context.Context, id uuid.UUID, status, paymentStatus string, remainingAmount float64, tx interface{}) error {
	db := r.db
	if tx != nil {
		if pgxTx, ok := tx.(interface {
			Exec(ctx context.Context, sql string, args ...interface{}) (interface{}, error)
		}); ok {
			var err error
			if paymentStatus != "" {
				_, err = pgxTx.Exec(ctx, `UPDATE down_payments SET status = $2, payment_status = $3, remaining_amount = $4, updated_at = NOW() WHERE id = $1`, id, status, paymentStatus, remainingAmount)
			} else {
				_, err = pgxTx.Exec(ctx, `UPDATE down_payments SET status = $2, remaining_amount = $3, updated_at = NOW() WHERE id = $1`, id, status, remainingAmount)
			}
			if err != nil {
				return fmt.Errorf("update down payment status (tx): %w", err)
			}
			return nil
		}
	}

	var err error
	if paymentStatus != "" {
		_, err = db.Exec(ctx, `UPDATE down_payments SET status = $2, payment_status = $3, remaining_amount = $4, updated_at = NOW() WHERE id = $1`, id, status, paymentStatus, remainingAmount)
	} else {
		_, err = db.Exec(ctx, `UPDATE down_payments SET status = $2, remaining_amount = $3, updated_at = NOW() WHERE id = $1`, id, status, remainingAmount)
	}
	if err != nil {
		return fmt.Errorf("update down payment status: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) UpdateDownPaymentGLJE(ctx context.Context, id uuid.UUID, glJeID uuid.UUID, paymentGLJEID *uuid.UUID, postedBy *uuid.UUID, tx interface{}) error {
	db := r.db
	if tx != nil {
		if pgxTx, ok := tx.(interface {
			Exec(ctx context.Context, sql string, args ...interface{}) (interface{}, error)
		}); ok {
			var err error
			if paymentGLJEID != nil {
				_, err = pgxTx.Exec(ctx, `UPDATE down_payments SET gl_je_id = $2, payment_gl_je_id = $3, posted_by = $4, posted_at = NOW(), updated_at = NOW() WHERE id = $1`, id, glJeID, *paymentGLJEID, postedBy)
			} else {
				_, err = pgxTx.Exec(ctx, `UPDATE down_payments SET gl_je_id = $2, posted_by = $3, posted_at = NOW(), updated_at = NOW() WHERE id = $1`, id, glJeID, postedBy)
			}
			if err != nil {
				return fmt.Errorf("update down payment gl je (tx): %w", err)
			}
			return nil
		}
	}

	var err error
	if paymentGLJEID != nil {
		_, err = db.Exec(ctx, `UPDATE down_payments SET gl_je_id = $2, payment_gl_je_id = $3, posted_by = $4, posted_at = NOW(), updated_at = NOW() WHERE id = $1`, id, glJeID, *paymentGLJEID, postedBy)
	} else {
		_, err = db.Exec(ctx, `UPDATE down_payments SET gl_je_id = $2, posted_by = $3, posted_at = NOW(), updated_at = NOW() WHERE id = $1`, id, glJeID, postedBy)
	}
	if err != nil {
		return fmt.Errorf("update down payment gl je: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) CreateDownPaymentClearing(ctx context.Context, clearing *purchasemodels.DownPaymentClearing) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO down_payment_clearings (id, dp_id, invoice_id, clearing_amount, currency, gl_je_id, notes, created_by, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
	`, clearing.ID, clearing.DPID, clearing.InvoiceID, clearing.ClearingAmount, clearing.Currency, clearing.GLJEID, clearing.Notes, clearing.CreatedBy)
	if err != nil {
		return fmt.Errorf("create down payment clearing: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) ListDPClearings(ctx context.Context, dpID uuid.UUID) ([]*purchasemodels.DownPaymentClearing, error) {
	rows, err := r.db.Query(ctx, `
		SELECT dpc.id, dpc.dp_id, dpc.invoice_id, COALESCE(pi.invoice_number,''),
			dpc.clearing_amount, dpc.currency, dpc.gl_je_id, COALESCE(dpc.notes,''),
			dpc.created_by, dpc.created_at
		FROM down_payment_clearings dpc
		LEFT JOIN purchase_invoices pi ON pi.id = dpc.invoice_id
		WHERE dpc.dp_id = $1
		ORDER BY dpc.created_at DESC
	`, dpID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.DownPaymentClearing
	for rows.Next() {
		c := &purchasemodels.DownPaymentClearing{}
		if err := rows.Scan(&c.ID, &c.DPID, &c.InvoiceID, &c.InvoiceNumber,
			&c.ClearingAmount, &c.Currency, &c.GLJEID, &c.Notes,
			&c.CreatedBy, &c.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, nil
}

func (r *PurchaseRepo) CreateDownPaymentRefund(ctx context.Context, refund *purchasemodels.DownPaymentRefund) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO down_payment_refunds (id, dp_id, refund_amount, refund_date, refund_method, source_account_id, gl_je_id, payment_gl_je_id, reason, created_by, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW())
	`, refund.ID, refund.DPID, refund.RefundAmount, refund.RefundDate, refund.RefundMethod, refund.SourceAccountID, refund.GLJEID, refund.PaymentGLJEID, refund.Reason, refund.CreatedBy)
	if err != nil {
		return fmt.Errorf("create down payment refund: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) ListDPRefunds(ctx context.Context, dpID uuid.UUID) ([]*purchasemodels.DownPaymentRefund, error) {
	rows, err := r.db.Query(ctx, `
		SELECT dpr.id, dpr.dp_id, dpr.refund_amount, dpr.refund_date, dpr.refund_method,
			dpr.source_account_id, COALESCE(sa_acc.account_code,''), COALESCE(sa_acc.account_name,''),
			dpr.gl_je_id, dpr.payment_gl_je_id,
			COALESCE(dpr.reason,''), dpr.created_by, dpr.created_at
		FROM down_payment_refunds dpr
		LEFT JOIN gl_accounts sa_acc ON sa_acc.id = dpr.source_account_id
		WHERE dpr.dp_id = $1
		ORDER BY dpr.created_at DESC
	`, dpID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.DownPaymentRefund
	for rows.Next() {
		r := &purchasemodels.DownPaymentRefund{}
		if err := rows.Scan(&r.ID, &r.DPID, &r.RefundAmount, &r.RefundDate, &r.RefundMethod,
			&r.SourceAccountID, &r.SourceAccountCode, &r.SourceAccountName,
			&r.GLJEID, &r.PaymentGLJEID,
			&r.Reason, &r.CreatedBy, &r.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, r)
	}
	return list, nil
}

// ══════════════════════════════════════════
//  VENDOR PAYMENTS & OPEN ITEMS
// ══════════════════════════════════════════

func (r *PurchaseRepo) GetVendorOpenItems(ctx context.Context, vendorID, orgID uuid.UUID) ([]*purchasemodels.OpenItem, error) {
	invRows, err := r.db.Query(ctx, `
		SELECT i.id::text, i.invoice_number, i.invoice_date::text, i.invoice_date::text,
		       i.total_amount, (i.total_amount - COALESCE(i.paid_amount, 0)), i.currency
		FROM purchase_invoices i
		WHERE i.vendor_id = $1 AND i.org_id = $2 AND i.status = 'POSTED'
		  AND i.total_amount - COALESCE(i.paid_amount, 0) > 0.001
		ORDER BY i.invoice_date ASC
	`, vendorID, orgID)
	if err != nil {
		return nil, fmt.Errorf("query open invoices: %w", err)
	}
	defer invRows.Close()

	var items []*purchasemodels.OpenItem
	for invRows.Next() {
		item := &purchasemodels.OpenItem{Type: "INVOICE", IsDownPayment: false}
		if err := invRows.Scan(&item.ID, &item.DocumentNo, &item.Date, &item.DueDate,
			&item.TotalAmount, &item.OpenAmount, &item.Currency); err != nil {
			return nil, fmt.Errorf("scan open invoice: %w", err)
		}
		items = append(items, item)
	}

	dpRows, err := r.db.Query(ctx, `
		SELECT d.id::text, d.dp_number, COALESCE(d.posted_at, d.created_at)::text, COALESCE(d.posted_at, d.created_at)::text,
		       d.total_amount, d.remaining_amount, d.currency
		FROM down_payments d
		WHERE d.vendor_id = $1 AND d.org_id = $2 AND d.status IN ('POSTED','PARTIALLY_CLEARED')
		  AND d.remaining_amount > 0.001
		ORDER BY COALESCE(d.posted_at, d.created_at) ASC
	`, vendorID, orgID)
	if err != nil {
		return nil, fmt.Errorf("query open down payments: %w", err)
	}
	defer dpRows.Close()

	for dpRows.Next() {
		item := &purchasemodels.OpenItem{Type: "DOWN_PAYMENT", IsDownPayment: true}
		if err := dpRows.Scan(&item.ID, &item.DocumentNo, &item.Date, &item.DueDate,
			&item.TotalAmount, &item.OpenAmount, &item.Currency); err != nil {
			return nil, fmt.Errorf("scan open dp: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

func (r *PurchaseRepo) CreateVendorPayment(ctx context.Context, payment *purchasemodels.VendorPayment) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO vendor_payments (id, org_id, vendor_id, bank_account_id, payment_amount, payment_date, currency, status, gl_je_id, description, created_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
	`, payment.ID, payment.OrgID, payment.VendorID, payment.BankAccountID,
		payment.PaymentAmount, payment.PaymentDate, payment.Currency, payment.Status,
		payment.GLJEID, payment.Description, payment.CreatedBy, payment.CreatedAt, payment.CreatedAt)
	if err != nil {
		return fmt.Errorf("create vendor payment: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) CreateVendorPaymentAllocation(ctx context.Context, alloc *purchasemodels.VendorPaymentAllocation) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO vendor_payment_allocations (id, payment_id, source_type, source_id, allocated_amount, created_at)
		VALUES ($1,$2,$3,$4,$5,$6)
	`, alloc.ID, alloc.PaymentID, alloc.SourceType, alloc.SourceID, alloc.AllocatedAmount, alloc.CreatedAt)
	if err != nil {
		return fmt.Errorf("create payment allocation: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) GetVendorPayment(ctx context.Context, id uuid.UUID) (*purchasemodels.VendorPayment, error) {
	p := &purchasemodels.VendorPayment{}
	var glJeID *uuid.UUID
	err := r.db.QueryRow(ctx, `
		SELECT vp.id, vp.org_id, vp.vendor_id, v.vendor_code, COALESCE(v.name, ''),
		       vp.bank_account_id, vp.payment_amount, vp.payment_date, vp.currency, vp.status,
		       vp.gl_je_id, COALESCE(vp.description, ''),
		       vp.created_by, vp.created_at, vp.updated_at
		FROM vendor_payments vp
		LEFT JOIN vendors v ON v.id = vp.vendor_id
		WHERE vp.id = $1
	`, id).Scan(
		&p.ID, &p.OrgID, &p.VendorID, &p.VendorCode, &p.VendorName,
		&p.BankAccountID, &p.PaymentAmount, &p.PaymentDate, &p.Currency, &p.Status,
		&glJeID, &p.Description,
		&p.CreatedBy, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get vendor payment: %w", err)
	}
	if glJeID != nil && *glJeID != uuid.Nil {
		p.GLJEID = glJeID
	}

	allocRows, err := r.db.Query(ctx, `
		SELECT id, payment_id, source_type, source_id, allocated_amount, created_at
		FROM vendor_payment_allocations WHERE payment_id = $1
	`, id)
	if err != nil {
		return nil, fmt.Errorf("load allocations: %w", err)
	}
	defer allocRows.Close()
	for allocRows.Next() {
		a := purchasemodels.VendorPaymentAllocation{}
		if err := allocRows.Scan(&a.ID, &a.PaymentID, &a.SourceType, &a.SourceID, &a.AllocatedAmount, &a.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan allocation: %w", err)
		}
		p.Allocations = append(p.Allocations, a)
	}
	return p, nil
}

func (r *PurchaseRepo) UpdateInvoicePaidAmount(ctx context.Context, invoiceID uuid.UUID, paidAmount float64) error {
	_, err := r.db.Exec(ctx, `UPDATE purchase_invoices SET paid_amount = $2 WHERE id = $1`, invoiceID, paidAmount)
	if err != nil {
		return fmt.Errorf("update invoice paid amount: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) GetInvoicePaidAmount(ctx context.Context, invoiceID uuid.UUID) (float64, error) {
	var paid float64
	err := r.db.QueryRow(ctx, `SELECT COALESCE(paid_amount, 0) FROM purchase_invoices WHERE id = $1`, invoiceID).Scan(&paid)
	if err != nil {
		return 0, fmt.Errorf("get invoice paid amount: %w", err)
	}
	return paid, nil
}

func (r *PurchaseRepo) UpdateDownPaymentCleared(ctx context.Context, id uuid.UUID, clearedAmount, remainingAmount float64, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE down_payments SET cleared_amount = $2, remaining_amount = $3, status = $4, updated_at = NOW() WHERE id = $1`, id, clearedAmount, remainingAmount, status)
	if err != nil {
		return fmt.Errorf("update dp cleared amount: %w", err)
	}
	return nil
}

func (r *PurchaseRepo) ListPaymentHistory(ctx context.Context, orgID uuid.UUID, vendorID string, dateFrom, dateTo time.Time) ([]*purchasemodels.PaymentHistoryItem, error) {
	query := `
		SELECT vp.id::text, vp.org_id::text, COALESCE(o.org_code,''), COALESCE(o.org_name,''),
		       vp.vendor_id::text, v.vendor_code, COALESCE(v.name,''),
		       vp.payment_amount, vp.payment_date::text, vp.currency, vp.status,
		       COALESCE(vp.description,''), COALESCE(vp.gl_je_id::text,'')
		FROM vendor_payments vp
		LEFT JOIN vendors v ON v.id = vp.vendor_id
		LEFT JOIN organizations o ON o.id = vp.org_id
		WHERE vp.org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if vendorID != "" && vendorID != "all" {
		query += fmt.Sprintf(" AND vp.vendor_id = $%d::uuid", argIdx)
		args = append(args, vendorID)
		argIdx++
	}
	if !dateFrom.IsZero() {
		query += fmt.Sprintf(" AND vp.payment_date >= $%d", argIdx)
		args = append(args, dateFrom)
		argIdx++
	}
	if !dateTo.IsZero() {
		query += fmt.Sprintf(" AND vp.payment_date <= $%d", argIdx)
		args = append(args, dateTo)
		argIdx++
	}
	query += ` ORDER BY vp.payment_date DESC, vp.created_at DESC`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*purchasemodels.PaymentHistoryItem
	for rows.Next() {
		p := &purchasemodels.PaymentHistoryItem{}
		if err := rows.Scan(&p.ID, &p.OrgID, &p.OrgCode, &p.OrgName,
			&p.VendorID, &p.VendorCode, &p.VendorName,
			&p.PaymentAmount, &p.PaymentDate, &p.Currency, &p.Status,
			&p.Description, &p.GLJEID); err != nil {
			return nil, err
		}
		list = append(list, p)
	}
	return list, nil
}

// generatePONumber creates a PO number in format PO-YYMMDDNNNN (daily sequential)
func (r *PurchaseRepo) generatePONumber(ctx context.Context) string {
	today := time.Now().Format("060102") // YYMMDD
	var seq int
	_ = r.db.QueryRow(ctx, `
		SELECT COALESCE(MAX(CAST(SUBSTRING(po_number FROM '.{4}$') AS INTEGER)), 0) + 1
		FROM purchase_orders WHERE po_number LIKE $1
	`, "PO-"+today+"%").Scan(&seq)
	if seq < 1 {
		seq = 1
	}
	if seq > 9999 {
		seq = 1
	}
	return fmt.Sprintf("PO-%s%04d", today, seq)
}

// nilIfUUID returns nil for zero UUID (for nullable DB columns)
func nilIfUUID(id uuid.UUID) *uuid.UUID {
	if id == uuid.Nil {
		return nil
	}
	return &id
}
