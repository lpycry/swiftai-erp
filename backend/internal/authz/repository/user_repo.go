package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	models "github.com/swiftai-erp/backend/internal/authz/models"
)

type UserRepo struct {
	db *pgxpool.Pool
}

func NewUserRepo(db *pgxpool.Pool) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) List(ctx context.Context, tenantID uuid.UUID, search, status string) ([]*models.AdminUser, error) {
	query := `
		SELECT id, tenant_id, email, display_name, COALESCE(phone,''), COALESCE(avatar_url,''),
		       is_active, is_mfa_enabled, last_login_at, created_at, updated_at
		FROM users
		WHERE tenant_id = $1`
	args := []interface{}{tenantID}

	if strings.TrimSpace(search) != "" {
		args = append(args, "%"+strings.ToLower(strings.TrimSpace(search))+"%")
		query += fmt.Sprintf(` AND (LOWER(email) LIKE $%d OR LOWER(display_name) LIKE $%d OR LOWER(COALESCE(phone,'')) LIKE $%d)`,
			len(args), len(args), len(args))
	}
	if status == "active" || status == "inactive" {
		args = append(args, status == "active")
		query += fmt.Sprintf(` AND is_active = $%d`, len(args))
	}
	query += ` ORDER BY is_active DESC, display_name, email`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list users: %w", err)
	}
	defer rows.Close()

	users := []*models.AdminUser{}
	for rows.Next() {
		user := &models.AdminUser{}
		if err := scanAdminUser(rows, user); err != nil {
			return nil, err
		}
		user.Roles, _ = r.ListRoles(ctx, user.ID)
		users = append(users, user)
	}
	return users, nil
}

func (r *UserRepo) Get(ctx context.Context, tenantID, userID uuid.UUID) (*models.AdminUser, error) {
	query := `
		SELECT id, tenant_id, email, display_name, COALESCE(phone,''), COALESCE(avatar_url,''),
		       is_active, is_mfa_enabled, last_login_at, created_at, updated_at
		FROM users
		WHERE tenant_id = $1 AND id = $2`
	user := &models.AdminUser{}
	err := r.db.QueryRow(ctx, query, tenantID, userID).Scan(
		&user.ID, &user.TenantID, &user.Email, &user.DisplayName, &user.Phone, &user.AvatarURL,
		&user.IsActive, &user.IsMFAEnabled, &user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get user: %w", err)
	}
	user.Roles, _ = r.ListRoles(ctx, user.ID)
	return user, nil
}

func (r *UserRepo) Create(ctx context.Context, user *models.AdminUser, passwordHash string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO users (id, tenant_id, email, password_hash, display_name, phone, avatar_url,
		                   is_active, is_mfa_enabled, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, NULLIF($6,''), NULLIF($7,''), $8, $9, $10, $11)`,
		user.ID, user.TenantID, strings.ToLower(strings.TrimSpace(user.Email)), passwordHash,
		user.DisplayName, user.Phone, user.AvatarURL, user.IsActive, user.IsMFAEnabled,
		user.CreatedAt, user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("create user: %w", err)
	}
	return nil
}

func (r *UserRepo) Update(ctx context.Context, tenantID uuid.UUID, user *models.AdminUser) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE users
		SET email = $1, display_name = $2, phone = NULLIF($3,''), avatar_url = NULLIF($4,''),
		    is_active = $5, is_mfa_enabled = $6, updated_at = NOW()
		WHERE tenant_id = $7 AND id = $8`,
		strings.ToLower(strings.TrimSpace(user.Email)), user.DisplayName, user.Phone, user.AvatarURL,
		user.IsActive, user.IsMFAEnabled, tenantID, user.ID)
	if err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *UserRepo) SetActive(ctx context.Context, tenantID, userID uuid.UUID, active bool) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE users SET is_active = $1, updated_at = NOW()
		WHERE tenant_id = $2 AND id = $3`, active, tenantID, userID)
	if err != nil {
		return fmt.Errorf("set user active: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *UserRepo) ResetPassword(ctx context.Context, tenantID, userID uuid.UUID, passwordHash string) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE users SET password_hash = $1, updated_at = NOW()
		WHERE tenant_id = $2 AND id = $3`, passwordHash, tenantID, userID)
	if err != nil {
		return fmt.Errorf("reset password: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *UserRepo) ListRoles(ctx context.Context, userID uuid.UUID) ([]models.RoleMaster, error) {
	rows, err := r.db.Query(ctx, `
		SELECT rm.id, rm.tenant_id, rm.role_id, COALESCE(rm.description,''), rm.role_type,
		       COALESCE(rm.role_category,''), rm.parent_role_id, rm.inherit_level,
		       rm.is_system, rm.is_active, rm.valid_from, rm.valid_to,
		       rm.created_by, rm.created_at, rm.updated_at
		FROM role_master rm
		INNER JOIN user_role_assignments ura ON ura.role_id = rm.id
		WHERE ura.user_id = $1 AND ura.is_active = true
		ORDER BY rm.role_id`, userID)
	if err != nil {
		return nil, fmt.Errorf("list user roles: %w", err)
	}
	defer rows.Close()

	roles := []models.RoleMaster{}
	for rows.Next() {
		role := models.RoleMaster{}
		if err := rows.Scan(
			&role.ID, &role.TenantID, &role.RoleID, &role.Description,
			&role.RoleType, &role.RoleCategory, &role.ParentRoleID, &role.InheritLevel,
			&role.IsSystem, &role.IsActive, &role.ValidFrom, &role.ValidTo,
			&role.CreatedBy, &role.CreatedAt, &role.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan user role: %w", err)
		}
		roles = append(roles, role)
	}
	return roles, nil
}

type adminUserScanner interface {
	Scan(dest ...interface{}) error
}

func scanAdminUser(row adminUserScanner, user *models.AdminUser) error {
	if err := row.Scan(
		&user.ID, &user.TenantID, &user.Email, &user.DisplayName, &user.Phone, &user.AvatarURL,
		&user.IsActive, &user.IsMFAEnabled, &user.LastLoginAt, &user.CreatedAt, &user.UpdatedAt,
	); err != nil {
		return fmt.Errorf("scan user: %w", err)
	}
	return nil
}

func NewAdminUser(tenantID uuid.UUID, email, displayName, phone string, active bool) *models.AdminUser {
	now := time.Now()
	return &models.AdminUser{
		ID:          uuid.New(),
		TenantID:    tenantID,
		Email:       email,
		DisplayName: displayName,
		Phone:       phone,
		IsActive:    active,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
}
