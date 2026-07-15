package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	models "github.com/swiftai-erp/backend/internal/authz/models"
)

type RoleRepo struct {
	db *pgxpool.Pool
}

func NewRoleRepo(db *pgxpool.Pool) *RoleRepo {
	return &RoleRepo{db: db}
}

func (r *RoleRepo) Create(ctx context.Context, role *models.RoleMaster) error {
	query := `
		INSERT INTO role_master (id, tenant_id, role_id, description, role_type, role_category,
		                         parent_role_id, inherit_level, is_system, is_active,
		                         valid_from, valid_to, created_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
	`
	_, err := r.db.Exec(ctx, query,
		role.ID, role.TenantID, role.RoleID, role.Description,
		role.RoleType, role.RoleCategory,
		role.ParentRoleID, role.InheritLevel,
		role.IsSystem, role.IsActive,
		role.ValidFrom, role.ValidTo, role.CreatedBy,
		role.CreatedAt, role.UpdatedAt)
	return err
}

func (r *RoleRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.RoleMaster, error) {
	query := `
		SELECT id, tenant_id, role_id, COALESCE(description,''), role_type, COALESCE(role_category,''),
		       parent_role_id, inherit_level, is_system, is_active,
		       valid_from, valid_to, created_by, created_at, updated_at
		FROM role_master WHERE id = $1
	`
	role := &models.RoleMaster{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&role.ID, &role.TenantID, &role.RoleID, &role.Description,
		&role.RoleType, &role.RoleCategory,
		&role.ParentRoleID, &role.InheritLevel,
		&role.IsSystem, &role.IsActive,
		&role.ValidFrom, &role.ValidTo, &role.CreatedBy,
		&role.CreatedAt, &role.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get role: %w", err)
	}
	return role, nil
}

func (r *RoleRepo) List(ctx context.Context, tenantID uuid.UUID, category string) ([]*models.RoleMaster, error) {
	var rows pgx.Rows
	var err error
	baseQuery := `
		SELECT id, tenant_id, role_id, COALESCE(description,''), role_type, COALESCE(role_category,''),
		       parent_role_id, inherit_level, is_system, is_active,
		       valid_from, valid_to, created_by, created_at, updated_at
		FROM role_master WHERE tenant_id = $1`
	args := []interface{}{tenantID}

	if category != "" {
		baseQuery += ` AND role_category = $2`
		args = append(args, category)
	}
	baseQuery += ` ORDER BY role_type, role_id`

	rows, err = r.db.Query(ctx, baseQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("list roles: %w", err)
	}
	defer rows.Close()

	var roles []*models.RoleMaster
	for rows.Next() {
		role := &models.RoleMaster{}
		if err := rows.Scan(
			&role.ID, &role.TenantID, &role.RoleID, &role.Description,
			&role.RoleType, &role.RoleCategory,
			&role.ParentRoleID, &role.InheritLevel,
			&role.IsSystem, &role.IsActive,
			&role.ValidFrom, &role.ValidTo, &role.CreatedBy,
			&role.CreatedAt, &role.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan role: %w", err)
		}
		roles = append(roles, role)
	}
	return roles, nil
}

func (r *RoleRepo) Update(ctx context.Context, role *models.RoleMaster) error {
	query := `
		UPDATE role_master SET role_id=$1, description=$2, role_type=$3, role_category=$4,
		       parent_role_id=$5, inherit_level=$6, is_active=$7,
		       valid_from=$8, valid_to=$9, updated_at=NOW()
		WHERE id=$10 AND tenant_id=$11
	`
	_, err := r.db.Exec(ctx, query,
		role.RoleID, role.Description, role.RoleType, role.RoleCategory,
		role.ParentRoleID, role.InheritLevel, role.IsActive,
		role.ValidFrom, role.ValidTo, role.ID, role.TenantID)
	return err
}

func (r *RoleRepo) ListCompositeMembers(ctx context.Context, compositeRoleID uuid.UUID) ([]*models.RoleMaster, error) {
	rows, err := r.db.Query(ctx, `
		SELECT rm.id, rm.tenant_id, rm.role_id, COALESCE(rm.description,''), rm.role_type, COALESCE(rm.role_category,''),
		       rm.parent_role_id, rm.inherit_level, rm.is_system, rm.is_active,
		       rm.valid_from, rm.valid_to, rm.created_by, rm.created_at, rm.updated_at
		FROM composite_role_members crm
		INNER JOIN role_master rm ON rm.id = crm.child_role_id
		WHERE crm.composite_role_id = $1
		ORDER BY rm.role_id`, compositeRoleID)
	if err != nil {
		return nil, fmt.Errorf("list composite members: %w", err)
	}
	defer rows.Close()

	var roles []*models.RoleMaster
	for rows.Next() {
		role := &models.RoleMaster{}
		if err := rows.Scan(
			&role.ID, &role.TenantID, &role.RoleID, &role.Description,
			&role.RoleType, &role.RoleCategory,
			&role.ParentRoleID, &role.InheritLevel,
			&role.IsSystem, &role.IsActive,
			&role.ValidFrom, &role.ValidTo, &role.CreatedBy,
			&role.CreatedAt, &role.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan composite member: %w", err)
		}
		roles = append(roles, role)
	}
	return roles, nil
}

