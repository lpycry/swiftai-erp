package handler

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
	salessvc "github.com/swiftai-erp/backend/internal/sales/service"
	"github.com/swiftai-erp/backend/pkg/response"
)

type SalesHandler struct {
	svc *salessvc.SalesService
}

func NewSalesHandler(svc *salessvc.SalesService) *SalesHandler {
	return &SalesHandler{svc: svc}
}

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid := c.GetString("tenant_id")
	if tid == "" {
		return uuid.Nil, nil
	}
	return uuid.Parse(tid)
}

func getUserID(c *gin.Context) (uuid.UUID, error) {
	userID := c.GetString("user_id")
	if userID == "" {
		return uuid.Nil, fmt.Errorf("missing user_id")
	}
	return uuid.Parse(userID)
}

// ══════════════════════════════════════════
//  CUSTOMERS
// ══════════════════════════════════════════

func (h *SalesHandler) ListCustomers(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	query := c.Query("q")
	status := c.Query("status")
	list, err := h.svc.ListCustomers(c.Request.Context(), tid, query, status)
	if err != nil {
		log.Err(err).Msg("list customers failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetCustomer(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	cust, err := h.svc.GetCustomer(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "customer not found")
		return
	}
	response.OK(c, cust)
}

func (h *SalesHandler) CreateCustomer(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req salesmodels.CreateCustomerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	cust, err := h.svc.CreateCustomer(c.Request.Context(), tid, &req)
	if err != nil {
		log.Err(err).Msg("create customer failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, cust)
}

func (h *SalesHandler) UpdateCustomer(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateCustomerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	if err := h.svc.UpdateCustomer(c.Request.Context(), id, tid, &req); err != nil {
		log.Err(err).Msg("update customer failed")
		response.InternalError(c, "update failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *SalesHandler) DeleteCustomer(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.DeleteCustomer(c.Request.Context(), id, tid); err != nil {
		log.Err(err).Msg("delete customer failed")
		response.InternalError(c, "delete failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════
//  CUSTOMER CERTIFICATES
// ══════════════════════════════════════════

func (h *SalesHandler) UploadCertificate(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	customerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid customer id")
		return
	}

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		response.BadRequest(c, "file is required")
		return
	}
	defer file.Close()

	// Ensure upload directory exists
	uploadDir := filepath.Join("uploads", "certificates", customerID.String())
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		response.InternalError(c, "failed to create upload directory")
		return
	}

	// Generate unique file name
	ext := filepath.Ext(header.Filename)
	savedName := fmt.Sprintf("%s_%d%s", uuid.New().String(), time.Now().UnixMilli(), ext)
	savedPath := filepath.Join(uploadDir, savedName)

	dst, err := os.Create(savedPath)
	if err != nil {
		response.InternalError(c, "failed to create file")
		return
	}
	defer dst.Close()

	written, err := io.Copy(dst, file)
	if err != nil {
		response.InternalError(c, "failed to save file")
		return
	}

	certType := c.PostForm("cert_type")
	if certType == "" {
		certType = "TAX_EXEMPT"
	}

	cert := &salesmodels.CustomerCertificate{
		ID:         uuid.New(),
		CustomerID: customerID,
		TenantID:   tid,
		CertType:   certType,
		FileName:   header.Filename,
		FilePath:   savedPath,
		FileSize:   int(written),
		MimeType:   header.Header.Get("Content-Type"),
		UploadedAt: time.Now(),
	}

	if err := h.svc.UploadCertificate(c.Request.Context(), cert); err != nil {
		log.Err(err).Msg("upload certificate failed")
		response.InternalError(c, "upload failed")
		return
	}

	response.Created(c, cert)
}

func (h *SalesHandler) ListCertificates(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	customerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid customer id")
		return
	}
	list, err := h.svc.ListCertificates(c.Request.Context(), customerID, tid)
	if err != nil {
		log.Err(err).Msg("list certificates failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) DeleteCertificate(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	customerID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid customer id")
		return
	}
	certID, err := uuid.Parse(c.Param("certId"))
	if err != nil {
		response.BadRequest(c, "invalid cert id")
		return
	}
	if err := h.svc.DeleteCertificate(c.Request.Context(), certID, customerID, tid); err != nil {
		log.Err(err).Msg("delete certificate failed")
		response.InternalError(c, "delete failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════
//  MATERIAL PRICES
// ══════════════════════════════════════════

func (h *SalesHandler) ListMaterialPrices(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	activeOnly := c.Query("active_only") == "true"
	var productID uuid.UUID
	if pid := c.Query("product_id"); pid != "" {
		productID, _ = uuid.Parse(pid)
	}
	list, err := h.svc.ListMaterialPrices(c.Request.Context(), tid, productID, activeOnly)
	if err != nil {
		log.Err(err).Msg("list material prices failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetMaterialPrice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	mp, err := h.svc.GetMaterialPrice(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "material price not found")
		return
	}
	response.OK(c, mp)
}

func (h *SalesHandler) CreateMaterialPrice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req salesmodels.CreateMaterialPriceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	mp, err := h.svc.CreateMaterialPrice(c.Request.Context(), tid, &req)
	if err != nil {
		log.Err(err).Msg("create material price failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, mp)
}

func (h *SalesHandler) UpdateMaterialPrice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateMaterialPriceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	if err := h.svc.UpdateMaterialPrice(c.Request.Context(), id, tid, &req); err != nil {
		log.Err(err).Msg("update material price failed")
		response.InternalError(c, "update failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *SalesHandler) LookupMaterialPrice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	customerID, err := uuid.Parse(c.Query("customer_id"))
	if err != nil {
		response.BadRequest(c, "invalid customer_id")
		return
	}
	productID, err := uuid.Parse(c.Query("product_id"))
	if err != nil {
		response.BadRequest(c, "invalid product_id")
		return
	}
	mp, err := h.svc.LookupMaterialPrice(c.Request.Context(), tid, customerID, productID)
	if err != nil {
		log.Err(err).Msg("lookup material price failed")
		response.InternalError(c, "lookup failed")
		return
	}
	response.OK(c, mp)
}

func (h *SalesHandler) DeleteMaterialPrice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.DeleteMaterialPrice(c.Request.Context(), id, tid); err != nil {
		log.Err(err).Msg("delete material price failed")
		response.InternalError(c, "delete failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════
//  QUOTATIONS
// ══════════════════════════════════════════

func (h *SalesHandler) ListQuotations(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	status := c.Query("status")
	list, err := h.svc.ListQuotations(c.Request.Context(), tid, status)
	if err != nil {
		log.Err(err).Msg("list quotations failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetQuotation(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	q, err := h.svc.GetQuotation(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "quotation not found")
		return
	}
	response.OK(c, q)
}

func (h *SalesHandler) CreateQuotation(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req salesmodels.CreateQuotationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	userID := uuid.Nil
	if uid := c.GetString("user_id"); uid != "" {
		userID, _ = uuid.Parse(uid)
	}
	q, err := h.svc.CreateQuotation(c.Request.Context(), tid, &req, &userID)
	if err != nil {
		log.Err(err).Msg("create quotation failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, q)
}

func (h *SalesHandler) UpdateQuotation(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.CreateQuotationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	q, err := h.svc.UpdateQuotation(c.Request.Context(), id, tid, &req)
	if err != nil {
		log.Err(err).Msg("update quotation failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, q)
}

func (h *SalesHandler) UpdateQuotationStatus(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateQuotationStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateQuotationStatus(c.Request.Context(), id, tid, req.Status); err != nil {
		log.Err(err).Msg("update quotation status failed")
		response.InternalError(c, "update failed")
		return
	}
	response.OK(c, map[string]string{"status": req.Status})
}

func (h *SalesHandler) CalculateTax(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req salessvc.TaxCalculationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	customerID, err := uuid.Parse(req.CustomerID)
	if err != nil {
		response.BadRequest(c, "invalid customer_id")
		return
	}
	_ = tid // tenant context available for future per-tenant tax config
	result, err := h.svc.CalculateTax(c.Request.Context(), customerID, req.NetAmount)
	if err != nil {
		log.Err(err).Msg("calculate tax failed")
		response.InternalError(c, "tax calculation failed")
		return
	}
	response.OK(c, result)
}

func (h *SalesHandler) DeleteQuotation(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.DeleteQuotation(c.Request.Context(), id, tid); err != nil {
		log.Err(err).Msg("delete quotation failed")
		response.InternalError(c, "delete failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════
//  SALES ORDERS
// ══════════════════════════════════════════

func (h *SalesHandler) ListSalesOrders(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	status := c.Query("status")
	list, err := h.svc.ListSalesOrders(c.Request.Context(), tid, status)
	if err != nil {
		log.Err(err).Msg("list so failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetSalesOrder(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	so, err := h.svc.GetSalesOrder(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "so not found")
		return
	}
	response.OK(c, so)
}

func (h *SalesHandler) CreateSalesOrder(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	var req salesmodels.CreateSalesOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	userID := uuid.Nil
	if uid := c.GetString("user_id"); uid != "" {
		userID, _ = uuid.Parse(uid)
	}
	so, err := h.svc.CreateSalesOrder(c.Request.Context(), tid, &req, &userID)
	if err != nil {
		log.Err(err).Msg("create so failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, so)
}

func (h *SalesHandler) UpdateSOStatus(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateSOStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateSOStatus(c.Request.Context(), id, tid, req.Status); err != nil {
		log.Err(err).Msg("update so status failed")
		response.InternalError(c, "update failed")
		return
	}
	response.OK(c, map[string]string{"status": req.Status})
}

func (h *SalesHandler) UpdateSalesOrder(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateSalesOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	so, err := h.svc.UpdateSalesOrder(c.Request.Context(), id, tid, &req)
	if err != nil {
		log.Err(err).Msg("update so failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, so)
}

func (h *SalesHandler) DeleteSalesOrder(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}

	// Only allow deletion if order is still Draft
	so, err := h.svc.GetSalesOrder(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "order not found")
		return
	}
	if so.Status != "DRAFT" {
		response.BadRequest(c, "cannot delete an order with status '"+so.Status+"' — cancel it instead")
		return
	}
	if err := h.svc.DeleteSalesOrder(c.Request.Context(), id, tid); err != nil {
		log.Err(err).Msg("delete so failed")
		response.InternalError(c, "delete failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════════
func (h *SalesHandler) CreateDeliveryNote(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req salesmodels.CreateDeliveryNoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	dn, err := h.svc.CreateDeliveryNote(c.Request.Context(), tid, &req)
	if err != nil {
		log.Err(err).Msg("create delivery note failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, dn)
}

func (h *SalesHandler) ListDeliveryNotes(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListDeliveryNotes(c.Request.Context(), tid, c.Query("status"))
	if err != nil {
		log.Err(err).Msg("list delivery notes failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetDeliveryNote(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid delivery id")
		return
	}
	dn, err := h.svc.GetDeliveryNote(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "delivery note not found")
		return
	}
	response.OK(c, dn)
}

func (h *SalesHandler) DeleteDeliveryNote(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid delivery id")
		return
	}
	if err := h.svc.DeleteDeliveryNote(c.Request.Context(), id, tid); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

func (h *SalesHandler) UpdateDeliveryPicking(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid delivery id")
		return
	}
	var req salesmodels.UpdateDeliveryPickingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	dn, err := h.svc.UpdateDeliveryPicking(c.Request.Context(), id, tid, &req)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, dn)
}

func (h *SalesHandler) PostDeliveryPGI(c *gin.Context) {
	tid, err := getTenantID(c)
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
		response.BadRequest(c, "invalid delivery id")
		return
	}
	dn, err := h.svc.PostDeliveryPGI(c.Request.Context(), id, tid, userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, dn)
}

func (h *SalesHandler) ListPendingInvoiceDeliveries(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListPendingInvoiceDeliveries(c.Request.Context(), tid)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) CreateSalesInvoice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	var req salesmodels.CreateSalesInvoiceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	inv, err := h.svc.CreateSalesInvoice(c.Request.Context(), tid, userID, &req)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, inv)
}

func (h *SalesHandler) ListSalesInvoices(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	list, err := h.svc.ListSalesInvoices(c.Request.Context(), tid, c.Query("status"))
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetSalesInvoice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid invoice id")
		return
	}
	inv, err := h.svc.GetSalesInvoice(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "invoice not found")
		return
	}
	response.OK(c, inv)
}

func (h *SalesHandler) PostSalesInvoice(c *gin.Context) {
	tid, err := getTenantID(c)
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
		response.BadRequest(c, "invalid invoice id")
		return
	}
	inv, err := h.svc.PostSalesInvoice(c.Request.Context(), id, tid, userID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, inv)
}

//  DELIVERY BLOCK REASONS
// ══════════════════════════════════════════════

func (h *SalesHandler) ListDeliveryBlockReasons(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	activeOnly := c.Query("active_only") == "true"
	list, err := h.svc.ListDeliveryBlockReasons(c.Request.Context(), tid, activeOnly)
	if err != nil {
		log.Err(err).Msg("list dbr failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetDeliveryBlockReason(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	d, err := h.svc.GetDeliveryBlockReason(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "not found")
		return
	}
	response.OK(c, d)
}

func (h *SalesHandler) CreateDeliveryBlockReason(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	var req salesmodels.CreateDeliveryBlockReasonRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	d, err := h.svc.CreateDeliveryBlockReason(c.Request.Context(), tid, &req)
	if err != nil {
		log.Err(err).Msg("create dbr failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, d)
}

func (h *SalesHandler) UpdateDeliveryBlockReason(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateDeliveryBlockReasonRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	d, err := h.svc.UpdateDeliveryBlockReason(c.Request.Context(), id, tid, &req)
	if err != nil {
		log.Err(err).Msg("update dbr failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, d)
}

func (h *SalesHandler) DeleteDeliveryBlockReason(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.DeleteDeliveryBlockReason(c.Request.Context(), id, tid); err != nil {
		log.Err(err).Msg("delete dbr failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════════
//  CARRIER SERVICE TYPES
// ══════════════════════════════════════════════

func (h *SalesHandler) ListCarrierServiceTypes(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	carrier := c.Query("carrier")
	list, err := h.svc.ListCarrierServiceTypes(c.Request.Context(), tid, carrier)
	if err != nil {
		log.Err(err).Msg("list carrier service types failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetCarrierServiceType(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	d, err := h.svc.GetCarrierServiceType(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "not found")
		return
	}
	response.OK(c, d)
}

func (h *SalesHandler) CreateCarrierServiceType(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	var req salesmodels.CreateCarrierServiceTypeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	d, err := h.svc.CreateCarrierServiceType(c.Request.Context(), tid, &req)
	if err != nil {
		log.Err(err).Msg("create carrier service type failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, d)
}

func (h *SalesHandler) UpdateCarrierServiceType(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateCarrierServiceTypeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	d, err := h.svc.UpdateCarrierServiceType(c.Request.Context(), id, tid, &req)
	if err != nil {
		log.Err(err).Msg("update carrier service type failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, d)
}

func (h *SalesHandler) DeleteCarrierServiceType(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.DeleteCarrierServiceType(c.Request.Context(), id, tid); err != nil {
		log.Err(err).Msg("delete carrier service type failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════════
//  ORDER TYPE CONFIGS
// ══════════════════════════════════════════════

func (h *SalesHandler) ListOrderTypeConfigs(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	activeOnly := c.Query("active_only") == "true"
	list, err := h.svc.ListOrderTypeConfigs(c.Request.Context(), tid, activeOnly)
	if err != nil {
		log.Err(err).Msg("list otc failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, list)
}

func (h *SalesHandler) GetOrderTypeConfig(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	otc, err := h.svc.GetOrderTypeConfig(c.Request.Context(), id, tid)
	if err != nil {
		response.NotFound(c, "not found")
		return
	}
	response.OK(c, otc)
}

func (h *SalesHandler) CreateOrderTypeConfig(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	var req salesmodels.CreateOrderTypeConfigRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	userID := uuid.Nil
	if uid := c.GetString("user_id"); uid != "" {
		userID, _ = uuid.Parse(uid)
	}
	otc, err := h.svc.CreateOrderTypeConfig(c.Request.Context(), tid, &req, &userID)
	if err != nil {
		log.Err(err).Msg("create otc failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, otc)
}

func (h *SalesHandler) UpdateOrderTypeConfig(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	var req salesmodels.UpdateOrderTypeConfigRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	otc, err := h.svc.UpdateOrderTypeConfig(c.Request.Context(), id, tid, &req)
	if err != nil {
		log.Err(err).Msg("update otc failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, otc)
}

func (h *SalesHandler) DeleteOrderTypeConfig(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid id")
		return
	}
	if err := h.svc.DeleteOrderTypeConfig(c.Request.Context(), id, tid); err != nil {
		log.Err(err).Msg("delete otc failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ══════════════════════════════════════════════
//  ATP CHECK & PRICING ENGINE
// ══════════════════════════════════════════════

func (h *SalesHandler) CheckATP(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	prodID, err := uuid.Parse(c.Query("product_id"))
	if err != nil {
		response.BadRequest(c, "invalid product_id")
		return
	}
	qty := 1.0
	if q := c.Query("quantity"); q != "" {
		qty, _ = strconv.ParseFloat(q, 64)
	}
	var deliveryDate *time.Time
	if d := c.Query("delivery_date"); d != "" {
		parsed, err := time.Parse("2006-01-02", d)
		if err != nil {
			response.BadRequest(c, "invalid delivery_date")
			return
		}
		deliveryDate = &parsed
	}
	var siteID *uuid.UUID
	if s := c.Query("site_id"); s != "" {
		parsed, err := uuid.Parse(s)
		if err != nil {
			response.BadRequest(c, "invalid site_id")
			return
		}
		siteID = &parsed
	}
	result, err := h.svc.CheckATP(c.Request.Context(), tid, prodID, qty, deliveryDate, siteID)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, result)
}

func (h *SalesHandler) CalculatePrice(c *gin.Context) {
	tid, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant")
		return
	}
	var req salessvc.PricingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	result, err := h.svc.CalculatePrice(c.Request.Context(), tid, &req)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, result)
}
