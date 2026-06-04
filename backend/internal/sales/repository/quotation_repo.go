package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
)

// ══════════════════════════════════════════
//  QUOTATIONS
// ══════════════════════════════════════════

func (r *SalesRepo) ListQuotations(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.Quotation, error) {
	sql := `SELECT q.id, q.tenant_id, q.customer_id, q.quotation_no, q.quotation_type, q.status,
		q.valid_from, q.valid_to, q.currency, COALESCE(q.payment_terms,''), COALESCE(q.incoterm,''),
		q.delivery_date, q.total_amount, q.discount_pct, q.discount_amount,
		q.net_amount, q.tax_amount, COALESCE(q.tax_calc_source,''), COALESCE(q.tax_calc_detail,''), COALESCE(q.tax_calc_rate,0), q.grand_total,
		COALESCE(q.notes,''), COALESCE(q.internal_notes,''), COALESCE(q.reference_inquiry,''),
		q.employee_id,
		q.created_by, q.created_at, q.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,''),
		COALESCE(eb.employee_code,''), COALESCE(eb.first_name || ' ' || eb.last_name,'')
		FROM quotations q
		LEFT JOIN customers c ON c.id = q.customer_id
		LEFT JOIN employee_base eb ON eb.id = q.employee_id
		WHERE q.tenant_id = $1`
	args := []interface{}{tenantID}
	if status != "" {
		sql += " AND q.status = $2"
		args = append(args, status)
	}
	sql += " ORDER BY q.created_at DESC"

	rows, err := r.db.Query(ctx, sql, args...)
	if err != nil { return nil, err }
	defer rows.Close()
	var list []*salesmodels.Quotation
	for rows.Next() {
		q := &salesmodels.Quotation{}
		if err := rows.Scan(&q.ID, &q.TenantID, &q.CustomerID, &q.QuotationNo, &q.QuotationType, &q.Status,
			&q.ValidFrom, &q.ValidTo, &q.Currency, &q.PaymentTerms, &q.Incoterm,
			&q.DeliveryDate, &q.TotalAmount, &q.DiscountPct, &q.DiscountAmount,
			&q.NetAmount, &q.TaxAmount, &q.TaxCalcSource, &q.TaxCalcDetail, &q.TaxCalcRate, &q.GrandTotal,
			&q.Notes, &q.InternalNotes, &q.ReferenceInquiry,
			&q.EmployeeID,
			&q.CreatedBy, &q.CreatedAt, &q.UpdatedAt,
			&q.CustomerCode, &q.CustomerName,
			&q.EmployeeCode, &q.EmployeeName); err != nil { return nil, err }
		list = append(list, q)
	}
	return list, nil
}

func (r *SalesRepo) GetQuotation(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.Quotation, error) {
	q := &salesmodels.Quotation{}
	err := r.db.QueryRow(ctx, `SELECT q.id, q.tenant_id, q.customer_id, q.quotation_no, q.quotation_type, q.status,
		q.valid_from, q.valid_to, q.currency, COALESCE(q.payment_terms,''), COALESCE(q.incoterm,''),
		q.delivery_date, q.total_amount, q.discount_pct, q.discount_amount,
		q.net_amount, q.tax_amount, COALESCE(q.tax_calc_source,''), COALESCE(q.tax_calc_detail,''), COALESCE(q.tax_calc_rate,0), q.grand_total,
		COALESCE(q.notes,''), COALESCE(q.internal_notes,''), COALESCE(q.reference_inquiry,''),
		q.employee_id,
		q.created_by, q.created_at, q.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,''),
		COALESCE(eb.employee_code,''), COALESCE(eb.first_name || ' ' || eb.last_name,'')
		FROM quotations q
		LEFT JOIN customers c ON c.id = q.customer_id
		LEFT JOIN employee_base eb ON eb.id = q.employee_id
		WHERE q.id = $1 AND q.tenant_id = $2`, id, tenantID).Scan(
		&q.ID, &q.TenantID, &q.CustomerID, &q.QuotationNo, &q.QuotationType, &q.Status,
		&q.ValidFrom, &q.ValidTo, &q.Currency, &q.PaymentTerms, &q.Incoterm,
		&q.DeliveryDate, &q.TotalAmount, &q.DiscountPct, &q.DiscountAmount,
		&q.NetAmount, &q.TaxAmount, &q.TaxCalcSource, &q.TaxCalcDetail, &q.TaxCalcRate, &q.GrandTotal,
		&q.Notes, &q.InternalNotes, &q.ReferenceInquiry,
		&q.EmployeeID,
		&q.CreatedBy, &q.CreatedAt, &q.UpdatedAt,
		&q.CustomerCode, &q.CustomerName,
		&q.EmployeeCode, &q.EmployeeName)
	if err != nil { return nil, err }

	// Load items
	itemPtrs, err := r.ListQuotationItems(ctx, id)
	if err != nil { return nil, err }
	for _, it := range itemPtrs { q.Items = append(q.Items, *it) }
	return q, nil
}

