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
	var req prodmodels.UpdateTemplateOperationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.DeleteTemplateOperation(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete template operation failed")
		response.InternalError(c, "delete template operation failed")
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
