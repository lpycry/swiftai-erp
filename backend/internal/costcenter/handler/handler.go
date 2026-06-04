package handler

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	ccmodels "github.com/swiftai-erp/backend/internal/costcenter/models"
	"github.com/swiftai-erp/backend/internal/costcenter/repository"
	"github.com/swiftai-erp/backend/pkg/response"
)

type CostCenterHandler struct {
	repo *repository.CostCenterRepo
}

func NewCostCenterHandler(repo *repository.CostCenterRepo) *CostCenterHandler {
	return &CostCenterHandler{repo: repo}
}

// CreateCostCenter handles POST /api/v1/cost-centers
func (h *CostCenterHandler) CreateCostCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req ccmodels.CreateCostCenterRequest
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

	now := time.Now()
	cc := &ccmodels.CostCenter{
		ID:             uuid.New(),
		TenantID:       tenantID,
		CostCenterID:   req.CostCenterID,
		Description:    req.Description,
		CostCenterType: req.CostCenterType,
		IsActive:       isActive,
		ValidFrom:      validFrom,
		ValidTo:        req.ValidTo,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := h.repo.Create(c.Request.Context(), cc); err != nil {
		log.Err(err).Msg("create cost center failed")
		response.InternalError(c, err.Error())
		return
	}

	response.Created(c, cc)
}

// ListCostCenters handles GET /api/v1/cost-centers
func (h *CostCenterHandler) ListCostCenters(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	search := c.Query("search")
	list, err := h.repo.List(c.Request.Context(), tenantID, search)
	if err != nil {
		log.Err(err).Msg("list cost centers failed")
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, list)
}

// GetCostCenter handles GET /api/v1/cost-centers/:id
func (h *CostCenterHandler) GetCostCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	ccID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid cost center id")
		return
	}

	cc, err := h.repo.GetByID(c.Request.Context(), ccID, tenantID)
	if err != nil {
		log.Err(err).Msg("get cost center failed")
		response.InternalError(c, "failed to get cost center")
		return
	}
	if cc == nil {
		response.NotFound(c, "cost center not found")
		return
	}

	response.OK(c, cc)
}

// UpdateCostCenter handles PUT /api/v1/cost-centers/:id
func (h *CostCenterHandler) UpdateCostCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	ccID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid cost center id")
		return
	}

	var req ccmodels.UpdateCostCenterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	cc, err := h.repo.Update(c.Request.Context(), ccID, tenantID, &req)
	if err != nil {
		log.Err(err).Msg("update cost center failed")
		response.InternalError(c, "failed to update cost center")
		return
	}
	if cc == nil {
		response.NotFound(c, "cost center not found")
		return
	}

	response.OK(c, cc)
}

// DeleteCostCenter handles DELETE /api/v1/cost-centers/:id
func (h *CostCenterHandler) DeleteCostCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	ccID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid cost center id")
		return
	}

	if err := h.repo.Delete(c.Request.Context(), ccID, tenantID); err != nil {
		log.Err(err).Msg("delete cost center failed")
		response.InternalError(c, "failed to delete cost center")
		return
	}

	response.OK(c, gin.H{"message": "cost center deleted"})
}

// ── Helpers ──

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tenantIDStr := c.GetString("tenant_id")
	if tenantIDStr == "" {
		return uuid.Nil, fmt.Errorf("missing tenant context")
	}
	return uuid.Parse(tenantIDStr)
}
