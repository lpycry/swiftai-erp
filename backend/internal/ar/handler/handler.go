package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	armodels "github.com/swiftai-erp/backend/internal/ar/models"
	arsvc "github.com/swiftai-erp/backend/internal/ar/service"
	"github.com/swiftai-erp/backend/pkg/response"
)

type ARHandler struct {
	svc *arsvc.ARService
}

func NewARHandler(svc *arsvc.ARService) *ARHandler {
	return &ARHandler{svc: svc}
}

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid := c.GetString("tenant_id")
	if tid == "" { return uuid.Nil, nil }
	return uuid.Parse(tid)
}

func getUserID(c *gin.Context) (uuid.UUID, error) {
	uid := c.GetString("user_id")
	if uid == "" { return uuid.Nil, nil }
	return uuid.Parse(uid)
}

// ══════════════════════════════════════════
//  CREDIT LIMITS
// ══════════════════════════════════════════

func (h *ARHandler) ListCreditLimits(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	list, err := h.svc.ListCreditLimits(c.Request.Context(), tid)
	if err != nil { log.Err(err).Msg("list credit limits failed"); response.InternalError(c, "list failed"); return }
	response.OK(c, list)
}

func (h *ARHandler) GetCreditLimit(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	cl, err := h.svc.GetCreditLimit(c.Request.Context(), id, tid)
	if err != nil { response.NotFound(c, "not found"); return }
	response.OK(c, cl)
}

func (h *ARHandler) CreateCreditLimit(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	var req armodels.CreateCreditLimitRequest
	if err := c.ShouldBindJSON(&req); err != nil { response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()}); return }
	cl, err := h.svc.CreateCreditLimit(c.Request.Context(), tid, &req)
	if err != nil { log.Err(err).Msg("create credit limit failed"); response.InternalError(c, err.Error()); return }
	response.Created(c, cl)
}

func (h *ARHandler) UpdateCreditLimit(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	var req armodels.UpdateCreditLimitRequest
	if err := c.ShouldBindJSON(&req); err != nil { response.BadRequest(c, "invalid request"); return }
	if err := h.svc.UpdateCreditLimit(c.Request.Context(), id, tid, &req); err != nil { log.Err(err).Msg("update failed"); response.InternalError(c, "update failed"); return }
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ARHandler) DeleteCreditLimit(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	if err := h.svc.DeleteCreditLimit(c.Request.Context(), id, tid); err != nil { log.Err(err).Msg("delete failed"); response.InternalError(c, "delete failed"); return }
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════
//  CUSTOMER DOWN PAYMENTS
// ══════════════════════════════════════════

func (h *ARHandler) ListDownPayments(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	list, err := h.svc.ListDownPayments(c.Request.Context(), tid)
	if err != nil { log.Err(err).Msg("list dps failed"); response.InternalError(c, "list failed"); return }
	response.OK(c, list)
}

func (h *ARHandler) GetDownPayment(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	dp, err := h.svc.GetDownPayment(c.Request.Context(), id, tid)
	if err != nil { response.NotFound(c, "not found"); return }
	response.OK(c, dp)
}

func (h *ARHandler) CreateDownPayment(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	userID, _ := getUserID(c)
	var req armodels.CreateCustomerDownPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil { response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()}); return }
	dp, err := h.svc.CreateDownPayment(c.Request.Context(), tid, &req, &userID)
	if err != nil { log.Err(err).Msg("create dp failed"); response.InternalError(c, err.Error()); return }
	response.Created(c, dp)
}
