package handler

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	oumodels "github.com/swiftai-erp/backend/internal/orgunit/models"
	"github.com/swiftai-erp/backend/internal/orgunit/repository"
	"github.com/swiftai-erp/backend/pkg/response"
)

type OrgUnitHandler struct {
	repo *repository.OrgUnitRepo
}

func NewOrgUnitHandler(repo *repository.OrgUnitRepo) *OrgUnitHandler {
	return &OrgUnitHandler{repo: repo}
}

// CreateOrgUnit handles POST /api/v1/org-units
func (h *OrgUnitHandler) CreateOrgUnit(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req oumodels.CreateOrgUnitRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	validFrom := req.ValidFrom
	if validFrom == "" {
		validFrom = time.Now().Format("2006-01-02")
	}

	var parentID *uuid.UUID
	if req.ParentID != "" {
		pid, err := uuid.Parse(req.ParentID)
		if err != nil {
			response.BadRequest(c, "invalid parent_id")
			return
		}
		parentID = &pid
	}

	now := time.Now()
	ou := &oumodels.OrgUnit{
		ID:           uuid.New(),
		TenantID:     tenantID,
		UnitCode:     req.UnitCode,
		UnitName:     req.UnitName,
		ParentID:     parentID,
		ManagerID:    req.ManagerID,
		CostCenterID: req.CostCenterID,
		IsActive:     isActive,
		ValidFrom:    validFrom,
		ValidTo:      req.ValidTo,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	if err := h.repo.Create(c.Request.Context(), ou); err != nil {
		log.Err(err).Msg("create org unit failed")
		response.InternalError(c, err.Error())
		return
	}

	response.Created(c, ou)
}

// ListOrgUnits handles GET /api/v1/org-units
func (h *OrgUnitHandler) ListOrgUnits(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	mode := c.DefaultQuery("mode", "list")
	search := c.Query("search")

	if mode == "tree" {
		tree, err := h.repo.ListTree(c.Request.Context(), tenantID)
		if err != nil {
			log.Err(err).Msg("list org unit tree failed")
			response.InternalError(c, "failed to list org unit tree")
			return
		}
		response.OK(c, tree)
		return
	}

	list, err := h.repo.List(c.Request.Context(), tenantID, search)
	if err != nil {
		log.Err(err).Msg("list org units failed")
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, list)
}

// GetOrgUnit handles GET /api/v1/org-units/:id
func (h *OrgUnitHandler) GetOrgUnit(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid org unit id")
		return
	}

	ou, err := h.repo.GetByID(c.Request.Context(), id, tenantID)
	if err != nil {
		log.Err(err).Msg("get org unit failed")
		response.InternalError(c, "failed to get org unit")
		return
	}
	if ou == nil {
		response.NotFound(c, "org unit not found")
		return
	}

	response.OK(c, ou)
}

// UpdateOrgUnit handles PUT /api/v1/org-units/:id
func (h *OrgUnitHandler) UpdateOrgUnit(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid org unit id")
		return
	}

	var req oumodels.UpdateOrgUnitRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	// Special sentinel for clearing parent_id
	if req.ParentID == "" {
		req.ParentID = "__null__"
	}

	ou, err := h.repo.Update(c.Request.Context(), id, tenantID, &req)
	if err != nil {
		log.Err(err).Msg("update org unit failed")
		response.InternalError(c, "failed to update org unit")
		return
	}
	if ou == nil {
		response.NotFound(c, "org unit not found")
		return
	}

	response.OK(c, ou)
}

// DeleteOrgUnit handles DELETE /api/v1/org-units/:id
func (h *OrgUnitHandler) DeleteOrgUnit(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid org unit id")
		return
	}

	if err := h.repo.Delete(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete org unit failed")
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, gin.H{"message": "org unit deleted"})
}

// ── Helpers ──

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tenantIDStr := c.GetString("tenant_id")
	if tenantIDStr == "" {
		return uuid.Nil, fmt.Errorf("missing tenant context")
	}
	return uuid.Parse(tenantIDStr)
}
