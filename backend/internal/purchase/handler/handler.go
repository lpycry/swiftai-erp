package handler

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	purchasemodels "github.com/swiftai-erp/backend/internal/purchase/models"
	purchasesvc "github.com/swiftai-erp/backend/internal/purchase/service"
	"github.com/swiftai-erp/backend/pkg/response"
)

type PurchaseHandler struct {
	svc *purchasesvc.PurchaseService
}

func NewPurchaseHandler(svc *purchasesvc.PurchaseService) *PurchaseHandler {
	return &PurchaseHandler{svc: svc}
}

// ══════════════════════════════════════════
//  VENDORS
// ══════════════════════════════════════════

func (h *PurchaseHandler) CreateVendor(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	var req purchasemodels.CreateVendorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	vendor, err := h.svc.CreateVendor(c.Request.Context(), orgID, &req)
	if err != nil {
		log.Err(err).Msg("create vendor failed")
		response.InternalError(c, "create vendor failed")
		return
	}
	response.Created(c, vendor)
}

func (h *PurchaseHandler) ListVendors(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	search := c.Query("q")
	vendors, err := h.svc.ListVendors(c.Request.Context(), orgID, search)
	if err != nil {
		log.Err(err).Msg("list vendors failed")
		response.InternalError(c, "list vendors failed")
		return
	}
	response.OK(c, vendors)
}

func (h *PurchaseHandler) GetVendor(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid vendor id"); return }
	vendor, err := h.svc.GetVendor(c.Request.Context(), id, orgID)
	if err != nil {
		log.Err(err).Msg("get vendor failed")
		response.NotFound(c, "vendor not found")
		return
	}
	response.OK(c, vendor)
}

func (h *PurchaseHandler) UpdateVendor(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid vendor id"); return }
	var req purchasemodels.UpdateVendorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateVendor(c.Request.Context(), id, orgID, &req); err != nil {
		log.Err(err).Msg("update vendor failed")
		response.InternalError(c, "update vendor failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *PurchaseHandler) DeleteVendor(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid vendor id"); return }
	if err := h.svc.DeleteVendor(c.Request.Context(), id, orgID); err != nil {
		log.Err(err).Msg("delete vendor failed")
		errMsg := err.Error()
		if errMsg == "vendor has existing purchase orders, receipts or invoices; deletion blocked" {
			response.BadRequest(c, errMsg)
		} else {
			response.InternalError(c, "delete vendor failed")
		}
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

func (h *PurchaseHandler) RecommendVendors(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	productID, _ := uuid.Parse(c.Query("product_id"))
	recs, err := h.svc.RecommendVendors(c.Request.Context(), orgID, productID)
	if err != nil {
		log.Err(err).Msg("recommend vendors failed")
		response.InternalError(c, "recommend vendors failed")
		return
	}
	response.OK(c, recs)
}

// ══════════════════════════════════════════
//  PURCHASE ORDERS
// ══════════════════════════════════════════

func (h *PurchaseHandler) CreatePO(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	userID := getUserIDPtr(c)
	var req purchasemodels.CreatePORequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	po, err := h.svc.CreatePO(c.Request.Context(), orgID, &req, userID)
	if err != nil {
		log.Err(err).Msg("create po failed")
		response.InternalError(c, "create PO failed")
		return
	}
	response.Created(c, po)
}

func (h *PurchaseHandler) ListPOs(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	status := c.Query("status")
	vendorID, _ := uuid.Parse(c.Query("vendor_id"))
	pos, err := h.svc.ListPOs(c.Request.Context(), orgID, status, vendorID)
	if err != nil {
		log.Err(err).Msg("list POs failed")
		response.InternalError(c, "list POs failed")
		return
	}
	response.OK(c, pos)
}

func (h *PurchaseHandler) GetPO(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid PO id"); return }
	po, err := h.svc.GetPO(c.Request.Context(), id, orgID)
	if err != nil {
		log.Err(err).Msg("get PO failed")
		response.NotFound(c, "PO not found")
		return
	}
	response.OK(c, po)
}

func (h *PurchaseHandler) UpdatePOStatus(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid PO id"); return }
	var req purchasemodels.UpdatePOStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdatePOStatus(c.Request.Context(), id, orgID, req.Status); err != nil {
		log.Err(err).Msg("update PO status failed")
		response.InternalError(c, "update PO status failed")
		return
	}
	response.OK(c, map[string]string{"status": req.Status})
}

// ══════════════════════════════════════════
//  PURCHASE RECEIPTS (核心：收货→仓库+财务事件)
// ══════════════════════════════════════════

func (h *PurchaseHandler) ExecuteGoodsReceipt(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	userID := getUserIDPtr(c)
	var req purchasemodels.CreateReceiptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	receipt, event, err := h.svc.ExecuteGoodsReceipt(c.Request.Context(), orgID, &req, userID)
	if err != nil {
		log.Err(err).Msg("execute goods receipt failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, map[string]interface{}{
		"receipt":        receipt,
		"business_event": event,
	})
}

func (h *PurchaseHandler) ListReceipts(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	poID, _ := uuid.Parse(c.Query("po_id"))
	receipts, err := h.svc.ListReceipts(c.Request.Context(), orgID, poID)
	if err != nil {
		log.Err(err).Msg("list receipts failed")
		response.InternalError(c, "list receipts failed")
		return
	}
	response.OK(c, receipts)
}

func (h *PurchaseHandler) ReverseGoodsReceipt(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	userID := getUserIDPtr(c)
	receiptID, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid receipt id"); return }

	if err := h.svc.ReverseGoodsReceipt(c.Request.Context(), orgID, receiptID, userID); err != nil {
		log.Err(err).Msg("reverse goods receipt failed")
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, map[string]string{"status": "reversed"})
}

// ══════════════════════════════════════════
//  PURCHASE INVOICES (联动财务结算)
// ══════════════════════════════════════════

func (h *PurchaseHandler) CreateInvoice(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	userID := getUserIDPtr(c)
	var req purchasemodels.CreateInvoiceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	invoice, event, err := h.svc.CreateInvoice(c.Request.Context(), orgID, &req, userID)
	if err != nil {
		log.Err(err).Msg("create invoice failed")
		response.InternalError(c, err.Error())
		return
	}
	resp := map[string]interface{}{"invoice": invoice}
	if event != nil {
		resp["business_event"] = event
	}
	response.Created(c, resp)
}

func (h *PurchaseHandler) ListInvoices(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	vendorID, _ := uuid.Parse(c.Query("vendor_id"))
	invoices, err := h.svc.ListInvoices(c.Request.Context(), orgID, vendorID)
	if err != nil {
		log.Err(err).Msg("list invoices failed")
		response.InternalError(c, "list invoices failed")
		return
	}
	response.OK(c, invoices)
}

func (h *PurchaseHandler) GetInvoice(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid invoice id"); return }
	invoice, err := h.svc.GetInvoice(c.Request.Context(), id, orgID)
	if err != nil {
		log.Err(err).Msg("get invoice failed")
		response.NotFound(c, "invoice not found")
		return
	}
	response.OK(c, invoice)
}

// ══════════════════════════════════════════
//  PO ATTACHMENTS
// ══════════════════════════════════════════

func (h *PurchaseHandler) UploadPOAttachment(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	userID := getUserIDPtr(c)

	poID, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid po id"); return }

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		response.BadRequest(c, "file is required")
		return
	}
	defer file.Close()

	// Create upload directory
	uploadDir := filepath.Join("uploads", "po_attachments", poID.String())
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		log.Err(err).Msg("create upload dir failed")
		response.InternalError(c, "upload failed")
		return
	}

	// Generate unique filename
	ext := filepath.Ext(header.Filename)
	storedName := fmt.Sprintf("%s_%d%s", uuid.New().String()[:8], time.Now().UnixMilli(), ext)
	filePath := filepath.Join(uploadDir, storedName)

	// Write file
	out, err := os.Create(filePath)
	if err != nil {
		log.Err(err).Msg("create file failed")
		response.InternalError(c, "upload failed")
		return
	}
	defer out.Close()

	written, err := io.Copy(out, file)
	if err != nil {
		log.Err(err).Msg("write file failed")
		response.InternalError(c, "upload failed")
		return
	}

	// Insert record
	attachID := uuid.New()
	if err := h.svc.InsertAttachment(c.Request.Context(), orgID, poID, attachID, header.Filename, header.Header.Get("Content-Type"), written, filePath, userID); err != nil {
		log.Err(err).Msg("insert attachment record failed")
		os.Remove(filePath)
		response.InternalError(c, "upload failed")
		return
	}

	response.Created(c, map[string]interface{}{
		"id":        attachID.String(),
		"file_name": header.Filename,
		"file_size": written,
	})
}

