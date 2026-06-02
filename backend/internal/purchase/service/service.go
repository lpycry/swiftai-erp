package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
	glsvc "github.com/swiftai-erp/backend/internal/gl/service"
	purchasemodels "github.com/swiftai-erp/backend/internal/purchase/models"
	purchaserepo "github.com/swiftai-erp/backend/internal/purchase/repository"
)

type PurchaseService struct {
	db    *pgxpool.Pool
	repo  *purchaserepo.PurchaseRepo
	glSvc *glsvc.GLService
}

func NewPurchaseService(db *pgxpool.Pool, repo *purchaserepo.PurchaseRepo, glSvc *glsvc.GLService) *PurchaseService {
	return &PurchaseService{db: db, repo: repo, glSvc: glSvc}
}

// ── Vendors ──

// ── Pending Invoice POs ──

func (s *PurchaseService) ListPendingInvoicePOs(ctx context.Context, orgID uuid.UUID) ([]*purchasemodels.PurchaseOrder, error) {
	return s.repo.ListPendingInvoicePOs(ctx, orgID)
}

func (s *PurchaseService) CreateVendor(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateVendorRequest) (*purchasemodels.Vendor, error) {
	return s.repo.CreateVendor(ctx, orgID, req)
}

func (s *PurchaseService) GetVendor(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.Vendor, error) {
	return s.repo.GetVendor(ctx, id, orgID)
}

func (s *PurchaseService) ListVendors(ctx context.Context, orgID uuid.UUID, search string) ([]*purchasemodels.Vendor, error) {
	return s.repo.ListVendors(ctx, orgID, search)
}

func (s *PurchaseService) UpdateVendor(ctx context.Context, id, orgID uuid.UUID, req *purchasemodels.UpdateVendorRequest) error {
	return s.repo.UpdateVendor(ctx, id, orgID, req)
}

func (s *PurchaseService) DeleteVendor(ctx context.Context, id, orgID uuid.UUID) error {
	hasTx, err := s.repo.HasTransactions(ctx, id, orgID)
	if err != nil {
		return fmt.Errorf("check transactions: %w", err)
	}
	if hasTx {
		return fmt.Errorf("vendor has existing purchase orders, receipts or invoices; deletion blocked")
	}
	return s.repo.DeleteVendor(ctx, id, orgID)
}

func (s *PurchaseService) RecommendVendors(ctx context.Context, orgID uuid.UUID, productID uuid.UUID) ([]*purchasemodels.VendorRecommendation, error) {
	return s.repo.RecommendVendors(ctx, orgID, productID)
}

// ── Purchase Orders ──

func (s *PurchaseService) CreatePO(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreatePORequest, createdBy *uuid.UUID) (*purchasemodels.PurchaseOrder, error) {
	return s.repo.CreatePO(ctx, orgID, req, createdBy)
}

func (s *PurchaseService) GetPO(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.PurchaseOrder, error) {
	return s.repo.GetPO(ctx, id, orgID)
}

func (s *PurchaseService) ListPOs(ctx context.Context, orgID uuid.UUID, status string, vendorID uuid.UUID) ([]*purchasemodels.PurchaseOrder, error) {
	return s.repo.ListPOs(ctx, orgID, status, vendorID)
}

func (s *PurchaseService) UpdatePOStatus(ctx context.Context, id, orgID uuid.UUID, status string) error {
	return s.repo.UpdatePOStatus(ctx, id, orgID, status)
}

// ── Purchase Receipts (核心事务：收货→更新库存→业务事件→会计分录) ──

func (s *PurchaseService) ExecuteGoodsReceipt(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateReceiptRequest, userID *uuid.UUID) (*purchasemodels.PurchaseReceipt, *purchasemodels.BusinessEvent, error) {
	po, err := s.repo.GetPO(ctx, req.POID, orgID)
	if err != nil {
		return nil, nil, err
	}

	receipt, event, err := s.repo.ExecuteGoodsReceipt(ctx, orgID, req, userID, po.Status)
	if err != nil {
		return nil, nil, err
	}

	// ── Auto-create GL Journal Entry ──
	// Debit:  company-level vendor reconciliation account (from org_reconciliation_accounts)
	// Credit: vendor-specific reconciliation account (from vendors.reconciliation_account_id)
	// Amount: receipt quantity × unit_cost
	if err := s.createReceiptJournalEntry(ctx, orgID, po, req, receipt, userID); err != nil {
		// Log error but don't fail the receipt — the receipt is already recorded
		// Accounting can be fixed later via manual journal entry
		fmt.Printf("WARN: failed to create GL journal entry for receipt %s: %v\n", receipt.ID, err)
	}

	return receipt, event, nil
}

