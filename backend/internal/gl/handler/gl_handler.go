package handler

import (
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
	"github.com/swiftai-erp/backend/internal/gl/service"
	"github.com/swiftai-erp/backend/pkg/response"
)

// GLHandler holds all GL HTTP handlers.
type GLHandler struct {
	glSvc *service.GLService
	aiSvc *service.AIService
}

func NewGLHandler(glSvc *service.GLService, aiSvc *service.AIService) *GLHandler {
	return &GLHandler{glSvc: glSvc, aiSvc: aiSvc}
}

// ── Chart of Accounts ──

// CreateAccount handles POST /api/v1/gl/accounts
func (h *GLHandler) CreateAccount(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req glmodels.CreateAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	// Auto-set level based on parent
	if req.Level == 0 {
		req.Level = 1
		if req.ParentID != nil {
			parent, err := h.glSvc.GetAccount(c.Request.Context(), *req.ParentID, tenantID)
			if err == nil && parent != nil {
				req.Level = parent.Level + 1
			}
		}
	}

	acc, err := h.glSvc.CreateAccount(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create account failed")
		response.InternalError(c, "failed to create account")
		return
	}

	response.Created(c, acc)
}

// GetAccount handles GET /api/v1/gl/accounts/:id
func (h *GLHandler) GetAccount(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	accountID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid account id")
		return
	}

	acc, err := h.glSvc.GetAccount(c.Request.Context(), accountID, tenantID)
	if err != nil {
		response.InternalError(c, "failed to get account")
		return
	}
	if acc == nil {
		response.NotFound(c, "account not found")
		return
	}

	response.OK(c, acc)
}

// ListAccounts handles GET /api/v1/gl/accounts
func (h *GLHandler) ListAccounts(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	accs, err := h.glSvc.ListAccounts(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list accounts failed")
		response.InternalError(c, "failed to list accounts")
		return
	}

	response.OK(c, accs)
}

// UpdateAccount handles PUT /api/v1/gl/accounts/:id
func (h *GLHandler) UpdateAccount(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	accountID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid account id")
		return
	}

	var req glmodels.UpdateAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	acc, err := h.glSvc.UpdateAccount(c.Request.Context(), accountID, tenantID, &req)
	if err != nil {
		log.Err(err).Msg("update account failed")
		response.InternalError(c, "failed to update account")
		return
	}
	if acc == nil {
		response.NotFound(c, "account not found")
		return
	}

	response.OK(c, acc)
}

// DeleteAccount handles DELETE /api/v1/gl/accounts/:id
func (h *GLHandler) DeleteAccount(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	accountID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid account id")
		return
	}

	if err := h.glSvc.DeleteAccount(c.Request.Context(), accountID, tenantID); err != nil {
		log.Err(err).Msg("delete account failed")
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, gin.H{"message": "account deactivated"})
}

// ReactivateAccount handles PUT /api/v1/gl/accounts/:id/reactivate
func (h *GLHandler) ReactivateAccount(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	accountID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid account id")
		return
	}

	acc, err := h.glSvc.ReactivateAccount(c.Request.Context(), accountID, tenantID)
	if err != nil {
		log.Err(err).Msg("reactivate account failed")
		response.InternalError(c, err.Error())
		return
	}
	if acc == nil {
		response.NotFound(c, "account not found")
		return
	}

	response.OK(c, acc)
}

// GetAccountTree handles GET /api/v1/gl/accounts/tree
func (h *GLHandler) GetAccountTree(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	tree, err := h.glSvc.GetAccountTree(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("get account tree failed")
		response.InternalError(c, "failed to get account tree")
		return
	}

	response.OK(c, tree)
}

// SearchAccounts handles GET /api/v1/gl/accounts/search?q=...
func (h *GLHandler) SearchAccounts(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	query := c.Query("q")
	if query == "" {
		response.BadRequest(c, "search query is required")
		return
	}

	results, err := h.glSvc.SearchAccounts(c.Request.Context(), tenantID, query)
	if err != nil {
		log.Err(err).Msg("search accounts failed")
		response.InternalError(c, "failed to search accounts")
		return
	}

	response.OK(c, results)
}

