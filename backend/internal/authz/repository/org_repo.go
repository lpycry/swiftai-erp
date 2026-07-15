package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	models "github.com/swiftai-erp/backend/internal/authz/models"
)

type OrgRepo struct {
	db *pgxpool.Pool
}

func NewOrgRepo(db *pgxpool.Pool) *OrgRepo {
	return &OrgRepo{db: db}
}

func (r *OrgRepo) List(ctx context.Context, tenantID uuid.UUID) ([]*models.OrgUnit, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, tenant_id, parent_id, org_code, org_name, org_type, is_active,
		       level, COALESCE(path,''), manager_id, created_at, updated_at
		FROM org_units
		WHERE tenant_id=$1
		ORDER BY path, org_code`, tenantID)
	if err != nil {
		return nil, fmt.Errorf("list org units: %w", err)
	}
	defer rows.Close()

	var units []*models.OrgUnit
	for rows.Next() {
		unit := &models.OrgUnit{}
		if err := rows.Scan(
			&unit.ID, &unit.TenantID, &unit.ParentID, &unit.OrgCode, &unit.OrgName,
			&unit.OrgType, &unit.IsActive, &unit.Level, &unit.Path, &unit.ManagerID,
			&unit.CreatedAt, &unit.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan org unit: %w", err)
		}
		units = append(units, unit)
	}
	return units, nil
}

func (r *OrgRepo) Create(ctx context.Context, unit *models.OrgUnit) error {
	if unit.ParentID != nil {
		parent, err := r.GetByID(ctx, *unit.ParentID)
		if err != nil {
			return err
		}
		if parent != nil {
			unit.Level = parent.Level + 1
			unit.Path = parent.Path + "/" + unit.OrgCode
		}
	}
	if unit.Path == "" {
		unit.Path = "/" + unit.OrgCode
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO org_units (
			id, tenant_id, parent_id, org_code, org_name, org_type, is_active,
			level, path, manager_id, created_at, updated_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW(),NOW())`,
		unit.ID, unit.TenantID, unit.ParentID, unit.OrgCode, unit.OrgName,
		unit.OrgType, unit.IsActive, unit.Level, unit.Path, unit.ManagerID)
	return err
}

func (r *OrgRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.OrgUnit, error) {
	unit := &models.OrgUnit{}
	err := r.db.QueryRow(ctx, `
		SELECT id, tenant_id, parent_id, org_code, org_name, org_type, is_active,
		       level, COALESCE(path,''), manager_id, created_at, updated_at
		FROM org_units WHERE id=$1`, id).Scan(
		&unit.ID, &unit.TenantID, &unit.ParentID, &unit.OrgCode, &unit.OrgName,
		&unit.OrgType, &unit.IsActive, &unit.Level, &unit.Path, &unit.ManagerID,
		&unit.CreatedAt, &unit.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return unit, nil
}

func (r *OrgRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM org_units WHERE id=$1 AND tenant_id=$2`, id, tenantID)
	return err
}
