package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog/log"
	"github.com/swiftai-erp/backend/internal/authz/engine"
	"github.com/swiftai-erp/backend/pkg/response"
)

// RequirePermission returns a middleware that checks a specific auth object + activity.
// Usage: r.POST("/path", RequirePermission(permEngine, "F_GL_POST", "create"), handler)
func RequirePermission(permEngine *engine.PermissionEngine, objectCode, activity string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString(ContextKeyUserID)
		if userID == "" {
			response.Unauthorized(c, "user context required")
			c.Abort()
			return
		}

		ok, err := permEngine.CheckSimple(c.Request.Context(), userID, objectCode, activity)
		if err != nil {
			log.Err(err).Str("user", userID).Str("object", objectCode).Str("activity", activity).
				Msg("permission check error")
			response.InternalError(c, "permission check failed")
			c.Abort()
			return
		}

		if !ok {
			response.Forbidden(c, "insufficient permissions: "+objectCode+"."+activity)
			c.Abort()
			return
		}

		c.Next()
	}
}

// RequireFieldPermission is a middleware for field-level permission checks.
// The fieldsProvider function extracts field values from the request context.
// Usage:
//
//	r.POST("/finance/journal", RequireFieldPermission(permEngine, "F_GL_POST", "create",
//	    func(c *gin.Context) map[string]string {
//	        return map[string]string{"company_code": c.PostForm("company")}
//	    }), handler)
func RequireFieldPermission(permEngine *engine.PermissionEngine, objectCode, activity string,
	fieldsProvider func(c *gin.Context) map[string]string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString(ContextKeyUserID)
		if userID == "" {
			response.Unauthorized(c, "user context required")
			c.Abort()
			return
		}

		fields := fieldsProvider(c)
		ok, err := permEngine.CheckField(c.Request.Context(), userID, objectCode, activity, fields)
		if err != nil {
			log.Err(err).Str("user", userID).Str("object", objectCode).
				Msg("field permission check error")
			response.InternalError(c, "permission check failed")
			c.Abort()
			return
		}

		if !ok {
			response.Forbidden(c, "insufficient permissions: "+objectCode+"."+activity)
			c.Abort()
			return
		}

		c.Next()
	}
}

// RequireOrgAccess checks org-unit-level access using user's org hierarchy.
func RequireOrgAccess(permEngine *engine.PermissionEngine, objectCode, activity string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString(ContextKeyUserID)
		if userID == "" {
			response.Unauthorized(c, "user context required")
			c.Abort()
			return
		}

		// Simple check without org field for now
		ok, err := permEngine.CheckSimple(c.Request.Context(), userID, objectCode, activity)
		if err != nil {
			log.Err(err).Str("user", userID).Msg("org access check error")
			response.InternalError(c, "permission check failed")
			c.Abort()
			return
		}

		if !ok {
			response.Forbidden(c, "no access to this resource")
			c.Abort()
			return
		}

		c.Next()
	}
}
