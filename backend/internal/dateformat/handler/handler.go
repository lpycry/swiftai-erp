package handler

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	dfmodels "github.com/swiftai-erp/backend/internal/dateformat/models"
	"github.com/swiftai-erp/backend/internal/dateformat/repository"
	"github.com/swiftai-erp/backend/pkg/response"
)

type DateFormatHandler struct {
	repo *repository.DateFormatRepo
}

func NewDateFormatHandler(repo *repository.DateFormatRepo) *DateFormatHandler {
	return &DateFormatHandler{repo: repo}
}

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid := c.GetString("tenant_id")
	if tid == "" { return uuid.Nil, fmt.Errorf("missing tenant context") }
	return uuid.Parse(tid)
}

func (h *DateFormatHandler) Create(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }

	var req dfmodels.CreateDateFormatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	isActive := true
	if req.IsActive != nil { isActive = *req.IsActive }
	if req.Separator == "" { req.Separator = "." }

	now := time.Now()
	df := &dfmodels.DateFormat{
		ID: uuid.New(), TenantID: tenantID,
		FormatCode: req.FormatCode, DisplayName: req.DisplayName,
		DatePattern: req.DatePattern, Separator: req.Separator,
		ExampleOutput: req.ExampleOutput, SortOrder: req.SortOrder,
		IsActive: isActive, CreatedAt: now, UpdatedAt: now,
	}
	if err := h.repo.Create(c.Request.Context(), df); err != nil {
		log.Err(err).Msg("create date format failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, df)
}

func (h *DateFormatHandler) List(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	list, err := h.repo.List(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list date formats failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, list)
}

func (h *DateFormatHandler) Get(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	df, err := h.repo.GetByID(c.Request.Context(), id, tenantID)
	if err != nil { response.InternalError(c, err.Error()); return }
	if df == nil { response.NotFound(c, "date format not found"); return }
	response.OK(c, df)
}

func (h *DateFormatHandler) Update(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	var req dfmodels.UpdateDateFormatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	df, err := h.repo.Update(c.Request.Context(), id, tenantID, &req)
	if err != nil { response.InternalError(c, err.Error()); return }
	if df == nil { response.NotFound(c, "date format not found"); return }
	response.OK(c, df)
}

func (h *DateFormatHandler) Delete(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	if err := h.repo.Delete(c.Request.Context(), id, tenantID); err != nil {
		response.InternalError(c, err.Error()); return
	}
	response.OK(c, gin.H{"message": "date format deleted"})
}
