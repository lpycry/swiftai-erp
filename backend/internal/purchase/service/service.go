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
	// 1. Reverse receipt (PO, stock) in DB transaction
	if err := s.repo.ReverseGoodsReceipt(ctx, receiptID, orgID, userID); err != nil {
		return err
	}

	// 2. Find and reverse the GL journal entry
	je, err := s.repo.FindJournalEntryForReceipt(ctx, receiptID)
	if err == nil {
		jeID, _ := uuid.Parse(je["id"].(string))
		jeTenantID := orgID
		// Try to resolve tenant_id for GL reversal
		if err := s.db.QueryRow(ctx, `SELECT COALESCE(tenant_id, $1) FROM organizations WHERE id = $1`, orgID).Scan(&jeTenantID); err != nil {
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

	// Get AP account from vendor
	var apAccountID uuid.UUID
	err = s.db.QueryRow(ctx, `SELECT reconciliation_account_id FROM vendors WHERE id = $1`, req.VendorID).Scan(&apAccountID)
	if err != nil {
		return fmt.Errorf("no reconciliation account for vendor %s: %w", req.VendorID, err)
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
			// Invoice price > PO price → Dr PRICE_DIF
			lines = append(lines, glmodels.CreateJournalLineRequest{
				AccountID:   *priceDifID,
				Debit:       totalPriceDiff,
				Credit:      0,
				Description: fmt.Sprintf("Inv %s: Price variance", invoice.InvoiceNumber),
				PartnerID:   &req.VendorID,
				PartnerType: "vendor",
			})
		} else {
			// Invoice price < PO price → Cr PRICE_DIF
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