func (s *PurchaseService) createReceiptJournalEntry(ctx context.Context, orgID uuid.UUID, po *purchasemodels.PurchaseOrder, req *purchasemodels.CreateReceiptRequest, receipt *purchasemodels.PurchaseReceipt, userID *uuid.UUID) error {
	// Resolve the actual organization UUID (PO's org, not the JWT tenant_id)
	realOrgID := orgID
	if po.OrganizationID != nil && *po.OrganizationID != uuid.Nil {
		realOrgID = *po.OrganizationID
	}

	// 1. Get Inventory account (DEBIT) from org_reconciliation_accounts
	var inventoryID uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'INVENTORY'`, realOrgID).Scan(&inventoryID)
	if err != nil || inventoryID == uuid.Nil {
		return fmt.Errorf("no INVENTORY account configured for org %s in Finance Settings (Account Types tab); cannot create journal entry", realOrgID)
	}

	// 2. Get GR/IR Clearing account (CREDIT) from org_reconciliation_accounts
	var grIrID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'GR_IR'`, realOrgID).Scan(&grIrID)
	if err != nil || grIrID == uuid.Nil {
		return fmt.Errorf("no GR_IR account configured for org %s in Finance Settings (Account Types tab); cannot create journal entry", realOrgID)
	}

	// 3. Resolve tenant_id from the org for GL account lookup
	var glTenantID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT tenant_id FROM organizations WHERE id = $1`, realOrgID).Scan(&glTenantID)
	if err != nil {
		return fmt.Errorf("resolve tenant for org %s: %w", realOrgID, err)
	}

	// 4. Build journal entry
	totalAmount := receipt.Quantity * receipt.UnitCost
	description := fmt.Sprintf("Goods Receipt - PO %s / Receipt %s", po.PONumber, receipt.ID.String()[:8])
	now := time.Now()

	entryReq := &glmodels.CreateJournalEntryRequest{
		PostingDate:    now,
		Description:    description,
		Reference:      po.PONumber,
		EntryType:      "normal",
		Source:         "purchase",
		OrganizationID: &realOrgID,
		Lines: []glmodels.CreateJournalLineRequest{
			{
				AccountID:   inventoryID, // Dr: Inventory (Raw Materials)
				Debit:       totalAmount,
				Credit:      0,
				Description: fmt.Sprintf("GR: %s x %.2f @ %.2f", receipt.ItemSKU, receipt.Quantity, receipt.UnitCost),
				PartnerID:   &po.VendorID,
				PartnerType: "vendor",
			},
			{
				AccountID:   grIrID, // Cr: GR/IR Clearing (unbilled GR)
				Debit:       0,
				Credit:      totalAmount,
				Description: fmt.Sprintf("GR: %s x %.2f @ %.2f", receipt.ItemSKU, receipt.Quantity, receipt.UnitCost),
				PartnerID:   &po.VendorID,
				PartnerType: "vendor",
			},
		},
	}

	// Resolve userID — use a valid UUID from the receipt context, or fallback to any user in the same tenant
	glUserID := uuid.Nil
	if userID != nil {
		glUserID = *userID
	}
	if glUserID == uuid.Nil {
		// Fallback: find any user for this tenant
		_ = s.db.QueryRow(ctx, `SELECT id FROM users WHERE tenant_id = $1 LIMIT 1`, glTenantID).Scan(&glUserID)
	}

	// 5. Create as draft (use glTenantID for GL account lookup — NOT the org UUID)
	entry, err := s.glSvc.CreateJournalEntry(ctx, glTenantID, glUserID, entryReq)
	if err != nil {
		return fmt.Errorf("create journal entry: %w", err)
	}

	// 6. Post it immediately
	_, err = s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, glTenantID, glUserID, "posted")
	if err != nil {
		return fmt.Errorf("post journal entry: %w", err)
	}

	return nil
}

func (s *PurchaseService) ListReceipts(ctx context.Context, orgID uuid.UUID, poID uuid.UUID) ([]*purchasemodels.PurchaseReceipt, error) {
	return s.repo.ListReceipts(ctx, orgID, poID)
}

// ── Receipt Reversal ──

func (s *PurchaseService) ReverseGoodsReceipt(ctx context.Context, orgID uuid.UUID, receiptID uuid.UUID, userID *uuid.UUID) error {
	// 0. Get receipt to find PO ID
	var poID uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT po_id FROM purchase_receipts WHERE id = $1 AND org_id = $2`, receiptID, orgID).Scan(&poID)
	if err != nil {
		return fmt.Errorf("get receipt po: %w", err)
	}

	// 1. Cancel any POSTED invoices for this PO first (reverse invoice before reversing receipt)
	invRows, err := s.db.Query(ctx, `SELECT pi.id, COALESCE(pi.paid_amount, 0) FROM purchase_invoices pi WHERE pi.po_id = $1 AND pi.org_id = $2 AND pi.status = 'POSTED'`, poID, orgID)
	if err == nil {
		for invRows.Next() {
			var invID uuid.UUID
			var paidAmt float64
			if err := invRows.Scan(&invID, &paidAmt); err == nil {
				if paidAmt > 0.005 {
					invRows.Close()
					return fmt.Errorf("cannot reverse receipt: invoice %s has been paid (paid=%.2f). Reverse the payment(s) first", invID.String()[:8], paidAmt)
				}
				if cErr := s.CancelInvoice(ctx, orgID, invID, uuid.Nil); cErr != nil {
					invRows.Close()
					return fmt.Errorf("failed to cancel invoice before receipt reversal: %w", cErr)
				}
			}
		}
		invRows.Close()
	}

	// 2. Reverse receipt (PO, stock) in DB transaction
	if err := s.repo.ReverseGoodsReceipt(ctx, receiptID, orgID, userID); err != nil {
		return err
	}

	// 3. Find and reverse the GL journal entry
	je, err := s.repo.FindJournalEntryForReceipt(ctx, receiptID)
	if err == nil {
		jeID, _ := uuid.Parse(je["id"].(string))
		jeTenantID := orgID
		if err := s.db.QueryRow(ctx, `SELECT COALESCE((SELECT tenant_id FROM organizations WHERE id = $1), $1::uuid)`, orgID).Scan(&jeTenantID); err != nil {
			jeTenantID = orgID
		}
		glUserID := uuid.Nil
		if userID != nil { glUserID = *userID }
		if glUserID == uuid.Nil {
			_ = s.db.QueryRow(ctx, `SELECT id FROM users WHERE tenant_id = $1 LIMIT 1`, jeTenantID).Scan(&glUserID)
		}
		if _, err := s.glSvc.ReverseJournalEntry(ctx, jeTenantID, glUserID, jeID, "negative"); err != nil {
			fmt.Printf("WARN: failed to reverse JE %s for receipt %s: %v\n", jeID.String()[:8], receiptID.String()[:8], err)
		}
	}

	return nil
}

// ── Purchase Invoices ──

func (s *PurchaseService) CreateInvoice(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateInvoiceRequest, createdBy *uuid.UUID) (*purchasemodels.PurchaseInvoice, *purchasemodels.BusinessEvent, error) {
	invoice, event, err := s.repo.CreateInvoice(ctx, orgID, req, createdBy)
	if err != nil {
		return nil, nil, err
	}

	// Auto-post GL journal entry for matched invoices (FULL or PARTIAL)
	if invoice != nil && invoice.MatchStatus != "" && invoice.MatchStatus != "NO_MATCH" && invoice.MatchStatus != "PRICE_MISMATCH" && req.POID != nil {
		if glErr := s.createInvoiceJournalEntry(ctx, orgID, invoice, req, createdBy); glErr != nil {
			fmt.Printf("WARN: failed to create GL entry for invoice %s: %v\n", invoice.ID, glErr)
		}
	}

	return invoice, event, nil
}

func (s *PurchaseService) GetInvoice(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.PurchaseInvoice, error) {
	inv, err := s.repo.GetInvoice(ctx, id, orgID)
	if err != nil {
		return nil, err
	}
	// Load items
	items, err := s.repo.GetInvoiceItems(ctx, id)
	if err == nil {
		inv.Items = items
	}
	return inv, nil
}

func (s *PurchaseService) ListInvoices(ctx context.Context, orgID uuid.UUID, vendorID uuid.UUID) ([]*purchasemodels.PurchaseInvoice, error) {
	return s.repo.ListInvoices(ctx, orgID, vendorID)
}