func (r *SalesRepo) CreateQuotation(ctx context.Context, q *salesmodels.Quotation, items []*salesmodels.QuotationItem) error {
	tx, err := r.db.Begin(ctx)
	if err != nil { return err }
	defer tx.Rollback(ctx)

	// employee_id param: convert *uuid.UUID to interface{} nil for pgx
	var empIDParam interface{} = nil
	if q.EmployeeID != nil { empIDParam = *q.EmployeeID }
	_, err = tx.Exec(ctx, `
		INSERT INTO quotations(id, tenant_id, customer_id, quotation_no, quotation_type, status,
			valid_from, valid_to, currency, payment_terms, incoterm, delivery_date,
			total_amount, discount_pct, discount_amount, net_amount, tax_amount,
			tax_calc_source, tax_calc_detail, tax_calc_rate, grand_total,
			notes, internal_notes, reference_inquiry, employee_id, created_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28)
	`, q.ID, q.TenantID, q.CustomerID, q.QuotationNo, q.QuotationType, q.Status,
		q.ValidFrom, q.ValidTo, q.Currency, q.PaymentTerms, q.Incoterm, q.DeliveryDate,
		q.TotalAmount, q.DiscountPct, q.DiscountAmount, q.NetAmount, q.TaxAmount, q.TaxCalcSource, q.TaxCalcDetail, q.TaxCalcRate, q.GrandTotal,
		q.Notes, q.InternalNotes, q.ReferenceInquiry, empIDParam, q.CreatedBy, q.CreatedAt, q.UpdatedAt)
	if err != nil { return fmt.Errorf("insert quotation: %w", err) }

	for _, item := range items {
		_, err = tx.Exec(ctx, `
			INSERT INTO quotation_items(id, quotation_id, line_no, product_id, description, quantity, unit_of_measure, unit_price, discount_pct, line_total, delivery_date, created_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		`, item.ID, item.QuotationID, item.LineNo, item.ProductID, item.Description,
			item.Quantity, item.UnitOfMeasure, item.UnitPrice, item.DiscountPct, item.LineTotal, item.DeliveryDate, item.CreatedAt)
		if err != nil { return fmt.Errorf("insert item %d: %w", item.LineNo, err) }
	}
	return tx.Commit(ctx)
}

func (r *SalesRepo) UpdateQuotationStatus(ctx context.Context, id, tenantID uuid.UUID, status string) error {
	_, err := r.db.Exec(ctx, "UPDATE quotations SET status = $3, updated_at = NOW() WHERE id = $1 AND tenant_id = $2", id, tenantID, status)
	return err
}

func (r *SalesRepo) DeleteQuotation(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM quotations WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

func (r *SalesRepo) ListQuotationItems(ctx context.Context, quotationID uuid.UUID) ([]*salesmodels.QuotationItem, error) {
	rows, err := r.db.Query(ctx, `SELECT qi.id, qi.quotation_id, qi.line_no, qi.product_id,
		COALESCE(qi.description,''), qi.quantity, qi.unit_of_measure, qi.unit_price, qi.discount_pct, qi.line_total,
		qi.delivery_date, qi.created_at,
		COALESCE(p.sku,''), COALESCE(p.name,'')
		FROM quotation_items qi
		LEFT JOIN products p ON p.id = qi.product_id
		WHERE qi.quotation_id = $1 ORDER BY qi.line_no`, quotationID)
	if err != nil { return nil, err }
	defer rows.Close()
	var list []*salesmodels.QuotationItem
	for rows.Next() {
		it := &salesmodels.QuotationItem{}
		if err := rows.Scan(&it.ID, &it.QuotationID, &it.LineNo, &it.ProductID,
			&it.Description, &it.Quantity, &it.UnitOfMeasure, &it.UnitPrice, &it.DiscountPct, &it.LineTotal,
			&it.DeliveryDate, &it.CreatedAt,
			&it.ProductSKU, &it.ProductName); err != nil { return nil, err }
		list = append(list, it)
	}
	return list, nil
}

// GetQuotationForPrint loads quotation with items (same as GetQuotation but explicit)
func (r *SalesRepo) GetQuotationForPrint(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.Quotation, error) {
	return r.GetQuotation(ctx, id, tenantID)
}

// GetNextQuotationNo generates the next quotation number
func (r *SalesRepo) GetNextQuotationNo(ctx context.Context, tenantID uuid.UUID) (string, error) {
	var seq int
	err := r.db.QueryRow(ctx, "SELECT COALESCE(MAX(SUBSTRING(quotation_no FROM 'Q-(\\d+)')::int), 0)+1 FROM quotations WHERE tenant_id = $1", tenantID).Scan(&seq)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("Q-%05d", seq), nil
}


