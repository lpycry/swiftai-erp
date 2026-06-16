package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
)

// ══════════════════════════════════════════
//  SALES ORDERS
// ══════════════════════════════════════════

func (r *SalesRepo) ListSalesOrders(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.SalesOrder, error) {
	sql := `SELECT so.id, so.tenant_id, so.customer_id, so.quotation_id, so.so_number, so.so_type, so.status,
		COALESCE(so.customer_po_no,''), so.po_date, so.currency, COALESCE(so.payment_terms,''), COALESCE(so.incoterm,''),
		so.valid_from, so.delivery_date, so.requested_date,
		so.total_amount, so.discount_pct, so.discount_amount, so.net_amount, so.tax_amount, so.grand_total,
		COALESCE(so.notes,''), COALESCE(so.internal_notes,''),
		COALESCE(so.carrier,''), COALESCE(so.shipping_method,''), COALESCE(so.shipper_account,''),
		so.signature_required, so.saturday_delivery, so.insurance_amt,
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
	if status != "" { sql += " AND so.status = $2"; args = append(args, status) }
	sql += " ORDER BY so.created_at DESC"
	rows, err := r.db.Query(ctx, sql, args...)
	if err != nil { return nil, err }
	defer rows.Close()
	var list []*salesmodels.SalesOrder
	for rows.Next() {
		so := &salesmodels.SalesOrder{}
		if err := rows.Scan(&so.ID, &so.TenantID, &so.CustomerID, &so.QuotationID, &so.SONumber, &so.SOType, &so.Status,
			&so.CustomerPONo, &so.PODate, &so.Currency, &so.PaymentTerms, &so.Incoterm,
			&so.ValidFrom, &so.DeliveryDate, &so.RequestedDate,
			&so.TotalAmount, &so.DiscountPct, &so.DiscountAmount, &so.NetAmount, &so.TaxAmount, &so.GrandTotal,
			&so.Notes, &so.InternalNotes,
			&so.Carrier, &so.ShippingMethod, &so.ShipperAccount,
			&so.SignatureRequired, &so.SaturdayDelivery, &so.InsuranceAmt,
			&so.TransportationTo, &so.TransportPayerAccount, &so.BillToAddress,
			&so.CreditCheckStatus, &so.InventoryCheckStatus, &so.TaxCalcStatus, &so.AllocationStatus,
			&so.BillingBlocked,
			&so.DeliveryBlockID,
			&so.DeliveryBlockCode, &so.DeliveryBlockDesc,
			&so.CreatedBy, &so.CreatedAt, &so.UpdatedAt,
			&so.CustomerCode, &so.CustomerName, &so.QuotationNo); err != nil { return nil, err }
		list = append(list, so)
	}
	return list, nil
}

func (r *SalesRepo) GetSalesOrder(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.SalesOrder, error) {
	so := &salesmodels.SalesOrder{}
	err := r.db.QueryRow(ctx, `SELECT so.id, so.tenant_id, so.customer_id, so.quotation_id, so.so_number, so.so_type, so.status,
		COALESCE(so.customer_po_no,''), so.po_date, so.currency, COALESCE(so.payment_terms,''), COALESCE(so.incoterm,''),
		so.valid_from, so.delivery_date, so.requested_date,
		so.total_amount, so.discount_pct, so.discount_amount, so.net_amount, so.tax_amount, so.grand_total,
		COALESCE(so.notes,''), COALESCE(so.internal_notes,''),
		COALESCE(so.carrier,''), COALESCE(so.shipping_method,''), COALESCE(so.shipper_account,''),
		so.signature_required, so.saturday_delivery, so.insurance_amt,
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
		&so.Notes, &so.InternalNotes,
		&so.Carrier, &so.ShippingMethod, &so.ShipperAccount,
		&so.SignatureRequired, &so.SaturdayDelivery, &so.InsuranceAmt,
		&so.TransportationTo, &so.TransportPayerAccount, &so.BillToAddress,
		&so.CreditCheckStatus, &so.InventoryCheckStatus, &so.TaxCalcStatus, &so.AllocationStatus,
		&so.BillingBlocked,
		&so.DeliveryBlockID,
		&so.DeliveryBlockCode, &so.DeliveryBlockDesc,
		&so.CreatedBy, &so.CreatedAt, &so.UpdatedAt,
		&so.CustomerCode, &so.CustomerName, &so.QuotationNo)
	if err != nil { return nil, err }
	items, err := r.ListSOItems(ctx, id)
	if err != nil { return nil, err }
	for _, it := range items { so.Items = append(so.Items, *it) }
	return so, nil
}

