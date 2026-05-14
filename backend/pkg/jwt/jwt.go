package jwt

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/swiftai-erp/backend/internal/config"
)

// Claims represents JWT claims with user context.
type Claims struct {
	UserID    string   `json:"user_id"`
	TenantID  string   `json:"tenant_id"`
	Email     string   `json:"email"`
	Roles     []string `json:"roles"`
	jwt.RegisteredClaims
}

// TokenPair contains both access and refresh tokens.
type TokenPair struct {
	AccessToken  string        `json:"access_token"`
	RefreshToken string        `json:"refresh_token"`
	AccessExp    time.Duration `json:"access_expires_in"`
	RefreshExp   time.Duration `json:"refresh_expires_in"`
	TokenType    string        `json:"token_type"`
}

// GenerateTokenPair creates access and refresh tokens for a user.
func GenerateTokenPair(cfg config.JWTConfig, userID, tenantID, email string, roles []string) (*TokenPair, error) {
	now := time.Now()

	// Access token
	accessClaims := Claims{
		UserID:   userID,
		TenantID: tenantID,
		Email:    email,
		Roles:    roles,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    cfg.Issuer,
			Subject:   userID,
			Audience:  jwt.ClaimStrings{"swiftai-erp"},
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(cfg.AccessTTL)),
			ID:        fmt.Sprintf("acc-%s-%d", userID, now.UnixNano()),
		},
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessStr, err := accessToken.SignedString([]byte(cfg.Secret))
	if err != nil {
		return nil, fmt.Errorf("sign access token: %w", err)
	}

	// Refresh token
	refreshClaims := jwt.RegisteredClaims{
		Issuer:    cfg.Issuer,
		Subject:   userID,
		Audience:  jwt.ClaimStrings{"swiftai-erp"},
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(cfg.RefreshTTL)),
		ID:        fmt.Sprintf("ref-%s-%d", userID, now.UnixNano()),
	}

	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshStr, err := refreshToken.SignedString([]byte(cfg.Secret))
	if err != nil {
		return nil, fmt.Errorf("sign refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessStr,
		RefreshToken: refreshStr,
		AccessExp:    cfg.AccessTTL,
		RefreshExp:   cfg.RefreshTTL,
		TokenType:    "Bearer",
	}, nil
}

// ValidateToken parses and validates a JWT token string.
func ValidateToken(cfg config.JWTConfig, tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(cfg.Secret), nil
	})
	if err != nil {
		return nil, fmt.Errorf("parse token: %w", err)
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}

	return claims, nil
}