// GetLeafAccounts handles GET /api/v1/gl/accounts/leaf
func (h *GLHandler) GetLeafAccounts(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	accs, err := h.glSvc.GetLeafAccounts(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("get leaf accounts failed")
		response.InternalError(c, "failed to get leaf accounts")
		return
	}

	response.OK(c, accs)
}

// ── Journal Entries ──

// CreateJournalEntry handles POST /api/v1/gl/journal-entries
func (h *GLHandler) CreateJournalEntry(c *gin.Context) {
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

	var req glmodels.CreateJournalEntryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	entry, err := h.glSvc.CreateJournalEntry(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create journal entry failed")
		switch err {
		case service.ErrNoLines:
			response.BadRequest(c, err.Error())
		case service.ErrNegativeAmount:
			response.BadRequest(c, err.Error())
		case service.ErrInvalidBalance:
			response.BadRequest(c, err.Error())
		case service.ErrAccountNotLeaf:
			response.BadRequest(c, err.Error())
		case service.ErrAccountInactive:
			response.BadRequest(c, err.Error())
		case service.ErrNoAccountMatch:
			response.BadRequest(c, err.Error())
		case service.ErrPeriodClosed:
			response.BadRequest(c, err.Error())
		default:
			response.InternalError(c, "failed to create journal entry")
		}
		return
	}

	response.Created(c, entry)
}

// GetJournalEntry handles GET /api/v1/gl/journal-entries/:id
func (h *GLHandler) GetJournalEntry(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	entry, err := h.glSvc.GetJournalEntry(c.Request.Context(), entryID, tenantID)
	if err != nil {
		if err == service.ErrEntryNotFound {
			response.NotFound(c, "journal entry not found")
			return
		}
		log.Err(err).Msg("get journal entry failed")
		response.InternalError(c, "failed to get journal entry")
		return
	}

	response.OK(c, entry)
}

// ListJournalEntries handles GET /api/v1/gl/journal-entries?page=1&page_size=20&status=draft&q=search
func (h *GLHandler) ListJournalEntries(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	status := c.Query("status")
	entryType := c.Query("entry_type")
	query := c.Query("q") // smart search: matches doc_no, description, reference, amounts

	entries, total, err := h.glSvc.ListJournalEntries(c.Request.Context(), tenantID, page, pageSize, status, entryType, query)
	if err != nil {
		log.Err(err).Msg("list journal entries failed")
		response.InternalError(c, "failed to list journal entries")
		return
	}

	totalPages := int(math.Ceil(float64(total) / float64(pageSize)))
	response.OKWithMeta(c, entries, &response.Meta{
		Page:       page,
		PageSize:   pageSize,
		TotalCount: total,
		TotalPages: totalPages,
	})
}

