package middleware

import (
	"github.com/gin-gonic/gin"
)

const ContextKeyOrgID = "organization_id"

// ProxyContext reads forwarded headers from the API gateway
// and sets them as Gin context values for downstream handlers.
// This allows the auth-service handlers to use c.GetString("tenant_id")
// even when proxied through the gateway.
func ProxyContext() gin.HandlerFunc {
	return func(c *gin.Context) {
		// X-Tenant-Id header is set by the gateway after JWT validation
		if tid := c.GetHeader("X-Tenant-Id"); tid != "" {
			c.Set(ContextKeyTenantID, tid)
		}
		if uid := c.GetHeader("X-User-Id"); uid != "" {
			c.Set(ContextKeyUserID, uid)
		}
		if email := c.GetHeader("X-Email"); email != "" {
			c.Set(ContextKeyEmail, email)
		}
		if oid := c.GetHeader("X-Org-Id"); oid != "" {
			c.Set(ContextKeyOrgID, oid)
		}
		c.Next()
	}
}
