package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
)

// ══════════════════════════════════════════
//  SALES ORDERS
// ══════════════════════════════════════════

func (r *SalesRepo) ensureSalesOrderReceiptColumns(ctx context.Context) error {
	_, err := r.db.Exec(ctx, `
		ALTER TABLE sales_orders
		  ADD COLUMN IF NOT EXISTS receipt_method VARCHAR(30) NOT NULL DEFAULT '',
		  ADD COLUMN IF NOT EXISTS received_amount NUMERIC(18,2) NOT NULL DEFAULT 0
	`)
	if err != nil {
		return fmt.Errorf("ensure sales order receipt columns: %w", err)
	}
	return nil
}

func (r *SalesRepo) ListSalesOrders(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.SalesOrder, error) {
	if err := r.ensureSalesOrderReceiptColumns(ctx); err != nil {
		return nil, err
	}
	sql := `SELECT so.id, so.tenant_id, so.customer_id, so.quotation_id, so.so_number, so.so_type, so.status,
		COALESCE(so.customer_po_no,''), so.po_date, so.currency, COALESCE(so.payment_terms,''), COALESCE(so.incoterm,''),
		so.valid_from, so.delivery_date, so.requested_date,
		so.total_amount, so.discount_pct, so.discount_amount, so.net_amount, so.tax_amount, so.grand_total,
		COALESCE(so.receipt_method,''), COALESCE(so.received_amount,0)::float8,
		COALESCE(so.notes,''), COALESCE(so.internal_notes,''),
		COALESCE(so.carrier,''), COALESCE(so.shipping_method,''), COALESCE(so.shipper_account,''),
		so.signature_required, so.saturday_delivery, so.insurance_amt, COALESCE(so.allow_early_ship,false),
		COALESCE(so.transportation_to,''), COALESCE(so.transport_payer_account,''), COALESCE(so.bill_to_address,''),
		so.credit_check_status, so.inventory_check_status, so.tax_calc_status, so.allocation_status,
		so.billing_blocked,
		so.delivery_block_id,
		COALESCE(dbr.block_code,''), COALESCE(dbr.description,''),
		so.created_by, so.created_at, so.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,''), COALESCE(q.quotation_no,'')
		FROM sales_orders so
		LEFT JOIN customers c ON c.id = so.customer_id
		LEFT JOIN quotations q ON q.id = so.quotation_id
		LEFT JOIN delivery_block_reasons dbr ON dbr.id = so.delivery_block_id
		WHERE so.tenant_id = $1`
	args := []interface{}{tenantID}
	if status != "" {
		sql += " AND so.status = $2"
		args = append(args, status)
	}
	sql += " ORDER BY so.created_at DESC"
	rows, err := r.db.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.SalesOrder
	for rows.Next() {
		so := &salesmodels.SalesOrder{}
		if err := rows.Scan(&so.ID, &so.TenantID, &so.CustomerID, &so.QuotationID, &so.SONumber, &so.SOType, &so.Status,
			&so.CustomerPONo, &so.PODate, &so.Currency, &so.PaymentTerms, &so.Incoterm,
			&so.ValidFrom, &so.DeliveryDate, &so.RequestedDate,
			&so.TotalAmount, &so.DiscountPct, &so.DiscountAmount, &so.NetAmount, &so.TaxAmount, &so.GrandTotal,
			&so.ReceiptMethod, &so.ReceivedAmount,
			&so.Notes, &so.InternalNotes,
			&so.Carrier, &so.ShippingMethod, &so.ShipperAccount,
			&so.SignatureRequired, &so.SaturdayDelivery, &so.InsuranceAmt, &so.AllowEarlyShip,
			&so.TransportationTo, &so.TransportPayerAccount, &so.BillToAddress,
			&so.CreditCheckStatus, &so.InventoryCheckStatus, &so.TaxCalcStatus, &so.AllocationStatus,
			&so.BillingBlocked,
			&so.DeliveryBlockID,
			&so.DeliveryBlockCode, &so.DeliveryBlockDesc,
			&so.CreatedBy, &so.CreatedAt, &so.UpdatedAt,
			&so.CustomerCode, &so.CustomerName, &so.QuotationNo); err != nil {
			return nil, err
		}
		items, _ := r.ListSOItems(ctx, so.ID)
		for _, it := range items {
			so.Items = append(so.Items, *it)
		}
		list = append(list, so)
	}
	return list, nil
}

func (r *SalesRepo) GetSalesOrder(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.SalesOrder, error) {
	if err := r.ensureSalesOrderReceiptColumns(ctx); err != nil {
		return nil, err
	}
	so := &salesmodels.SalesOrder{}
	err := r.db.QueryRow(ctx, `SELECT so.id, so.tenant_id, so.customer_id, so.quotation_id, so.so_number, so.so_type, so.status,
		COALESCE(so.customer_po_no,''), so.po_date, so.currency, COALESCE(so.payment_terms,''), COALESCE(so.incoterm,''),
		so.valid_from, so.delivery_date, so.requested_date,
		so.total_amount, so.discount_pct, so.discount_amount, so.net_amount, so.tax_amount, so.grand_total,
		COALESCE(so.receipt_method,''), COALESCE(so.received_amount,0)::float8,
		COALESCE(so.notes,''), COALESCE(so.internal_notes,''),
		COALESCE(so.carrier,''), COALESCE(so.shipping_method,''), COALESCE(so.shipper_account,''),
		so.signature_required, so.saturday_delivery, so.insurance_amt, COALESCE(so.allow_early_ship,false),
		COALESCE(so.transportation_to,''), COALESCE(so.transport_payer_account,''), COALESCE(so.bill_to_address,''),
		so.credit_check_status, so.inventory_check_status, so.tax_calc_status, so.allocation_status,
		so.billing_blocked,
		so.delivery_block_id,
		COALESCE(dbr.block_code,''), COALESCE(dbr.description,''),
		so.created_by, so.created_at, so.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,''), COALESCE(q.quotation_no,'')
		FROM sales_orders so
		LEFT JOIN customers c ON c.id = so.customer_id
		LEFT JOIN quotations q ON q.id = so.quotation_id
		LEFT JOIN delivery_block_reasons dbr ON dbr.id = so.delivery_block_id
		WHERE so.id = $1 AND so.tenant_id = $2`, id, tenantID).Scan(
		&so.ID, &so.TenantID, &so.CustomerID, &so.QuotationID, &so.SONumber, &so.SOType, &so.Status,
		&so.CustomerPONo, &so.PODate, &so.Currency, &so.PaymentTerms, &so.Incoterm,
		&so.ValidFrom, &so.DeliveryDate, &so.RequestedDate,
		&so.TotalAmount, &so.DiscountPct, &so.DiscountAmount, &so.NetAmount, &so.TaxAmount, &so.GrandTotal,
		&so.ReceiptMethod, &so.ReceivedAmount,
		&so.Notes, &so.InternalNotes,
		&so.Carrier, &so.ShippingMethod, &so.ShipperAccount,
		&so.SignatureRequired, &so.SaturdayDelivery, &so.InsuranceAmt, &so.AllowEarlyShip,
		&so.TransportationTo, &so.TransportPayerAccount, &so.BillToAddress,
		&so.CreditCheckStatus, &so.InventoryCheckStatus, &so.TaxCalcStatus, &so.AllocationStatus,
		&so.BillingBlocked,
		&so.DeliveryBlockID,
		&so.DeliveryBlockCode, &so.DeliveryBlockDesc,
		&so.CreatedBy, &so.CreatedAt, &so.UpdatedAt,
		&so.CustomerCode, &so.CustomerName, &so.QuotationNo)
	if err != nil {
		return nil, err
	}
	items, err := r.ListSOItems(ctx, id)
	if err != nil {
		return nil, err
	}
	for _, it := range items {
		so.Items = append(so.Items, *it)
	}
	return so, nil
}

