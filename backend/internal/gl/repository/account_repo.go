package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
)

// AccountRepo handles chart of account CRUD with tree support.
type AccountRepo struct {
	db *pgxpool.Pool
}

func NewAccountRepo(db *pgxpool.Pool) *AccountRepo {
	return &AccountRepo{db: db}
}

const accountSelectCols = `id, tenant_id, account_code, account_name, account_type,
	parent_id, level, is_active, is_leaf, currency,
	COALESCE(description,'') as description,
	COALESCE(reconciliation_type,'none') as reconciliation_type,
	created_at, updated_at`

// Create inserts a new account.
func (r *AccountRepo) Create(ctx context.Context, tenantID uuid.UUID, req *glmodels.CreateAccountRequest) (*glmodels.Account, error) {
	recType := req.ReconciliationType
	if recType == "" {
		recType = "none"
	}

	acc := &glmodels.Account{
		ID:                 uuid.New(),
		TenantID:           tenantID,
		AccountCode:        req.AccountCode,
		AccountName:        req.AccountName,
		AccountType:        req.AccountType,
		ParentID:           req.ParentID,
		Level:              req.Level,
		IsActive:           true,
		IsLeaf:             req.IsLeaf,
		Currency:           req.Currency,
		Description:        req.Description,
		ReconciliationType: recType,
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}
	if acc.Currency == "" {
		acc.Currency = "USD"
	}

	query := `
		INSERT INTO gl_accounts (id, tenant_id, account_code, account_name, account_type,
		                         parent_id, level, is_active, is_leaf, currency, description,
		                         reconciliation_type, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
	`
	_, err := r.db.Exec(ctx, query,
		acc.ID, acc.TenantID, acc.AccountCode, acc.AccountName, acc.AccountType,
		acc.ParentID, acc.Level, acc.IsActive, acc.IsLeaf, acc.Currency, acc.Description,
		acc.ReconciliationType, acc.CreatedAt, acc.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create account: %w", err)
	}
	return acc, nil
}

// GetByID retrieves a single account by ID and tenant.
func (r *AccountRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*glmodels.Account, error) {
	query := `
		SELECT ` + accountSelectCols + `
		FROM gl_accounts WHERE id = $1 AND tenant_id = $2
	`
	acc := &glmodels.Account{}
	err := r.db.QueryRow(ctx, query, id, tenantID).Scan(
		&acc.ID, &acc.TenantID, &acc.AccountCode, &acc.AccountName, &acc.AccountType,
		&acc.ParentID, &acc.Level, &acc.IsActive, &acc.IsLeaf, &acc.Currency,
		&acc.Description, &acc.ReconciliationType,
		&acc.CreatedAt, &acc.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get account by id: %w", err)
	}
	return acc, nil
}

// ListByTenant retrieves all accounts for a tenant, ordered by account_code.
func (r *AccountRepo) ListByTenant(ctx context.Context, tenantID uuid.UUID) ([]*glmodels.Account, error) {
	query := `
		SELECT ` + accountSelectCols + `
		FROM gl_accounts WHERE tenant_id = $1
		ORDER BY account_code
	`
	rows, err := r.db.Query(ctx, query, tenantID)
	if err != nil {
		return nil, fmt.Errorf("list accounts: %w", err)
	}
	defer rows.Close()

	return scanAccounts(rows)
}

// ListByType retrieves accounts filtered by account type.
func (r *AccountRepo) ListByType(ctx context.Context, tenantID uuid.UUID, accountType string) ([]*glmodels.Account, error) {
	query := `
		SELECT ` + accountSelectCols + `
		FROM gl_accounts WHERE tenant_id = $1 AND account_type = $2
		ORDER BY account_code
	`
	rows, err := r.db.Query(ctx, query, tenantID, accountType)
	if err != nil {
		return nil, fmt.Errorf("list accounts by type: %w", err)
	}
	defer rows.Close()

	return scanAccounts(rows)
}

