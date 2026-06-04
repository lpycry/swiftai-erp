package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	ccmodels "github.com/swiftai-erp/backend/internal/costcenter/models"
)

type CostCenterRepo struct {
	db *pgxpool.Pool
}

func NewCostCenterRepo(db *pgxpool.Pool) *CostCenterRepo {
	return &CostCenterRepo{db: db}
}

const ccSelectCols = `id, tenant_id, cost_center_id, description,
	COALESCE(cost_center_type,'') as cost_center_type,
	is_active, valid_from::text, COALESCE(valid_to::text,'') as valid_to,
	created_at, updated_at`

func (r *CostCenterRepo) Create(ctx context.Context, cc *ccmodels.CostCenter) error {
	query := `
		INSERT INTO cost_centers (id, tenant_id, cost_center_id, description, cost_center_type, is_active, valid_from, valid_to, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7::date, NULLIF($8,'')::date, $9, $10)
	`
	_, err := r.db.Exec(ctx, query,
		cc.ID, cc.TenantID, cc.CostCenterID, cc.Description, cc.CostCenterType,
		cc.IsActive, cc.ValidFrom, cc.ValidTo, cc.CreatedAt, cc.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create cost center: %w", err)
	}
	return nil
}

func (r *CostCenterRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*ccmodels.CostCenter, error) {
	query := `SELECT ` + ccSelectCols + ` FROM cost_centers WHERE id = $1 AND tenant_id = $2`
	cc := &ccmodels.CostCenter{}
	err := r.db.QueryRow(ctx, query, id, tenantID).Scan(
		&cc.ID, &cc.TenantID, &cc.CostCenterID, &cc.Description,
		&cc.CostCenterType, &cc.IsActive, &cc.ValidFrom, &cc.ValidTo,
		&cc.CreatedAt, &cc.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get cost center: %w", err)
	}
	return cc, nil
}

func (r *CostCenterRepo) List(ctx context.Context, tenantID uuid.UUID, search string) ([]*ccmodels.CostCenter, error) {
	var rows pgx.Rows
	var err error

	if search == "" {
		query := `SELECT ` + ccSelectCols + ` FROM cost_centers WHERE tenant_id = $1 ORDER BY cost_center_id`
		rows, err = r.db.Query(ctx, query, tenantID)
	} else {
		query := `SELECT ` + ccSelectCols + ` FROM cost_centers WHERE tenant_id = $1 AND (cost_center_id ILIKE $2 OR description ILIKE $2 OR cost_center_type ILIKE $2) ORDER BY cost_center_id`
		like := "%" + search + "%"
		rows, err = r.db.Query(ctx, query, tenantID, like)
	}
	if err != nil {
		return nil, fmt.Errorf("list cost centers: %w", err)
	}
	defer rows.Close()
	return scanCCs(rows)
}

func (r *CostCenterRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *ccmodels.UpdateCostCenterRequest) (*ccmodels.CostCenter, error) {
	setClauses := make([]string, 0, 6)
	args := []interface{}{}
	argIdx := 1

	if req.Description != "" {
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", argIdx))
		args = append(args, req.Description)
		argIdx++
	}
	if req.CostCenterType != "" {
		setClauses = append(setClauses, fmt.Sprintf("cost_center_type = $%d", argIdx))
		args = append(args, req.CostCenterType)
		argIdx++
	}
	if req.IsActive != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_active = $%d", argIdx))
		args = append(args, *req.IsActive)
		argIdx++
	}
	if req.ValidFrom != "" {
		setClauses = append(setClauses, fmt.Sprintf("valid_from = $%d::date", argIdx))
		args = append(args, req.ValidFrom)
		argIdx++
	}
	if req.ValidTo != "" {
		setClauses = append(setClauses, fmt.Sprintf("valid_to = NULLIF($%d,'')::date", argIdx))
		args = append(args, req.ValidTo)
		argIdx++
	}

	if len(setClauses) == 0 {
		return r.GetByID(ctx, id, tenantID)
	}

	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now())
	argIdx++

	args = append(args, id, tenantID)

	query := fmt.Sprintf(`
		UPDATE cost_centers SET %s
		WHERE id = $%d AND tenant_id = $%d
		RETURNING `+ccSelectCols+`
	`, joinClauses(setClauses, ", "), argIdx, argIdx+1)

	cc := &ccmodels.CostCenter{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&cc.ID, &cc.TenantID, &cc.CostCenterID, &cc.Description,
		&cc.CostCenterType, &cc.IsActive, &cc.ValidFrom, &cc.ValidTo,
		&cc.CreatedAt, &cc.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("update cost center: %w", err)
	}
	return cc, nil
}

func (r *CostCenterRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		"DELETE FROM cost_centers WHERE id = $1 AND tenant_id = $2",
		id, tenantID,
	)
	if err != nil {
		return fmt.Errorf("delete cost center: %w", err)
	}
	return nil
}

// ── Scanners ──

func scanCCs(rows pgx.Rows) ([]*ccmodels.CostCenter, error) {
	var list []*ccmodels.CostCenter
	for rows.Next() {
		cc := &ccmodels.CostCenter{}
		err := rows.Scan(
			&cc.ID, &cc.TenantID, &cc.CostCenterID, &cc.Description,
			&cc.CostCenterType, &cc.IsActive, &cc.ValidFrom, &cc.ValidTo,
			&cc.CreatedAt, &cc.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan cost center: %w", err)
		}
		list = append(list, cc)
	}
	return list, nil
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