func (s *PurchaseService) ListOutstandingInvoices(ctx context.Context, orgIDStr, vendorID, itemID, dateFrom, dateTo string) ([]*purchasemodels.OutstandingInvoice, error) {
	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid org id: %w", err)
	}
	var vID, iID string
	if vendorID != "" && vendorID != "all" { vID = vendorID }
	if itemID != "" && itemID != "all" { iID = itemID }
	var df, dt time.Time
	if dateFrom != "" {
		df, _ = time.Parse("2006-01-02", dateFrom)
	}
	if dateTo != "" {
		dt, _ = time.Parse("2006-01-02", dateTo)
	}
	return s.repo.ListOutstandingInvoices(ctx, orgID, vID, iID, df, dt)
}

func (s *PurchaseService) CancelInvoice(ctx context.Context, orgID, invoiceID, userID uuid.UUID) error {
	inv, err := s.repo.GetInvoice(ctx, invoiceID, orgID)
	if err != nil {
		return fmt.Errorf("get invoice: %w", err)
	}
	if inv.Status == "CANCELLED" || inv.Status == "REJECTED" {
		return fmt.Errorf("invoice %s is already %s", inv.InvoiceNumber, inv.Status)
	}

	// Check if invoice has been paid (fully or partially)
	var paidAmt float64
	_ = s.db.QueryRow(ctx, `SELECT COALESCE(paid_amount, 0) FROM purchase_invoices WHERE id = $1`, invoiceID).Scan(&paidAmt)
	if paidAmt > 0.005 {
		return fmt.Errorf("invoice %s has been paid (paid=%.2f), cannot cancel. Reverse the payment first", inv.InvoiceNumber, paidAmt)
	}

	// Reverse invoiced quantities on PO items
	items, err := s.repo.GetInvoiceItems(ctx, invoiceID)
	if err == nil {
		for _, it := range items {
			if it.POItemID != nil {
				_, _ = s.db.Exec(ctx, `UPDATE purchase_order_items SET invoiced_quantity = GREATEST(0, invoiced_quantity - $1) WHERE id = $2`,
					it.Quantity, *it.POItemID)
			}
		}
	}

	// Find and reverse the GL journal entry if invoice was posted
	var jeID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT id FROM gl_journal_entries WHERE reference = $1 AND source = 'purchase' AND status = 'posted' ORDER BY created_at DESC LIMIT 1`,
		inv.InvoiceNumber).Scan(&jeID)
	if err == nil && jeID != uuid.Nil {
		var glTenantID uuid.UUID
		_ = s.db.QueryRow(ctx, `SELECT tenant_id FROM organizations WHERE id = $1`, orgID).Scan(&glTenantID)
		if glTenantID == uuid.Nil {
			glTenantID = orgID
		}
		if _, rErr := s.glSvc.ReverseJournalEntry(ctx, glTenantID, userID, jeID, "negative"); rErr != nil {
			fmt.Printf("WARN: failed to reverse JE %s for invoice %s: %v\n", jeID.String()[:8], inv.InvoiceNumber, rErr)
		}
	}

	// Update invoice status
	_, err = s.db.Exec(ctx, `UPDATE purchase_invoices SET status = 'CANCELLED', updated_at = NOW() WHERE id = $1`, invoiceID)
	return err
}

func (s *PurchaseService) PostInvoice(ctx context.Context, orgID, invoiceID, userID uuid.UUID) error {
	// Get invoice
	inv, err := s.repo.GetInvoice(ctx, invoiceID, orgID)
	if err != nil {
		return fmt.Errorf("get invoice: %w", err)
	}

	if inv.Status == "POSTED" || inv.Status == "CLEARED" {
		return fmt.Errorf("invoice %s is already %s", inv.InvoiceNumber, inv.Status)
	}
	if inv.MatchStatus == "PRICE_MISMATCH" {
		return fmt.Errorf("invoice %s has price mismatch, cannot post until resolved", inv.InvoiceNumber)
	}

	// Build request for GL posting
	req := &purchasemodels.CreateInvoiceRequest{
		InvoiceNumber: inv.InvoiceNumber,
		VendorID:      inv.VendorID,
		POID:          inv.POID,
		TotalAmount:   inv.TotalAmount,
		TaxAmount:     inv.TaxAmount,
		Currency:      inv.Currency,
		InvoiceDate:   inv.InvoiceDate.Format("2006-01-02"),
	}

	if err := s.createInvoiceJournalEntry(ctx, orgID, inv, req, &userID); err != nil {
		return err
	}

	// Update invoice status
	_, err = s.db.Exec(ctx, `UPDATE purchase_invoices SET status = 'POSTED', updated_at = NOW() WHERE id = $1`, invoiceID)
	return err
}

func (s *PurchaseService) createInvoiceJournalEntry(ctx context.Context, invoiceOrgID uuid.UUID, invoice *purchasemodels.PurchaseInvoice, req *purchasemodels.CreateInvoiceRequest, userID *uuid.UUID) error {
	if req.POID == nil {
		return nil
	}

	// Resolve org for GL
	var realOrgID uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT COALESCE(organization_id, org_id) FROM purchase_orders WHERE id = $1`, *req.POID).Scan(&realOrgID)
	if err != nil {
		return fmt.Errorf("resolve org for po %s: %w", *req.POID, err)
	}

	// Resolve tenant
	var glTenantID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT tenant_id FROM organizations WHERE id = $1`, realOrgID).Scan(&glTenantID)
	if err != nil {
		return fmt.Errorf("resolve tenant: %w", err)
	}

	// Get GR/IR account
	var grIrID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'GR_IR'`, realOrgID).Scan(&grIrID)
	if err != nil {
		return fmt.Errorf("no GR_IR account configured: %w", err)
	}

	// Get AP reconciliation account from Finance Settings (Account Types: AP_RECON)
	var apAccountID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'AP_RECON'`, realOrgID).Scan(&apAccountID)
	if err != nil || apAccountID == uuid.Nil {
		return fmt.Errorf("no AP_RECON account configured for org %s in Finance Settings (Account Types tab)", realOrgID)
	}

	// Get PRICE_DIF account (if price diff exists)
	var priceDifID *uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'PRICE_DIF'`, realOrgID).Scan(&priceDifID)
	if err != nil {
		priceDifID = nil // optional account
	}

	// Get total price diff from invoice_items
	var totalPriceDiff float64
	_ = s.db.QueryRow(ctx, `SELECT COALESCE(SUM(price_diff),0) FROM invoice_items WHERE invoice_id = $1`, invoice.ID).Scan(&totalPriceDiff)

	// Build journal entry lines
	description := fmt.Sprintf("Invoice %s - PO %s / Vendor %s", invoice.InvoiceNumber, invoice.PONumber, req.VendorID.String()[:8])
	amount := req.TotalAmount

	// Dr: GR/IR clearing, Cr: Vendor AP (reconciliation account allowed for purchase source)
	lines := []glmodels.CreateJournalLineRequest{
		{
			AccountID:   grIrID,
			Debit:       amount,
			Credit:      0,
			Description: fmt.Sprintf("Inv %s: GR/IR clearing", invoice.InvoiceNumber),
			PartnerID:   &req.VendorID,
			PartnerType: "vendor",
		},
		{
			AccountID:   apAccountID,
			Debit:       0,
			Credit:      amount,
			Description: fmt.Sprintf("Inv %s: AP accrual", invoice.InvoiceNumber),
			PartnerID:   &req.VendorID,
			PartnerType: "vendor",
		},
	}

	// Price difference line
	if totalPriceDiff != 0 && priceDifID != nil {
		if totalPriceDiff > 0 {
			lines = append(lines, glmodels.CreateJournalLineRequest{
				AccountID:   *priceDifID,
				Debit:       totalPriceDiff,
				Credit:      0,
				Description: fmt.Sprintf("Inv %s: Price variance", invoice.InvoiceNumber),
				PartnerID:   &req.VendorID,
				PartnerType: "vendor",
			})
		} else {
			lines = append(lines, glmodels.CreateJournalLineRequest{
				AccountID:   *priceDifID,
				Debit:       0,
				Credit:      -totalPriceDiff,
				Description: fmt.Sprintf("Inv %s: Price variance", invoice.InvoiceNumber),
				PartnerID:   &req.VendorID,
				PartnerType: "vendor",
			})
		}
	}

	entryReq := &glmodels.CreateJournalEntryRequest{
		PostingDate:    invoice.InvoiceDate,
		Description:    description,
		Reference:      invoice.InvoiceNumber,
		EntryType:      "normal",
		Source:         "purchase",
		OrganizationID: &realOrgID,
		Lines:          lines,
	}

	glUserID := uuid.Nil
	if userID != nil {
		glUserID = *userID
	}

	entry, err := s.glSvc.CreateJournalEntry(ctx, glTenantID, glUserID, entryReq)
	if err != nil {
		return fmt.Errorf("create journal entry: %w", err)
	}

	_, err = s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, glTenantID, glUserID, "posted")
	if err != nil {
		return fmt.Errorf("post journal entry: %w", err)
	}

	// Update invoice status to POSTED
	_, _ = s.db.Exec(ctx, `UPDATE purchase_invoices SET status = 'POSTED', updated_at = NOW() WHERE id = $1`, invoice.ID)

	return nil
}

