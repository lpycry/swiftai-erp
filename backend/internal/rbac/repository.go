package rbac

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/swiftai-erp/backend/internal/models"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) CreateRole(ctx context.Context, role *models.Role) error {
	query := `
		INSERT INTO roles (id, tenant_id, name, description, is_system, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.db.Exec(ctx, query,
		role.ID, role.TenantID, role.Name, role.Description,
		role.IsSystem, role.CreatedAt, role.UpdatedAt)
	return err
}

func (r *Repository) ListRoles(ctx context.Context, tenantID uuid.UUID) ([]*models.Role, error) {
	query := `SELECT id, tenant_id, name, description, is_system, created_at, updated_at
		FROM roles WHERE tenant_id = $1 ORDER BY name`
	rows, err := r.db.Query(ctx, query, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var roles []*models.Role
	for rows.Next() {
		role := &models.Role{}
		if err := rows.Scan(&role.ID, &role.TenantID, &role.Name, &role.Description,
			&role.IsSystem, &role.CreatedAt, &role.UpdatedAt); err != nil {
			return nil, err
		}
		roles = append(roles, role)
	}
	return roles, nil
}

func (r *Repository) UpdateRole(ctx context.Context, role *models.Role) error {
	query := `UPDATE roles SET name=$1, description=$2, updated_at=$3 WHERE id=$4 AND tenant_id=$5 AND is_system=false`
	_, err := r.db.Exec(ctx, query, role.Name, role.Description, time.Now(), role.ID, role.TenantID)
	return err
}

func (r *Repository) DeleteRole(ctx context.Context, roleID, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM roles WHERE id=$1 AND tenant_id=$2 AND is_system=false`, roleID, tenantID)
	return err
}

func (r *Repository) AssignRole(ctx context.Context, userID, roleID, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)
		 ON CONFLICT DO NOTHING`, userID, roleID)
	return err
}

func (r *Repository) RemoveRole(ctx context.Context, userID, roleID, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM user_roles WHERE user_id=$1 AND role_id=$2`, userID, roleID)
	return err
}

func (r *Repository) GetUserPermissions(ctx context.Context, userID uuid.UUID) ([]*models.Permission, error) {
	query := `
		SELECT DISTINCT p.id, p.code, p.name, p.module, p.action, p.description
		FROM permissions p
		INNER JOIN role_permissions rp ON rp.permission_id = p.id
		INNER JOIN user_roles ur ON ur.role_id = rp.role_id
		WHERE ur.user_id = $1
		ORDER BY p.module, p.code
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var perms []*models.Permission
	for rows.Next() {
		p := &models.Permission{}
		if err := rows.Scan(&p.ID, &p.Code, &p.Name, &p.Module, &p.Action, &p.Description); err != nil {
			return nil, err
		}
		perms = append(perms, p)
	}
	return perms, nil
}

func (r *Repository) SeedPermissions(ctx context.Context) error {
	permissions := []models.Permission{
		// Finance
		{ID: uuid.New(), Code: "finance:gl:read", Name: "Read GL", Module: "finance", Action: "read", Description: "View general ledger entries"},
		{ID: uuid.New(), Code: "finance:gl:write", Name: "Write GL", Module: "finance", Action: "write", Description: "Create journal entries"},
		{ID: uuid.New(), Code: "finance:ap:read", Name: "Read AP", Module: "finance", Action: "read", Description: "View accounts payable"},
		{ID: uuid.New(), Code: "finance:ap:write", Name: "Write AP", Module: "finance", Action: "write", Description: "Manage accounts payable"},
		{ID: uuid.New(), Code: "finance:ar:read", Name: "Read AR", Module: "finance", Action: "read", Description: "View accounts receivable"},
		{ID: uuid.New(), Code: "finance:ar:write", Name: "Write AR", Module: "finance", Action: "write", Description: "Manage accounts receivable"},
		{ID: uuid.New(), Code: "finance:report:read", Name: "Read Reports", Module: "finance", Action: "read", Description: "View financial reports"},

		// Logistics
		{ID: uuid.New(), Code: "logistics:warehouse:read", Name: "Read Warehouse", Module: "logistics", Action: "read", Description: "View warehouse data"},
		{ID: uuid.New(), Code: "logistics:warehouse:write", Name: "Write Warehouse", Module: "logistics", Action: "write", Description: "Manage warehouse operations"},

		// Procurement
		{ID: uuid.New(), Code: "procurement:po:read", Name: "Read PO", Module: "procurement", Action: "read", Description: "View purchase orders"},
		{ID: uuid.New(), Code: "procurement:po:write", Name: "Write PO", Module: "procurement", Action: "write", Description: "Manage purchase orders"},

		// Sales
		{ID: uuid.New(), Code: "sales:order:read", Name: "Read Orders", Module: "sales", Action: "read", Description: "View sales orders"},
		{ID: uuid.New(), Code: "sales:order:write", Name: "Write Orders", Module: "sales", Action: "write", Description: "Manage sales orders"},

		// Admin
		{ID: uuid.New(), Code: "admin:users:manage", Name: "Manage Users", Module: "admin", Action: "manage", Description: "Manage users"},
		{ID: uuid.New(), Code: "admin:roles:manage", Name: "Manage Roles", Module: "admin", Action: "manage", Description: "Manage roles and permissions"},
		{ID: uuid.New(), Code: "admin:tenant:manage", Name: "Manage Tenant", Module: "admin", Action: "manage", Description: "Manage tenant settings"},
	}

	for _, p := range permissions {
		_, err := r.db.Exec(ctx,
			`INSERT INTO permissions (id, code, name, module, action, description)
			 VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (code) DO NOTHING`,
			p.ID, p.Code, p.Name, p.Module, p.Action, p.Description)
		if err != nil {
			return fmt.Errorf("seed permission %s: %w", p.Code, err)
		}
	}
	return nil
}

func (r *Repository) AssignPermissionToRole(ctx context.Context, roleID, permissionID, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		roleID, permissionID)
	return err
}

func (r *Repository) RemovePermissionFromRole(ctx context.Context, roleID, permissionID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM role_permissions WHERE role_id=$1 AND permission_id=$2`,
		roleID, permissionID)
	return err
}