// ListLeafAccounts retrieves only leaf (postable) accounts for a tenant.
func (r *AccountRepo) ListLeafAccounts(ctx context.Context, tenantID uuid.UUID) ([]*glmodels.Account, error) {
	query := `
		SELECT ` + accountSelectCols + `
		FROM gl_accounts WHERE tenant_id = $1 AND is_leaf = true AND is_active = true
		ORDER BY account_code
	`
	rows, err := r.db.Query(ctx, query, tenantID)
	if err != nil {
		return nil, fmt.Errorf("list leaf accounts: %w", err)
	}
	defer rows.Close()

	return scanAccounts(rows)
}

// Update modifies an existing account.
func (r *AccountRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *glmodels.UpdateAccountRequest) (*glmodels.Account, error) {
	// Build dynamic update
	setClauses := make([]string, 0, 9)
	args := []interface{}{}
	argIdx := 1

	if req.AccountName != "" {
		setClauses = append(setClauses, fmt.Sprintf("account_name = $%d", argIdx))
		args = append(args, req.AccountName)
		argIdx++
	}
	if req.AccountType != "" {
		setClauses = append(setClauses, fmt.Sprintf("account_type = $%d", argIdx))
		args = append(args, req.AccountType)
		argIdx++
	}
	if req.ParentID != nil {
		setClauses = append(setClauses, fmt.Sprintf("parent_id = $%d", argIdx))
		args = append(args, *req.ParentID)
		argIdx++
	}
	if req.IsActive != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_active = $%d", argIdx))
		args = append(args, *req.IsActive)
		argIdx++
	}
	if req.IsLeaf != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_leaf = $%d", argIdx))
		args = append(args, *req.IsLeaf)
		argIdx++
	}
	if req.Currency != "" {
		setClauses = append(setClauses, fmt.Sprintf("currency = $%d", argIdx))
		args = append(args, req.Currency)
		argIdx++
	}
	if req.Description != "" {
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", argIdx))
		args = append(args, req.Description)
		argIdx++
	}
	if req.ReconciliationType != "" {
		setClauses = append(setClauses, fmt.Sprintf("reconciliation_type = $%d", argIdx))
		args = append(args, req.ReconciliationType)
		argIdx++
	}

	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now())
	argIdx++

	args = append(args, id, tenantID)

	query := fmt.Sprintf(`
		UPDATE gl_accounts SET %s
		WHERE id = $%d AND tenant_id = $%d
		RETURNING `+accountSelectCols+`
	`, joinClauses(setClauses, ", "), argIdx, argIdx+1)

	if len(setClauses) <= 1 {
		// Only updated_at changed, nothing meaningful to update
		acc, err := r.GetByID(ctx, id, tenantID)
		if err != nil {
			return nil, err
		}
		if acc == nil {
			return nil, fmt.Errorf("account not found")
		}
		return acc, nil
	}

	acc := &glmodels.Account{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&acc.ID, &acc.TenantID, &acc.AccountCode, &acc.AccountName, &acc.AccountType,
		&acc.ParentID, &acc.Level, &acc.IsActive, &acc.IsLeaf, &acc.Currency,
		&acc.Description, &acc.ReconciliationType,
		&acc.CreatedAt, &acc.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("update account: %w", err)
	}
	return acc, nil
}

// Delete soft-deletes (deactivates) an account by ID.
func (r *AccountRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	// Check if account has children
	var childCount int
	err := r.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM gl_accounts WHERE parent_id = $1 AND tenant_id = $2",
		id, tenantID,
	).Scan(&childCount)
	if err != nil {
		return fmt.Errorf("check children: %w", err)
	}
	if childCount > 0 {
		return fmt.Errorf("cannot delete account with %d child accounts", childCount)
	}

	// Check if account has been used in any journal entry lines
	var lineCount int
	err = r.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM gl_journal_lines WHERE account_id = $1",
		id,
	).Scan(&lineCount)
	if err != nil {
		return fmt.Errorf("check journal lines: %w", err)
	}
	if lineCount > 0 {
		return fmt.Errorf("cannot delete account with %d journal entry transaction(s)", lineCount)
	}

	// Soft delete: deactivate
	_, err = r.db.Exec(ctx,
		"UPDATE gl_accounts SET is_active = false, updated_at = $1 WHERE id = $2 AND tenant_id = $3",
		time.Now(), id, tenantID,
	)
	if err != nil {
		return fmt.Errorf("delete account: %w", err)
	}
	return nil
}