// ── Attachments ──

func (s *PurchaseService) InsertAttachment(ctx context.Context, orgID, poID, attachID uuid.UUID, fileName, fileType string, fileSize int64, filePath string, userID *uuid.UUID) error {
	return s.repo.InsertAttachment(ctx, orgID, poID, attachID, fileName, fileType, fileSize, filePath, userID)
}

func (s *PurchaseService) ListAttachments(ctx context.Context, orgID, poID uuid.UUID) ([]map[string]interface{}, error) {
	return s.repo.ListAttachments(ctx, orgID, poID)
}

func (s *PurchaseService) GetAttachment(ctx context.Context, orgID, poID, attachID uuid.UUID) (map[string]interface{}, error) {
	return s.repo.GetAttachment(ctx, orgID, poID, attachID)
}

// ── Receipt → Journal Entry ──

// ── Down Payments ──

func (s *PurchaseService) CreateDownPayment(ctx context.Context, orgID uuid.UUID, req *purchasemodels.CreateDownPaymentRequest, userID *uuid.UUID) (*purchasemodels.DownPayment, error) {
	// 1. Ensure DP tables exist
	if err := s.repo.EnsureDownPaymentTable(ctx); err != nil {
		return nil, fmt.Errorf("ensure dp table: %w", err)
	}

	// 2. Validate PO exists and get its details
	po, err := s.repo.GetPO(ctx, req.POID, orgID)
	if err != nil {
		return nil, fmt.Errorf("get po: %w", err)
	}

	// 3. Get vendor for reconciliation account details
	vendor, err := s.repo.GetVendor(ctx, req.VendorID, orgID)
	if err != nil {
		return nil, fmt.Errorf("get vendor: %w", err)
	}
	if !vendor.IsActive {
		return nil, fmt.Errorf("vendor %s is inactive", vendor.VendorCode)
	}

	currency := req.Currency
	if currency == "" {
		currency = po.Currency
	}
	if currency == "" {
		currency = "USD"
	}

	exchangeRate := req.ExchangeRate
	if exchangeRate <= 0 {
		exchangeRate = 1
	}

	// 4. Resolve real org ID for GL posting
	realOrgID := orgID
	if po.OrganizationID != nil && *po.OrganizationID != uuid.Nil {
		realOrgID = *po.OrganizationID
	}

	// 5. Resolve tenant_id for GL account lookup
	var glTenantID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT COALESCE((SELECT tenant_id FROM organizations WHERE id = $1), $1::uuid)`, realOrgID).Scan(&glTenantID)
	if err != nil {
		glTenantID = realOrgID
	}

	// 6. Get AP_DP account from org_reconciliation_accounts
	var apDpAccountID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'AP_DP'`, realOrgID).Scan(&apDpAccountID)
	if err != nil {
		// Fallback: try tenant-level lookup
		err = s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'AP_DP'`, glTenantID).Scan(&apDpAccountID)
		if err != nil {
			return nil, fmt.Errorf("no AP_DP (预付款统驭科目) configured for org %s (or tenant %s). Go to Finance Settings > Account Types to add one", realOrgID, glTenantID)
		}
	}

	// 7. Generate DP number: DP-YYYYMMDD-XXXX
	dpNumber := s.generateDPNumber(ctx)

	// 8. Create DP record
	dpID := uuid.New()
	now := time.Now()
	paymentStatus := "UNPAID"
	dpStatus := "DRAFT"
	if req.PostImmediately {
		dpStatus = "POSTED"
		paymentStatus = "PAID"
	}

	dp := &purchasemodels.DownPayment{
		ID:                 dpID,
		OrgID:              orgID,
		DPNumber:           dpNumber,
		VendorID:           req.VendorID,
		POID:               req.POID,
		TotalAmount:        req.Amount,
		PaidAmount:         req.Amount,
		RefundedAmount:     0,
		ClearedAmount:      0,
		RemainingAmount:    req.Amount,
		Currency:           currency,
		ExchangeRate:       exchangeRate,
		APDPAccountID:      apDpAccountID,
		CreditAccountID:    req.CreditAccountID,
		Status:             dpStatus,
		PaymentStatus:      paymentStatus,
		Description:        req.Description,
		ReferenceNo:        req.ReferenceNo,
		SpecialGLIndicator: "A",
		CreatedBy:          userID,
		CreatedAt:          now,
	}

	if err := s.repo.CreateDownPayment(ctx, orgID, dp, nil); err != nil {
		return nil, fmt.Errorf("create dp: %w", err)
	}

	// 9. If post_immediately, create and post the JE
	if req.PostImmediately {
		glUserID := uuid.Nil
		if userID != nil {
			glUserID = *userID
		}
		if glUserID == uuid.Nil {
			_ = s.db.QueryRow(ctx, `SELECT id FROM users WHERE tenant_id = $1 LIMIT 1`, glTenantID).Scan(&glUserID)
		}

		description := fmt.Sprintf("Down Payment %s - PO %s / Vendor %s", dpNumber, po.PONumber, vendor.Name)
		entryReq := &glmodels.CreateJournalEntryRequest{
			PostingDate:    now,
			Description:    description,
			Reference:      dpNumber,
			EntryType:      "normal",
			Source:         "purchase",
			OrganizationID: &realOrgID,
			Lines: []glmodels.CreateJournalLineRequest{
				{
					AccountID:   apDpAccountID,
					Debit:       req.Amount,
					Credit:      0,
					Description: fmt.Sprintf("DP %s: Prepayment to %s", dpNumber, vendor.Name),
					PartnerID:   &req.VendorID,
					PartnerType: "vendor",
				},
				{
					AccountID:   req.CreditAccountID,
					Debit:       0,
					Credit:      req.Amount,
					Description: fmt.Sprintf("DP %s: Payment source", dpNumber),
					PartnerID:   &req.VendorID,
					PartnerType: "vendor",
				},
			},
		}

		entry, err := s.glSvc.CreateJournalEntry(ctx, glTenantID, glUserID, entryReq)
		if err != nil {
			return nil, fmt.Errorf("create journal entry: %w", err)
		}

		_, err = s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, glTenantID, glUserID, "posted")
		if err != nil {
			return nil, fmt.Errorf("post journal entry: %w", err)
		}

		// Link GL JE to DP
		_ = s.repo.UpdateDownPaymentGLJE(ctx, dpID, entry.ID, nil, &glUserID, nil)

		// Reload to get updated fields
		dp, err = s.repo.GetDownPayment(ctx, dpID, orgID)
		if err != nil {
			return nil, err
		}
	}

	return dp, nil
}

func (s *PurchaseService) generateDPNumber(ctx context.Context) string {
	today := time.Now().Format("20060102")
	var seq int
	_ = s.db.QueryRow(ctx, `
		SELECT COALESCE(MAX(CAST(SUBSTRING(dp_number FROM '....$') AS INTEGER)), 0) + 1
		FROM down_payments WHERE dp_number LIKE $1
	`, "DP-"+today+"-%").Scan(&seq)
	if seq < 1 {
		seq = 1
	}
	if seq > 9999 {
		seq = 1 // wrap around
	}
	return fmt.Sprintf("DP-%s-%04d", today, seq)
}

func (s *PurchaseService) PostDownPayment(ctx context.Context, orgID uuid.UUID, dpID uuid.UUID, userID *uuid.UUID) (*purchasemodels.DownPayment, error) {
	dp, err := s.repo.GetDownPayment(ctx, dpID, orgID)
	if err != nil {
		return nil, fmt.Errorf("get down payment: %w", err)
	}
	if dp.Status != "DRAFT" {
		return nil, fmt.Errorf("down payment %s is already %s, cannot post", dp.DPNumber, dp.Status)
	}

	// Resolve tenant ID (fallback to orgID itself if organizations table has no entry)
	var glTenantID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT COALESCE((SELECT tenant_id FROM organizations WHERE id = $1), $1::uuid)`, orgID).Scan(&glTenantID)
	if err != nil {
		glTenantID = orgID
	}

	// Resolve userID
	glUserID := uuid.Nil
	if userID != nil {
		glUserID = *userID
	}
	if glUserID == uuid.Nil {
		_ = s.db.QueryRow(ctx, `SELECT id FROM users WHERE tenant_id = $1 LIMIT 1`, glTenantID).Scan(&glUserID)
	}

	// Create Journal Entry: Dr AP_DP (prepayment reconciliation account), Cr user-specified account
	description := fmt.Sprintf("Down Payment %s - PO %s / Vendor %s", dp.DPNumber, dp.PONumber, dp.VendorName)
	entryReq := &glmodels.CreateJournalEntryRequest{
		PostingDate:    time.Now(),
		Description:    description,
		Reference:      dp.DPNumber,
		EntryType:      "normal",
		Source:         "purchase",
		Lines: []glmodels.CreateJournalLineRequest{
			{
				AccountID:   dp.APDPAccountID, // Dr: AP_DP (vendor prepayment reconciliation)
				Debit:       dp.TotalAmount,
				Credit:      0,
				Description: fmt.Sprintf("DP %s: Prepayment to vendor", dp.DPNumber),
				PartnerID:   &dp.VendorID,
				PartnerType: "vendor",
			},
			{
				AccountID:   dp.CreditAccountID, // Cr: user-selected account (bank/cash)
				Debit:       0,
				Credit:      dp.TotalAmount,
				Description: fmt.Sprintf("DP %s: Payment source", dp.DPNumber),
				PartnerID:   &dp.VendorID,
				PartnerType: "vendor",
			},
		},
	}

	entry, err := s.glSvc.CreateJournalEntry(ctx, glTenantID, glUserID, entryReq)
	if err != nil {
		return nil, fmt.Errorf("create journal entry: %w", err)
	}

	// Post the journal entry immediately
	_, err = s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, glTenantID, glUserID, "posted")
	if err != nil {
		return nil, fmt.Errorf("post journal entry: %w", err)
	}

	// Update DP: status -> POSTED, payment_status -> PAID, link JE
	paymentStatus := "PAID"
	err = s.repo.UpdateDownPaymentStatus(ctx, dpID, "POSTED", paymentStatus, 0, nil)
	if err != nil {
		return nil, fmt.Errorf("update dp status: %w", err)
	}

	// Link GL JE
	glJEID := entry.ID
	updatedBy := glUserID
	err = s.repo.UpdateDownPaymentGLJE(ctx, dpID, glJEID, nil, &updatedBy, nil)
	if err != nil {
		return nil, fmt.Errorf("link gl je: %w", err)
	}

	return s.repo.GetDownPayment(ctx, dpID, orgID)
}

