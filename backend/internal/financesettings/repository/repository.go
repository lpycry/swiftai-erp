package repository

import (
	"context"
	"time"
	"fmt"

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

// ══════════════════════════════════════════
//  TAX JURISDICTIONS
// ══════════════════════════════════════════

func (r *FinanceSettingsRepo) ListTaxJurisdictions(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*fsmodels.TaxJurisdiction, error) {
	query := "SELECT id, tenant_id, state, county, city, zip_code, tax_rate, effective_date, expiration_date, is_active, created_at, updated_at FROM tax_jurisdictions WHERE tenant_id = $1"
	args := []interface{}{tenantID}
	if activeOnly {
		query += " AND is_active = true"
	}
	query += " ORDER BY state, county, city"
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*fsmodels.TaxJurisdiction
	for rows.Next() {
		j := &fsmodels.TaxJurisdiction{}
		if err := rows.Scan(&j.ID, &j.TenantID, &j.State, &j.County, &j.City, &j.ZipCode,
			&j.TaxRate, &j.EffectiveDate, &j.ExpirationDate, &j.IsActive, &j.CreatedAt, &j.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, j)
	}
	return list, nil
}

func (r *FinanceSettingsRepo) GetTaxJurisdiction(ctx context.Context, id uuid.UUID) (*fsmodels.TaxJurisdiction, error) {
	j := &fsmodels.TaxJurisdiction{}
	err := r.db.QueryRow(ctx, "SELECT id, tenant_id, state, county, city, zip_code, tax_rate, effective_date, expiration_date, is_active, created_at, updated_at FROM tax_jurisdictions WHERE id = $1", id).Scan(
		&j.ID, &j.TenantID, &j.State, &j.County, &j.City, &j.ZipCode, &j.TaxRate, &j.EffectiveDate, &j.ExpirationDate, &j.IsActive, &j.CreatedAt, &j.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return j, nil
}

func (r *FinanceSettingsRepo) CreateTaxJurisdiction(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateTaxJurisdictionRequest) (*fsmodels.TaxJurisdiction, error) {
	effDate, _ := time.Parse("2006-01-02", req.EffectiveDate)
	j := &fsmodels.TaxJurisdiction{
		ID:            uuid.New(),
		TenantID:      tenantID,
		State:         req.State,
		County:        req.County,
		City:          req.City,
		ZipCode:       req.ZipCode,
		TaxRate:       req.TaxRate,
		EffectiveDate: effDate,
		IsActive:      true,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}
	if req.ExpirationDate != "" {
		if d, err := time.Parse("2006-01-02", req.ExpirationDate); err == nil {
			j.ExpirationDate = &d
		}
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO tax_jurisdictions(id, tenant_id, state, county, city, zip_code, tax_rate, effective_date, expiration_date, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
	`, j.ID, j.TenantID, j.State, j.County, j.City, j.ZipCode, j.TaxRate, j.EffectiveDate, j.ExpirationDate, j.IsActive, j.CreatedAt, j.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create tax jurisdiction: %w", err)
	}
	return j, nil
}

func (r *FinanceSettingsRepo) UpdateTaxJurisdiction(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdateTaxJurisdictionRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE tax_jurisdictions SET
			state           = COALESCE($3, state),
			county          = COALESCE($4, county),
			city            = COALESCE($5, city),
			zip_code        = COALESCE($6, zip_code),
			tax_rate        = COALESCE($7, tax_rate),
			effective_date  = COALESCE($8, effective_date),
			expiration_date = COALESCE($9, expiration_date),
			is_active       = COALESCE($10, is_active),
			updated_at      = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.State, req.County, req.City, req.ZipCode, req.TaxRate, req.EffectiveDate, req.ExpirationDate, req.IsActive)
	return err
}

func (r *FinanceSettingsRepo) DeleteTaxJurisdiction(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM tax_jurisdictions WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

// ══════════════════════════════════════════
//  TAX NEXUS
// ══════════════════════════════════════════

func (r *FinanceSettingsRepo) ListTaxNexus(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*fsmodels.TaxNexus, error) {
	query := "SELECT id, tenant_id, state, nexus_type, sub_type, threshold_amount, effective_date, is_active, created_at, updated_at FROM tax_nexus WHERE tenant_id = $1"
	args := []interface{}{tenantID}
	if activeOnly {
		query += " AND is_active = true"
	}
	query += " ORDER BY state, nexus_type"
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*fsmodels.TaxNexus
	for rows.Next() {
		n := &fsmodels.TaxNexus{}
		if err := rows.Scan(&n.ID, &n.TenantID, &n.State, &n.NexusType, &n.SubType, &n.ThresholdAmount, &n.EffectiveDate, &n.IsActive, &n.CreatedAt, &n.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, n)
	}
	return list, nil
}

func (r *FinanceSettingsRepo) GetTaxNexus(ctx context.Context, id uuid.UUID) (*fsmodels.TaxNexus, error) {
	n := &fsmodels.TaxNexus{}
	err := r.db.QueryRow(ctx, "SELECT id, tenant_id, state, nexus_type, sub_type, threshold_amount, effective_date, is_active, created_at, updated_at FROM tax_nexus WHERE id = $1", id).Scan(
		&n.ID, &n.TenantID, &n.State, &n.NexusType, &n.SubType, &n.ThresholdAmount, &n.EffectiveDate, &n.IsActive, &n.CreatedAt, &n.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return n, nil
}

func (r *FinanceSettingsRepo) CreateTaxNexus(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateTaxNexusRequest) (*fsmodels.TaxNexus, error) {
	effDate, _ := time.Parse("2006-01-02", req.EffectiveDate)
	n := &fsmodels.TaxNexus{
		ID:        uuid.New(),
		TenantID:  tenantID,
		State:     req.State,
		NexusType: req.NexusType,
		SubType:   req.SubType,
		ThresholdAmount: req.ThresholdAmount,
		EffectiveDate:   effDate,
		IsActive:  true,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO tax_nexus(id, tenant_id, state, nexus_type, sub_type, threshold_amount, effective_date, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
	`, n.ID, n.TenantID, n.State, n.NexusType, n.SubType, n.ThresholdAmount, n.EffectiveDate, n.IsActive, n.CreatedAt, n.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create tax nexus: %w", err)
	}
	return n, nil
}

func (r *FinanceSettingsRepo) UpdateTaxNexus(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdateTaxNexusRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE tax_nexus SET
			state           = COALESCE($3, state),
			nexus_type      = COALESCE($4, nexus_type),
			sub_type        = COALESCE($5, sub_type),
			threshold_amount= COALESCE($6, threshold_amount),
			effective_date  = COALESCE($7, effective_date),
			is_active       = COALESCE($8, is_active),
			updated_at      = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.State, req.NexusType, req.SubType, req.ThresholdAmount, req.EffectiveDate, req.IsActive)
	return err
}

func (r *FinanceSettingsRepo) DeleteTaxNexus(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM tax_nexus WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

// ══════════════════════════════════════════
//  TAX JURISDICTION RULES (Product Category × Tax Code)
// ══════════════════════════════════════════

func (r *FinanceSettingsRepo) ListTaxJurisdictionRules(ctx context.Context, tenantID uuid.UUID) ([]*fsmodels.TaxJurisdictionRule, error) {
	rows, err := r.db.Query(ctx, `
		SELECT rule_id, tenant_id, jurisdiction_code, state_code, zip_code, tax_category_code,
			is_taxable, base_rate, condition_type, condition_value,
			effective_from, effective_to, COALESCE(updated_by,''),
			created_at, updated_at
		FROM tax_jurisdiction_rules
		WHERE tenant_id = $1
		ORDER BY jurisdiction_code, tax_category_code, effective_from DESC
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*fsmodels.TaxJurisdictionRule
	for rows.Next() {
		rule := &fsmodels.TaxJurisdictionRule{}
		if err := rows.Scan(&rule.RuleID, &rule.TenantID, &rule.JurisdictionCode, &rule.StateCode, &rule.ZipCode, &rule.TaxCategoryCode,
			&rule.IsTaxable, &rule.BaseRate, &rule.ConditionType, &rule.ConditionValue,
			&rule.EffectiveFrom, &rule.EffectiveTo, &rule.UpdatedBy,
			&rule.CreatedAt, &rule.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, rule)
	}
	return list, nil
}

func (r *FinanceSettingsRepo) GetTaxJurisdictionRule(ctx context.Context, ruleID int, tenantID uuid.UUID) (*fsmodels.TaxJurisdictionRule, error) {
	rule := &fsmodels.TaxJurisdictionRule{}
	err := r.db.QueryRow(ctx, `
		SELECT rule_id, tenant_id, jurisdiction_code, state_code, zip_code, tax_category_code,
			is_taxable, base_rate, condition_type, condition_value,
			effective_from, effective_to, COALESCE(updated_by,''),
			created_at, updated_at
		FROM tax_jurisdiction_rules
		WHERE rule_id = $1 AND tenant_id = $2
	`, ruleID, tenantID).Scan(
		&rule.RuleID, &rule.TenantID, &rule.JurisdictionCode, &rule.StateCode, &rule.ZipCode, &rule.TaxCategoryCode,
		&rule.IsTaxable, &rule.BaseRate, &rule.ConditionType, &rule.ConditionValue,
		&rule.EffectiveFrom, &rule.EffectiveTo, &rule.UpdatedBy,
		&rule.CreatedAt, &rule.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return rule, nil
}

func (r *FinanceSettingsRepo) CreateTaxJurisdictionRule(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateTaxJurisdictionRuleRequest) (*fsmodels.TaxJurisdictionRule, error) {
	effFrom, _ := time.Parse("2006-01-02", req.EffectiveFrom)
	isTaxable := true
	if req.IsTaxable != nil {
		isTaxable = *req.IsTaxable
	}
	condType := "NONE"
	if req.ConditionType != "" {
		condType = req.ConditionType
	}

	rule := &fsmodels.TaxJurisdictionRule{
		TenantID:         tenantID,
		JurisdictionCode: req.JurisdictionCode,
		StateCode:        req.StateCode,
		ZipCode:          req.ZipCode,
		TaxCategoryCode:  req.TaxCategoryCode,
		IsTaxable:        isTaxable,
		BaseRate:         req.BaseRate,
		ConditionType:    condType,
		ConditionValue:   req.ConditionValue,
		EffectiveFrom:    effFrom,
		UpdatedBy:        req.UpdatedBy,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}
	if req.EffectiveTo != "" {
		if d, err := time.Parse("2006-01-02", req.EffectiveTo); err == nil {
			rule.EffectiveTo = &d
		}
	}

	err := r.db.QueryRow(ctx, `
		INSERT INTO tax_jurisdiction_rules(tenant_id, jurisdiction_code, state_code, zip_code, tax_category_code,
			is_taxable, base_rate, condition_type, condition_value,
			effective_from, effective_to, updated_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
		RETURNING rule_id
	`, rule.TenantID, rule.JurisdictionCode, rule.StateCode, rule.ZipCode, rule.TaxCategoryCode,
		rule.IsTaxable, rule.BaseRate, rule.ConditionType, rule.ConditionValue,
		rule.EffectiveFrom, rule.EffectiveTo, rule.UpdatedBy, rule.CreatedAt, rule.UpdatedAt).Scan(&rule.RuleID)
	if err != nil {
		return nil, fmt.Errorf("create tax jurisdiction rule: %w", err)
	}
	return rule, nil
}

func (r *FinanceSettingsRepo) UpdateTaxJurisdictionRule(ctx context.Context, ruleID int, tenantID uuid.UUID, req *fsmodels.UpdateTaxJurisdictionRuleRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE tax_jurisdiction_rules SET
			jurisdiction_code = COALESCE($3, jurisdiction_code),
			state_code        = COALESCE($4, state_code),
			zip_code          = COALESCE($5, zip_code),
			tax_category_code = COALESCE($6, tax_category_code),
			is_taxable        = COALESCE($7, is_taxable),
			base_rate         = COALESCE($8, base_rate),
			condition_type    = COALESCE($9, condition_type),
			condition_value   = COALESCE($10, condition_value),
			effective_from    = COALESCE($11, effective_from),
			effective_to      = COALESCE($12, effective_to),
			updated_by        = COALESCE($13, updated_by),
			updated_at        = NOW()
		WHERE rule_id = $1 AND tenant_id = $2
	`, ruleID, tenantID, req.JurisdictionCode, req.StateCode, req.ZipCode, req.TaxCategoryCode,
		req.IsTaxable, req.BaseRate, req.ConditionType, req.ConditionValue,
		req.EffectiveFrom, req.EffectiveTo, req.UpdatedBy)
	return err
}

func (r *FinanceSettingsRepo) DeleteTaxJurisdictionRule(ctx context.Context, ruleID int, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM tax_jurisdiction_rules WHERE rule_id = $1 AND tenant_id = $2", ruleID, tenantID)
	return err
}

// ══════════════════════════════════════════
//  TAX CATEGORIES
// ══════════════════════════════════════════

func (r *FinanceSettingsRepo) ListTaxCategories(ctx context.Context, tenantID uuid.UUID) ([]*fsmodels.TaxCategory, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, tenant_id, code, COALESCE(description,''), COALESCE(example,''), is_active, created_at, updated_at
		FROM tax_categories WHERE tenant_id = $1 ORDER BY code
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*fsmodels.TaxCategory
	for rows.Next() {
		c := &fsmodels.TaxCategory{}
		if err := rows.Scan(&c.ID, &c.TenantID, &c.Code, &c.Description, &c.Example, &c.IsActive, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, nil
}

func (r *FinanceSettingsRepo) GetTaxCategory(ctx context.Context, id, tenantID uuid.UUID) (*fsmodels.TaxCategory, error) {
	c := &fsmodels.TaxCategory{}
	err := r.db.QueryRow(ctx, `
		SELECT id, tenant_id, code, COALESCE(description,''), COALESCE(example,''), is_active, created_at, updated_at
		FROM tax_categories WHERE id = $1 AND tenant_id = $2
	`, id, tenantID).Scan(
		&c.ID, &c.TenantID, &c.Code, &c.Description, &c.Example, &c.IsActive, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return c, nil
}

func (r *FinanceSettingsRepo) CreateTaxCategory(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateTaxCategoryRequest) (*fsmodels.TaxCategory, error) {
	c := &fsmodels.TaxCategory{
		ID:          uuid.New(),
		TenantID:    tenantID,
		Code:        req.Code,
		Description: req.Description,
		Example:     req.Example,
		IsActive:    true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO tax_categories(id, tenant_id, code, description, example, is_active, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8)
	`, c.ID, c.TenantID, c.Code, c.Description, c.Example, c.IsActive, c.CreatedAt, c.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create tax category: %w", err)
	}
	return c, nil
}

func (r *FinanceSettingsRepo) UpdateTaxCategory(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdateTaxCategoryRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE tax_categories SET
			code        = COALESCE($3, code),
			description = COALESCE($4, description),
			example     = COALESCE($5, example),
			is_active   = COALESCE($6, is_active),
			updated_at  = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.Code, req.Description, req.Example, req.IsActive)
	return err
}

func (r *FinanceSettingsRepo) DeleteTaxCategory(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM tax_categories WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

func (r *FinanceSettingsRepo) DeleteOrgReconAccount(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM org_reconciliation_accounts WHERE id = $1`, id)
	return err
}