// Reactivate sets is_active = true for a previously deactivated account.
func (r *AccountRepo) Reactivate(ctx context.Context, id, tenantID uuid.UUID) (*glmodels.Account, error) {
	_, err := r.db.Exec(ctx,
		"UPDATE gl_accounts SET is_active = true, updated_at = $1 WHERE id = $2 AND tenant_id = $3",
		time.Now(), id, tenantID,
	)
	if err != nil {
		return nil, fmt.Errorf("reactivate account: %w", err)
	}
	return r.GetByID(ctx, id, tenantID)
}

// GetChildren retrieves direct child accounts of a parent.
func (r *AccountRepo) GetChildren(ctx context.Context, parentID, tenantID uuid.UUID) ([]*glmodels.Account, error) {
	query := `
		SELECT ` + accountSelectCols + `
		FROM gl_accounts WHERE parent_id = $1 AND tenant_id = $2
		ORDER BY account_code
	`
	rows, err := r.db.Query(ctx, query, parentID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get children: %w", err)
	}
	defer rows.Close()

	return scanAccounts(rows)
}

// GetTree returns the full account tree for a tenant.
func (r *AccountRepo) GetTree(ctx context.Context, tenantID uuid.UUID) ([]*glmodels.AccountTreeResponse, error) {
	all, err := r.ListByTenant(ctx, tenantID)
	if err != nil {
		return nil, err
	}

	// Build tree
	childrenMap := make(map[uuid.UUID][]*glmodels.AccountTreeResponse)
	for _, a := range all {
		node := &glmodels.AccountTreeResponse{Account: *a}
		pid := uuid.Nil
		if a.ParentID != nil {
			pid = *a.ParentID
		}
		childrenMap[pid] = append(childrenMap[pid], node)
	}

	// Recursively attach children
	var attachChildren func(parentID uuid.UUID) []*glmodels.AccountTreeResponse
	attachChildren = func(parentID uuid.UUID) []*glmodels.AccountTreeResponse {
		nodes := childrenMap[parentID]
		for _, node := range nodes {
			node.Children = attachChildren(node.ID)
		}
		return nodes
	}

	return attachChildren(uuid.Nil), nil
}

// Search searches accounts by code or name.
func (r *AccountRepo) Search(ctx context.Context, tenantID uuid.UUID, query string) ([]*glmodels.Account, error) {
	sqlQuery := `
		SELECT ` + accountSelectCols + `
		FROM gl_accounts
		WHERE tenant_id = $1
		  AND (account_code ILIKE $2 OR account_name ILIKE $2)
		ORDER BY account_code
		LIMIT 50
	`
	pattern := "%" + query + "%"
	rows, err := r.db.Query(ctx, sqlQuery, tenantID, pattern)
	if err != nil {
		return nil, fmt.Errorf("search accounts: %w", err)
	}
	defer rows.Close()

	return scanAccounts(rows)
}

func scanAccounts(rows pgx.Rows) ([]*glmodels.Account, error) {
	var accounts []*glmodels.Account
	for rows.Next() {
		acc := &glmodels.Account{}
		err := rows.Scan(
			&acc.ID, &acc.TenantID, &acc.AccountCode, &acc.AccountName, &acc.AccountType,
			&acc.ParentID, &acc.Level, &acc.IsActive, &acc.IsLeaf, &acc.Currency,
			&acc.Description, &acc.ReconciliationType,
			&acc.CreatedAt, &acc.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan account: %w", err)
		}
		accounts = append(accounts, acc)
	}
	return accounts, nil
}

func joinClauses(clauses []string, sep string) string {
	if len(clauses) == 0 {
		return ""
	}
	result := clauses[0]
	for _, c := range clauses[1:] {
		result += sep + c
	}
	return result
}