func (s *PurchaseService) DeleteDownPayment(ctx context.Context, id, orgID uuid.UUID) error {
	return s.repo.DeleteDownPayment(ctx, id, orgID)
}

func (s *PurchaseService) ListDownPayments(ctx context.Context, orgID uuid.UUID, vendorID uuid.UUID, status, dateFrom, dateTo string, minAmount, maxAmount float64) ([]*purchasemodels.DownPayment, error) {
	return s.repo.ListDownPayments(ctx, orgID, vendorID, status, dateFrom, dateTo, minAmount, maxAmount)
}

func (s *PurchaseService) GetDownPayment(ctx context.Context, id, orgID uuid.UUID) (*purchasemodels.DownPayment, error) {
	return s.repo.GetDownPayment(ctx, id, orgID)
}

func (s *PurchaseService) RefundDownPayment(ctx context.Context, orgID uuid.UUID, dpID uuid.UUID, req *purchasemodels.CreateDownPaymentRefundRequest, userID *uuid.UUID) (*purchasemodels.DownPayment, error) {
	dp, err := s.repo.GetDownPayment(ctx, dpID, orgID)
	if err != nil {
		return nil, fmt.Errorf("get down payment: %w", err)
	}

	// Validate refund amount
	if req.RefundAmount > dp.RemainingAmount {
		return nil, fmt.Errorf("refund amount %.2f exceeds remaining amount %.2f", req.RefundAmount, dp.RemainingAmount)
	}

	if dp.PaymentStatus != "PAID" {
		return nil, fmt.Errorf("down payment %s has not been paid yet (status: %s)", dp.DPNumber, dp.PaymentStatus)
	}

	// Resolve tenant
	var glTenantID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT COALESCE((SELECT tenant_id FROM organizations WHERE id = $1), $1::uuid)`, orgID).Scan(&glTenantID)
	if err != nil {
		glTenantID = orgID
	}

	glUserID := uuid.Nil
	if userID != nil {
		glUserID = *userID
	}
	if glUserID == uuid.Nil {
		_ = s.db.QueryRow(ctx, `SELECT id FROM users WHERE tenant_id = $1 LIMIT 1`, glTenantID).Scan(&glUserID)
	}

	refundDate := time.Now()
	if req.RefundDate != "" {
		if parsed, err := time.Parse("2006-01-02", req.RefundDate); err == nil {
			refundDate = parsed
		}
	}

	// Create refund journal entry: Dr credit account (reverse of original Cr), Cr AP_DP (reverse of original Dr)
	description := fmt.Sprintf("Down Payment Refund %s - %s", dp.DPNumber, req.Reason)
	entryReq := &glmodels.CreateJournalEntryRequest{
		PostingDate:    refundDate,
		Description:    description,
		Reference:      dp.DPNumber,
		EntryType:      "normal",
		Source:         "purchase",
		Lines: []glmodels.CreateJournalLineRequest{
			{
				AccountID:   dp.CreditAccountID, // Dr: original credit account (money comes back)
				Debit:       req.RefundAmount,
				Credit:      0,
				Description: fmt.Sprintf("DP Refund %s: Refund from vendor", dp.DPNumber),
				PartnerID:   &dp.VendorID,
				PartnerType: "vendor",
			},
			{
				AccountID:   dp.APDPAccountID, // Cr: AP_DP (reduce prepayment)
				Debit:       0,
				Credit:      req.RefundAmount,
				Description: fmt.Sprintf("DP Refund %s: Reverse prepayment", dp.DPNumber),
				PartnerID:   &dp.VendorID,
				PartnerType: "vendor",
			},
		},
	}

	entry, err := s.glSvc.CreateJournalEntry(ctx, glTenantID, glUserID, entryReq)
	if err != nil {
		return nil, fmt.Errorf("create refund journal entry: %w", err)
	}

	_, err = s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, glTenantID, glUserID, "posted")
	if err != nil {
		return nil, fmt.Errorf("post refund journal entry: %w", err)
	}

	// Create refund record
	refundID := uuid.New()
	refund := &purchasemodels.DownPaymentRefund{
		ID:               refundID,
		DPID:             dpID,
		RefundAmount:     req.RefundAmount,
		RefundDate:       refundDate,
		RefundMethod:     req.RefundMethod,
		SourceAccountID:  req.SourceAccountID,
		GLJEID:           &entry.ID,
		Reason:           req.Reason,
		CreatedBy:        userID,
		CreatedAt:        time.Now(),
	}
	if err := s.repo.CreateDownPaymentRefund(ctx, refund); err != nil {
		return nil, fmt.Errorf("create refund record: %w", err)
	}

	// Update DP: refunded_amount += refund, remaining_amount -= refund, status
	newRefundedAmount := dp.RefundedAmount + req.RefundAmount
	newRemainingAmount := dp.RemainingAmount - req.RefundAmount

	// Determine new status
	newStatus := "POSTED"
	newPaymentStatus := "PAID"
	if newRemainingAmount <= 0.001 {
		newStatus = "FULLY_REFUNDED"
		newPaymentStatus = "REFUNDED"
	} else {
		newStatus = "PARTIALLY_REFUNDED"
	}

	// Update refunded amount and remaining amount directly
	_, err = s.db.Exec(ctx, `
		UPDATE down_payments SET refunded_amount = $2, remaining_amount = $3, status = $4, payment_status = $5, updated_at = NOW()
		WHERE id = $1
	`, dpID, newRefundedAmount, newRemainingAmount, newStatus, newPaymentStatus)
	if err != nil {
		return nil, fmt.Errorf("update dp after refund: %w", err)
	}

	return s.repo.GetDownPayment(ctx, dpID, orgID)
}

// ReverseDownPayment reverses a posted down payment using 红字冲销 (negative reversal).
// Creates a reversal journal entry (negative amounts) on the original DP JE and marks the DP as REVERSED.
func (s *PurchaseService) ReverseDownPayment(ctx context.Context, orgID uuid.UUID, dpID uuid.UUID, userID *uuid.UUID) (*purchasemodels.DownPayment, error) {
	dp, err := s.repo.GetDownPayment(ctx, dpID, orgID)
	if err != nil {
		return nil, fmt.Errorf("get down payment: %w", err)
	}

	// Only POSTED or PARTIALLY_CLEARED DPs without refunds can be reversed
	if dp.Status != "POSTED" && dp.Status != "PARTIALLY_CLEARED" {
		return nil, fmt.Errorf("down payment %s is in status %s, cannot reverse", dp.DPNumber, dp.Status)
	}
	if dp.RefundedAmount > 0 {
		return nil, fmt.Errorf("down payment %s has refunds (%s), cannot reverse", dp.DPNumber, dp.Status)
	}

	// Resolve tenant
	var glTenantID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT COALESCE((SELECT tenant_id FROM organizations WHERE id = $1), $1::uuid)`, orgID).Scan(&glTenantID)
	if err != nil {
		glTenantID = orgID
	}

	glUserID := uuid.Nil
	if userID != nil {
		glUserID = *userID
	}
	if glUserID == uuid.Nil {
		_ = s.db.QueryRow(ctx, `SELECT id FROM users WHERE tenant_id = $1 LIMIT 1`, glTenantID).Scan(&glUserID)
	}

	// Reverse the original DP journal entry (红字冲销: negative amounts)
	if dp.GLJEID != nil {
		if _, err := s.glSvc.ReverseJournalEntry(ctx, glTenantID, glUserID, *dp.GLJEID, "negative"); err != nil {
			return nil, fmt.Errorf("reverse DP journal entry: %w", err)
		}
	}

	// Update DP status to REVERSED, remaining amount to 0
	var newPaymentStatus string
	if dp.PaymentStatus == "PAID" {
		newPaymentStatus = "REVERSED"
	} else {
		newPaymentStatus = dp.PaymentStatus
	}
	_, err = s.db.Exec(ctx, `
		UPDATE down_payments SET status = $2, payment_status = $3, remaining_amount = 0, updated_at = NOW()
		WHERE id = $1
	`, dpID, "REVERSED", newPaymentStatus)
	if err != nil {
		return nil, fmt.Errorf("update dp status after reversal: %w", err)
	}

	return s.repo.GetDownPayment(ctx, dpID, orgID)
}