func (r *SalesRepo) CreateSalesOrder(ctx context.Context, so *salesmodels.SalesOrder, items []*salesmodels.SalesOrderItem) error {
	tx, err := r.db.Begin(ctx)
	if err != nil { return err }
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO sales_orders(id, tenant_id, customer_id, quotation_id, so_number, so_type, status,
			customer_po_no, po_date, currency, payment_terms, incoterm,
			valid_from, delivery_date, requested_date,
			total_amount, discount_pct, discount_amount, net_amount, tax_amount, grand_total,
			notes, internal_notes,
			carrier, shipping_method, shipper_account, signature_required, saturday_delivery, insurance_amt,
			transportation_to, transport_payer_account, bill_to_address,
			credit_check_status, inventory_check_status, tax_calc_status, allocation_status,
			billing_blocked,
			delivery_block_id,
			created_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$40,$41)
	`, so.ID, so.TenantID, so.CustomerID, so.QuotationID, so.SONumber, so.SOType, so.Status,
		so.CustomerPONo, so.PODate, so.Currency, so.PaymentTerms, so.Incoterm,
		so.ValidFrom, so.DeliveryDate, so.RequestedDate,
		so.TotalAmount, so.DiscountPct, so.DiscountAmount, so.NetAmount, so.TaxAmount, so.GrandTotal,
		so.Notes, so.InternalNotes,
		so.Carrier, so.ShippingMethod, so.ShipperAccount, so.SignatureRequired, so.SaturdayDelivery, so.InsuranceAmt,
		so.TransportationTo, so.TransportPayerAccount, so.BillToAddress,
		so.CreditCheckStatus, so.InventoryCheckStatus, so.TaxCalcStatus, so.AllocationStatus,
		so.BillingBlocked,
		so.DeliveryBlockID,
		so.CreatedBy, so.CreatedAt, so.UpdatedAt)
	if err != nil { return fmt.Errorf("insert so: %w", err) }

	for _, it := range items {
		_, err = tx.Exec(ctx, `
			INSERT INTO sales_order_items(id, so_id, line_no, product_id, quotation_item_id, description, quantity, allocated_qty, unit_of_measure, unit_price, discount_pct, line_total, delivery_date, created_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
		`, it.ID, it.SOID, it.LineNo, it.ProductID, it.QuotationItemID, it.Description,
			it.Quantity, it.AllocatedQty, it.UnitOfMeasure, it.UnitPrice, it.DiscountPct, it.LineTotal, it.DeliveryDate, it.CreatedAt)
		if err != nil { return fmt.Errorf("insert so item %d: %w", it.LineNo, err) }
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

func (r *SalesRepo) GetNextSONo(ctx context.Context, tenantID uuid.UUID) (string, error) {
	var seq int
	err := r.db.QueryRow(ctx, "SELECT COALESCE(MAX(SUBSTRING(so_number FROM 'SO-(\\d+)')::int), 0)+1 FROM sales_orders WHERE tenant_id = $1", tenantID).Scan(&seq)
	if err != nil { return "", err }
	return fmt.Sprintf("SO-%05d", seq), nil
}

func (r *SalesRepo) ListSOItems(ctx context.Context, soID uuid.UUID) ([]*salesmodels.SalesOrderItem, error) {
	rows, err := r.db.Query(ctx, `SELECT soi.id, soi.so_id, soi.line_no, soi.product_id, soi.quotation_item_id,
		COALESCE(soi.description,''), soi.quantity, soi.allocated_qty, soi.unit_of_measure, soi.unit_price, soi.discount_pct, soi.line_total,
		soi.delivery_date, soi.created_at,
		COALESCE(p.sku,''), COALESCE(p.name,'')
		FROM sales_order_items soi
		LEFT JOIN products p ON p.id = soi.product_id
		WHERE soi.so_id = $1 ORDER BY soi.line_no`, soID)
	if err != nil { return nil, err }
	defer rows.Close()
	var list []*salesmodels.SalesOrderItem
	for rows.Next() {
		it := &salesmodels.SalesOrderItem{}
		if err := rows.Scan(&it.ID, &it.SOID, &it.LineNo, &it.ProductID, &it.QuotationItemID,
			&it.Description, &it.Quantity, &it.AllocatedQty, &it.UnitOfMeasure, &it.UnitPrice, &it.DiscountPct, &it.LineTotal,
			&it.DeliveryDate, &it.CreatedAt,
			&it.ProductSKU, &it.ProductName); err != nil { return nil, err }
		list = append(list, it)
	}
	return list, nil
}

// ── Automated Checks ──

func (r *SalesRepo) CheckInventory(ctx context.Context, tenantID uuid.UUID, items []*salesmodels.SalesOrderItem) (string, error) {
	overall := "AVAILABLE"
	for _, it := range items {
		var onHand float64
		err := r.db.QueryRow(ctx, "SELECT COALESCE(SUM(quantity),0) FROM stock_on_hand WHERE tenant_id = $1 AND product_id = $2", tenantID, it.ProductID).Scan(&onHand)
		if err != nil { return "UNAVAILABLE", fmt.Errorf("inventory check product %s: %w", it.ProductID, err) }
		if onHand < it.Quantity {
			overall = "PARTIAL"
			if onHand <= 0 { overall = "UNAVAILABLE"; break }
		}
	}
	return overall, nil
}

func (r *SalesRepo) CheckCreditLimit(ctx context.Context, tenantID, customerID uuid.UUID, orderAmount float64) (string, error) {
	var limit, used float64
	err := r.db.QueryRow(ctx, "SELECT credit_limit, used_credit FROM credit_limits WHERE tenant_id = $1 AND customer_id = $2", tenantID, customerID).Scan(&limit, &used)
	if err != nil { return "SKIPPED", nil } // no credit limit configured
	avail := limit - used
	if avail >= orderAmount { return "PASSED", nil }
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
	if err != nil { return 0, "SKIPPED", nil }
	return netAmount * taxRate, "CALCULATED", nil
}

func (r *SalesRepo) AllocateInventory(ctx context.Context, tenantID uuid.UUID, items []*salesmodels.SalesOrderItem) (string, error) {
	overall := "ALLOCATED"
	for _, it := range items {
		// Reserve stock by reducing available qty (simplified — real WMS would do bin allocation)
		var onHand float64
		r.db.QueryRow(ctx, "SELECT COALESCE(SUM(quantity),0) FROM stock_on_hand WHERE tenant_id = $1 AND product_id = $2", tenantID, it.ProductID).Scan(&onHand)
		alloc := it.Quantity
		if onHand < alloc { alloc = onHand; overall = "PARTIAL" }
		// Record allocation in item
		_, err := r.db.Exec(ctx, "UPDATE sales_order_items SET allocated_qty = $1 WHERE id = $2", alloc, it.ID)
		if err != nil { return "NOT_ALLOCATED", err }
	}
	return overall, nil
}

// ══════════════════════════════════════════
//  SALES ORDERS — UPDATE
// ══════════════════════════════════════════

func (r *SalesRepo) UpdateSalesOrder(ctx context.Context, so *salesmodels.SalesOrder, items []*salesmodels.SalesOrderItem) error {
	tx, err := r.db.Begin(ctx)
	if err != nil { return err }
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
			signature_required = $25, saturday_delivery = $26, insurance_amt = $27,
			transportation_to = $28, transport_payer_account = $29, bill_to_address = $30,
			billing_blocked = $31,
			delivery_block_id = $32,
			updated_at = NOW()
		WHERE id = $1 AND tenant_id = $2`, so.ID, so.TenantID,
		so.CustomerID, so.SOType, so.Status,
		so.CustomerPONo, so.PODate, so.Currency, so.PaymentTerms, so.Incoterm,
		so.ValidFrom, so.DeliveryDate, so.RequestedDate,
		so.TotalAmount, so.DiscountPct, so.DiscountAmount, so.NetAmount, so.TaxAmount, so.GrandTotal,
		so.Notes, so.InternalNotes,
		so.Carrier, so.ShippingMethod, so.ShipperAccount,
		so.SignatureRequired, so.SaturdayDelivery, so.InsuranceAmt,
		so.TransportationTo, so.TransportPayerAccount, so.BillToAddress,
		so.BillingBlocked,
		so.DeliveryBlockID)
	if err != nil { return fmt.Errorf("update so header: %w", err) }

	// Delete old items and insert new ones
	_, err = tx.Exec(ctx, `DELETE FROM sales_order_items WHERE so_id = $1`, so.ID)
	if err != nil { return fmt.Errorf("delete old items: %w", err) }

	for _, it := range items {
		_, err = tx.Exec(ctx, `
			INSERT INTO sales_order_items(id, so_id, line_no, product_id, quotation_item_id, description, quantity, allocated_qty, unit_of_measure, unit_price, discount_pct, line_total, delivery_date, created_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
		`, it.ID, it.SOID, it.LineNo, it.ProductID, it.QuotationItemID, it.Description,
			it.Quantity, it.AllocatedQty, it.UnitOfMeasure, it.UnitPrice, it.DiscountPct, it.LineTotal, it.DeliveryDate, it.CreatedAt)
		if err != nil { return fmt.Errorf("insert so item %d: %w", it.LineNo, err) }
	}
	return tx.Commit(ctx)
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
	if err != nil { return nil, err }
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
	if err != nil { return nil, err }
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
	if err != nil { return nil, err }
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
	if err != nil { return err }
	if isSystem { return fmt.Errorf("cannot delete system order type") }
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
	if activeOnly { query += " AND is_active = true" }
	query += " ORDER BY sort_order"
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil { return nil, err }
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
	if err != nil { return nil, err }
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
	if err != nil { return err }
	if isSystem { return fmt.Errorf("cannot delete system delivery block reason") }
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
