package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	oumodels "github.com/swiftai-erp/backend/internal/orgunit/models"
)

type OrgUnitRepo struct {
	db *pgxpool.Pool
}

func NewOrgUnitRepo(db *pgxpool.Pool) *OrgUnitRepo {
	return &OrgUnitRepo{db: db}
}

const ouSelectCols = `id, tenant_id, unit_code, unit_name,
	parent_id,
	COALESCE(manager_id,'') as manager_id,
	COALESCE(cost_center_id,'') as cost_center_id,
	is_active, valid_from::text, COALESCE(valid_to::text,'') as valid_to,
	created_at, updated_at`

func (r *OrgUnitRepo) Create(ctx context.Context, ou *oumodels.OrgUnit) error {
	// Convert nil *uuid.UUID to interface{}-nil for pgx compatibility
	var parentIDParam interface{} = nil
	if ou.ParentID != nil {
		parentIDParam = *ou.ParentID
	}
	query := `
		INSERT INTO organization_units
			(id, tenant_id, unit_code, unit_name, parent_id, manager_id, cost_center_id, is_active, valid_from, valid_to, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::date, NULLIF($10,'')::date, $11, $12)
	`
	_, err := r.db.Exec(ctx, query,
		ou.ID, ou.TenantID, ou.UnitCode, ou.UnitName, parentIDParam,
		ou.ManagerID, ou.CostCenterID, ou.IsActive,
		ou.ValidFrom, ou.ValidTo, ou.CreatedAt, ou.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create org unit: %w", err)
	}
	return nil
}

func (r *OrgUnitRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*oumodels.OrgUnit, error) {
	query := `SELECT ` + ouSelectCols + ` FROM organization_units WHERE id = $1 AND tenant_id = $2`
	ou := &oumodels.OrgUnit{}
	err := r.db.QueryRow(ctx, query, id, tenantID).Scan(
		&ou.ID, &ou.TenantID, &ou.UnitCode, &ou.UnitName,
		&ou.ParentID, &ou.ManagerID, &ou.CostCenterID,
		&ou.IsActive, &ou.ValidFrom, &ou.ValidTo,
		&ou.CreatedAt, &ou.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get org unit: %w", err)
	}
	return ou, nil
}

func (r *OrgUnitRepo) List(ctx context.Context, tenantID uuid.UUID, search string) ([]*oumodels.OrgUnit, error) {
	var rows pgx.Rows
	var err error

	if search == "" {
		query := `SELECT ` + ouSelectCols + ` FROM organization_units WHERE tenant_id = $1 ORDER BY unit_code`
		rows, err = r.db.Query(ctx, query, tenantID)
	} else {
		query := `SELECT ` + ouSelectCols + ` FROM organization_units WHERE tenant_id = $1
			AND (unit_code ILIKE $2 OR unit_name ILIKE $2) ORDER BY unit_code`
		like := "%" + search + "%"
		rows, err = r.db.Query(ctx, query, tenantID, like)
	}
	if err != nil {
		return nil, fmt.Errorf("list org units: %w", err)
	}
	defer rows.Close()
	return scanOUs(rows)
}

func (r *OrgUnitRepo) ListTree(ctx context.Context, tenantID uuid.UUID) ([]*oumodels.OrgUnitNode, error) {
	all, err := r.List(ctx, tenantID, "")
	if err != nil {
		return nil, err
	}
	return buildTree(all), nil
}

func buildTree(flat []*oumodels.OrgUnit) []*oumodels.OrgUnitNode {
	nodeMap := make(map[uuid.UUID]*oumodels.OrgUnitNode)
	var roots []*oumodels.OrgUnitNode

	for _, u := range flat {
		nodeMap[u.ID] = &oumodels.OrgUnitNode{OrgUnit: *u}
	}
	for _, u := range flat {
		node := nodeMap[u.ID]
		if u.ParentID != nil {
			parent, ok := nodeMap[*u.ParentID]
			if ok {
				parent.Children = append(parent.Children, node)
			} else {
				roots = append(roots, node)
			}
		} else {
			roots = append(roots, node)
		}
	}
	return roots
}

func (r *OrgUnitRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *oumodels.UpdateOrgUnitRequest) (*oumodels.OrgUnit, error) {
	setClauses := make([]string, 0, 7)
	args := []interface{}{}
	argIdx := 1

	if req.UnitName != "" {
		setClauses = append(setClauses, fmt.Sprintf("unit_name = $%d", argIdx))
		args = append(args, req.UnitName)
		argIdx++
	}
	if req.ManagerID != "" {
		setClauses = append(setClauses, fmt.Sprintf("manager_id = $%d", argIdx))
		args = append(args, req.ManagerID)
		argIdx++
	}
	if req.CostCenterID != "" {
		setClauses = append(setClauses, fmt.Sprintf("cost_center_id = $%d", argIdx))
		args = append(args, req.CostCenterID)
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

	// Parent update (can set to NULL via empty string sentinel)
	if req.ParentID != "" {
		setClauses = append(setClauses, fmt.Sprintf("parent_id = $%d", argIdx))
		args = append(args, req.ParentID)
		argIdx++
	} else if req.ParentID == "__null__" {
		setClauses = append(setClauses, fmt.Sprintf("parent_id = $%d", argIdx))
		args = append(args, nil)
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
		UPDATE organization_units SET %s
		WHERE id = $%d AND tenant_id = $%d
		RETURNING `+ouSelectCols+`
	`, strings.Join(setClauses, ", "), argIdx, argIdx+1)

	ou := &oumodels.OrgUnit{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&ou.ID, &ou.TenantID, &ou.UnitCode, &ou.UnitName,
		&ou.ParentID, &ou.ManagerID, &ou.CostCenterID,
		&ou.IsActive, &ou.ValidFrom, &ou.ValidTo,
		&ou.CreatedAt, &ou.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("update org unit: %w", err)
	}
	return ou, nil
}

func (r *OrgUnitRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	// Check for children
	var childCount int
	err := r.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM organization_units WHERE parent_id = $1", id,
	).Scan(&childCount)
	if err != nil {
		return fmt.Errorf("check children: %w", err)
	}
	if childCount > 0 {
		return fmt.Errorf("cannot delete unit with %d child unit(s)", childCount)
	}

	_, err = r.db.Exec(ctx,
		"DELETE FROM organization_units WHERE id = $1 AND tenant_id = $2",
		id, tenantID,
	)
	if err != nil {
		return fmt.Errorf("delete org unit: %w", err)
	}
	return nil
}

// ── Scanners ──

func scanOUs(rows pgx.Rows) ([]*oumodels.OrgUnit, error) {
	var list []*oumodels.OrgUnit
	for rows.Next() {
		ou := &oumodels.OrgUnit{}
		err := rows.Scan(
			&ou.ID, &ou.TenantID, &ou.UnitCode, &ou.UnitName,
			&ou.ParentID, &ou.ManagerID, &ou.CostCenterID,
			&ou.IsActive, &ou.ValidFrom, &ou.ValidTo,
			&ou.CreatedAt, &ou.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan org unit: %w", err)
		}
		list = append(list, ou)
	}
	return list, nil
}