func (s *PurchaseService) GetDPClearings(ctx context.Context, dpID uuid.UUID) ([]*purchasemodels.DownPaymentClearing, error) {
	return s.repo.ListDPClearings(ctx, dpID)
}

func (s *PurchaseService) FindJournalEntryForReceipt(ctx context.Context, receiptID uuid.UUID) (map[string]interface{}, error) {
	je, err := s.repo.FindJournalEntryForReceipt(ctx, receiptID)
	if err != nil {
		return nil, err
	}
	jeID, _ := uuid.Parse(je["id"].(string))
	lines, err := s.repo.GetJournalEntryLines(ctx, jeID)
	if err != nil {
		return nil, err
	}
	je["lines"] = lines
	return je, nil
}

// ══════════════════════════════════════════
//  VENDOR PAYMENTS & AUTO-CLEARING
// ══════════════════════════════════════════

func (s *PurchaseService) ListPaymentHistory(ctx context.Context, orgIDStr, vendorID, dateFrom, dateTo string) ([]*purchasemodels.PaymentHistoryItem, error) {
	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid org id: %w", err)
	}
	var vID string
	if vendorID != "" && vendorID != "all" { vID = vendorID }
	var df, dt time.Time
	if dateFrom != "" {
		df, _ = time.Parse("2006-01-02", dateFrom)
	}
	if dateTo != "" {
		dt, _ = time.Parse("2006-01-02", dateTo)
	}
	return s.repo.ListPaymentHistory(ctx, orgID, vID, df, dt)
}

