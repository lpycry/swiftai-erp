package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"golang.org/x/crypto/bcrypt"

	"github.com/swiftai-erp/backend/internal/config"
	"github.com/swiftai-erp/backend/internal/models"
	jwtpkg "github.com/swiftai-erp/backend/pkg/jwt"
)

var (
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrEmailTaken         = errors.New("email already registered")
	ErrUserInactive       = errors.New("user account is inactive")
	ErrInvalidToken       = errors.New("invalid or expired token")
)

type Service struct {
	repo *Repository
	cfg  config.JWTConfig
}

func NewService(repo *Repository, cfg config.JWTConfig) *Service {
	return &Service{repo: repo, cfg: cfg}
}

// Register creates a new tenant and admin user.
func (s *Service) Register(ctx context.Context, req models.RegisterRequest) (*models.LoginResponse, error) {
	// Check if email already exists
	existing, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("check existing user: %w", err)
	}
	if existing != nil {
		return nil, ErrEmailTaken
	}

	// Hash password
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	now := time.Now()

	// Create tenant
	tenant := &models.Tenant{
		ID:        uuid.New(),
		Name:      req.CompanyName,
		Slug:      slugify(req.CompanyName),
		Plan:      "starter",
		IsActive:  true,
		Settings:  models.JSONB{},
		CreatedAt: now,
		UpdatedAt: now,
	}
	if err := s.repo.CreateTenant(ctx, tenant); err != nil {
		return nil, fmt.Errorf("create tenant: %w", err)
	}

	// Create default roles for tenant
	if err := s.repo.CreateDefaultRoles(ctx, tenant.ID); err != nil {
		log.Warn().Err(err).Msg("failed to create default roles, continuing")
	}

	// Create admin user
	user := &models.User{
		ID:           uuid.New(),
		TenantID:     tenant.ID,
		Email:        req.Email,
		PasswordHash: string(hashedBytes),
		DisplayName:  req.DisplayName,
		IsActive:     true,
		IsMFAEnabled: false,
		LastLoginAt:  &now,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	// Assign admin role
	if err := s.repo.AssignDefaultRole(ctx, user.ID, tenant.ID); err != nil {
		log.Warn().Err(err).Msg("failed to assign default role")
	}

	// Get roles for token
	roles, _ := s.repo.GetUserRoles(ctx, user.ID)

	// Generate tokens
	tokens, err := jwtpkg.GenerateTokenPair(s.cfg,
		user.ID.String(), tenant.ID.String(), user.Email, roles)
	if err != nil {
		return nil, fmt.Errorf("generate tokens: %w", err)
	}

	return &models.LoginResponse{
		TokenPair: models.TokenPair{
			AccessToken:  tokens.AccessToken,
			RefreshToken: tokens.RefreshToken,
			AccessExp:    int(tokens.AccessExp.Seconds()),
			RefreshExp:   int(tokens.RefreshExp.Seconds()),
			TokenType:    tokens.TokenType,
		},
		User: models.UserBrief{
			ID:          user.ID,
			Email:       user.Email,
			DisplayName: user.DisplayName,
			TenantID:    user.TenantID,
			Roles:       roles,
		},
	}, nil
}

// Login authenticates a user and returns tokens.
func (s *Service) Login(ctx context.Context, req models.LoginRequest) (*models.LoginResponse, error) {
	user, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}
	if user == nil {
		return nil, ErrInvalidCredentials
	}

	if !user.IsActive {
		return nil, ErrUserInactive
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	// Get roles
	roles, err := s.repo.GetUserRoles(ctx, user.ID)
	if err != nil {
		log.Warn().Err(err).Msg("failed to get user roles")
		roles = []string{}
	}

	// Generate tokens
	tokens, err := jwtpkg.GenerateTokenPair(s.cfg,
		user.ID.String(), user.TenantID.String(), user.Email, roles)
	if err != nil {
		return nil, fmt.Errorf("generate tokens: %w", err)
	}

	// Store refresh token
	for _, token := range []string{tokens.RefreshToken} {
		parsed, _ := jwtpkg.ValidateToken(s.cfg, token)
		if parsed != nil {
			_ = s.repo.StoreRefreshToken(ctx, user.ID.String(), parsed.ID)
		}
	}

	// Update last login
	_ = s.repo.UpdateLastLogin(ctx, user.ID)

	return &models.LoginResponse{
		TokenPair: models.TokenPair{
			AccessToken:  tokens.AccessToken,
			RefreshToken: tokens.RefreshToken,
			AccessExp:    int(tokens.AccessExp.Seconds()),
			RefreshExp:   int(tokens.RefreshExp.Seconds()),
			TokenType:    tokens.TokenType,
		},
		User: models.UserBrief{
			ID:          user.ID,
			Email:       user.Email,
			DisplayName: user.DisplayName,
			TenantID:    user.TenantID,
			Roles:       roles,
		},
	}, nil
}

// RefreshToken creates a new access token from a valid refresh token.
func (s *Service) RefreshToken(ctx context.Context, refreshToken string) (*models.TokenPair, error) {
	claims, err := jwtpkg.ValidateToken(s.cfg, refreshToken)
	if err != nil {
		return nil, ErrInvalidToken
	}

	// Verify refresh token exists in Redis
	userID, err := s.repo.ValidateRefreshToken(ctx, claims.ID)
	if err != nil || userID == "" {
		return nil, ErrInvalidToken
	}

	// Delete old refresh token
	_ = s.repo.DeleteRefreshToken(ctx, claims.ID)

	// Get user info
	uid := uuid.MustParse(claims.Subject)
	roles, _ := s.repo.GetUserRoles(ctx, uid)

	// Generate new token pair
	tokens, err := jwtpkg.GenerateTokenPair(s.cfg,
		claims.Subject, claims.TenantID, claims.Email, roles)
	if err != nil {
		return nil, fmt.Errorf("generate tokens: %w", err)
	}

	// Store new refresh token
	parsed, _ := jwtpkg.ValidateToken(s.cfg, tokens.RefreshToken)
	if parsed != nil {
		_ = s.repo.StoreRefreshToken(ctx, claims.Subject, parsed.ID)
	}

	return &models.TokenPair{
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		AccessExp:    int(tokens.AccessExp.Seconds()),
		RefreshExp:   int(tokens.RefreshExp.Seconds()),
		TokenType:    tokens.TokenType,
	}, nil
}

// ValidateToken validates a raw JWT string.
func (s *Service) ValidateToken(ctx context.Context, tokenStr string) (*jwtpkg.Claims, error) {
	return jwtpkg.ValidateToken(s.cfg, tokenStr)
}

func slugify(name string) string {
	// Simple slug: lowercase, replace spaces with hyphens, remove special chars
	slug := make([]byte, 0, len(name))
	for _, c := range []byte(name) {
		if c >= 'A' && c <= 'Z' {
			slug = append(slug, c+32)
		} else if c >= 'a' && c <= 'z' || c >= '0' && c <= '9' {
			slug = append(slug, c)
		} else if c == ' ' || c == '-' || c == '_' {
			if len(slug) > 0 && slug[len(slug)-1] != '-' {
				slug = append(slug, '-')
			}
		}
	}
	// Add unique suffix for uniqueness
	result := string(slug)
	if len(result) > 50 {
		result = result[:50]
	}
	result += "-" + uuid.New().String()[:8]
	return result
}
