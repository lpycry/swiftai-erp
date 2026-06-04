package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	armodels "github.com/swiftai-erp/backend/internal/ar/models"
)

type ARRepo struct {
	db *pgxpool.Pool
}

func NewARRepo(db *pgxpool.Pool) *ARRepo {
	return &ARRepo{db: db}
}

// ══════════════════════════════════════════
//  CREDIT LIMITS
// ══════════════════════════════════════════

func (r *ARRepo) ListCreditLimits(ctx context.Context, tenantID uuid.UUID) ([]*armodels.CreditLimit, error) {
	query := `SELECT cl.id, cl.tenant_id, cl.customer_id,
		cl.credit_limit, cl.used_credit, cl.available_credit,
		cl.currency, cl.risk_category, cl.credit_status,
		cl.last_reviewed, cl.reviewed_by, COALESCE(cl.notes,''),
		cl.is_active, cl.created_at, cl.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM credit_limits cl
		LEFT JOIN customers c ON c.id = cl.customer_id
		WHERE cl.tenant_id = $1
		ORDER BY c.customer_code`
	rows, err := r.db.Query(ctx, query, tenantID)
	if err != nil { return nil, err }
	defer rows.Close()
	var list []*armodels.CreditLimit
	for rows.Next() {
		cl := &armodels.CreditLimit{}
		if err := rows.Scan(&cl.ID, &cl.TenantID, &cl.CustomerID,
			&cl.CreditLimit, &cl.UsedCredit, &cl.AvailableCredit,
			&cl.Currency, &cl.RiskCategory, &cl.CreditStatus,
			&cl.LastReviewed, &cl.ReviewedBy, &cl.Notes,
			&cl.IsActive, &cl.CreatedAt, &cl.UpdatedAt,
			&cl.CustomerCode, &cl.CustomerName); err != nil { return nil, err }
		list = append(list, cl)
	}
	return list, nil
}

func (r *ARRepo) GetCreditLimit(ctx context.Context, id, tenantID uuid.UUID) (*armodels.CreditLimit, error) {
	cl := &armodels.CreditLimit{}
	err := r.db.QueryRow(ctx, `SELECT cl.id, cl.tenant_id, cl.customer_id,
		cl.credit_limit, cl.used_credit, cl.available_credit,
		cl.currency, cl.risk_category, cl.credit_status,
		cl.last_reviewed, cl.reviewed_by, COALESCE(cl.notes,''),
		cl.is_active, cl.created_at, cl.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM credit_limits cl
		LEFT JOIN customers c ON c.id = cl.customer_id
		WHERE cl.id = $1 AND cl.tenant_id = $2`, id, tenantID).Scan(
		&cl.ID, &cl.TenantID, &cl.CustomerID,
		&cl.CreditLimit, &cl.UsedCredit, &cl.AvailableCredit,
		&cl.Currency, &cl.RiskCategory, &cl.CreditStatus,
		&cl.LastReviewed, &cl.ReviewedBy, &cl.Notes,
		&cl.IsActive, &cl.CreatedAt, &cl.UpdatedAt,
		&cl.CustomerCode, &cl.CustomerName)
	if err != nil { return nil, err }
	return cl, nil
}

func (r *ARRepo) CreateCreditLimit(ctx context.Context, tenantID uuid.UUID, req *armodels.CreateCreditLimitRequest) (*armodels.CreditLimit, error) {
	customerID, _ := uuid.Parse(req.CustomerID)
	cl := &armodels.CreditLimit{
		ID: uuid.New(), TenantID: tenantID, CustomerID: customerID,
		CreditLimit: req.CreditLimit, UsedCredit: req.UsedCredit,
		Currency: req.Currency, RiskCategory: req.RiskCategory,
		Notes: req.Notes, IsActive: true, CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}
	if cl.Currency == "" { cl.Currency = "USD" }
	if cl.RiskCategory == "" { cl.RiskCategory = "LOW" }

	_, err := r.db.Exec(ctx, `
		INSERT INTO credit_limits(id, tenant_id, customer_id, credit_limit, used_credit, currency, risk_category, credit_status, notes, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,'OK',$8,$9,$10,$11)
		ON CONFLICT (tenant_id, customer_id) DO UPDATE SET
			credit_limit = EXCLUDED.credit_limit, used_credit = EXCLUDED.used_credit,
			currency = EXCLUDED.currency, updated_at = NOW()
	`, cl.ID, cl.TenantID, cl.CustomerID, cl.CreditLimit, cl.UsedCredit, cl.Currency, cl.RiskCategory, cl.Notes, cl.IsActive, cl.CreatedAt, cl.UpdatedAt)
	if err != nil { return nil, fmt.Errorf("create credit limit: %w", err) }
	return cl, nil
}

