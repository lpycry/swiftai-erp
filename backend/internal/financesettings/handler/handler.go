package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	fsmodels "github.com/swiftai-erp/backend/internal/financesettings/models"
	fssvc "github.com/swiftai-erp/backend/internal/financesettings/service"
	"github.com/swiftai-erp/backend/pkg/response"
)

type FinanceSettingsHandler struct {
	svc *fssvc.FinanceSettingsService
}

func NewFinanceSettingsHandler(svc *fssvc.FinanceSettingsService) *FinanceSettingsHandler {
	return &FinanceSettingsHandler{svc: svc}
}

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid := c.GetString("tenant_id")
	if tid == "" {
		return uuid.Nil, nil
	}
	return uuid.Parse(tid)
}

// ══════════════════════════════════════════
//  PAYMENT TERMS
// ══════════════════════════════════════════

func (h *FinanceSettingsHandler) ListPaymentTerms(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	list, err := h.svc.ListPaymentTerms(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list payment terms failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *FinanceSettingsHandler) CreatePaymentTerm(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	var req fsmodels.CreatePaymentTermRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	pt, err := h.svc.CreatePaymentTerm(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create payment term failed")
		response.InternalError(c, "create failed")
		return
	}
	response.Created(c, pt)
}

func (h *FinanceSettingsHandler) UpdatePaymentTerm(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	var req fsmodels.UpdatePaymentTermRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdatePaymentTerm(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update payment term failed")
		response.InternalError(c, "update failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *FinanceSettingsHandler) DeletePaymentTerm(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	if err := h.svc.DeletePaymentTerm(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete payment term failed")
		errMsg := err.Error()
		if errMsg == "payment term not found or is a standard term — standard terms cannot be deleted" {
			response.BadRequest(c, errMsg)
		} else {
			response.InternalError(c, "delete failed")
		}
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════
//  INCOTERMS
// ══════════════════════════════════════════

func (h *FinanceSettingsHandler) ListIncoterms(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	list, err := h.svc.ListIncoterms(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list incoterms failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *FinanceSettingsHandler) CreateIncoterm(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	var req fsmodels.CreateIncotermRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	inc, err := h.svc.CreateIncoterm(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create incoterm failed")
		response.InternalError(c, "create failed")
		return
	}
	response.Created(c, inc)
}

func (h *FinanceSettingsHandler) UpdateIncoterm(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	var req fsmodels.UpdateIncotermRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateIncoterm(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update incoterm failed")
		response.InternalError(c, "update failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *FinanceSettingsHandler) DeleteIncoterm(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	if err := h.svc.DeleteIncoterm(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete incoterm failed")
		response.InternalError(c, "delete failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════
//  ORG RECONCILIATION ACCOUNTS
// ══════════════════════════════════════════

func (h *FinanceSettingsHandler) ListOrgReconAccounts(c *gin.Context) {
	orgIDStr := c.Query("org_id")
	var orgID uuid.UUID
	if orgIDStr != "" {
		orgID, _ = uuid.Parse(orgIDStr)
	}
	list, err := h.svc.ListOrgReconAccounts(c.Request.Context(), orgID)
	if err != nil {
		log.Err(err).Msg("list org recon accounts failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *FinanceSettingsHandler) CreateOrgReconAccount(c *gin.Context) {
	var req fsmodels.CreateOrgReconAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	ra, err := h.svc.CreateOrgReconAccount(c.Request.Context(), &req)
	if err != nil {
		log.Err(err).Msg("create org recon account failed")
		response.InternalError(c, "create failed")
		return
	}
	response.Created(c, ra)
}

func (h *FinanceSettingsHandler) UpdateOrgReconAccount(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	var req fsmodels.CreateOrgReconAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	ra, err := h.svc.UpdateOrgReconAccount(c.Request.Context(), id, &req)
	if err != nil {
		log.Err(err).Msg("update org recon account failed")
		response.InternalError(c, "update failed")
		return
	}
	response.OK(c, ra)
}

func (h *FinanceSettingsHandler) DeleteOrgReconAccount(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid id"); return }
	if err := h.svc.DeleteOrgReconAccount(c.Request.Context(), id); err != nil {
		log.Err(err).Msg("delete org recon account failed")
		response.InternalError(c, "delete failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}
