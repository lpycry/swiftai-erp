package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	fsmodels "github.com/swiftai-erp/backend/internal/financesettings/models"
)

type FinanceSettingsRepo struct {
	db *pgxpool.Pool
}

func NewFinanceSettingsRepo(db *pgxpool.Pool) *FinanceSettingsRepo {
	return &FinanceSettingsRepo{db: db}
}

// ══════════════════════════════════════════
//  PAYMENT TERMS
// ══════════════════════════════════════════

func (r *FinanceSettingsRepo) ListPaymentTerms(ctx context.Context, tenantID uuid.UUID) ([]*fsmodels.PaymentTerm, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, tenant_id, code, name, COALESCE(description,''), due_days, discount_days, discount_pct, is_standard, is_active, created_at, updated_at
		FROM payment_terms WHERE tenant_id = $1 ORDER BY due_days, code
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*fsmodels.PaymentTerm
	for rows.Next() {
		p := &fsmodels.PaymentTerm{}
		if err := rows.Scan(&p.ID, &p.TenantID, &p.Code, &p.Name, &p.Description,
			&p.DueDays, &p.DiscountDays, &p.DiscountPct, &p.IsStandard, &p.IsActive,
			&p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, p)
	}
	return list, nil
}

func (r *FinanceSettingsRepo) CreatePaymentTerm(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreatePaymentTermRequest) (*fsmodels.PaymentTerm, error) {
	p := &fsmodels.PaymentTerm{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Code:         req.Code,
		Name:         req.Name,
		Description:  req.Description,
		DueDays:      req.DueDays,
		DiscountDays: req.DiscountDays,
		DiscountPct:  req.DiscountPct,
		IsStandard:   false,
		IsActive:     true,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO payment_terms(id, tenant_id, code, name, description, due_days, discount_days, discount_pct, is_standard, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
	`, p.ID, p.TenantID, p.Code, p.Name, p.Description, p.DueDays, p.DiscountDays, p.DiscountPct, p.IsStandard, p.IsActive, p.CreatedAt, p.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create payment term: %w", err)
	}
	return p, nil
}

func (r *FinanceSettingsRepo) UpdatePaymentTerm(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdatePaymentTermRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE payment_terms SET
			name         = COALESCE($3, name),
			description  = COALESCE($4, description),
			due_days     = COALESCE($5, due_days),
			discount_days= COALESCE($6, discount_days),
			discount_pct = COALESCE($7, discount_pct),
			is_active    = COALESCE($8, is_active),
			updated_at   = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.Name, req.Description, req.DueDays, req.DiscountDays, req.DiscountPct, req.IsActive)
	return err
}

func (r *FinanceSettingsRepo) DeletePaymentTerm(ctx context.Context, id, tenantID uuid.UUID) error {
	result, err := r.db.Exec(ctx, `DELETE FROM payment_terms WHERE id = $1 AND tenant_id = $2 AND is_standard = false`, id, tenantID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("payment term not found or is a standard term — standard terms cannot be deleted")
	}
	return nil
}

// ══════════════════════════════════════════
//  INCOTERMS
// ══════════════════════════════════════════

func (r *FinanceSettingsRepo) ListIncoterms(ctx context.Context, tenantID uuid.UUID) ([]*fsmodels.Incoterm, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, tenant_id, code, name, COALESCE(description,''), category, is_active, created_at, updated_at
		FROM incoterms WHERE tenant_id = $1 ORDER BY category, code
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*fsmodels.Incoterm
	for rows.Next() {
		inc := &fsmodels.Incoterm{}
		if err := rows.Scan(&inc.ID, &inc.TenantID, &inc.Code, &inc.Name, &inc.Description,
			&inc.Category, &inc.IsActive, &inc.CreatedAt, &inc.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, inc)
	}
	return list, nil
}

func (r *FinanceSettingsRepo) CreateIncoterm(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateIncotermRequest) (*fsmodels.Incoterm, error) {
	inc := &fsmodels.Incoterm{
		ID:          uuid.New(),
		TenantID:    tenantID,
		Code:        req.Code,
		Name:        req.Name,
		Description: req.Description,
		Category:    req.Category,
		IsActive:    true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO incoterms(id, tenant_id, code, name, description, category, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)
	`, inc.ID, inc.TenantID, inc.Code, inc.Name, inc.Description, inc.Category, inc.IsActive, inc.CreatedAt, inc.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create incoterm: %w", err)
	}
	return inc, nil
}

func (r *FinanceSettingsRepo) UpdateIncoterm(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdateIncotermRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE incoterms SET
			name        = COALESCE($3, name),
			description = COALESCE($4, description),
			category    = COALESCE($5, category),
			is_active   = COALESCE($6, is_active),
			updated_at  = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.Name, req.Description, req.Category, req.IsActive)
	return err
}

