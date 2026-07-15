package handler

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	prodmodels "github.com/swiftai-erp/backend/internal/production/models"
	prodsvc "github.com/swiftai-erp/backend/internal/production/service"
	"github.com/swiftai-erp/backend/pkg/response"
)

type ProductionHandler struct {
	svc *prodsvc.ProductionService
}

func NewProductionHandler(svc *prodsvc.ProductionService) *ProductionHandler {
	return &ProductionHandler{svc: svc}
}

// ═══════════════════════════════════════════════════════════════
// BOM CRUD
// ═══════════════════════════════════════════════════════════════

func (h *ProductionHandler) CreateBOM(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}

	var req prodmodels.CreateBOMRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	bom, err := h.svc.CreateBOM(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create BOM failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, bom)
}

func (h *ProductionHandler) ListBOMs(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var materialID *uuid.UUID
	if pid := c.Query("material_id"); pid != "" {
		id, err := uuid.Parse(pid)
		if err != nil {
			response.BadRequest(c, "invalid material_id")
			return
		}
		materialID = &id
	}
	status := c.Query("status")

	list, err := h.svc.ListBOMs(c.Request.Context(), tenantID, materialID, status)
	if err != nil {
		log.Err(err).Msg("list BOMs failed")
		response.InternalError(c, "list BOMs failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) GetBOM(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid BOM id")
		return
	}

	bom, err := h.svc.GetBOM(c.Request.Context(), id, tenantID)
	if err != nil {
		log.Err(err).Msg("get BOM failed")
		response.NotFound(c, "BOM not found")
		return
	}
	response.OK(c, bom)
}