func (r *ARRepo) UpdateCreditLimit(ctx context.Context, id, tenantID uuid.UUID, req *armodels.UpdateCreditLimitRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE credit_limits SET
			credit_limit  = COALESCE($3, credit_limit),
			used_credit   = COALESCE($4, used_credit),
			currency      = COALESCE($5, currency),
			risk_category = COALESCE($6, risk_category),
			credit_status = COALESCE($7, credit_status),
			last_reviewed = COALESCE($8, last_reviewed),
			notes         = COALESCE($9, notes),
			is_active     = COALESCE($10, is_active),
			updated_at    = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.CreditLimit, req.UsedCredit, req.Currency, req.RiskCategory, req.CreditStatus, req.LastReviewed, req.Notes, req.IsActive)
	return err
}

func (r *ARRepo) DeleteCreditLimit(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM credit_limits WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

// ══════════════════════════════════════════
//  CUSTOMER DOWN PAYMENTS
// ══════════════════════════════════════════

func (r *ARRepo) ListDownPayments(ctx context.Context, tenantID uuid.UUID) ([]*armodels.CustomerDownPayment, error) {
	query := `SELECT cdp.id, cdp.tenant_id, cdp.customer_id, cdp.org_id,
		cdp.dp_type, cdp.dp_number, cdp.amount, cdp.currency, cdp.payment_method,
		COALESCE(cdp.reference_no,''), cdp.status, cdp.dp_date, cdp.clearing_date,
		COALESCE(cdp.description,''), cdp.gl_je_id, cdp.gl_posting_status,
		cdp.created_by, cdp.created_at, cdp.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM customer_down_payments cdp
		LEFT JOIN customers c ON c.id = cdp.customer_id
		WHERE cdp.tenant_id = $1 ORDER BY cdp.dp_date DESC`
	rows, err := r.db.Query(ctx, query, tenantID)
	if err != nil { return nil, err }
	defer rows.Close()
	var list []*armodels.CustomerDownPayment
	for rows.Next() {
		dp := &armodels.CustomerDownPayment{}
		if err := rows.Scan(&dp.ID, &dp.TenantID, &dp.CustomerID, &dp.OrgID,
			&dp.DPType, &dp.DPNumber, &dp.Amount, &dp.Currency, &dp.PaymentMethod,
			&dp.ReferenceNo, &dp.Status, &dp.DPDate, &dp.ClearingDate,
			&dp.Description, &dp.GLJEID, &dp.GLPostingStatus,
			&dp.CreatedBy, &dp.CreatedAt, &dp.UpdatedAt,
			&dp.CustomerCode, &dp.CustomerName); err != nil { return nil, err }
		list = append(list, dp)
	}
	return list, nil
}

func (r *ARRepo) GetDownPayment(ctx context.Context, id, tenantID uuid.UUID) (*armodels.CustomerDownPayment, error) {
	dp := &armodels.CustomerDownPayment{}
	err := r.db.QueryRow(ctx, `SELECT cdp.id, cdp.tenant_id, cdp.customer_id, cdp.org_id,
		cdp.dp_type, cdp.dp_number, cdp.amount, cdp.currency, cdp.payment_method,
		COALESCE(cdp.reference_no,''), cdp.status, cdp.dp_date, cdp.clearing_date,
		COALESCE(cdp.description,''), cdp.gl_je_id, cdp.gl_posting_status,
		cdp.created_by, cdp.created_at, cdp.updated_at,
		COALESCE(c.customer_code,''), COALESCE(c.name,'')
		FROM customer_down_payments cdp
		LEFT JOIN customers c ON c.id = cdp.customer_id
		WHERE cdp.id = $1 AND cdp.tenant_id = $2`, id, tenantID).Scan(
		&dp.ID, &dp.TenantID, &dp.CustomerID, &dp.OrgID,
		&dp.DPType, &dp.DPNumber, &dp.Amount, &dp.Currency, &dp.PaymentMethod,
		&dp.ReferenceNo, &dp.Status, &dp.DPDate, &dp.ClearingDate,
		&dp.Description, &dp.GLJEID, &dp.GLPostingStatus,
		&dp.CreatedBy, &dp.CreatedAt, &dp.UpdatedAt,
		&dp.CustomerCode, &dp.CustomerName)
	if err != nil { return nil, err }
	return dp, nil
}

func (r *ARRepo) CreateDownPayment(ctx context.Context, dp *armodels.CustomerDownPayment) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO customer_down_payments(id, tenant_id, customer_id, org_id, dp_type, dp_number, amount, currency, payment_method,
			reference_no, status, dp_date, description, gl_je_id, gl_posting_status, created_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
	`, dp.ID, dp.TenantID, dp.CustomerID, dp.OrgID, dp.DPType, dp.DPNumber, dp.Amount, dp.Currency, dp.PaymentMethod,
		dp.ReferenceNo, dp.Status, dp.DPDate, dp.Description, dp.GLJEID, dp.GLPostingStatus, dp.CreatedBy, dp.CreatedAt, dp.UpdatedAt)
	return err
}

func (r *ARRepo) UpdateDownPaymentGLJE(ctx context.Context, dpID, glJEID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE customer_down_payments SET gl_je_id = $2, gl_posting_status = 'POSTED', updated_at = NOW() WHERE id = $1`, dpID, glJEID)
	return err
}