func (s *PurchaseService) GetVendorOpenItems(ctx context.Context, vendorIDStr, orgIDStr string) ([]*purchasemodels.OpenItem, error) {
	vendorID, err := uuid.Parse(vendorIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid vendor id: %w", err)
	}
	orgID, err := uuid.Parse(orgIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid org id: %w", err)
	}
	return s.repo.GetVendorOpenItems(ctx, vendorID, orgID)
}

func (s *PurchaseService) CreateVendorPayment(ctx context.Context, req *purchasemodels.CreateVendorPaymentRequest, userID *uuid.UUID) (*purchasemodels.VendorPayment, error) {
	vendorID, err := uuid.Parse(req.VendorID)
	if err != nil {
		return nil, fmt.Errorf("invalid vendor id: %w", err)
	}
	orgID, err := uuid.Parse(req.OrgID)
	if err != nil {
		return nil, fmt.Errorf("invalid org id: %w", err)
	}
	bankAcctID, err := uuid.Parse(req.BankAccountID)
	if err != nil {
		return nil, fmt.Errorf("invalid bank account id: %w", err)
	}

	// Resolve tenant
	var glTenantID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT COALESCE((SELECT tenant_id FROM organizations WHERE id = $1), $1::uuid)`, orgID).Scan(&glTenantID)
	if err != nil {
		glTenantID = orgID
	}

	glUserID := uuid.Nil
	if userID != nil {
		glUserID = *userID
	}
	if glUserID == uuid.Nil {
		_ = s.db.QueryRow(ctx, `SELECT id FROM users WHERE tenant_id = $1 LIMIT 1`, glTenantID).Scan(&glUserID)
	}

	// Load open items to validate selections
	openItems, err := s.repo.GetVendorOpenItems(ctx, vendorID, orgID)
	if err != nil {
		return nil, fmt.Errorf("get open items: %w", err)
	}

	// Build lookup
	itemMap := make(map[string]*purchasemodels.OpenItem)
	for _, item := range openItems {
		itemMap[item.ID] = item
	}

	// Validate selected items and compute allocations
	var totalAllocated float64
	type allocation struct {
		sourceType string
		sourceID   uuid.UUID
		amount     float64
	}
	var allocs []allocation

	// Prioritize: down payments first (prepayment deduction), then invoices
	var selectedDPs []string
	var selectedInvs []string
	for _, sid := range req.SelectedItemIDs {
		item, ok := itemMap[sid]
		if !ok {
			return nil, fmt.Errorf("selected item %s not found in open items", sid)
		}
		if item.IsDownPayment {
			selectedDPs = append(selectedDPs, sid)
		} else {
			selectedInvs = append(selectedInvs, sid)
		}
	}

	// 1) First allocate to down payments (prepayment deduction)
	remainingAmount := req.PaymentAmount
	for _, dpID := range selectedDPs {
		item := itemMap[dpID]
		allocAmt := min(item.OpenAmount, remainingAmount)
		if allocAmt <= 0 {
			continue
		}
		parsedID, _ := uuid.Parse(dpID)
		allocs = append(allocs, allocation{sourceType: "DOWN_PAYMENT", sourceID: parsedID, amount: allocAmt})
		totalAllocated += allocAmt
		remainingAmount -= allocAmt
	}

	// 2) Then allocate to invoices (net payment)
	for _, invID := range selectedInvs {
		item := itemMap[invID]
		allocAmt := min(item.OpenAmount, remainingAmount)
		if allocAmt <= 0 {
			continue
		}
		parsedID, _ := uuid.Parse(invID)
		allocs = append(allocs, allocation{sourceType: "INVOICE", sourceID: parsedID, amount: allocAmt})
		totalAllocated += allocAmt
		remainingAmount -= allocAmt
	}

	if remainingAmount > 0.01 {
		return nil, fmt.Errorf("payment amount $%.2f exceeds total open amount of selected items", req.PaymentAmount)
	}

	// Get vendor info for description
	var vendorName string
	_ = s.db.QueryRow(ctx, `SELECT name FROM vendors WHERE id = $1`, vendorID).Scan(&vendorName)

	paymentDate := time.Now()
	if req.PaymentDate != "" {
		if parsed, err := time.Parse("2006-01-02", req.PaymentDate); err == nil {
			paymentDate = parsed
		}
	}

	description := req.Description
	if description == "" {
		description = fmt.Sprintf("Vendor Payment - %s", vendorName)
	}

	// Create journal entry
	// Dr AP control account (invoice total) / Dr Down Payment (DP deduction)
	// Cr Bank account
	// Get AP reconciliation account from Finance Settings (Account Types: AP_RECON)
	var realOrgID uuid.UUID
	_ = s.db.QueryRow(ctx, `SELECT id FROM organizations WHERE tenant_id = $1 LIMIT 1`, glTenantID).Scan(&realOrgID)
	if realOrgID == uuid.Nil {
		realOrgID = orgID
	}
	var apAccountID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'AP_RECON'`, realOrgID).Scan(&apAccountID)
	if err != nil || apAccountID == uuid.Nil {
		return nil, fmt.Errorf("no AP_RECON account configured for org %s in Finance Settings (Account Types tab)", realOrgID)
	}

	// Build journal lines: for each allocation, create a Dr line
	jeLines := []glmodels.CreateJournalLineRequest{}
	for _, alloc := range allocs {
		var lineDesc string
		if alloc.sourceType == "DOWN_PAYMENT" {
			lineDesc = fmt.Sprintf("DP clearing: %s", alloc.sourceID.String()[:8])
			// Dr the AP-DP account (reduce prepayment)
			jeLines = append(jeLines, glmodels.CreateJournalLineRequest{
				AccountID:   apAccountID,
				Debit:       alloc.amount,
				Credit:      0,
				Description: lineDesc,
				PartnerID:   &vendorID,
				PartnerType: "vendor",
			})
		} else {
			lineDesc = fmt.Sprintf("Invoice payment: %s", alloc.sourceID.String()[:8])
			jeLines = append(jeLines, glmodels.CreateJournalLineRequest{
				AccountID:   apAccountID,
				Debit:       alloc.amount,
				Credit:      0,
				Description: lineDesc,
				PartnerID:   &vendorID,
				PartnerType: "vendor",
			})
		}
	}
	// Cr Bank account (total payment)
	jeLines = append(jeLines, glmodels.CreateJournalLineRequest{
		AccountID:   bankAcctID,
		Debit:       0,
		Credit:      totalAllocated,
		Description: fmt.Sprintf("Vendor payment to %s", vendorName),
		PartnerID:   &vendorID,
		PartnerType: "vendor",
	})

	entryReq := &glmodels.CreateJournalEntryRequest{
		PostingDate: paymentDate,
		Description: description,
		Reference:   fmt.Sprintf("PMT-%s", time.Now().Format("20060102-150405")),
		EntryType:   "normal",
		Source:      "purchase",
		Lines:       jeLines,
	}

	entry, err := s.glSvc.CreateJournalEntry(ctx, glTenantID, glUserID, entryReq)
	if err != nil {
		return nil, fmt.Errorf("create payment journal entry: %w", err)
	}

	_, err = s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, glTenantID, glUserID, "posted")
	if err != nil {
		return nil, fmt.Errorf("post payment journal entry: %w", err)
	}

	now := time.Now()
	payment := &purchasemodels.VendorPayment{
		ID:            uuid.New(),
		OrgID:         orgID,
		VendorID:      vendorID,
		BankAccountID: bankAcctID,
		PaymentAmount: totalAllocated,
		PaymentDate:   paymentDate,
		Currency:      "USD",
		Status:        "POSTED",
		GLJEID:        &entry.ID,
		Description:   description,
		CreatedBy:     userID,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	// Save payment record
	if err := s.repo.CreateVendorPayment(ctx, payment); err != nil {
		return nil, fmt.Errorf("create payment record: %w", err)
	}

	// Save allocations and update source documents
	for _, alloc := range allocs {
		allocRec := &purchasemodels.VendorPaymentAllocation{
			ID:              uuid.New(),
			PaymentID:       payment.ID,
			SourceType:      alloc.sourceType,
			SourceID:        alloc.sourceID,
			AllocatedAmount: alloc.amount,
			CreatedAt:       now,
		}
		if err := s.repo.CreateVendorPaymentAllocation(ctx, allocRec); err != nil {
			return nil, fmt.Errorf("create allocation record: %w", err)
		}

		// Update source document paid/cleared amounts
		if alloc.sourceType == "INVOICE" {
			currentPaid, _ := s.repo.GetInvoicePaidAmount(ctx, alloc.sourceID)
			if err := s.repo.UpdateInvoicePaidAmount(ctx, alloc.sourceID, currentPaid+alloc.amount); err != nil {
				return nil, fmt.Errorf("update invoice paid amount: %w", err)
			}
		} else if alloc.sourceType == "DOWN_PAYMENT" {
			dp, err := s.repo.GetDownPayment(ctx, alloc.sourceID, orgID)
			if err != nil {
				continue
			}
			newCleared := dp.ClearedAmount + alloc.amount
			newRemaining := dp.RemainingAmount - alloc.amount
			newStatus := dp.Status
			if newRemaining <= 0.001 {
				newStatus = "FULLY_CLEARED"
			} else if newStatus != "PARTIALLY_CLEARED" {
				newStatus = "PARTIALLY_CLEARED"
			}
			_ = s.repo.UpdateDownPaymentCleared(ctx, alloc.sourceID, newCleared, newRemaining, newStatus)
		}
	}

	return s.repo.GetVendorPayment(ctx, payment.ID)
}