func (r *FinanceSettingsRepo) DeleteIncoterm(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM incoterms WHERE id = $1 AND tenant_id = $2`, id, tenantID)
	return err
}

// ══════════════════════════════════════════
//  ORG RECONCILIATION ACCOUNTS
// ══════════════════════════════════════════

func (r *FinanceSettingsRepo) ListOrgReconAccounts(ctx context.Context, orgID uuid.UUID) ([]*fsmodels.OrgReconAccount, error) {
	var query string
	var args []interface{}
	if orgID != uuid.Nil {
		query = `SELECT o.id, o.org_id, o.account_id, o.reconciliation_type, o.account_type,
			COALESCE(org.org_code,''), COALESCE(org.org_name,''),
			COALESCE(a.account_code,''), COALESCE(a.account_name,''),
			o.created_at, o.updated_at
		FROM org_reconciliation_accounts o
		LEFT JOIN organizations org ON org.id = o.org_id
		LEFT JOIN gl_accounts a ON a.id = o.account_id
		WHERE o.org_id = $1
		ORDER BY org.org_code, o.account_type`
		args = append(args, orgID)
	} else {
		query = `SELECT o.id, o.org_id, o.account_id, o.reconciliation_type, o.account_type,
			COALESCE(org.org_code,''), COALESCE(org.org_name,''),
			COALESCE(a.account_code,''), COALESCE(a.account_name,''),
			o.created_at, o.updated_at
		FROM org_reconciliation_accounts o
		LEFT JOIN organizations org ON org.id = o.org_id
		LEFT JOIN gl_accounts a ON a.id = o.account_id
		ORDER BY org.org_code, o.account_type`
	}

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*fsmodels.OrgReconAccount
	for rows.Next() {
		ra := &fsmodels.OrgReconAccount{}
		if err := rows.Scan(&ra.ID, &ra.OrgID, &ra.AccountID, &ra.ReconciliationType, &ra.AccountType,
			&ra.OrgCode, &ra.OrgName, &ra.AccountCode, &ra.AccountName,
			&ra.CreatedAt, &ra.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, ra)
	}
	return list, nil
}

func (r *FinanceSettingsRepo) CreateOrgReconAccount(ctx context.Context, req *fsmodels.CreateOrgReconAccountRequest) (*fsmodels.OrgReconAccount, error) {
	ra := &fsmodels.OrgReconAccount{
		ID:                uuid.New(),
		OrgID:             req.OrgID,
		AccountID:         req.AccountID,
		ReconciliationType: req.ReconciliationType,
		AccountType:       req.AccountType,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO org_reconciliation_accounts (id, org_id, account_id, reconciliation_type, account_type, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,NOW(),NOW())
		ON CONFLICT (org_id, account_type) DO UPDATE SET
			account_id = EXCLUDED.account_id,
			reconciliation_type = EXCLUDED.reconciliation_type,
			updated_at = NOW()
	`, ra.ID, ra.OrgID, ra.AccountID, ra.ReconciliationType, ra.AccountType)
	if err != nil {
		return nil, fmt.Errorf("create recon account: %w", err)
	}
	return ra, nil
}

func (r *FinanceSettingsRepo) UpdateOrgReconAccount(ctx context.Context, id uuid.UUID, req *fsmodels.CreateOrgReconAccountRequest) (*fsmodels.OrgReconAccount, error) {
	_, err := r.db.Exec(ctx, `
		UPDATE org_reconciliation_accounts SET
			account_id = $2,
			reconciliation_type = $3,
			account_type = $4,
			updated_at = NOW()
		WHERE id = $1
	`, id, req.AccountID, req.ReconciliationType, req.AccountType)
	if err != nil {
		return nil, fmt.Errorf("update recon account: %w", err)
	}
	return &fsmodels.OrgReconAccount{
		ID:                id,
		OrgID:             req.OrgID,
		AccountID:         req.AccountID,
		ReconciliationType: req.ReconciliationType,
		AccountType:       req.AccountType,
	}, nil
}

func (r *FinanceSettingsRepo) DeleteOrgReconAccount(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM org_reconciliation_accounts WHERE id = $1`, id)
	return err
}
