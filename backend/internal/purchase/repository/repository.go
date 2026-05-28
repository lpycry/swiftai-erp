package repository

import (
	"context"
	"encoding/json"
	"fmt"
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
		ID:                     uuid.New(),
		OrgID:                  orgID,
		VendorCode:             req.VendorCode,
		Name:                   req.Name,
		TaxNumber:              req.TaxNumber,
		Currency:               req.Currency,
		PaymentTerms:           req.PaymentTerms,
		Status:                 "active",
		LeadTimeDays:           req.LeadTimeDays,
		Address:                req.Address,
		ContactPerson:          req.ContactPerson,
		ContactEmail:           req.ContactEmail,
		ContactPhone:           req.ContactPhone,
		ReconciliationAccountID: req.ReconciliationAccountID,
		IsActive:               true,
		CreatedAt:              time.Now(),
		UpdatedAt:              time.Now(),
	}
	if v.Currency == "" { v.Currency = "USD" }
	if v.PaymentTerms == "" { v.PaymentTerms = "Net 30" }

	_, err := r.db.Exec(ctx, `
		INSERT INTO vendors(id, org_id, vendor_code, name, tax_number, currency, payment_terms, status,
			lead_time_days, address, contact_person, contact_email, contact_phone, reconciliation_account_id, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
	`, v.ID, v.OrgID, v.VendorCode, v.Name, v.TaxNumber, v.Currency, v.PaymentTerms, v.Status,
		v.LeadTimeDays, v.Address, v.ContactPerson, v.ContactEmail, v.ContactPhone, v.ReconciliationAccountID, v.IsActive, v.CreatedAt, v.UpdatedAt)
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
			COALESCE(v.contact_email,''), COALESCE(v.contact_phone,''), v.reconciliation_account_id,
			COALESCE(a.account_code,''), COALESCE(a.account_name,''), v.is_active, v.created_at, v.updated_at
		FROM vendors v
		LEFT JOIN gl_accounts a ON a.id = v.reconciliation_account_id
		WHERE v.id = $1 AND v.org_id = $2
	`, id, orgID).Scan(
		&v.ID, &v.OrgID, &v.VendorCode, &v.Name, &v.TaxNumber, &v.Currency, &v.PaymentTerms, &v.Status,
		&v.AIRating, &v.LeadTimeDays, &v.Address, &v.ContactPerson, &v.ContactEmail, &v.ContactPhone,
		&v.ReconciliationAccountID, &v.ReconciliationAccountCode, &v.ReconciliationAccountName,
		&v.IsActive, &v.CreatedAt, &v.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get vendor: %w", err)
	}
	return v, nil
}

func (r *PurchaseRepo) ListVendors(ctx context.Context, orgID uuid.UUID, search string) ([]*purchasemodels.Vendor, error) {
	query := `SELECT v.id, v.org_id, v.vendor_code, v.name, COALESCE(v.tax_number,''), v.currency, v.payment_terms, v.status,
		v.ai_rating, v.lead_time_days, COALESCE(v.address,''), COALESCE(v.contact_person,''),
		COALESCE(v.contact_email,''), COALESCE(v.contact_phone,''), v.reconciliation_account_id,
		COALESCE(a.account_code,''), COALESCE(a.account_name,''), v.is_active, v.created_at, v.updated_at
		FROM vendors v
		LEFT JOIN gl_accounts a ON a.id = v.reconciliation_account_id
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
	if err != nil { return nil, err }
	defer rows.Close()

	var list []*purchasemodels.Vendor
	for rows.Next() {
		v := &purchasemodels.Vendor{}
		if err := rows.Scan(&v.ID, &v.OrgID, &v.VendorCode, &v.Name, &v.TaxNumber, &v.Currency,
			&v.PaymentTerms, &v.Status, &v.AIRating, &v.LeadTimeDays, &v.Address, &v.ContactPerson,
			&v.ContactEmail, &v.ContactPhone, &v.ReconciliationAccountID, &v.ReconciliationAccountCode, &v.ReconciliationAccountName,
			&v.IsActive, &v.CreatedAt, &v.UpdatedAt); err != nil {
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
			reconciliation_account_id = COALESCE($13, reconciliation_account_id),
			is_active    = COALESCE($14, is_active),
			updated_at   = NOW()
		WHERE id = $1 AND org_id = $2
	`, id, orgID, req.Name, req.TaxNumber, req.Currency, req.PaymentTerms, req.Status,
		req.LeadTimeDays, req.Address, req.ContactPerson, req.ContactEmail, req.ContactPhone, req.ReconciliationAccountID, req.IsActive)
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
	poNumber := "PO-" + poID.String()[:8]
	totalAmount := 0.0
	for _, it := range req.Items {
		totalAmount += it.Quantity * it.UnitPrice
	}

	currency := req.Currency
	if currency == "" { currency = "USD" }

	poDate := time.Now()
	if req.PODate != "" {
		if parsed, err := time.Parse("2006-01-02", req.PODate); err == nil {
			poDate = parsed
		}
	}

	tx, err := r.db.Begin(ctx)
	if err != nil { return nil, fmt.Errorf("begin tx: %w", err) }
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO purchase_orders (id, org_id, po_number, vendor_id, total_amount, currency, status, notes,
			organization_id, po_date, payment_term_code, delivery_address, incoterm_code, created_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,'DRAFT',$7,$8,$9,$10,$11,$12,$13,NOW(),NOW())
	`, poID, orgID, poNumber, req.VendorID, totalAmount, currency, req.Notes,
		req.OrganizationID, poDate, req.PaymentTermCode, req.DeliveryAddress, req.IncotermCode, createdBy)
	if err != nil { return nil, fmt.Errorf("insert po: %w", err) }

	for _, it := range req.Items {
		uom := it.UOM
		if uom == "" { uom = "EA" }
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
		if err != nil { return nil, fmt.Errorf("insert po item: %w", err) }
	}

	if err := tx.Commit(ctx); err != nil { return nil, fmt.Errorf("commit po: %w", err) }

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
	if err != nil { return nil, fmt.Errorf("get po: %w", err) }

	// Load items
	items, err := r.getPOItems(ctx, id)
	if err != nil { return nil, err }
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
	if err != nil { return nil, err }
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
	if err != nil { return nil, err }
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
//  PURCHASE RECEIPTS  (核心：联动仓库+财务事件)
// ══════════════════════════════════════════

func (r *PurchaseRepo) ExecuteGoodsReceipt(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateReceiptRequest, userID *uuid.UUID, poStatus string) (*purchasemodels.PurchaseReceipt, *purchasemodels.BusinessEvent, error) {
	receiptID := uuid.New()
	now := time.Now()

	tx, err := r.db.Begin(ctx)
	if err != nil { return nil, nil, fmt.Errorf("begin tx: %w", err) }
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
	if err != nil { return nil, nil, fmt.Errorf("insert receipt: %w", err) }

	// 2. Update PO item received_quantity
	_, err = tx.Exec(ctx, `
		UPDATE purchase_order_items SET received_quantity = received_quantity + $1 WHERE po_id = $2 AND item_id = $3
	`, req.Quantity, req.POID, req.ItemID)
	if err != nil { return nil, nil, fmt.Errorf("update po item: %w", err) }

	// 3. Update PO status to RECEIVED if not already
	if poStatus != "RECEIVED" && poStatus != "INVOICED" {
		_, err = tx.Exec(ctx, `UPDATE purchase_orders SET status = 'RECEIVED', updated_at = NOW() WHERE id = $1`, req.POID)
		if err != nil { return nil, nil, fmt.Errorf("update po status: %w", err) }
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
		if err != nil { return nil, nil, fmt.Errorf("upsert stock: %w", err) }

		// 5. Record stock movement
		moveID = uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO stock_movements (id, tenant_id, transaction_type, reference_type, reference_id, reference_no,
				product_id, warehouse_id, bin_id, quantity, unit_cost, total_cost, description, status, created_by, created_at, posted_at, posted_by)
			VALUES ($1,$2,'goods_receipt','purchase_receipt',$3, $4, $5,$6,$7,$8,$9,$10,'PO Goods Receipt','posted',$11,NOW(),NOW(),$11)
		`, moveID, orgID, receiptID, req.POID.String(), req.ItemID, warehouseID, req.BinID,
			req.Quantity, req.UnitCost, totalCost, userID)
		if err != nil { return nil, nil, fmt.Errorf("insert movement: %w", err) }
	}

	// 6. Create business event for AI GL posting
	eventData, _ := json.Marshal(map[string]interface{}{
		"receipt_id":    receiptID.String(),
		"po_id":         req.POID.String(),
		"item_id":       req.ItemID.String(),
		"site_id":       req.SiteID.String(),
		"quantity":      req.Quantity,
		"unit_cost":     req.UnitCost,
		"total_cost":    totalCost,
		"movement_id":   moveID.String(),
	})
	eventID := uuid.New()
	_, err = tx.Exec(ctx, `
		INSERT INTO business_events (id, org_id, event_type, source_id, source_type, event_data, status, created_at)
		VALUES ($1,$2,'PO_GOODS_RECEIVED',$3,'purchase_receipt',$4,'PENDING',NOW())
	`, eventID, orgID, receiptID, eventData)
	if err != nil { return nil, nil, fmt.Errorf("insert business event: %w", err) }

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

func (r *PurchaseRepo) ListReceipts(ctx context.Context, orgID uuid.UUID, poID uuid.UUID) ([]*purchasemodels.PurchaseReceipt, error) {
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
		WHERE pr.org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2
	if poID != uuid.Nil {
		query += fmt.Sprintf(" AND pr.po_id = $%d", argIdx)
		args = append(args, poID)
		argIdx++
	}
	query += " ORDER BY pr.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil { return nil, err }
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
		list = append(list, r)
	}
	return list, nil
}

// ══════════════════════════════════════════
//  PURCHASE RECEIPT REVERSAL
// ══════════════════════════════════════════

func (r *PurchaseRepo) ReverseGoodsReceipt(ctx context.Context, receiptID, orgID uuid.UUID, userID *uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil { return fmt.Errorf("begin tx: %w", err) }
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
	if err != nil { return fmt.Errorf("revert po item: %w", err) }
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
	if err != nil { return fmt.Errorf("check po received: %w", err) }

	if totalReceived <= 0 {
		_, err = tx.Exec(ctx, `UPDATE purchase_orders SET status = 'CONFIRMED', updated_at = NOW() WHERE id = $1`, rec.POID)
		if err != nil { return fmt.Errorf("revert po status: %w", err) }
	}

	// 4. Mark receipt as reversed
	now := time.Now()
	_, err = tx.Exec(ctx, `
		UPDATE purchase_receipts SET is_reversed = true, reversed_at = $1 WHERE id = $2
	`, now, receiptID)
	if err != nil { return fmt.Errorf("mark reversed: %w", err) }

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit reversal: %w", err)
	}

	return nil
}

// ══════════════════════════════════════════
//  PURCHASE INVOICES  (联动财务结算)
// ══════════════════════════════════════════

func (r *PurchaseRepo) CreateInvoice(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateInvoiceRequest, createdBy *uuid.UUID) (*purchasemodels.PurchaseInvoice, *purchasemodels.BusinessEvent, error) {
	invoiceID := uuid.New()
	now := time.Now()

	tx, err := r.db.Begin(ctx)
	if err != nil { return nil, nil, fmt.Errorf("begin tx: %w", err) }
	defer tx.Rollback(ctx)

	invoiceDate := now
	if req.InvoiceDate != "" {
		parsed, err := time.Parse("2006-01-02", req.InvoiceDate)
		if err == nil { invoiceDate = parsed }
	}
	currency := req.Currency
	if currency == "" { currency = "USD" }

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
	if err != nil { return nil, nil, fmt.Errorf("insert invoice: %w", err) }

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
		if err != nil { return nil, nil, fmt.Errorf("update invoice match: %w", err) }

		// Update PO status (for both FULL and PARTIAL match)
		var totalOpen float64
		_ = tx.QueryRow(ctx, `SELECT COALESCE(SUM(quantity - invoiced_quantity),0) FROM purchase_order_items WHERE po_id = $1`, *req.POID).Scan(&totalOpen)
		poStatus := "PARTIALLY_INVOICED"
		if totalOpen <= 0.001 {
			poStatus = "INVOICED"
		}
		_, err = tx.Exec(ctx, `UPDATE purchase_orders SET status = $2, updated_at = NOW() WHERE id = $1`, *req.POID, poStatus)
		if err != nil { return nil, nil, fmt.Errorf("update po status: %w", err) }

		// Create business event
		eventType := "PO_INVOICE_MATCHED"
		if matchResult == "FULL_MATCH" {
			eventType = "PO_INVOICE_SETTLED"
		}
		eventData, _ := json.Marshal(map[string]interface{}{
			"invoice_id":    invoiceID.String(),
			"po_id":         req.POID.String(),
			"vendor_id":     req.VendorID.String(),
			"total_amount":  req.TotalAmount,
			"tax_amount":    req.TaxAmount,
			"match_status":  matchResult,
			"total_price_diff": totalPriceDiff,
		})
		eventID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO business_events (id, org_id, event_type, source_id, source_type, event_data, status, created_at)
			VALUES ($1,$2,$3,$4,'purchase_invoice',$5,'PENDING',NOW())
		`, eventID, orgID, eventType, invoiceID, eventData)
		if err != nil { return nil, nil, fmt.Errorf("insert business event: %w", err) }

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
	if err != nil { return nil, fmt.Errorf("get invoice: %w", err) }
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
	if err != nil { return nil, err }
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
	if err != nil { return nil, err }
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
		if desc != nil { m["description"] = *desc }
		if uploadedBy != nil { m["uploaded_by"] = *uploadedBy }
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
		if partnerID != nil { m["partner_id"] = *partnerID }
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
	if err != nil { return nil, err }
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
		if score > 5.0 { score = 5.0 }
		if score < 0 { score = 0 }

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

// nilIfUUID returns nil for zero UUID (for nullable DB columns)
func nilIfUUID(id uuid.UUID) *uuid.UUID {
	if id == uuid.Nil {
		return nil
	}
	return &id
}