func (h *GLHandler) ListOpenItems(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	accountID, err := uuid.Parse(c.Query("account_id"))
	if err != nil {
		response.BadRequest(c, "account_id is required")
		return
	}
	items, err := h.glSvc.ListOpenItems(c.Request.Context(), tenantID, accountID)
	if err != nil {
		log.Err(err).Msg("list open items failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, items)
}

func (h *GLHandler) ListClearedItems(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	accountID, err := uuid.Parse(c.Query("account_id"))
	if err != nil {
		response.BadRequest(c, "account_id is required")
		return
	}
	items, err := h.glSvc.ListClearedItems(c.Request.Context(), tenantID, accountID)
	if err != nil {
		log.Err(err).Msg("list cleared items failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, items)
}

func (h *GLHandler) CreateClearing(c *gin.Context) {
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
	var req glmodels.CreateClearingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	result, err := h.glSvc.CreateClearing(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create clearing failed")
		response.BadRequest(c, err.Error())
		return
	}
	response.Created(c, result)
}

func (h *GLHandler) ListARCustomers(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	customers, err := h.glSvc.ListARCustomers(c.Request.Context(), tenantID, c.Query("q"))
	if err != nil {
		log.Err(err).Msg("list AR customers failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, customers)
}

func (h *GLHandler) ListAROpenInvoices(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	customerID, err := uuid.Parse(c.Query("customer_id"))
	if err != nil {
		response.BadRequest(c, "customer_id is required")
		return
	}
	invoices, err := h.glSvc.ListAROpenInvoices(c.Request.Context(), tenantID, customerID)
	if err != nil {
		log.Err(err).Msg("list AR open invoices failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, invoices)
}

func (h *GLHandler) CreateIncomingPayment(c *gin.Context) {
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
	var req glmodels.CreateIncomingPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	result, err := h.glSvc.CreateIncomingPayment(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create incoming payment failed")
		response.BadRequest(c, err.Error())
		return
	}
	response.Created(c, result)
}

func (h *GLHandler) ListAROpenCreditMemos(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	customerID, err := uuid.Parse(c.Query("customer_id"))
	if err != nil {
		response.BadRequest(c, "customer_id is required")
		return
	}
	memos, err := h.glSvc.ListAROpenCreditMemos(c.Request.Context(), tenantID, customerID)
	if err != nil {
		log.Err(err).Msg("list AR open credit memos failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, memos)
}

func (h *GLHandler) CreateCreditMemoClearing(c *gin.Context) {
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
	var req glmodels.CreateCreditMemoClearingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	result, err := h.glSvc.CreateCreditMemoClearing(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create credit memo clearing failed")
		response.BadRequest(c, err.Error())
		return
	}
	response.Created(c, result)
}

func (h *GLHandler) CancelClearing(c *gin.Context) {
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
	clearingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid clearing id")
		return
	}
	result, err := h.glSvc.CancelClearing(c.Request.Context(), tenantID, userID, clearingID)
	if err != nil {
		log.Err(err).Msg("cancel clearing failed")
		response.BadRequest(c, err.Error())
		return
	}
	response.OK(c, result)
}

// PostJournalEntries handles POST /api/v1/gl/journal-entries/post
func (h *GLHandler) PostJournalEntries(c *gin.Context) {
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

	var req glmodels.PostJournalEntryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	result, err := h.glSvc.PostJournalEntries(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Interface("failures", result).Msg("post journal entries failed")
		// Partial success is still returned
		if result != nil && result.SuccessCount > 0 {
			response.OK(c, result)
			return
		}
		if result != nil {
			response.BadRequest(c, err.Error(), response.ErrorDetail{
				Field:   "entries",
				Message: fmt.Sprintf("%+v", result.Failures),
			})
			return
		}
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, result)
}

// UpdateJournalEntryStatus handles PATCH /api/v1/gl/journal-entries/:id/status
func (h *GLHandler) UpdateJournalEntryStatus(c *gin.Context) {
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

	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	var req struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "status field is required")
		return
	}

	entry, err := h.glSvc.UpdateJournalEntryStatus(c.Request.Context(), entryID, tenantID, userID, req.Status)
	if err != nil {
		log.Err(err).Str("entry_id", entryID.String()).Str("status", req.Status).Msg("update status failed")
		switch err {
		case service.ErrEntryNotFound:
			response.NotFound(c, err.Error())
		default:
			response.BadRequest(c, err.Error())
		}
		return
	}

	response.OK(c, entry)
}

// DeleteJournalEntry handles DELETE /api/v1/gl/journal-entries/:id
func (h *GLHandler) DeleteJournalEntry(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	if err := h.glSvc.DeleteJournalEntry(c.Request.Context(), entryID, tenantID); err != nil {
		log.Err(err).Msg("delete journal entry failed")
		switch err {
		case service.ErrEntryNotFound:
			response.NotFound(c, err.Error())
		default:
			response.BadRequest(c, err.Error())
		}
		return
	}

	response.OK(c, gin.H{"message": "journal entry deleted"})
}

// UpdateDraftEntry handles PUT /api/v1/gl/journal-entries/:id
func (h *GLHandler) UpdateDraftEntry(c *gin.Context) {
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

	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	var req glmodels.CreateJournalEntryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	entry, err := h.glSvc.UpdateDraftEntry(c.Request.Context(), tenantID, userID, entryID, &req)
	if err != nil {
		log.Err(err).Msg("update draft entry failed")
		switch err {
		case service.ErrEntryNotFound:
			response.NotFound(c, err.Error())
		case service.ErrNoLines:
			response.BadRequest(c, err.Error())
		case service.ErrNegativeAmount:
			response.BadRequest(c, err.Error())
		case service.ErrInvalidBalance:
			response.BadRequest(c, err.Error())
		case service.ErrAccountNotLeaf:
			response.BadRequest(c, err.Error())
		case service.ErrAccountInactive:
			response.BadRequest(c, err.Error())
		case service.ErrNoAccountMatch:
			response.BadRequest(c, err.Error())
		default:
			response.InternalError(c, err.Error())
		}
		return
	}

	response.OK(c, entry)
}

// UnpostEntry handles POST /api/v1/gl/journal-entries/:id/unpost
func (h *GLHandler) UnpostEntry(c *gin.Context) {
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
	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	entry, err := h.glSvc.UnpostEntry(c.Request.Context(), tenantID, userID, entryID)
	if err != nil {
		log.Err(err).Msg("unpost entry failed")
		response.BadRequest(c, err.Error())
		return
	}

	response.OK(c, entry)
}

// ReverseJournalEntry handles POST /api/v1/gl/journal-entries/:id/reverse
// Body: {"reversal_type":"normal"|"negative"} (default: "negative")
func (h *GLHandler) ReverseJournalEntry(c *gin.Context) {
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

	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	var req struct {
		ReversalType string `json:"reversal_type"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		req.ReversalType = "negative" // default to 红字冲销
	}
	if req.ReversalType != "normal" && req.ReversalType != "negative" {
		req.ReversalType = "negative"
	}

	entry, err := h.glSvc.ReverseJournalEntry(c.Request.Context(), tenantID, userID, entryID, req.ReversalType)
	if err != nil {
		log.Err(err).Msg("reverse journal entry failed")
		switch err {
		case service.ErrEntryNotFound:
			response.NotFound(c, "journal entry not found")
		case service.ErrEntryAlreadyReversed:
			response.BadRequest(c, err.Error())
		default:
			response.InternalError(c, err.Error())
		}
		return
	}

	response.Created(c, entry)
}

// ── AI Assistant ──

// ── Account Ledger ──

// GetAccountLedger handles GET /api/v1/gl/accounts/:id/ledger?from=...&to=...&page=1&page_size=20
func (h *GLHandler) GetAccountLedger(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	accountID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid account id")
		return
	}

	fromStr := c.DefaultQuery("from", time.Now().AddDate(0, -1, 0).Format("2006-01-02"))
	toStr := c.DefaultQuery("to", time.Now().Format("2006-01-02"))
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "50"))

	fromDate, err := time.Parse("2006-01-02", fromStr)
	if err != nil {
		response.BadRequest(c, "invalid from date")
		return
	}
	toDate, err := time.Parse("2006-01-02", toStr)
	if err != nil {
		response.BadRequest(c, "invalid to date")
		return
	}

	lines, total, err := h.glSvc.GetAccountLedger(c.Request.Context(), tenantID, accountID, fromDate, toDate, page, pageSize)
	if err != nil {
		log.Err(err).Msg("get account ledger failed")
		response.InternalError(c, "failed to get account ledger")
		return
	}

	totalPages := int(math.Ceil(float64(total) / float64(pageSize)))
	response.OKWithMeta(c, lines, &response.Meta{
		Page:       page,
		PageSize:   pageSize,
		TotalCount: total,
		TotalPages: totalPages,
	})
}

// ── Account Balances ──

// GetAccountBalances handles GET /api/v1/gl/balances?year=2026&month=5
func (h *GLHandler) GetAccountBalances(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	year, _ := strconv.Atoi(c.DefaultQuery("year", "2026"))
	month, _ := strconv.Atoi(c.DefaultQuery("month", "0")) // 0 = all year

	balances, err := h.glSvc.GetAccountBalances(c.Request.Context(), tenantID, year, month)
	if err != nil {
		log.Err(err).Msg("get account balances failed")
		response.InternalError(c, "failed to get account balances")
		return
	}

	response.OK(c, balances)
}

// ── Balance Sheet ──

// GetBalanceSheet handles GET /api/v1/gl/reports/balance-sheet?year=2026&month=5
func (h *GLHandler) GetBalanceSheet(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	year, _ := strconv.Atoi(c.DefaultQuery("year", "2026"))
	month, _ := strconv.Atoi(c.DefaultQuery("month", "0"))

	report, err := h.glSvc.GetBalanceSheet(c.Request.Context(), tenantID, year, month)
	if err != nil {
		log.Err(err).Msg("balance sheet failed")
		response.InternalError(c, "failed to generate balance sheet")
		return
	}

	response.OK(c, report)
}

// ── Profit & Loss ──

// GetProfitLoss handles GET /api/v1/gl/reports/profit-loss?year=2026&month=5
func (h *GLHandler) GetProfitLoss(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	year, _ := strconv.Atoi(c.DefaultQuery("year", "2026"))
	month, _ := strconv.Atoi(c.DefaultQuery("month", "0"))

	report, err := h.glSvc.GetProfitLoss(c.Request.Context(), tenantID, year, month)
	if err != nil {
		log.Err(err).Msg("profit loss failed")
		response.InternalError(c, "failed to generate profit & loss")
		return
	}

	response.OK(c, report)
}

// ── AI Assistant ──

// AISuggest handles POST /api/v1/gl/ai/suggest
func (h *GLHandler) AISuggest(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req glmodels.AISuggestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	suggestion, err := h.aiSvc.SuggestAccounts(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("AI suggest failed")
		response.InternalError(c, "AI suggestion failed")
		return
	}

	response.OK(c, suggestion)
}

// AnalyzeOCR handles POST /api/v1/gl/ai/ocr - accepts image upload and returns suggested entry
func (h *GLHandler) AnalyzeOCR(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	file, header, err := c.Request.FormFile("image")
	if err != nil {
		response.BadRequest(c, "no image file provided")
		return
	}
	defer file.Close()

	imageData, err := io.ReadAll(file)
	if err != nil {
		response.InternalError(c, "failed to read image file")
		return
	}

	if len(imageData) == 0 {
		response.BadRequest(c, "empty image file")
		return
	}

	suggestion, err := h.aiSvc.AnalyzeOCR(c.Request.Context(), tenantID, imageData, header.Filename)
	if err != nil {
		log.Err(err).Msg("OCR analysis failed")
		response.InternalError(c, "OCR analysis failed")
		return
	}

	response.OK(c, suggestion)
}

// ── Attachments ──

// UploadAttachment handles POST /api/v1/gl/journal-entries/:id/attachments
func (h *GLHandler) UploadAttachment(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}

	// Verify entry exists
	_, err = h.glSvc.GetJournalEntry(c.Request.Context(), entryID, tenantID)
	if err != nil {
		response.NotFound(c, "journal entry not found")
		return
	}

	// Get file from multipart form
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		response.BadRequest(c, "file is required")
		return
	}
	defer file.Close()

	// Read file content
	fileBytes := make([]byte, header.Size)
	if _, err := file.Read(fileBytes); err != nil {
		response.InternalError(c, "failed to read file")
		return
	}

	// Save to disk (in production, use S3/MinIO)
	uploadDir := "uploads/attachments"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		response.InternalError(c, "failed to create upload dir")
		return
	}

	filePath := filepath.Join(uploadDir, fmt.Sprintf("%s_%s", entryID.String(), header.Filename))
	if err := os.WriteFile(filePath, fileBytes, 0644); err != nil {
		response.InternalError(c, "failed to save file")
		return
	}

	description := c.PostForm("description")

	att := &glmodels.EntryAttachment{
		ID:          uuid.New(),
		EntryID:     entryID,
		FileName:    header.Filename,
		FileType:    header.Header.Get("Content-Type"),
		FileSize:    header.Size,
		FilePath:    filePath,
		Description: description,
		UploadedBy:  userID,
		CreatedAt:   time.Now(),
	}

	if err := h.glSvc.AddAttachment(c.Request.Context(), att); err != nil {
		response.InternalError(c, "failed to save attachment record")
		return
	}

	response.Created(c, att)
}

// GetAttachments handles GET /api/v1/gl/journal-entries/:id/attachments
func (h *GLHandler) GetAttachments(c *gin.Context) {
	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	atts, err := h.glSvc.GetAttachments(c.Request.Context(), entryID)
	if err != nil {
		response.InternalError(c, "failed to get attachments")
		return
	}

	response.OK(c, atts)
}

// DownloadAttachment handles GET /api/v1/gl/journal-entries/:id/attachments/:attachmentId/download
func (h *GLHandler) DownloadAttachment(c *gin.Context) {
	entryID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid entry id")
		return
	}

	attID, err := uuid.Parse(c.Param("attachmentId"))
	if err != nil {
		response.BadRequest(c, "invalid attachment id")
		return
	}

	att, err := h.glSvc.GetAttachmentByID(c.Request.Context(), attID, entryID)
	if err != nil {
		response.NotFound(c, "attachment not found")
		return
	}

	// Serve the file
	c.FileAttachment(att.FilePath, att.FileName)
}

// InitializeCoA handles POST /api/v1/gl/initialize-coa
func (h *GLHandler) InitializeCoA(c *gin.Context) {
	var req struct {
		CoaType        string     `json:"coa_type" binding:"required"`
		OrganizationID *uuid.UUID `json:"organization_id,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "coa_type field is required (gaap, ifrs, or china)")
		return
	}

	if err := h.glSvc.InitializeChartOfAccounts(c.Request.Context(), req.CoaType, req.OrganizationID); err != nil {
		log.Err(err).Msg("initialize COA failed")
		response.BadRequest(c, err.Error())
		return
	}

	msg := "Chart of accounts initialized successfully"
	if req.OrganizationID != nil {
		msg = fmt.Sprintf("Chart of accounts initialized for organization %s", req.OrganizationID.String()[:8])
	}
	response.OK(c, gin.H{"message": msg})
}

// ResetDatabase handles POST /api/v1/gl/reset-database
func (h *GLHandler) ResetDatabase(c *gin.Context) {
	if err := h.glSvc.ResetDatabase(c.Request.Context()); err != nil {
		log.Err(err).Msg("database reset failed")
		response.InternalError(c, "database reset failed: "+err.Error())
		return
	}

	response.OK(c, gin.H{"message": "All data cleared successfully"})
}

// ── Helpers ──

// getTenantID extracts tenant ID from the Gin context (set by auth middleware).
func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tenantIDStr := c.GetString("tenant_id")
	if tenantIDStr == "" {
		return uuid.Nil, http.ErrNoLocation
	}
	return uuid.Parse(tenantIDStr)
}

// getUserID extracts user ID from the Gin context.
func getUserID(c *gin.Context) (uuid.UUID, error) {
	userIDStr := c.GetString("user_id")
	if userIDStr == "" {
		return uuid.Nil, http.ErrNoLocation
	}
	return uuid.Parse(userIDStr)
}
