package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
)

type SalesRepo struct {
	db *pgxpool.Pool
}

func NewSalesRepo(db *pgxpool.Pool) *SalesRepo {
	return &SalesRepo{db: db}
}

func (r *SalesRepo) Pool() *pgxpool.Pool {
	return r.db
}

// ══════════════════════════════════════════
//  CUSTOMERS
// ══════════════════════════════════════════

func (r *SalesRepo) ListCustomers(ctx context.Context, tenantID uuid.UUID, query string, status string) ([]*salesmodels.Customer, error) {
	sql := `SELECT id, tenant_id, customer_code, name, COALESCE(tax_number,''), customer_type, currency,
		COALESCE(payment_terms,''), COALESCE(contact_person,''), COALESCE(contact_email,''), COALESCE(contact_phone,''),
		COALESCE(billing_street,''), COALESCE(billing_city,''), COALESCE(billing_state,''), COALESCE(billing_zip,''), COALESCE(billing_country,''),
		COALESCE(shipping_street,''), COALESCE(shipping_city,''), COALESCE(shipping_state,''), COALESCE(shipping_zip,''), COALESCE(shipping_country,''),
		status,
		is_tax_exempt, COALESCE(tax_exemption_cert,''), tax_exempt_start_date, tax_exempt_end_date, COALESCE(tax_exempt_reason,''),
		default_tax_jurisdiction_id, is_active, created_at, updated_at
		FROM customers WHERE tenant_id = $1`
	args := []interface{}{tenantID}
	argIdx := 2

	if query != "" {
		sql += fmt.Sprintf(" AND (customer_code ILIKE $%d OR name ILIKE $%d OR COALESCE(tax_number,'') ILIKE $%d)", argIdx, argIdx, argIdx)
		args = append(args, "%"+query+"%")
		argIdx++
	}
	if status != "" {
		sql += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	sql += " ORDER BY customer_code"

	rows, err := r.db.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*salesmodels.Customer
	for rows.Next() {
		c := &salesmodels.Customer{}
		if err := rows.Scan(
			&c.ID, &c.TenantID, &c.CustomerCode, &c.Name, &c.TaxNumber,
			&c.CustomerType, &c.Currency, &c.PaymentTerms,
			&c.ContactPerson, &c.ContactEmail, &c.ContactPhone,
			&c.BillingStreet, &c.BillingCity, &c.BillingState, &c.BillingZip, &c.BillingCountry,
			&c.ShippingStreet, &c.ShippingCity, &c.ShippingState, &c.ShippingZip, &c.ShippingCountry,
			&c.Status,
			&c.IsTaxExempt, &c.TaxExemptionCert, &c.TaxExemptStartDate, &c.TaxExemptEndDate, &c.TaxExemptReason,
			&c.DefaultTaxJurisdictionID, &c.IsActive, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, nil
}

func (r *SalesRepo) GetCustomer(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.Customer, error) {
	c := &salesmodels.Customer{}
	err := r.db.QueryRow(ctx, `SELECT id, tenant_id, customer_code, name, COALESCE(tax_number,''), customer_type, currency,
		COALESCE(payment_terms,''), COALESCE(contact_person,''), COALESCE(contact_email,''), COALESCE(contact_phone,''),
		COALESCE(billing_street,''), COALESCE(billing_city,''), COALESCE(billing_state,''), COALESCE(billing_zip,''), COALESCE(billing_country,''),
		COALESCE(shipping_street,''), COALESCE(shipping_city,''), COALESCE(shipping_state,''), COALESCE(shipping_zip,''), COALESCE(shipping_country,''),
		status,
		is_tax_exempt, COALESCE(tax_exemption_cert,''), tax_exempt_start_date, tax_exempt_end_date, COALESCE(tax_exempt_reason,''),
		default_tax_jurisdiction_id, is_active, created_at, updated_at
		FROM customers WHERE id = $1 AND tenant_id = $2`, id, tenantID).Scan(
		&c.ID, &c.TenantID, &c.CustomerCode, &c.Name, &c.TaxNumber,
		&c.CustomerType, &c.Currency, &c.PaymentTerms,
		&c.ContactPerson, &c.ContactEmail, &c.ContactPhone,
		&c.BillingStreet, &c.BillingCity, &c.BillingState, &c.BillingZip, &c.BillingCountry,
		&c.ShippingStreet, &c.ShippingCity, &c.ShippingState, &c.ShippingZip, &c.ShippingCountry,
		&c.Status,
		&c.IsTaxExempt, &c.TaxExemptionCert, &c.TaxExemptStartDate, &c.TaxExemptEndDate, &c.TaxExemptReason,
		&c.DefaultTaxJurisdictionID, &c.IsActive, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, err
	}
	// Load certificates
	certs, _ := r.ListCertificates(ctx, id, tenantID)
	for _, cc := range certs {
		c.Certificates = append(c.Certificates, *cc)
	}
	return c, nil
}

func (r *SalesRepo) CreateCustomer(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateCustomerRequest) (*salesmodels.Customer, error) {
	c := &salesmodels.Customer{
		ID:            uuid.New(),
		TenantID:      tenantID,
		CustomerCode:  req.CustomerCode,
		Name:          req.Name,
		TaxNumber:     req.TaxNumber,
		CustomerType:  req.CustomerType,
		Currency:      req.Currency,
		PaymentTerms:  req.PaymentTerms,
		ContactPerson: req.ContactPerson,
		ContactEmail:  req.ContactEmail,
		ContactPhone:  req.ContactPhone,
		BillingStreet:  req.BillingStreet,
		BillingCity:    req.BillingCity,
		BillingState:   req.BillingState,
		BillingZip:     req.BillingZip,
		BillingCountry: req.BillingCountry,
		ShippingStreet:  req.ShippingStreet,
		ShippingCity:    req.ShippingCity,
		ShippingState:   req.ShippingState,
		ShippingZip:     req.ShippingZip,
		ShippingCountry: req.ShippingCountry,
		Status:        "Active",
		TaxExemptionCert: req.TaxExemptionCert,
		TaxExemptReason:  req.TaxExemptReason,
		IsActive:      true,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}
	if c.CustomerType == "" { c.CustomerType = "Corporate" }
	if c.Currency == "" { c.Currency = "USD" }
	if c.PaymentTerms == "" { c.PaymentTerms = "Net 30" }
	if c.BillingCountry == "" { c.BillingCountry = "US" }
	if c.ShippingCountry == "" { c.ShippingCountry = "US" }
	if req.IsTaxExempt != nil { c.IsTaxExempt = *req.IsTaxExempt }
	if req.TaxExemptStartDate != "" {
		if d, err := time.Parse("2006-01-02", req.TaxExemptStartDate); err == nil { c.TaxExemptStartDate = &d }
	}
	if req.TaxExemptEndDate != "" {
		if d, err := time.Parse("2006-01-02", req.TaxExemptEndDate); err == nil { c.TaxExemptEndDate = &d }
	}
	if req.DefaultTaxJurisdictionID != nil && *req.DefaultTaxJurisdictionID != "" {
		if id, err := uuid.Parse(*req.DefaultTaxJurisdictionID); err == nil {
			c.DefaultTaxJurisdictionID = &id
		}
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO customers(id, tenant_id, customer_code, name, tax_number, customer_type, currency, payment_terms,
			contact_person, contact_email, contact_phone,
			billing_street, billing_city, billing_state, billing_zip, billing_country,
			shipping_street, shipping_city, shipping_state, shipping_zip, shipping_country,
			status,
			is_tax_exempt, tax_exemption_cert, tax_exempt_start_date, tax_exempt_end_date, tax_exempt_reason,
			default_tax_jurisdiction_id, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31)
	`, c.ID, c.TenantID, c.CustomerCode, c.Name, c.TaxNumber, c.CustomerType, c.Currency, c.PaymentTerms,
		c.ContactPerson, c.ContactEmail, c.ContactPhone,
		c.BillingStreet, c.BillingCity, c.BillingState, c.BillingZip, c.BillingCountry,
		c.ShippingStreet, c.ShippingCity, c.ShippingState, c.ShippingZip, c.ShippingCountry,
		c.Status,
		c.IsTaxExempt, c.TaxExemptionCert, c.TaxExemptStartDate, c.TaxExemptEndDate, c.TaxExemptReason,
		c.DefaultTaxJurisdictionID, c.IsActive, c.CreatedAt, c.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create customer: %w", err)
	}
	return c, nil
}

func (r *SalesRepo) UpdateCustomer(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateCustomerRequest) error {
	// Convert *string fields to proper types for SQL
	var jurisdictionUUID *uuid.UUID
	if req.DefaultTaxJurisdictionID != nil {
		if *req.DefaultTaxJurisdictionID != "" {
			if uid, err := uuid.Parse(*req.DefaultTaxJurisdictionID); err == nil { jurisdictionUUID = &uid }
		} // else: keep nil to clear
	}

	// Parse date strings — empty string means clear (set nil)
	var startDate, endDate *time.Time
	if req.TaxExemptStartDate != nil {
		if *req.TaxExemptStartDate != "" {
			if d, err := time.Parse("2006-01-02", *req.TaxExemptStartDate); err == nil { startDate = &d }
		} // else clear
	}
	if req.TaxExemptEndDate != nil {
		if *req.TaxExemptEndDate != "" {
			if d, err := time.Parse("2006-01-02", *req.TaxExemptEndDate); err == nil { endDate = &d }
		} // else clear
	}

	_, err := r.db.Exec(ctx, `
		UPDATE customers SET
			name                      = COALESCE($3, name),
			tax_number                = COALESCE($4, tax_number),
			customer_type             = COALESCE($5, customer_type),
			currency                  = COALESCE($6, currency),
			payment_terms             = COALESCE($7, payment_terms),
			contact_person            = COALESCE($8, contact_person),
			contact_email             = COALESCE($9, contact_email),
			contact_phone             = COALESCE($10, contact_phone),
			billing_street            = COALESCE($11, billing_street),
			billing_city              = COALESCE($12, billing_city),
			billing_state             = COALESCE($13, billing_state),
			billing_zip               = COALESCE($14, billing_zip),
			billing_country           = COALESCE($15, billing_country),
			shipping_street           = COALESCE($16, shipping_street),
			shipping_city             = COALESCE($17, shipping_city),
			shipping_state            = COALESCE($18, shipping_state),
			shipping_zip              = COALESCE($19, shipping_zip),
			shipping_country          = COALESCE($20, shipping_country),
			status                    = COALESCE($21, status),
			is_tax_exempt             = COALESCE($22, is_tax_exempt),
			tax_exemption_cert        = COALESCE($23, tax_exemption_cert),
			tax_exempt_start_date     = $24,
			tax_exempt_end_date       = $25,
			tax_exempt_reason         = COALESCE($26, tax_exempt_reason),
			default_tax_jurisdiction_id = $27,
			is_active                 = COALESCE($28, is_active),
			updated_at                = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID,
		req.Name, req.TaxNumber, req.CustomerType, req.Currency, req.PaymentTerms,
		req.ContactPerson, req.ContactEmail, req.ContactPhone,
		req.BillingStreet, req.BillingCity, req.BillingState, req.BillingZip, req.BillingCountry,
		req.ShippingStreet, req.ShippingCity, req.ShippingState, req.ShippingZip, req.ShippingCountry,
		req.Status, req.IsTaxExempt, req.TaxExemptionCert, startDate, endDate,
		req.TaxExemptReason, jurisdictionUUID, req.IsActive)
	return err
}

func (r *SalesRepo) DeleteCustomer(ctx context.Context, id, tenantID uuid.UUID) error {
	result, err := r.db.Exec(ctx, `DELETE FROM customers WHERE id = $1 AND tenant_id = $2`, id, tenantID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("customer not found")
	}
	return nil
}

// ══════════════════════════════════════════
//  CUSTOMER CERTIFICATES
// ══════════════════════════════════════════

func (r *SalesRepo) ListCertificates(ctx context.Context, customerID, tenantID uuid.UUID) ([]*salesmodels.CustomerCertificate, error) {
	rows, err := r.db.Query(ctx, `SELECT id, customer_id, tenant_id, cert_type, file_name, file_path, file_size, mime_type, uploaded_at
		FROM customer_certificates WHERE customer_id = $1 AND tenant_id = $2 ORDER BY uploaded_at DESC`, customerID, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.CustomerCertificate
	for rows.Next() {
		cc := &salesmodels.CustomerCertificate{}
		if err := rows.Scan(&cc.ID, &cc.CustomerID, &cc.TenantID, &cc.CertType, &cc.FileName, &cc.FilePath, &cc.FileSize, &cc.MimeType, &cc.UploadedAt); err != nil {
			return nil, err
		}
		list = append(list, cc)
	}
	return list, nil
}

func (r *SalesRepo) UploadCertificate(ctx context.Context, req *salesmodels.CustomerCertificate) error {
	_, err := r.db.Exec(ctx, `INSERT INTO customer_certificates(id, customer_id, tenant_id, cert_type, file_name, file_path, file_size, mime_type, uploaded_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
		req.ID, req.CustomerID, req.TenantID, req.CertType, req.FileName, req.FilePath, req.FileSize, req.MimeType, req.UploadedAt)
	return err
}

func (r *SalesRepo) DeleteCertificate(ctx context.Context, id, customerID, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM customer_certificates WHERE id = $1 AND customer_id = $2 AND tenant_id = $3`, id, customerID, tenantID)
	return err
}

// ══════════════════════════════════════════
//  MATERIAL PRICES
// ══════════════════════════════════════════

func (r *SalesRepo) ListMaterialPrices(ctx context.Context, tenantID uuid.UUID, productID uuid.UUID, activeOnly bool) ([]*salesmodels.MaterialPrice, error) {
	query := `SELECT mp.id, mp.tenant_id, mp.product_id, mp.customer_id,
		mp.price_type, mp.price, mp.currency, mp.price_unit, mp.uom,
		mp.valid_from, mp.valid_to, mp.is_active, mp.created_at, mp.updated_at,
		COALESCE(p.sku,''), COALESCE(p.name,''),
		COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM material_prices mp
		LEFT JOIN products p ON p.id = mp.product_id
		LEFT JOIN customers c ON c.id = mp.customer_id
		WHERE mp.tenant_id = $1`
	args := []interface{}{tenantID}
	argIdx := 2

	if productID != uuid.Nil {
		query += fmt.Sprintf(" AND mp.product_id = $%d", argIdx)
		args = append(args, productID)
		argIdx++
	}
	if activeOnly {
		query += " AND mp.is_active = true"
	}
	query += " ORDER BY mp.valid_from DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*salesmodels.MaterialPrice
	for rows.Next() {
		mp := &salesmodels.MaterialPrice{}
		if err := rows.Scan(&mp.ID, &mp.TenantID, &mp.ProductID, &mp.CustomerID,
			&mp.PriceType, &mp.Price, &mp.Currency, &mp.PriceUnit, &mp.UOM,
			&mp.ValidFrom, &mp.ValidTo, &mp.IsActive, &mp.CreatedAt, &mp.UpdatedAt,
			&mp.ProductSKU, &mp.ProductName,
			&mp.CustomerCode, &mp.CustomerName); err != nil {
			return nil, err
		}
		list = append(list, mp)
	}
	return list, nil
}

func (r *SalesRepo) GetMaterialPrice(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.MaterialPrice, error) {
	mp := &salesmodels.MaterialPrice{}
	err := r.db.QueryRow(ctx, `SELECT mp.id, mp.tenant_id, mp.product_id, mp.customer_id,
		mp.price_type, mp.price, mp.currency, mp.price_unit, mp.uom,
		mp.valid_from, mp.valid_to, mp.is_active, mp.created_at, mp.updated_at,
		COALESCE(p.sku,''), COALESCE(p.name,''),
		COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM material_prices mp
		LEFT JOIN products p ON p.id = mp.product_id
		LEFT JOIN customers c ON c.id = mp.customer_id
		WHERE mp.id = $1 AND mp.tenant_id = $2`, id, tenantID).Scan(
		&mp.ID, &mp.TenantID, &mp.ProductID, &mp.CustomerID,
		&mp.PriceType, &mp.Price, &mp.Currency, &mp.PriceUnit, &mp.UOM,
		&mp.ValidFrom, &mp.ValidTo, &mp.IsActive, &mp.CreatedAt, &mp.UpdatedAt,
		&mp.ProductSKU, &mp.ProductName,
		&mp.CustomerCode, &mp.CustomerName)
	if err != nil {
		return nil, err
	}
	return mp, nil
}

func (r *SalesRepo) CreateMaterialPrice(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateMaterialPriceRequest) (*salesmodels.MaterialPrice, error) {
	productID, _ := uuid.Parse(req.ProductID)
	validFrom, _ := time.Parse("2006-01-02", req.ValidFrom)

	mp := &salesmodels.MaterialPrice{
		ID:        uuid.New(),
		TenantID:  tenantID,
		ProductID: productID,
		PriceType: req.PriceType,
		Price:     req.Price,
		Currency:  req.Currency,
		PriceUnit: req.PriceUnit,
		ValidFrom: validFrom,
		IsActive:  true,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	if mp.PriceType == "" { mp.PriceType = "STANDARD" }
	if mp.Currency == "" { mp.Currency = "USD" }
	if mp.PriceUnit <= 0 { mp.PriceUnit = 1 }
	if req.UOM != "" { mp.UOM = &req.UOM }
	if req.CustomerID != "" {
		if cid, err := uuid.Parse(req.CustomerID); err == nil { mp.CustomerID = &cid }
	}
	if req.ValidTo != "" {
		if d, err := time.Parse("2006-01-02", req.ValidTo); err == nil {
			mp.ValidTo = &d
		}
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO material_prices(id, tenant_id, product_id, customer_id, price_type, price, currency, price_unit, uom,
			valid_from, valid_to, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
	`, mp.ID, mp.TenantID, mp.ProductID, mp.CustomerID, mp.PriceType, mp.Price, mp.Currency, mp.PriceUnit, mp.UOM,
		mp.ValidFrom, mp.ValidTo, mp.IsActive, mp.CreatedAt, mp.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create material price: %w", err)
	}
	return mp, nil
}

func (r *SalesRepo) UpdateMaterialPrice(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateMaterialPriceRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE material_prices SET
			customer_id  = COALESCE($3, customer_id),
			price_type   = COALESCE($4, price_type),
			price        = COALESCE($5, price),
			currency     = COALESCE($6, currency),
			price_unit   = COALESCE($7, price_unit),
			uom          = COALESCE($8, uom),
			valid_from   = COALESCE($9, valid_from),
			valid_to     = COALESCE($10, valid_to),
			is_active    = COALESCE($11, is_active),
			updated_at   = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID,
		nullIfEmptyStr(req.CustomerID), req.PriceType, req.Price, req.Currency, req.PriceUnit, req.UOM,
		req.ValidFrom, req.ValidTo, req.IsActive)
	return err
}

func (r *SalesRepo) DeleteMaterialPrice(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM material_prices WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

func (r *SalesRepo) LookupMaterialPrice(ctx context.Context, tenantID, customerID, productID uuid.UUID) (*salesmodels.MaterialPrice, error) {
	// First try: customer-specific price
	mp := &salesmodels.MaterialPrice{}
	err := r.db.QueryRow(ctx, `
		SELECT mp.id, mp.tenant_id, mp.product_id, mp.customer_id,
			mp.price_type, mp.price, mp.currency, mp.price_unit, mp.uom,
			mp.valid_from, mp.valid_to, mp.is_active, mp.created_at, mp.updated_at,
			COALESCE(p.sku,''), COALESCE(p.name,''),
			COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM material_prices mp
		LEFT JOIN products p ON p.id = mp.product_id
		LEFT JOIN customers c ON c.id = mp.customer_id
		WHERE mp.tenant_id = $1 AND mp.product_id = $2 AND mp.customer_id = $3
			AND mp.is_active = true AND mp.valid_from <= NOW() AND (mp.valid_to IS NULL OR mp.valid_to >= NOW())
		ORDER BY mp.valid_from DESC
		LIMIT 1
	`, tenantID, productID, customerID).Scan(
		&mp.ID, &mp.TenantID, &mp.ProductID, &mp.CustomerID,
		&mp.PriceType, &mp.Price, &mp.Currency, &mp.PriceUnit, &mp.UOM,
		&mp.ValidFrom, &mp.ValidTo, &mp.IsActive, &mp.CreatedAt, &mp.UpdatedAt,
		&mp.ProductSKU, &mp.ProductName,
		&mp.CustomerCode, &mp.CustomerName)
	if err == nil {
		return mp, nil
	}
	if err != pgx.ErrNoRows {
		return nil, err
	}
	// Fallback: product-only price (customer_id IS NULL)
	err = r.db.QueryRow(ctx, `
		SELECT mp.id, mp.tenant_id, mp.product_id, mp.customer_id,
			mp.price_type, mp.price, mp.currency, mp.price_unit, mp.uom,
			mp.valid_from, mp.valid_to, mp.is_active, mp.created_at, mp.updated_at,
			COALESCE(p.sku,''), COALESCE(p.name,''),
			COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM material_prices mp
		LEFT JOIN products p ON p.id = mp.product_id
		LEFT JOIN customers c ON c.id = mp.customer_id
		WHERE mp.tenant_id = $1 AND mp.product_id = $2 AND mp.customer_id IS NULL
			AND mp.is_active = true AND mp.valid_from <= NOW() AND (mp.valid_to IS NULL OR mp.valid_to >= NOW())
		ORDER BY mp.valid_from DESC
		LIMIT 1
	`, tenantID, productID).Scan(
		&mp.ID, &mp.TenantID, &mp.ProductID, &mp.CustomerID,
		&mp.PriceType, &mp.Price, &mp.Currency, &mp.PriceUnit, &mp.UOM,
		&mp.ValidFrom, &mp.ValidTo, &mp.IsActive, &mp.CreatedAt, &mp.UpdatedAt,
		&mp.ProductSKU, &mp.ProductName,
		&mp.CustomerCode, &mp.CustomerName)
	if err == pgx.ErrNoRows {
		return nil, nil // not found
	}
	return mp, err
}

// nullIfEmptyStr returns nil for empty string pointers (used in SQL COALESCE)
func nullIfEmptyStr(s *string) *string {
	if s == nil { return nil }
	if *s == "" { return nil }
	return s
}

func (r *SalesRepo) GetStockOnHand(ctx context.Context, tenantID, productID uuid.UUID, onHand *float64) error {
	return r.db.QueryRow(ctx, "SELECT COALESCE(SUM(quantity),0) FROM stock_on_hand WHERE tenant_id = $1 AND product_id = $2", tenantID, productID).Scan(onHand)
}