func (h *PurchaseHandler) ListPOAttachments(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	poID, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid po id"); return }
	attachments, err := h.svc.ListAttachments(c.Request.Context(), orgID, poID)
	if err != nil {
		log.Err(err).Msg("list attachments failed")
		response.InternalError(c, "list failed")
		return
	}
	response.OK(c, attachments)
}

func (h *PurchaseHandler) DownloadPOAttachment(c *gin.Context) {
	orgID, err := getOrgID(c)
	if err != nil { response.BadRequest(c, "missing org context"); return }
	poID, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid po id"); return }
	attachID, err := uuid.Parse(c.Param("attachId"))
	if err != nil { response.BadRequest(c, "invalid attachment id"); return }

	att, err := h.svc.GetAttachment(c.Request.Context(), orgID, poID, attachID)
	if err != nil {
		log.Err(err).Msg("get attachment failed")
		response.NotFound(c, "attachment not found")
		return
	}

	c.FileAttachment(att["file_path"].(string), att["file_name"].(string))
}

// ══════════════════════════════════════════
//  RECEIPT → JOURNAL ENTRY
// ══════════════════════════════════════════

func (h *PurchaseHandler) GetReceiptJournalEntry(c *gin.Context) {
	receiptID, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid receipt id"); return }
	je, err := h.svc.FindJournalEntryForReceipt(c.Request.Context(), receiptID)
	if err != nil {
		log.Err(err).Msg("find journal entry for receipt failed")
		response.NotFound(c, "no journal entry found for this receipt")
		return
	}
	response.OK(c, je)
}

// ══════════════════════════════════════════
//  HELPERS — reads org_id from context (not tenant_id)
// ══════════════════════════════════════════

func getOrgID(c *gin.Context) (uuid.UUID, error) {
	// First try organization_id from context (set by middleware)
	oid := c.GetString("organization_id")
	if oid != "" {
		return uuid.Parse(oid)
	}
	// Fallback to tenant_id (for backward compatibility with existing middleware)
	tid := c.GetString("tenant_id")
	if tid != "" {
		return uuid.Parse(tid)
	}
	return uuid.Nil, nil
}

func getUserIDPtr(c *gin.Context) *uuid.UUID {
	uid := c.GetString("user_id")
	if uid == "" { return nil }
	parsed, err := uuid.Parse(uid)
	if err != nil { return nil }
	return &parsed
}