func (r *RoleRepo) AddCompositeMember(ctx context.Context, compositeRoleID, childRoleID uuid.UUID) error {
	if compositeRoleID == childRoleID {
		return fmt.Errorf("composite role cannot contain itself")
	}

	var wouldCycle bool
	err := r.db.QueryRow(ctx, `
		WITH RECURSIVE descendants(role_id) AS (
			SELECT child_role_id FROM composite_role_members WHERE composite_role_id = $1
			UNION
			SELECT crm.child_role_id
			FROM composite_role_members crm
			INNER JOIN descendants d ON crm.composite_role_id = d.role_id
		)
		SELECT EXISTS (SELECT 1 FROM descendants WHERE role_id = $2)`,
		childRoleID, compositeRoleID).Scan(&wouldCycle)
	if err != nil {
		return fmt.Errorf("check composite cycle: %w", err)
	}
	if wouldCycle {
		return fmt.Errorf("composite role cycle is not allowed")
	}

	_, err = r.db.Exec(ctx, `
		INSERT INTO composite_role_members (composite_role_id, child_role_id)
		VALUES ($1, $2)
		ON CONFLICT (composite_role_id, child_role_id) DO NOTHING`,
		compositeRoleID, childRoleID)
	if err != nil {
		return fmt.Errorf("add composite member: %w", err)
	}
	return nil
}

func (r *RoleRepo) RemoveCompositeMember(ctx context.Context, compositeRoleID, childRoleID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM composite_role_members WHERE composite_role_id=$1 AND child_role_id=$2`,
		compositeRoleID, childRoleID)
	return err
}

func (r *RoleRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM role_master WHERE id=$1 AND tenant_id=$2 AND is_system=false`,
		id, tenantID)
	return err
}

// GetEffectiveRoles returns all roles for a user including expanded composite/derived roles.
func (r *RoleRepo) GetEffectiveRoles(ctx context.Context, userID uuid.UUID) ([]*models.RoleMaster, error) {
	query := `
		WITH RECURSIVE direct_roles AS (
			SELECT rm.* FROM role_master rm
			INNER JOIN user_role_assignments ura ON ura.role_id = rm.id
			WHERE ura.user_id = $1 AND ura.is_active = true
			  AND (ura.valid_to IS NULL OR ura.valid_to > NOW())
		),
		role_tree AS (
			SELECT * FROM direct_roles
			UNION
			SELECT rm.* FROM role_master rm
			INNER JOIN composite_role_members crm ON crm.child_role_id = rm.id
			INNER JOIN role_tree rt ON rt.id = crm.composite_role_id
			WHERE rm.is_active = true
		),
		derived_base_roles AS (
			SELECT parent.* FROM role_master parent
			INNER JOIN role_tree child ON child.parent_role_id = parent.id
			WHERE child.role_type = 'derived' AND parent.is_active = true
		),
		all_roles AS (
			SELECT * FROM role_tree
			UNION
			SELECT * FROM derived_base_roles
		)
		SELECT DISTINCT id, tenant_id, role_id, COALESCE(description,''), role_type, COALESCE(role_category,''),
		       parent_role_id, inherit_level, is_system, is_active,
		       valid_from, valid_to, created_by, created_at, updated_at
		FROM all_roles WHERE is_active = true
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("get effective roles: %w", err)
	}
	defer rows.Close()

	var roles []*models.RoleMaster
	for rows.Next() {
		role := &models.RoleMaster{}
		if err := rows.Scan(
			&role.ID, &role.TenantID, &role.RoleID, &role.Description,
			&role.RoleType, &role.RoleCategory,
			&role.ParentRoleID, &role.InheritLevel,
			&role.IsSystem, &role.IsActive,
			&role.ValidFrom, &role.ValidTo, &role.CreatedBy,
			&role.CreatedAt, &role.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan effective role: %w", err)
		}
		roles = append(roles, role)
	}
	return roles, nil
}

// AssignRole assigns a role to a user.
func (r *RoleRepo) AssignRole(ctx context.Context, userID, roleID uuid.UUID, assignedBy *uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO user_role_assignments (user_id, role_id, assignment_type, assigned_by)
		 VALUES ($1, $2, 'direct', $3) ON CONFLICT (user_id, role_id)
		 DO UPDATE SET is_active=true, assigned_at=NOW()`,
		userID, roleID, assignedBy)
	return err
}

func (r *RoleRepo) RemoveRole(ctx context.Context, userID, roleID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM user_role_assignments WHERE user_id=$1 AND role_id=$2`,
		userID, roleID)
	return err
}
