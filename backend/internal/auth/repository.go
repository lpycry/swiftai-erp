package auth

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
	"github.com/swiftai-erp/backend/internal/models"
)

const (
	refreshTokenPrefix = "refresh_token:"
	refreshTokenTTL    = 7 * 24 * time.Hour
)

type Repository struct {
	db  *pgxpool.Pool
	rdb *redis.Client
}

func NewRepository(db *pgxpool.Pool, rdb *redis.Client) *Repository {
	return &Repository{db: db, rdb: rdb}
}

func (r *Repository) CreateTenant(ctx context.Context, tenant *models.Tenant) error {
	query := `
		INSERT INTO tenants (id, name, slug, domain, plan, is_active, settings, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	_, err := r.db.Exec(ctx, query,
		tenant.ID, tenant.Name, tenant.Slug, tenant.Domain,
		tenant.Plan, tenant.IsActive, tenant.Settings,
		tenant.CreatedAt, tenant.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create tenant: %w", err)
	}
	return nil
}

func (r *Repository) CreateUser(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (id, tenant_id, email, password_hash, display_name, phone, avatar_url,
		                   is_active, is_mfa_enabled, last_login_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err := r.db.Exec(ctx, query,
		user.ID, user.TenantID, user.Email, user.PasswordHash,
		user.DisplayName, user.Phone, user.AvatarURL,
		user.IsActive, user.IsMFAEnabled, user.LastLoginAt,
		user.CreatedAt, user.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create user: %w", err)
	}
	return nil
}

func (r *Repository) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	query := `
		SELECT id, tenant_id, email, password_hash, display_name, COALESCE(phone,''), COALESCE(avatar_url,''),
		       is_active, is_mfa_enabled, last_login_at, created_at, updated_at
		FROM users WHERE email = $1
	`
	user := &models.User{}
	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID, &user.TenantID, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.Phone, &user.AvatarURL,
		&user.IsActive, &user.IsMFAEnabled, &user.LastLoginAt,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get user by email: %w", err)
	}
	return user, nil
}

func (r *Repository) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, tenant_id, email, password_hash, display_name, COALESCE(phone,''), COALESCE(avatar_url,''),
		       is_active, is_mfa_enabled, last_login_at, created_at, updated_at
		FROM users WHERE id = $1
	`
	user := &models.User{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID, &user.TenantID, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.Phone, &user.AvatarURL,
		&user.IsActive, &user.IsMFAEnabled, &user.LastLoginAt,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get user by id: %w", err)
	}
	return user, nil
}

func (r *Repository) GetUserRoles(ctx context.Context, userID uuid.UUID) ([]string, error) {
	query := `
		SELECT r.name FROM roles r
		INNER JOIN user_roles ur ON ur.role_id = r.id
		WHERE ur.user_id = $1 AND r.tenant_id = (
			SELECT tenant_id FROM users WHERE id = $1
		)
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("get user roles: %w", err)
	}
	defer rows.Close()

	var roles []string
	for rows.Next() {
		var role string
		if err := rows.Scan(&role); err != nil {
			return nil, fmt.Errorf("scan role: %w", err)
		}
		roles = append(roles, role)
	}
	return roles, nil
}

func (r *Repository) AssignRoleByName(ctx context.Context, userID, tenantID uuid.UUID, roleName string) error {
	var roleID uuid.UUID
	err := r.db.QueryRow(ctx,
		"SELECT id FROM roles WHERE tenant_id = $1 AND name = $2",
		tenantID, roleName,
	).Scan(&roleID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("role %s not found", roleName)
		}
		return fmt.Errorf("find role %s: %w", roleName, err)
	}
	_, err = r.db.Exec(ctx,
		"INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
		userID, roleID)
	return err
}

func (r *Repository) IsFirstTenantUser(ctx context.Context, userID, tenantID uuid.UUID) (bool, error) {
	var firstID uuid.UUID
	err := r.db.QueryRow(ctx,
		`SELECT id FROM users
		 WHERE tenant_id = $1
		 ORDER BY created_at ASC, id ASC
		 LIMIT 1`,
		tenantID,
	).Scan(&firstID)
	if err != nil {
		return false, fmt.Errorf("find first tenant user: %w", err)
	}
	return firstID == userID, nil
}

func (r *Repository) StoreRefreshToken(ctx context.Context, userID string, tokenID string) error {
	key := refreshTokenPrefix + tokenID
	return r.rdb.Set(ctx, key, userID, refreshTokenTTL).Err()
}

func (r *Repository) ValidateRefreshToken(ctx context.Context, tokenID string) (string, error) {
	key := refreshTokenPrefix + tokenID
	val, err := r.rdb.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return "", nil
		}
		return "", err
	}
	return val, nil
}

func (r *Repository) DeleteRefreshToken(ctx context.Context, tokenID string) error {
	key := refreshTokenPrefix + tokenID
	return r.rdb.Del(ctx, key).Err()
}

func (r *Repository) UpdateLastLogin(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "UPDATE users SET last_login_at = $1 WHERE id = $2", time.Now(), userID)
	return err
}

// AssignDefaultRole gives a user the default "user" role in their tenant.
func (r *Repository) AssignDefaultRole(ctx context.Context, userID, tenantID uuid.UUID) error {
	// Find the default role for this tenant
	var roleID uuid.UUID
	err := r.db.QueryRow(ctx,
		"SELECT id FROM roles WHERE tenant_id = $1 AND name = 'user' AND is_system = true", tenantID,
	).Scan(&roleID)
	if err != nil {
		// Create the default role if it doesn't exist
		roleID = uuid.New()
		now := time.Now()
		_, err = r.db.Exec(ctx,
			`INSERT INTO roles (id, tenant_id, name, description, is_system, created_at, updated_at)
			 VALUES ($1, $2, 'user', 'Default user role', true, $3, $4)`,
			roleID, tenantID, now, now)
		if err != nil {
			return fmt.Errorf("create default role: %w", err)
		}
	}

	_, err = r.db.Exec(ctx,
		"INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
		userID, roleID)
	if err != nil {
		return fmt.Errorf("assign default role: %w", err)
	}
	return nil
}

// CreateDefaultRoles creates system roles for a new tenant.
func (r *Repository) CreateDefaultRoles(ctx context.Context, tenantID uuid.UUID) error {
	now := time.Now()
	roles := []struct {
		Name        string
		Description string
	}{
		{"admin", "System administrator with full access"},
		{"user", "Standard user with assigned permissions"},
		{"viewer", "Read-only access to assigned modules"},
		{"accountant", "Finance module access"},
		{"warehouse", "Logistics and warehouse access"},
	}

	for _, role := range roles {
		_, err := r.db.Exec(ctx,
			`INSERT INTO roles (id, tenant_id, name, description, is_system, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, true, $5, $6) ON CONFLICT (tenant_id, name) DO NOTHING`,
			uuid.New(), tenantID, role.Name, role.Description, now, now)
		if err != nil {
			log.Warn().Err(err).Str("role", role.Name).Msg("failed to create default role")
		}
	}
	return nil
}
