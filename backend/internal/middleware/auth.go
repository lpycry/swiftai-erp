package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/swiftai-erp/backend/internal/config"
	jwtpkg "github.com/swiftai-erp/backend/pkg/jwt"
	"github.com/swiftai-erp/backend/pkg/response"
)

const (
	ContextKeyUserID   = "user_id"
	ContextKeyTenantID = "tenant_id"
	ContextKeyEmail    = "email"
	ContextKeyRoles    = "roles"
)

// AuthRequired validates JWT in Authorization header.
func AuthRequired(cfg config.JWTConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.Unauthorized(c, "missing authorization header")
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			response.Unauthorized(c, "invalid authorization format, expected: Bearer <token>")
			c.Abort()
			return
		}

		claims, err := jwtpkg.ValidateToken(cfg, parts[1])
		if err != nil {
			response.Unauthorized(c, "invalid or expired token")
			c.Abort()
			return
		}

		c.Set(ContextKeyUserID, claims.UserID)
		c.Set(ContextKeyTenantID, claims.TenantID)
		c.Set(ContextKeyEmail, claims.Email)
		c.Set(ContextKeyRoles, claims.Roles)
		c.Next()
	}
}

// TenantRequired ensures tenant context is available.
func TenantRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		tenantID := c.GetString(ContextKeyTenantID)
		if tenantID == "" {
			response.Forbidden(c, "tenant context required")
			c.Abort()
			return
		}
		c.Next()
	}
}

// CORS handles Cross-Origin Resource Sharing.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization, X-Tenant-ID")
		c.Header("Access-Control-Expose-Headers", "X-Request-ID")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