func (r *SalesRepo) SalesOrderExistsForQuotation(ctx context.Context, tenantID, quotationID uuid.UUID) (bool, string, error) {
	var soNumber string
	err := r.db.QueryRow(ctx, `SELECT so_number FROM sales_orders
		WHERE tenant_id = $1 AND quotation_id = $2
		ORDER BY created_at DESC LIMIT 1`, tenantID, quotationID).Scan(&soNumber)
	if err != nil {
		if err == pgx.ErrNoRows {
			return false, "", nil
		}
		return false, "", err
	}
	return true, soNumber, nil
}

func (r *SalesRepo) CreateSalesOrder(ctx context.Context, so *salesmodels.SalesOrder, items []*salesmodels.SalesOrderItem) error {
	if err := r.ensureSalesOrderReceiptColumns(ctx); err != nil {
		return err
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO sales_orders(id, tenant_id, customer_id, quotation_id, so_number, so_type, status,
			customer_po_no, po_date, currency, payment_terms, incoterm,
			valid_from, delivery_date, requested_date,
			total_amount, discount_pct, discount_amount, net_amount, tax_amount, grand_total,
			receipt_method, received_amount,
			notes, internal_notes,
			carrier, shipping_method, shipper_account, signature_required, saturday_delivery, insurance_amt, allow_early_ship,
			transportation_to, transport_payer_account, bill_to_address,
			credit_check_status, inventory_check_status, tax_calc_status, allocation_status,
			billing_blocked,
			delivery_block_id,
			created_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$40,$41,$42,$43,$44)
	`, so.ID, so.TenantID, so.CustomerID, so.QuotationID, so.SONumber, so.SOType, so.Status,
		so.CustomerPONo, so.PODate, so.Currency, so.PaymentTerms, so.Incoterm,
		so.ValidFrom, so.DeliveryDate, so.RequestedDate,
		so.TotalAmount, so.DiscountPct, so.DiscountAmount, so.NetAmount, so.TaxAmount, so.GrandTotal,
		so.ReceiptMethod, so.ReceivedAmount,
		so.Notes, so.InternalNotes,
		so.Carrier, so.ShippingMethod, so.ShipperAccount, so.SignatureRequired, so.SaturdayDelivery, so.InsuranceAmt, so.AllowEarlyShip,
		so.TransportationTo, so.TransportPayerAccount, so.BillToAddress,
		so.CreditCheckStatus, so.InventoryCheckStatus, so.TaxCalcStatus, so.AllocationStatus,
		so.BillingBlocked,
		so.DeliveryBlockID,
		so.CreatedBy, so.CreatedAt, so.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert so: %w", err)
	}

	for _, it := range items {
		_, err = tx.Exec(ctx, `
			INSERT INTO sales_order_items(id, so_id, line_no, product_id, delivering_site_id, quotation_item_id, description, quantity, allocated_qty, atp_status, unit_of_measure, unit_price, discount_pct, line_total, delivery_date, confirmed_delivery_date, created_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,COALESCE(NULLIF($10,''),'PENDING'),$11,$12,$13,$14,$15,$16,$17)
		`, it.ID, it.SOID, it.LineNo, it.ProductID, it.DeliveringSiteID, it.QuotationItemID, it.Description,
			it.Quantity, it.AllocatedQty, it.ATPStatus, it.UnitOfMeasure, it.UnitPrice, it.DiscountPct, it.LineTotal, it.DeliveryDate, it.ConfirmedDeliveryDate, it.CreatedAt)
		if err != nil {
			return fmt.Errorf("insert so item %d: %w", it.LineNo, err)
		}
	}
	if err := r.applyATPAllocationsTx(ctx, tx, so.TenantID, so.ID); err != nil {
		return err
	}
	if so.QuotationID != nil {
		if _, err := tx.Exec(ctx, `UPDATE quotations SET status = 'CONVERTED', updated_at = NOW()
			WHERE id = $1 AND tenant_id = $2`, *so.QuotationID, so.TenantID); err != nil {
			return fmt.Errorf("mark quotation converted: %w", err)
		}
	}
	return tx.Commit(ctx)
}

func (r *SalesRepo) UpdateSOStatus(ctx context.Context, id, tenantID uuid.UUID, status string) error {
	_, err := r.db.Exec(ctx, "UPDATE sales_orders SET status = $3, updated_at = NOW() WHERE id = $1 AND tenant_id = $2", id, tenantID, status)
	return err
}

func (r *SalesRepo) UpdateTaxAmount(ctx context.Context, id, tenantID uuid.UUID, taxAmount, grandTotal float64) error {
	_, err := r.db.Exec(ctx, "UPDATE sales_orders SET tax_amount = $3, grand_total = $4, updated_at = NOW() WHERE id = $1 AND tenant_id = $2", id, tenantID, taxAmount, grandTotal)
	return err
}

func (r *SalesRepo) UpdateInventoryStatuses(ctx context.Context, id, tenantID uuid.UUID, inventoryStatus, allocationStatus string) error {
	_, err := r.db.Exec(ctx, "UPDATE sales_orders SET inventory_check_status = $3, allocation_status = $4, updated_at = NOW() WHERE id = $1 AND tenant_id = $2", id, tenantID, inventoryStatus, allocationStatus)
	return err
}

func (r *SalesRepo) GetNextSONo(ctx context.Context, tenantID uuid.UUID) (string, error) {
	prefix := "SO" + time.Now().Format("060102") + "-"
	pattern := "^" + prefix + `([0-9]{5})$`
	var seq int
	err := r.db.QueryRow(ctx, `
		SELECT COALESCE(MAX(SUBSTRING(so_number FROM $2)::int), 0)+1
		FROM sales_orders
		WHERE tenant_id = $1 AND so_number LIKE $3
	`, tenantID, pattern, prefix+"%").Scan(&seq)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%05d", prefix, seq), nil
}

func (r *SalesRepo) DefaultDeliveryWarehouseForSO(ctx context.Context, tenantID, soID uuid.UUID) (uuid.UUID, error) {
	var warehouseID uuid.UUID
	err := r.db.QueryRow(ctx, `SELECT w.id
		FROM sales_order_items soi
		JOIN warehouses w ON w.site_id = soi.delivering_site_id AND w.tenant_id = $1 AND w.is_active = true
		WHERE soi.so_id = $2 AND soi.delivering_site_id IS NOT NULL
		ORDER BY w.code, w.created_at
		LIMIT 1`, tenantID, soID).Scan(&warehouseID)
	if err == nil && warehouseID != uuid.Nil {
		return warehouseID, nil
	}
	err = r.db.QueryRow(ctx, `SELECT si.warehouse_id
		FROM sales_order_items soi
		JOIN stock_items si ON si.product_id = soi.product_id AND si.tenant_id = $1
		JOIN warehouses w ON w.id = si.warehouse_id AND w.is_active = true
		WHERE soi.so_id = $2 AND si.quantity_on_hand - si.quantity_reserved > 0
		ORDER BY si.last_movement_at NULLS LAST, si.created_at
		LIMIT 1`, tenantID, soID).Scan(&warehouseID)
	if err == nil && warehouseID != uuid.Nil {
		return warehouseID, nil
	}
	err = r.db.QueryRow(ctx, `SELECT id FROM warehouses
		WHERE tenant_id = $1 AND is_active = true
		ORDER BY code, created_at
		LIMIT 1`, tenantID).Scan(&warehouseID)
	if err != nil || warehouseID == uuid.Nil {
		return uuid.Nil, fmt.Errorf("no active delivery warehouse found for sales order")
	}
	return warehouseID, nil
}

func (r *SalesRepo) PostSalesOrderReceiptJournal(ctx context.Context, tenantID, userID, soID, warehouseID uuid.UUID) (uuid.UUID, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	defer tx.Rollback(ctx)

	var soNo string
	var grandTotal float64
	err = tx.QueryRow(ctx, `SELECT so_number, grand_total::float8
		FROM sales_orders WHERE id=$1 AND tenant_id=$2 FOR UPDATE`, soID, tenantID).
		Scan(&soNo, &grandTotal)
	if err != nil {
		return uuid.Nil, err
	}
	if grandTotal <= 0 {
		return uuid.Nil, fmt.Errorf("sales order %s total is zero; cannot post receipt journal", soNo)
	}
	orgID, err := salesResolveOrgForWarehouseTx(ctx, tx, tenantID, warehouseID)
	if err != nil {
		return uuid.Nil, err
	}
	clearingAccountID, err := salesAccountForAnyTypeTx(ctx, tx, orgID, "CC_RECEIVABLE_CLEARING", "Credit Card Receivable / Clearing Account")
	if err != nil {
		return uuid.Nil, fmt.Errorf("no CC_RECEIVABLE_CLEARING account configured in Finance Settings (Account Types tab) for org %s; cannot post sales order receipt", orgID)
	}
	arAccountID, err := salesAccountForTypeTx(ctx, tx, orgID, "AR_RECON")
	if err != nil {
		return uuid.Nil, fmt.Errorf("no AR_RECON account configured in Finance Settings (Account Types tab) for org %s; cannot post sales order receipt", orgID)
	}
	lines := []salesJournalLine{
		{accountID: clearingAccountID, debit: grandTotal, description: fmt.Sprintf("Customer receipt clearing %s", soNo)},
		{accountID: arAccountID, credit: grandTotal, description: fmt.Sprintf("Clear customer receivable %s", soNo)},
	}
	entryID, err := salesInsertPostedJournalTx(ctx, tx, tenantID, userID, orgID, time.Now(), fmt.Sprintf("Sales Order Receipt - %s", soNo), soNo, lines)
	if err != nil {
		return uuid.Nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return uuid.Nil, err
	}
	return entryID, nil
}

func (r *SalesRepo) ListSOItems(ctx context.Context, soID uuid.UUID) ([]*salesmodels.SalesOrderItem, error) {
	rows, err := r.db.Query(ctx, `SELECT soi.id, soi.so_id, soi.line_no, soi.product_id, soi.delivering_site_id, soi.quotation_item_id,
		COALESCE(soi.description,''), soi.quantity, soi.allocated_qty,
		COALESCE((SELECT SUM(dni.delivery_qty)
			FROM sales_delivery_note_items dni
			JOIN sales_delivery_notes dn ON dn.id = dni.delivery_id
			WHERE dni.so_item_id = soi.id AND dn.status <> 'CANCELLED'),0)::float8 AS delivered_qty,
		GREATEST(soi.quantity - COALESCE((SELECT SUM(dni.delivery_qty)
			FROM sales_delivery_note_items dni
			JOIN sales_delivery_notes dn ON dn.id = dni.delivery_id
			WHERE dni.so_item_id = soi.id AND dn.status <> 'CANCELLED'),0),0)::float8 AS open_delivery_qty,
		COALESCE(soi.atp_status,'PENDING'), soi.unit_of_measure, soi.unit_price, soi.discount_pct, soi.line_total,
		soi.delivery_date, soi.confirmed_delivery_date, soi.created_at,
		COALESCE(p.sku,''), COALESCE(p.name,'')
		FROM sales_order_items soi
		LEFT JOIN products p ON p.id = soi.product_id
		WHERE soi.so_id = $1 ORDER BY soi.line_no`, soID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.SalesOrderItem
	for rows.Next() {
		it := &salesmodels.SalesOrderItem{}
		if err := rows.Scan(&it.ID, &it.SOID, &it.LineNo, &it.ProductID, &it.DeliveringSiteID, &it.QuotationItemID,
			&it.Description, &it.Quantity, &it.AllocatedQty, &it.DeliveredQty, &it.OpenDeliveryQty,
			&it.ATPStatus, &it.UnitOfMeasure, &it.UnitPrice, &it.DiscountPct, &it.LineTotal,
			&it.DeliveryDate, &it.ConfirmedDeliveryDate, &it.CreatedAt,
			&it.ProductSKU, &it.ProductName); err != nil {
			return nil, err
		}
		sched, _ := r.ListSOScheduleLines(ctx, it.ID)
		it.ScheduleLines = sched
		list = append(list, it)
	}
	return list, nil
}

func (r *SalesRepo) ListSOScheduleLines(ctx context.Context, soItemID uuid.UUID) ([]salesmodels.SalesOrderScheduleLine, error) {
	rows, err := r.db.Query(ctx, `SELECT id, so_item_id, schedule_line_no, confirmed_qty, confirmed_date, source_type, COALESCE(source_ref,''), created_at
		FROM sales_order_item_schedule_lines WHERE so_item_id = $1 ORDER BY schedule_line_no`, soItemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []salesmodels.SalesOrderScheduleLine
	for rows.Next() {
		var sl salesmodels.SalesOrderScheduleLine
		if err := rows.Scan(&sl.ID, &sl.SOItemID, &sl.ScheduleLineNo, &sl.ConfirmedQty, &sl.ConfirmedDate, &sl.SourceType, &sl.SourceRef, &sl.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, sl)
	}
	return list, nil
}

// ── Automated Checks ──

func (r *SalesRepo) CheckInventory(ctx context.Context, tenantID uuid.UUID, items []*salesmodels.SalesOrderItem) (string, error) {
	overall := "AVAILABLE"
	for _, it := range items {
		var onHand float64
		err := r.db.QueryRow(ctx, "SELECT COALESCE(SUM(quantity),0) FROM stock_on_hand WHERE tenant_id = $1 AND product_id = $2", tenantID, it.ProductID).Scan(&onHand)
		if err != nil {
			return "UNAVAILABLE", fmt.Errorf("inventory check product %s: %w", it.ProductID, err)
		}
		if onHand < it.Quantity {
			overall = "PARTIAL"
			if onHand <= 0 {
				overall = "UNAVAILABLE"
				break
			}
		}
	}
	return overall, nil
}

func (r *SalesRepo) CheckCreditLimit(ctx context.Context, tenantID, customerID uuid.UUID, orderAmount float64) (string, error) {
	var limit, used float64
	err := r.db.QueryRow(ctx, "SELECT credit_limit, used_credit FROM credit_limits WHERE tenant_id = $1 AND customer_id = $2", tenantID, customerID).Scan(&limit, &used)
	if err != nil {
		return "SKIPPED", nil
	} // no credit limit configured
	avail := limit - used
	if avail >= orderAmount {
		return "PASSED", nil
	}
	return "FAILED", nil
}

func (r *SalesRepo) CalculateTax(ctx context.Context, tenantID, customerID uuid.UUID, netAmount float64) (float64, string, error) {
	// Check if customer is tax-exempt
	var isExempt bool
	var exemptEndDate time.Time
	var exemptValid bool
	err := r.db.QueryRow(ctx, `SELECT COALESCE(is_tax_exempt, false), tax_exempt_end_date FROM customers WHERE id = $1 AND tenant_id = $2`, customerID, tenantID).Scan(&isExempt, &exemptEndDate, &exemptValid)
	// pgx v5: for nullable types, use special handling. Simpler: just parse text.
	if err == nil && isExempt {
		if !exemptValid || time.Now().Before(exemptEndDate) {
			return 0, "EXEMPT", nil // Customer is tax-exempt, no tax
		}
	}

	// Simple default tax rate lookup based on customer's default tax jurisdiction
	var taxRate float64
	err = r.db.QueryRow(ctx, `SELECT COALESCE(t.tax_rate, 0) FROM customers c
		LEFT JOIN tax_jurisdictions t ON t.id = c.default_tax_jurisdiction_id
		WHERE c.id = $1 AND c.tenant_id = $2`, customerID, tenantID).Scan(&taxRate)
	if err != nil {
		return 0, "SKIPPED", nil
	}
	return netAmount * taxRate, "CALCULATED", nil
}

func (r *SalesRepo) AllocateInventory(ctx context.Context, tenantID uuid.UUID, items []*salesmodels.SalesOrderItem) (string, error) {
	overall := "ALLOCATED"
	for _, it := range items {
		// Reserve stock by reducing available qty (simplified — real WMS would do bin allocation)
		var onHand float64
		r.db.QueryRow(ctx, "SELECT COALESCE(SUM(quantity),0) FROM stock_on_hand WHERE tenant_id = $1 AND product_id = $2", tenantID, it.ProductID).Scan(&onHand)
		alloc := it.Quantity
		if onHand < alloc {
			alloc = onHand
			overall = "PARTIAL"
		}
		// Record allocation in item
		_, err := r.db.Exec(ctx, "UPDATE sales_order_items SET allocated_qty = $1 WHERE id = $2", alloc, it.ID)
		if err != nil {
			return "NOT_ALLOCATED", err
		}
	}
	return overall, nil
}

// ══════════════════════════════════════════
//  SALES ORDERS — UPDATE
// ══════════════════════════════════════════

func (r *SalesRepo) UpdateSalesOrder(ctx context.Context, so *salesmodels.SalesOrder, items []*salesmodels.SalesOrderItem) error {
	if err := r.ensureSalesOrderReceiptColumns(ctx); err != nil {
		return err
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Update header
	_, err = tx.Exec(ctx, `
		UPDATE sales_orders SET
			customer_id = $3, so_type = $4, status = $5,
			customer_po_no = $6, po_date = $7, currency = $8, payment_terms = $9, incoterm = $10,
			valid_from = $11, delivery_date = $12, requested_date = $13,
			total_amount = $14, discount_pct = $15, discount_amount = $16, net_amount = $17, tax_amount = $18, grand_total = $19,
			notes = $20, internal_notes = $21,
			carrier = $22, shipping_method = $23, shipper_account = $24,
			signature_required = $25, saturday_delivery = $26, insurance_amt = $27, allow_early_ship = $28,
			transportation_to = $29, transport_payer_account = $30, bill_to_address = $31,
			billing_blocked = $32,
			delivery_block_id = $33,
			receipt_method = $34,
			received_amount = $35,
			updated_at = NOW()
		WHERE id = $1 AND tenant_id = $2`, so.ID, so.TenantID,
		so.CustomerID, so.SOType, so.Status,
		so.CustomerPONo, so.PODate, so.Currency, so.PaymentTerms, so.Incoterm,
		so.ValidFrom, so.DeliveryDate, so.RequestedDate,
		so.TotalAmount, so.DiscountPct, so.DiscountAmount, so.NetAmount, so.TaxAmount, so.GrandTotal,
		so.Notes, so.InternalNotes,
		so.Carrier, so.ShippingMethod, so.ShipperAccount,
		so.SignatureRequired, so.SaturdayDelivery, so.InsuranceAmt, so.AllowEarlyShip,
		so.TransportationTo, so.TransportPayerAccount, so.BillToAddress,
		so.BillingBlocked,
		so.DeliveryBlockID,
		so.ReceiptMethod, so.ReceivedAmount)
	if err != nil {
		return fmt.Errorf("update so header: %w", err)
	}

	// Delete old items and insert new ones
	_, err = tx.Exec(ctx, `DELETE FROM sales_order_items WHERE so_id = $1`, so.ID)
	if err != nil {
		return fmt.Errorf("delete old items: %w", err)
	}

	for _, it := range items {
		_, err = tx.Exec(ctx, `
			INSERT INTO sales_order_items(id, so_id, line_no, product_id, delivering_site_id, quotation_item_id, description, quantity, allocated_qty, atp_status, unit_of_measure, unit_price, discount_pct, line_total, delivery_date, confirmed_delivery_date, created_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,COALESCE(NULLIF($10,''),'PENDING'),$11,$12,$13,$14,$15,$16,$17)
		`, it.ID, it.SOID, it.LineNo, it.ProductID, it.DeliveringSiteID, it.QuotationItemID, it.Description,
			it.Quantity, it.AllocatedQty, it.ATPStatus, it.UnitOfMeasure, it.UnitPrice, it.DiscountPct, it.LineTotal, it.DeliveryDate, it.ConfirmedDeliveryDate, it.CreatedAt)
		if err != nil {
			return fmt.Errorf("insert so item %d: %w", it.LineNo, err)
		}
	}
	if err := r.applyATPAllocationsTx(ctx, tx, so.TenantID, so.ID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

type atpScheduleDraft struct {
	Qty       float64
	Date      time.Time
	Source    string
	SourceRef string
}

func (r *SalesRepo) applyATPAllocationsTx(ctx context.Context, tx pgx.Tx, tenantID, soID uuid.UUID) error {
	rows, err := tx.Query(ctx, `SELECT id, product_id, delivering_site_id, quantity, delivery_date FROM sales_order_items WHERE so_id = $1 ORDER BY line_no`, soID)
	if err != nil {
		return fmt.Errorf("load so items for ATP: %w", err)
	}
	defer rows.Close()

	type itemRow struct {
		id            uuid.UUID
		productID     uuid.UUID
		siteID        *uuid.UUID
		qty           float64
		requestedDate *time.Time
	}
	var items []itemRow
	for rows.Next() {
		var it itemRow
		if err := rows.Scan(&it.id, &it.productID, &it.siteID, &it.qty, &it.requestedDate); err != nil {
			return err
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	headerInventoryStatus := "AVAILABLE"
	headerAllocationStatus := "ALLOCATED"
	today := time.Now().Truncate(24 * time.Hour)

	for _, it := range items {
		cutoffDate := atpCutoffDate(today, it.requestedDate)
		stockRows, err := tx.Query(ctx, `SELECT si.quantity_on_hand, si.quantity_reserved
			FROM stock_items si
			WHERE si.tenant_id = $1 AND si.product_id = $2
				AND ($3::uuid IS NULL OR EXISTS (
					SELECT 1 FROM warehouses w WHERE w.id = si.warehouse_id AND w.site_id = $3
				))
			FOR UPDATE`, tenantID, it.productID, it.siteID)
		if err != nil {
			return fmt.Errorf("lock stock for ATP: %w", err)
		}
		var stockAvailable float64
		for stockRows.Next() {
			var qty, reserved float64
			if err := stockRows.Scan(&qty, &reserved); err != nil {
				stockRows.Close()
				return err
			}
			stockAvailable += qty - reserved
		}
		stockRows.Close()
		if stockAvailable < 0 {
			stockAvailable = 0
		}

		var otherAllocated float64
		if err := tx.QueryRow(ctx, `SELECT COALESCE(SUM(GREATEST(soi.allocated_qty - COALESCE(delivered.delivery_qty,0), 0)),0)
			FROM sales_order_items soi
			JOIN sales_orders so ON so.id = soi.so_id
			LEFT JOIN LATERAL (
				SELECT SUM(dni.delivery_qty) AS delivery_qty
				FROM sales_delivery_note_items dni
				JOIN sales_delivery_notes dn ON dn.id = dni.delivery_id
				WHERE dni.so_item_id = soi.id AND dn.status <> 'CANCELLED'
			) delivered ON true
			WHERE so.tenant_id = $1 AND soi.product_id = $2 AND soi.id <> $3
				AND so.status NOT IN ('CANCELLED','COMPLETED','INVOICED')
				AND COALESCE(soi.atp_status,'') <> 'ATP_HOLD'
				AND ($4::uuid IS NULL OR soi.delivering_site_id = $4 OR soi.delivering_site_id IS NULL)`,
			tenantID, it.productID, it.id, it.siteID).Scan(&otherAllocated); err != nil {
			return err
		}

		freeStock := stockAvailable - otherAllocated
		if freeStock < 0 {
			freeStock = 0
		}

		remaining := it.qty
		confirmed := 0.0
		var schedules []atpScheduleDraft
		if freeStock > 0 {
			q := minFloat(remaining, freeStock)
			schedules = append(schedules, atpScheduleDraft{Qty: q, Date: today, Source: "STOCK", SourceRef: "Available Stock"})
			confirmed += q
			remaining -= q
		}

		if remaining > 0 {
			supply, err := r.listNearTermSupplyTx(ctx, tx, tenantID, it.productID, it.siteID, today, cutoffDate)
			if err != nil {
				return err
			}
			for _, s := range supply {
				if remaining <= 0 {
					break
				}
				q := minFloat(remaining, s.Qty)
				if q <= 0 {
					continue
				}
				schedules = append(schedules, atpScheduleDraft{Qty: q, Date: s.Date, Source: s.Source, SourceRef: s.SourceRef})
				confirmed += q
				remaining -= q
			}
		}
		if remaining > 0 {
			rltDate := today.AddDate(0, 0, 14)
			q := remaining
			schedules = append(schedules, atpScheduleDraft{Qty: q, Date: rltDate, Source: "RLT", SourceRef: "Replenishment Lead Time"})
			confirmed += q
			remaining = 0
		}

		status := "ATP_HOLD"
		var confirmedDate *time.Time
		if confirmed >= it.qty {
			status = "RELEASED"
			if len(schedules) > 0 && schedules[len(schedules)-1].Date.After(cutoffDate) {
				status = "PARTIALLY_ALLOCATED"
			}
		} else if confirmed > 0 {
			status = "PARTIALLY_ALLOCATED"
		}
		if len(schedules) > 1 && schedules[0].Date.Equal(today) {
			status = "PARTIALLY_ALLOCATED"
		}
		if len(schedules) > 0 && confirmed >= it.qty {
			d := schedules[len(schedules)-1].Date
			if it.requestedDate != nil && !it.requestedDate.After(d) {
				d = *it.requestedDate
			}
			confirmedDate = &d
		}

		if _, err := tx.Exec(ctx, `DELETE FROM sales_order_item_schedule_lines WHERE so_item_id = $1`, it.id); err != nil {
			return err
		}
		for idx, sl := range schedules {
			if _, err := tx.Exec(ctx, `INSERT INTO sales_order_item_schedule_lines(id, so_item_id, schedule_line_no, confirmed_qty, confirmed_date, source_type, source_ref)
				VALUES($1,$2,$3,$4,$5,$6,$7)`, uuid.New(), it.id, idx+1, sl.Qty, sl.Date, sl.Source, sl.SourceRef); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `UPDATE sales_order_items SET allocated_qty = $2, atp_status = $3, confirmed_delivery_date = $4 WHERE id = $1`,
			it.id, confirmed, status, confirmedDate); err != nil {
			return err
		}

		if status == "ATP_HOLD" {
			headerInventoryStatus = "UNAVAILABLE"
			headerAllocationStatus = "NOT_ALLOCATED"
		} else if status == "PARTIALLY_ALLOCATED" && headerInventoryStatus != "UNAVAILABLE" {
			headerInventoryStatus = "PARTIAL"
			headerAllocationStatus = "PARTIAL"
		}
	}

	_, err = tx.Exec(ctx, `UPDATE sales_orders SET inventory_check_status = $3, allocation_status = $4, updated_at = NOW() WHERE id = $1 AND tenant_id = $2`,
		soID, tenantID, headerInventoryStatus, headerAllocationStatus)
	return err
}

type atpSupplyRow struct {
	Qty       float64
	Date      time.Time
	Source    string
	SourceRef string
}

func atpCutoffDate(today time.Time, deliveryDate *time.Time) time.Time {
	if deliveryDate == nil {
		return today.AddDate(0, 0, 7)
	}
	cutoff := deliveryDate.Truncate(24 * time.Hour)
	if cutoff.Before(today) {
		return today
	}
	return cutoff
}

func (r *SalesRepo) listNearTermSupplyTx(ctx context.Context, tx pgx.Tx, tenantID, productID uuid.UUID, siteID *uuid.UUID, today, until time.Time) ([]atpSupplyRow, error) {
	var supply []atpSupplyRow

	poRows, err := tx.Query(ctx, `SELECT (poi.quantity - poi.received_quantity) AS open_qty,
			COALESCE(poi.expected_delivery_date, po.po_date, CURRENT_DATE) AS supply_date,
			po.po_number
		FROM purchase_order_items poi
		JOIN purchase_orders po ON po.id = poi.po_id
		LEFT JOIN organizations org ON org.id = COALESCE(po.organization_id, po.org_id)
		WHERE poi.item_id = $1
			AND COALESCE(org.tenant_id, $2) = $2
			AND po.status NOT IN ('DRAFT','CANCELLED','RECEIVED','INVOICED')
			AND (poi.quantity - poi.received_quantity) > 0
			AND ($5::uuid IS NULL OR poi.site_id = $5 OR poi.site_id IS NULL)
			AND COALESCE(poi.expected_delivery_date, po.po_date, CURRENT_DATE) BETWEEN $3 AND $4
		ORDER BY supply_date`, productID, tenantID, today, until, siteID)
	if err == nil {
		for poRows.Next() {
			var s atpSupplyRow
			if err := poRows.Scan(&s.Qty, &s.Date, &s.SourceRef); err != nil {
				poRows.Close()
				return nil, err
			}
			s.Source = "PO"
			supply = append(supply, s)
		}
		poRows.Close()
	} else {
		return nil, err
	}

	woRows, err := tx.Query(ctx, `SELECT (order_qty - COALESCE(completed_qty,0)) AS open_qty,
			COALESCE(planned_end_date::date, CURRENT_DATE) AS supply_date,
			order_number
		FROM production_orders
		WHERE tenant_id = $1
			AND material_id = $2
			AND status IN ('RELEASED','IN_PROCESS','PARTIALLY_PRODUCED')
			AND (order_qty - COALESCE(completed_qty,0)) > 0
			AND ($5::uuid IS NULL OR site_id = $5 OR site_id IS NULL)
			AND COALESCE(planned_end_date::date, CURRENT_DATE) BETWEEN $3 AND $4
		ORDER BY supply_date`, tenantID, productID, today, until, siteID)
	if err != nil {
		return nil, err
	}
	defer woRows.Close()
	for woRows.Next() {
		var s atpSupplyRow
		if err := woRows.Scan(&s.Qty, &s.Date, &s.SourceRef); err != nil {
			return nil, err
		}
		s.Source = "WO"
		supply = append(supply, s)
	}
	return supply, nil
}

func minFloat(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

func (r *SalesRepo) PreviewATP(ctx context.Context, tenantID, productID uuid.UUID, quantity float64, deliveryDate *time.Time, siteID *uuid.UUID) (float64, float64, float64, string, []salesmodels.ATPPreviewScheduleLine, error) {
	var stockAvailable float64
	rows, err := r.db.Query(ctx, `SELECT si.quantity_on_hand, si.quantity_reserved
		FROM stock_items si
		WHERE si.tenant_id = $1 AND si.product_id = $2
			AND ($3::uuid IS NULL OR EXISTS (
				SELECT 1 FROM warehouses w WHERE w.id = si.warehouse_id AND w.site_id = $3
			))`, tenantID, productID, siteID)
	if err != nil {
		return 0, 0, 0, "UNAVAILABLE", nil, err
	}
	for rows.Next() {
		var qty, reserved float64
		if err := rows.Scan(&qty, &reserved); err != nil {
			rows.Close()
			return 0, 0, 0, "UNAVAILABLE", nil, err
		}
		stockAvailable += qty - reserved
	}
	rows.Close()
	if stockAvailable < 0 {
		stockAvailable = 0
	}

	var allocated float64
	if err := r.db.QueryRow(ctx, `SELECT COALESCE(SUM(GREATEST(soi.allocated_qty - COALESCE(delivered.delivery_qty,0), 0)),0)
		FROM sales_order_items soi
		JOIN sales_orders so ON so.id = soi.so_id
		LEFT JOIN LATERAL (
			SELECT SUM(dni.delivery_qty) AS delivery_qty
			FROM sales_delivery_note_items dni
			JOIN sales_delivery_notes dn ON dn.id = dni.delivery_id
			WHERE dni.so_item_id = soi.id AND dn.status <> 'CANCELLED'
		) delivered ON true
		WHERE so.tenant_id = $1 AND soi.product_id = $2
			AND so.status NOT IN ('CANCELLED','COMPLETED','INVOICED')
			AND COALESCE(soi.atp_status,'') <> 'ATP_HOLD'
			AND ($3::uuid IS NULL OR soi.delivering_site_id = $3 OR soi.delivering_site_id IS NULL)`, tenantID, productID, siteID).Scan(&allocated); err != nil {
		return 0, 0, 0, "UNAVAILABLE", nil, err
	}
	available := stockAvailable - allocated
	if available < 0 {
		available = 0
	}

	remaining := quantity
	confirmed := 0.0
	today := time.Now().Truncate(24 * time.Hour)
	cutoffDate := atpCutoffDate(today, deliveryDate)
	var lines []salesmodels.ATPPreviewScheduleLine
	if available > 0 {
		q := minFloat(remaining, available)
		lines = append(lines, salesmodels.ATPPreviewScheduleLine{
			ConfirmedQty: q, ConfirmedDate: today.Format("2006-01-02"), SourceType: "STOCK", SourceRef: "Available Stock",
		})
		confirmed += q
		remaining -= q
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return stockAvailable, available, confirmed, "UNAVAILABLE", lines, err
	}
	defer tx.Rollback(ctx)
	supply, err := r.listNearTermSupplyTx(ctx, tx, tenantID, productID, siteID, today, cutoffDate)
	if err != nil {
		return stockAvailable, available, confirmed, "UNAVAILABLE", lines, err
	}
	for _, s := range supply {
		if remaining <= 0 {
			break
		}
		q := minFloat(remaining, s.Qty)
		if q <= 0 {
			continue
		}
		lines = append(lines, salesmodels.ATPPreviewScheduleLine{
			ConfirmedQty: q, ConfirmedDate: s.Date.Format("2006-01-02"), SourceType: s.Source, SourceRef: s.SourceRef,
		})
		confirmed += q
		remaining -= q
	}
	if remaining > 0 {
		rltDate := today.AddDate(0, 0, 14)
		lines = append(lines, salesmodels.ATPPreviewScheduleLine{
			ConfirmedQty: remaining, ConfirmedDate: rltDate.Format("2006-01-02"), SourceType: "RLT", SourceRef: "Replenishment Lead Time",
		})
		confirmed += remaining
		remaining = 0
	}

	status := "ATP_HOLD"
	if confirmed >= quantity {
		status = "RELEASED"
		if len(lines) > 1 && lines[0].SourceType == "STOCK" {
			status = "PARTIALLY_ALLOCATED"
		}
		if len(lines) > 0 {
			if d, err := time.Parse("2006-01-02", lines[len(lines)-1].ConfirmedDate); err == nil && d.After(cutoffDate) {
				status = "PARTIALLY_ALLOCATED"
			}
		}
	} else if confirmed > 0 {
		status = "PARTIALLY_ALLOCATED"
	}
	return stockAvailable, available, confirmed, status, lines, nil
}

// ══════════════════════════════════════════
//  ORDER TYPE CONFIGS
// ══════════════════════════════════════════

func (r *SalesRepo) ListOrderTypeConfigs(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*salesmodels.OrderTypeConfig, error) {
	query := `SELECT id, tenant_id, order_type, description, is_active, is_system, sort_order,
		requires_shipping, shipping_direction, auto_create_delivery, auto_pgi_pgr, target_stock_type,
		auto_confirm_so, packing_slip,
		credit_check_required, atp_check_logic, reference_required,
		pricing_procedure, billing_trigger, billing_type, gl_account_strategy,
		billing_block_default,
		created_by, created_at, updated_at
		FROM order_type_configs WHERE tenant_id = $1`
	args := []interface{}{tenantID}
	if activeOnly {
		query += " AND is_active = true"
	}
	query += " ORDER BY sort_order"
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.OrderTypeConfig
	for rows.Next() {
		otc := &salesmodels.OrderTypeConfig{}
		if err := rows.Scan(&otc.ID, &otc.TenantID, &otc.OrderType, &otc.Description, &otc.IsActive, &otc.IsSystem, &otc.SortOrder,
			&otc.RequiresShipping, &otc.ShippingDirection, &otc.AutoCreateDelivery, &otc.AutoPgiPgr, &otc.TargetStockType,
			&otc.AutoConfirmSO, &otc.PackingSlip,
			&otc.CreditCheckRequired, &otc.AtpCheckLogic, &otc.ReferenceRequired,
			&otc.PricingProcedure, &otc.BillingTrigger, &otc.BillingType, &otc.GlAccountStrategy,
			&otc.BillingBlockDefault,
			&otc.CreatedBy, &otc.CreatedAt, &otc.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, otc)
	}
	return list, nil
}

func (r *SalesRepo) GetOrderTypeConfig(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.OrderTypeConfig, error) {
	otc := &salesmodels.OrderTypeConfig{}
	err := r.db.QueryRow(ctx, `SELECT id, tenant_id, order_type, description, is_active, is_system, sort_order,
		requires_shipping, shipping_direction, auto_create_delivery, auto_pgi_pgr, target_stock_type,
		auto_confirm_so, packing_slip,
		credit_check_required, atp_check_logic, reference_required,
		pricing_procedure, billing_trigger, billing_type, gl_account_strategy,
		billing_block_default,
		created_by, created_at, updated_at
		FROM order_type_configs WHERE id = $1 AND tenant_id = $2`, id, tenantID).Scan(
		&otc.ID, &otc.TenantID, &otc.OrderType, &otc.Description, &otc.IsActive, &otc.IsSystem, &otc.SortOrder,
		&otc.RequiresShipping, &otc.ShippingDirection, &otc.AutoCreateDelivery, &otc.AutoPgiPgr, &otc.TargetStockType,
		&otc.AutoConfirmSO, &otc.PackingSlip,
		&otc.CreditCheckRequired, &otc.AtpCheckLogic, &otc.ReferenceRequired,
		&otc.PricingProcedure, &otc.BillingTrigger, &otc.BillingType, &otc.GlAccountStrategy,
		&otc.BillingBlockDefault,
		&otc.CreatedBy, &otc.CreatedAt, &otc.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return otc, nil
}

func (r *SalesRepo) GetOrderTypeConfigByType(ctx context.Context, tenantID uuid.UUID, orderType string) (*salesmodels.OrderTypeConfig, error) {
	otc := &salesmodels.OrderTypeConfig{}
	err := r.db.QueryRow(ctx, `SELECT id, tenant_id, order_type, description, is_active, is_system, sort_order,
		requires_shipping, shipping_direction, auto_create_delivery, auto_pgi_pgr, target_stock_type,
		auto_confirm_so, packing_slip,
		credit_check_required, atp_check_logic, reference_required,
		pricing_procedure, billing_trigger, billing_type, gl_account_strategy,
		billing_block_default,
		created_by, created_at, updated_at
		FROM order_type_configs WHERE tenant_id = $1 AND order_type = $2`, tenantID, orderType).Scan(
		&otc.ID, &otc.TenantID, &otc.OrderType, &otc.Description, &otc.IsActive, &otc.IsSystem, &otc.SortOrder,
		&otc.RequiresShipping, &otc.ShippingDirection, &otc.AutoCreateDelivery, &otc.AutoPgiPgr, &otc.TargetStockType,
		&otc.AutoConfirmSO, &otc.PackingSlip,
		&otc.CreditCheckRequired, &otc.AtpCheckLogic, &otc.ReferenceRequired,
		&otc.PricingProcedure, &otc.BillingTrigger, &otc.BillingType, &otc.GlAccountStrategy,
		&otc.BillingBlockDefault,
		&otc.CreatedBy, &otc.CreatedAt, &otc.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return otc, nil
}

func (r *SalesRepo) CreateOrderTypeConfig(ctx context.Context, otc *salesmodels.OrderTypeConfig) error {
	_, err := r.db.Exec(ctx, `INSERT INTO order_type_configs(id, tenant_id, order_type, description, is_active, is_system, sort_order,
		requires_shipping, shipping_direction, auto_create_delivery, auto_pgi_pgr, target_stock_type,
		auto_confirm_so, packing_slip,
		credit_check_required, atp_check_logic, reference_required,
		pricing_procedure, billing_trigger, billing_type, gl_account_strategy,
		billing_block_default,
		created_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25)`, otc.ID, otc.TenantID, otc.OrderType, otc.Description, otc.IsActive, otc.IsSystem, otc.SortOrder,
		otc.RequiresShipping, otc.ShippingDirection, otc.AutoCreateDelivery, otc.AutoPgiPgr, otc.TargetStockType,
		otc.AutoConfirmSO, otc.PackingSlip,
		otc.CreditCheckRequired, otc.AtpCheckLogic, otc.ReferenceRequired,
		otc.PricingProcedure, otc.BillingTrigger, otc.BillingType, otc.GlAccountStrategy,
		otc.BillingBlockDefault,
		otc.CreatedBy, otc.CreatedAt, otc.UpdatedAt)
	return err
}

func (r *SalesRepo) UpdateOrderTypeConfig(ctx context.Context, id, tenantID uuid.UUID, otc *salesmodels.OrderTypeConfig) error {
	_, err := r.db.Exec(ctx, `UPDATE order_type_configs SET
		description = $3, is_active = $4, sort_order = $5,
		requires_shipping = $6, shipping_direction = $7, auto_create_delivery = $8, auto_pgi_pgr = $9, target_stock_type = $10,
		auto_confirm_so = $11, packing_slip = $12,
		credit_check_required = $13, atp_check_logic = $14, reference_required = $15,
		pricing_procedure = $16, billing_trigger = $17, billing_type = $18, gl_account_strategy = $19,
		billing_block_default = $20,
		updated_at = NOW()
		WHERE id = $1 AND tenant_id = $2`, id, tenantID,
		otc.Description, otc.IsActive, otc.SortOrder,
		otc.RequiresShipping, otc.ShippingDirection, otc.AutoCreateDelivery, otc.AutoPgiPgr, otc.TargetStockType,
		otc.AutoConfirmSO, otc.PackingSlip,
		otc.CreditCheckRequired, otc.AtpCheckLogic, otc.ReferenceRequired,
		otc.PricingProcedure, otc.BillingTrigger, otc.BillingType, otc.GlAccountStrategy,
		otc.BillingBlockDefault)
	return err
}

func (r *SalesRepo) DeleteOrderTypeConfig(ctx context.Context, id, tenantID uuid.UUID) error {
	// Cannot delete system types
	var isSystem bool
	err := r.db.QueryRow(ctx, "SELECT is_system FROM order_type_configs WHERE id = $1 AND tenant_id = $2", id, tenantID).Scan(&isSystem)
	if err != nil {
		return err
	}
	if isSystem {
		return fmt.Errorf("cannot delete system order type")
	}
	_, err = r.db.Exec(ctx, "DELETE FROM order_type_configs WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

// ══════════════════════════════════════════
//  DELIVERY BLOCK REASONS
// ══════════════════════════════════════════

func (r *SalesRepo) ListDeliveryBlockReasons(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*salesmodels.DeliveryBlockReason, error) {
	query := `SELECT id, tenant_id, block_code, description, is_active, is_system, sort_order, created_by, created_at, updated_at
		FROM delivery_block_reasons WHERE tenant_id = $1`
	args := []interface{}{tenantID}
	if activeOnly {
		query += " AND is_active = true"
	}
	query += " ORDER BY sort_order"
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.DeliveryBlockReason
	for rows.Next() {
		d := &salesmodels.DeliveryBlockReason{}
		if err := rows.Scan(&d.ID, &d.TenantID, &d.BlockCode, &d.Description, &d.IsActive, &d.IsSystem, &d.SortOrder, &d.CreatedBy, &d.CreatedAt, &d.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, d)
	}
	return list, nil
}

func (r *SalesRepo) GetDeliveryBlockReason(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.DeliveryBlockReason, error) {
	d := &salesmodels.DeliveryBlockReason{}
	err := r.db.QueryRow(ctx, `SELECT id, tenant_id, block_code, description, is_active, is_system, sort_order, created_by, created_at, updated_at
		FROM delivery_block_reasons WHERE id = $1 AND tenant_id = $2`, id, tenantID).Scan(
		&d.ID, &d.TenantID, &d.BlockCode, &d.Description, &d.IsActive, &d.IsSystem, &d.SortOrder, &d.CreatedBy, &d.CreatedAt, &d.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return d, nil
}

func (r *SalesRepo) CreateDeliveryBlockReason(ctx context.Context, d *salesmodels.DeliveryBlockReason) error {
	_, err := r.db.Exec(ctx, `INSERT INTO delivery_block_reasons(id, tenant_id, block_code, description, is_active, is_system, sort_order, created_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`, d.ID, d.TenantID, d.BlockCode, d.Description, d.IsActive, d.IsSystem, d.SortOrder, d.CreatedBy, d.CreatedAt, d.UpdatedAt)
	return err
}

func (r *SalesRepo) UpdateDeliveryBlockReason(ctx context.Context, id, tenantID uuid.UUID, d *salesmodels.DeliveryBlockReason) error {
	_, err := r.db.Exec(ctx, `UPDATE delivery_block_reasons SET description = $3, is_active = $4, sort_order = $5, updated_at = NOW()
		WHERE id = $1 AND tenant_id = $2`, id, tenantID, d.Description, d.IsActive, d.SortOrder)
	return err
}

func (r *SalesRepo) DeleteDeliveryBlockReason(ctx context.Context, id, tenantID uuid.UUID) error {
	var isSystem bool
	err := r.db.QueryRow(ctx, "SELECT is_system FROM delivery_block_reasons WHERE id = $1 AND tenant_id = $2", id, tenantID).Scan(&isSystem)
	if err != nil {
		return err
	}
	if isSystem {
		return fmt.Errorf("cannot delete system delivery block reason")
	}
	_, err = r.db.Exec(ctx, "DELETE FROM delivery_block_reasons WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

// ══════════════════════════════════════════
//  SALES ORDERS — DELETE
// ══════════════════════════════════════════

func (r *SalesRepo) DeleteSalesOrder(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM sales_orders WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}
