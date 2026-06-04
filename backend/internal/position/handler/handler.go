package handler

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	pmodels "github.com/swiftai-erp/backend/internal/position/models"
	"github.com/swiftai-erp/backend/internal/position/repository"
	"github.com/swiftai-erp/backend/pkg/response"
)

type PositionHandler struct {
	repo *repository.PositionRepo
}

func NewPositionHandler(repo *repository.PositionRepo) *PositionHandler {
	return &PositionHandler{repo: repo}
}

func (h *PositionHandler) CreatePosition(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req pmodels.CreatePositionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
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
	var orgUnitID, parentPosID *uuid.UUID
	if req.OrgUnitID != "" {
		if parsed, err := uuid.Parse(req.OrgUnitID); err == nil {
			orgUnitID = &parsed
		}
	}
	if req.ParentPositionID != "" {
		if parsed, err := uuid.Parse(req.ParentPositionID); err == nil {
			parentPosID = &parsed
		}
	}
	now := time.Now()
	p := &pmodels.Position{
		ID:               uuid.New(),
		TenantID:         tenantID,
		PositionCode:     req.PositionCode,
		PositionTitle:    req.PositionTitle,
		OrgUnitID:        orgUnitID,
		ParentPositionID: parentPosID,
		IsActive:         isActive,
		ValidFrom:        validFrom,
		ValidTo:          req.ValidTo,
		CreatedAt:        now, UpdatedAt: now,
	}
	if err := h.repo.Create(c.Request.Context(), p); err != nil {
		log.Err(err).Msg("create position failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, p)
}

func (h *PositionHandler) ListPositions(c *gin.Context) {
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
			log.Err(err).Msg("list position tree failed")
			response.InternalError(c, "failed to list positions")
			return
		}
		response.OK(c, tree)
		return
	}
	list, err := h.repo.List(c.Request.Context(), tenantID, search)
	if err != nil {
		log.Err(err).Msg("list positions failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, list)
}

func (h *PositionHandler) GetPosition(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid position id")
		return
	}
	p, err := h.repo.GetByID(c.Request.Context(), id, tenantID)
	if err != nil {
		log.Err(err).Msg("get position failed")
		response.InternalError(c, "failed to get position")
		return
	}
	if p == nil {
		response.NotFound(c, "position not found")
		return
	}
	response.OK(c, p)
}

func (h *PositionHandler) UpdatePosition(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid position id")
		return
	}
	var req pmodels.UpdatePositionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	if req.OrgUnitID == "" {
		req.OrgUnitID = "__null__"
	}
	if req.ParentPositionID == "" {
		req.ParentPositionID = "__null__"
	}
	p, err := h.repo.Update(c.Request.Context(), id, tenantID, &req)
	if err != nil {
		log.Err(err).Msg("update position failed")
		response.InternalError(c, "failed to update position")
		return
	}
	if p == nil {
		response.NotFound(c, "position not found")
		return
	}
	response.OK(c, p)
}

func (h *PositionHandler) DeletePosition(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid position id")
		return
	}
	if err := h.repo.Delete(c.Request.Context(), id, tenantID); err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, gin.H{"message": "position deleted"})
}

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid := c.GetString("tenant_id")
	if tid == "" {
		return uuid.Nil, fmt.Errorf("missing tenant context")
	}
	return uuid.Parse(tid)
}