func (h *ProductionHandler) UpdateBOM(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid BOM id")
		return
	}

	var req prodmodels.UpdateBOMRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if err := h.svc.UpdateBOM(c.Request.Context(), id, tenantID, userID, &req); err != nil {
		log.Err(err).Msg("update BOM failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) DeleteBOM(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid BOM id")
		return
	}

	if err := h.svc.DeleteBOM(c.Request.Context(), id, tenantID, userID); err != nil {
		log.Err(err).Msg("delete BOM failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ═══════════════════════════════════════════════════════════════
// BOM Items
// ═══════════════════════════════════════════════════════════════

func (h *ProductionHandler) AddBOMItem(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	bomID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid BOM id")
		return
	}

	var req prodmodels.CreateBOMItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	item, err := h.svc.AddBOMItem(c.Request.Context(), bomID, tenantID, &req)
	if err != nil {
		log.Err(err).Msg("add BOM item failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, item)
}

func (h *ProductionHandler) UpdateBOMItem(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid BOM item id")
		return
	}

	var req prodmodels.UpdateBOMItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if err := h.svc.UpdateBOMItem(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update BOM item failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) DeleteBOMItem(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid BOM item id")
		return
	}

	if err := h.svc.DeleteBOMItem(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete BOM item failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ═══════════════════════════════════════════════════════════════
// BOM Explosion
// ═══════════════════════════════════════════════════════════════

func (h *ProductionHandler) ExplodeBOM(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req prodmodels.ExplodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	result, err := h.svc.ExplodeBOM(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("BOM explosion failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, result)
}

// ═══════════════════════════════════════════════════════════════
// Helper — shared by warehouse handler (same package convention)
// ═══════════════════════════════════════════════════════════════

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid, exists := c.Get("tenant_id")
	if !exists || tid == nil {
		return uuid.Nil, nil
	}
	// The context value is stored as a string (from JWT claims), not uuid.UUID
	tidStr, ok := tid.(string)
	if !ok {
		return uuid.Nil, fmt.Errorf("tenant_id is not a string")
	}
	parsed, err := uuid.Parse(tidStr)
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalid tenant_id: %w", err)
	}
	return parsed, nil
}

func getUserID(c *gin.Context) (uuid.UUID, error) {
	uid, exists := c.Get("user_id")
	if !exists || uid == nil {
		return uuid.Nil, nil
	}
	uidStr, ok := uid.(string)
	if !ok {
		return uuid.Nil, fmt.Errorf("user_id is not a string")
	}
	parsed, err := uuid.Parse(uidStr)
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalid user_id: %w", err)
	}
	return parsed, nil
}

// ═══════════════════════════════════════════════════════════════
// Work Center CRUD
// ═══════════════════════════════════════════════════════════════

func (h *ProductionHandler) CreateWorkCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req prodmodels.CreateWorkCenterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	wc, err := h.svc.CreateWorkCenter(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create work center failed")
		response.InternalError(c, "create work center failed")
		return
	}
	response.Created(c, wc)
}

func (h *ProductionHandler) ListWorkCenters(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListWorkCenters(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list work centers failed")
		response.InternalError(c, "list work centers failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) GetWorkCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid work center id")
		return
	}
	wc, err := h.svc.GetWorkCenter(c.Request.Context(), id, tenantID)
	if err != nil {
		response.NotFound(c, "work center not found")
		return
	}
	response.OK(c, wc)
}

func (h *ProductionHandler) UpdateWorkCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid work center id")
		return
	}
	var req prodmodels.UpdateWorkCenterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateWorkCenter(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update work center failed")
		response.InternalError(c, "update work center failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) DeleteWorkCenter(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid work center id")
		return
	}
	if err := h.svc.DeleteWorkCenter(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete work center failed")
		response.InternalError(c, "delete work center failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ═══════════════════════════════════════════════════════════════
// Routing Template CRUD
// ═══════════════════════════════════════════════════════════════

func (h *ProductionHandler) CreateRoutingTemplate(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req prodmodels.CreateRoutingTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	rt, err := h.svc.CreateRoutingTemplate(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create routing template failed")
		response.InternalError(c, "create routing template failed")
		return
	}
	response.Created(c, rt)
}

func (h *ProductionHandler) ListRoutingTemplates(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListRoutingTemplates(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list routing templates failed")
		response.InternalError(c, "list routing templates failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) GetRoutingTemplate(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid routing template id")
		return
	}
	rt, err := h.svc.GetRoutingTemplate(c.Request.Context(), id, tenantID)
	if err != nil {
		response.NotFound(c, "routing template not found")
		return
	}
	response.OK(c, rt)
}

func (h *ProductionHandler) UpdateRoutingTemplate(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid routing template id")
		return
	}
	var req prodmodels.UpdateRoutingTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateRoutingTemplate(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update routing template failed")
		response.InternalError(c, "update routing template failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) DeleteRoutingTemplate(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid routing template id")
		return
	}
	if err := h.svc.DeleteRoutingTemplate(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete routing template failed")
		response.InternalError(c, "delete routing template failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ═══════════════════════════════════════════════════════════════
// Template Operation CRUD
// ═══════════════════════════════════════════════════════════════

func (h *ProductionHandler) CreateTemplateOperation(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req prodmodels.CreateTemplateOperationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	op, err := h.svc.CreateTemplateOperation(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create template operation failed")
		response.InternalError(c, "create template operation failed")
		return
	}
	response.Created(c, op)
}

func (h *ProductionHandler) UpdateTemplateOperation(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid template operation id")
		return
	}
	var req prodmodels.UpdateTemplateOperationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateTemplateOperation(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update template operation failed")
		response.InternalError(c, "update template operation failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) DeleteTemplateOperation(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid template operation id")
		return
	}

	if err := h.svc.DeleteTemplateOperation(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete template operation failed")
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, map[string]string{"status": "deleted"})
}

var _ = time.Now

// ---------------------------------------------------------------
// Production Order CRUD
// ---------------------------------------------------------------

func (h *ProductionHandler) CreateProductionOrder(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}

	var req prodmodels.CreateProductionOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	po, err := h.svc.CreateProductionOrder(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create production order failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, po)
}

func (h *ProductionHandler) ListProductionOrders(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var materialID *uuid.UUID
	if pid := c.Query("material_id"); pid != "" {
		id, err := uuid.Parse(pid)
		if err != nil {
			response.BadRequest(c, "invalid material_id")
			return
		}
		materialID = &id
	}
	status := c.Query("status")

	list, err := h.svc.ListProductionOrders(c.Request.Context(), tenantID, materialID, status)
	if err != nil {
		log.Err(err).Msg("list production orders failed")
		response.InternalError(c, "list production orders failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) GetProductionOrder(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid production order id")
		return
	}

	po, err := h.svc.GetProductionOrder(c.Request.Context(), id, tenantID)
	if err != nil {
		log.Err(err).Msg("get production order failed")
		response.NotFound(c, "production order not found")
		return
	}
	response.OK(c, po)
}

func (h *ProductionHandler) UpdateProductionOrder(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid production order id")
		return
	}

	var req prodmodels.UpdateProductionOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if err := h.svc.UpdateProductionOrder(c.Request.Context(), id, tenantID, userID, &req); err != nil {
		log.Err(err).Msg("update production order failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) DeleteProductionOrder(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid production order id")
		return
	}

	if err := h.svc.DeleteProductionOrder(c.Request.Context(), id, tenantID, userID); err != nil {
		log.Err(err).Msg("delete production order failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "cancelled"})
}

// GetPORoutingInfo returns routing template info for a production order
func (h *ProductionHandler) GetPORoutingInfo(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid production order id")
		return
	}

	rt, err := h.svc.GetPORoutingInfo(c.Request.Context(), id, tenantID)
	if err != nil {
		log.Err(err).Msg("get PO routing info failed")
		response.InternalError(c, err.Error())
		return
	}
	if rt == nil {
		response.OK(c, map[string]interface{}{})
		return
	}
	response.OK(c, rt)
}

// SyncPOMaterials (re-)explodes the BOM and syncs material lines for a production order
func (h *ProductionHandler) SyncPOMaterials(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid production order id")
		return
	}
	if err := h.svc.SyncPOMaterials(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("sync PO materials failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "synced"})
}

// UpdatePOMaterialIssueQty updates issue_qty for a single material line
func (h *ProductionHandler) UpdatePOMaterialIssueQty(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	matID, err := uuid.Parse(c.Param("mat_id"))
	if err != nil {
		response.BadRequest(c, "invalid material id")
		return
	}
	var req prodmodels.UpdatePOMaterialIssueRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	if err := h.svc.UpdatePOMaterialIssueQty(c.Request.Context(), matID, tenantID, req.IssueQty); err != nil {
		log.Err(err).Msg("update issue qty failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) CreateTimeConfirmation(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid production order id")
		return
	}
	var req prodmodels.CreateTimeConfirmationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	conf, err := h.svc.CreateTimeConfirmation(c.Request.Context(), orderID, tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create time confirmation failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, conf)
}

func (h *ProductionHandler) ListTimeConfirmations(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid production order id")
		return
	}
	list, err := h.svc.ListTimeConfirmations(c.Request.Context(), orderID, tenantID)
	if err != nil {
		log.Err(err).Msg("list time confirmations failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) RunMPS(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	var req prodmodels.MPSRunRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	result, err := h.svc.RunMPS(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("run MPS failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, result)
}

func (h *ProductionHandler) RunMRP(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	var req prodmodels.MPSRunRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	req.RunMRPAfterMPS = true
	result, err := h.svc.RunMPS(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("run MRP failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, result)
}

func (h *ProductionHandler) ListMPSPlannedOrders(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListMPSPlannedOrders(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list MPS planned orders failed")
		response.InternalError(c, "list MPS planned orders failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) ListMPSDependentDemands(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListMPSDependentDemands(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list MPS dependent demands failed")
		response.InternalError(c, "list MPS dependent demands failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) ListMPSExceptions(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListMPSExceptions(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list MPS exceptions failed")
		response.InternalError(c, "list MPS exceptions failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) ListMRPPlannedPurchaseRequisitions(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListMRPPlannedPurchaseRequisitions(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list MRP planned purchase requisitions failed")
		response.InternalError(c, "list MRP planned purchase requisitions failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) ListMRPExceptions(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListMRPExceptions(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list MRP exceptions failed")
		response.InternalError(c, "list MRP exceptions failed")
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) GetMaterialRequirementsList(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	productID, err := uuid.Parse(c.Query("product_id"))
	if err != nil {
		response.BadRequest(c, "product_id is required")
		return
	}
	var siteID *uuid.UUID
	if raw := c.Query("site_id"); raw != "" {
		id, err := uuid.Parse(raw)
		if err != nil {
			response.BadRequest(c, "invalid site_id")
			return
		}
		siteID = &id
	}
	list, err := h.svc.GetMaterialRequirementsList(c.Request.Context(), tenantID, productID, siteID)
	if err != nil {
		log.Err(err).Msg("get material requirements list failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, list)
}

func (h *ProductionHandler) FirmMPSPlannedOrder(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid planned order id")
		return
	}
	var req struct {
		Firm bool `json:"firm"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.FirmMPSPlannedOrder(c.Request.Context(), tenantID, userID, id, req.Firm); err != nil {
		log.Err(err).Msg("firm MPS planned order failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *ProductionHandler) ConvertMPSPlannedOrders(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	var req struct {
		IDs []string `json:"ids"`
		All bool     `json:"all"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	var ids []uuid.UUID
	for _, raw := range req.IDs {
		id, err := uuid.Parse(raw)
		if err != nil {
			response.BadRequest(c, "invalid planned order id")
			return
		}
		ids = append(ids, id)
	}
	if !req.All && len(ids) == 0 {
		response.BadRequest(c, "planned order ids are required")
		return
	}
	orders, err := h.svc.ConvertMPSPlannedOrders(c.Request.Context(), tenantID, userID, ids, req.All)
	if err != nil {
		log.Err(err).Msg("convert MPS planned orders failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, orders)
}

func (h *ProductionHandler) ConvertMPSPlannedOrder(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid planned order id")
		return
	}
	po, err := h.svc.ConvertMPSPlannedOrder(c.Request.Context(), tenantID, userID, id)
	if err != nil {
		log.Err(err).Msg("convert MPS planned order failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, po)
}
