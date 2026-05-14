package rbac

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/swiftai-erp/backend/internal/models"
	"github.com/swiftai-erp/backend/pkg/response"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

// ListRoles handles GET /api/v1/roles
func (h *Handler) ListRoles(c *gin.Context) {
	tenantID := c.GetString("tenant_id")
	roles, err := h.repo.ListRoles(c.Request.Context(), uuid.MustParse(tenantID))
	if err != nil {
		response.InternalError(c, "failed to list roles")
		return
	}
	response.OK(c, roles)
}

// CreateRole handles POST /api/v1/roles
type createRoleReq struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
}

func (h *Handler) CreateRole(c *gin.Context) {
	var req createRoleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	role := &models.Role{
		ID:          uuid.New(),
		TenantID:    uuid.MustParse(c.GetString("tenant_id")),
		Name:        req.Name,
		Description: req.Description,
	}

	if err := h.repo.CreateRole(c.Request.Context(), role); err != nil {
		response.InternalError(c, "failed to create role")
		return
	}
	response.Created(c, role)
}

// AssignUserRole handles POST /api/v1/roles/assign
type assignRoleReq struct {
	UserID string `json:"user_id" binding:"required"`
	RoleID string `json:"role_id" binding:"required"`
}

func (h *Handler) AssignUserRole(c *gin.Context) {
	var req assignRoleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	tenantID := uuid.MustParse(c.GetString("tenant_id"))
	if err := h.repo.AssignRole(c.Request.Context(),
		uuid.MustParse(req.UserID), uuid.MustParse(req.RoleID), tenantID); err != nil {
		response.InternalError(c, "failed to assign role")
		return
	}
	response.OK(c, gin.H{"message": "role assigned"})
}

// GetUserPermissions handles GET /api/v1/users/:id/permissions
func (h *Handler) GetUserPermissions(c *gin.Context) {
	userID := c.Param("id")
	perms, err := h.repo.GetUserPermissions(c.Request.Context(), uuid.MustParse(userID))
	if err != nil {
		response.InternalError(c, "failed to get permissions")
		return
	}
	response.OK(c, perms)
}
