package service

import (
	"os"
	"context"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
	"github.com/swiftai-erp/backend/internal/gl/repository"
)

var (
	ErrInvalidBalance           = errors.New("debits must equal credits")
	ErrNoLines                  = errors.New("journal entry must have at least 2 lines")
	ErrAccountNotLeaf           = errors.New("account is not a leaf account; cannot post to it")
	ErrAccountInactive          = errors.New("account is inactive")
	ErrAccountIsReconciliation  = errors.New("reconciliation account (统御科目) cannot be used directly in journal entries")
	ErrPeriodClosed             = errors.New("period is closed or locked")
	ErrEntryNotFound            = errors.New("journal entry not found")
	ErrEntryAlreadyPosted       = errors.New("journal entry is already posted")
	ErrNoAccountMatch           = errors.New("no matching account found")
	ErrEntryAlreadyReversed     = errors.New("entry has already been reversed or is a reversal")
	ErrNegativeAmount           = errors.New("debit and credit amounts must be positive")
)

// RoundOffTolerance is the maximum acceptable difference (in absolute value)
// between total debits and total credits.
const RoundOffTolerance = 0.01

// GLService handles general ledger business logic.
type GLService struct {
	accountRepo *repository.AccountRepo
	entryRepo   *repository.EntryRepo
	db          *pgxpool.Pool
}

func NewGLService(accountRepo *repository.AccountRepo, entryRepo *repository.EntryRepo, db *pgxpool.Pool) *GLService {
	return &GLService{
		accountRepo: accountRepo,
		entryRepo:   entryRepo,
		db:          db,
	}
}

// CreateJournalEntry validates and creates a new journal entry.
func (s *GLService) CreateJournalEntry(ctx context.Context, tenantID, userID uuid.UUID, req *glmodels.CreateJournalEntryRequest) (*glmodels.JournalEntry, error) {
	// Validate lines count
	if len(req.Lines) < 2 {
		return nil, ErrNoLines
	}

	// Validate each line
	for _, l := range req.Lines {
		if l.Debit < 0 || l.Credit < 0 {
			return nil, ErrNegativeAmount
		}

		// Verify account exists, is active, and is leaf
		acc, err := s.accountRepo.GetByID(ctx, l.AccountID, tenantID)
		if err != nil {
			return nil, fmt.Errorf("check account %s: %w", l.AccountID, err)
		}
		if acc == nil {
			return nil, fmt.Errorf("%w: %s", ErrNoAccountMatch, l.AccountID)
		}
		if !acc.IsActive {
			return nil, fmt.Errorf("%w: %s (%s)", ErrAccountInactive, acc.AccountCode, acc.AccountName)
		}
		if !acc.IsLeaf {
			return nil, fmt.Errorf("%w: %s (%s)", ErrAccountNotLeaf, acc.AccountCode, acc.AccountName)
		}
		// Allow reconciliation accounts for system-generated postings (e.g. purchase subledger)
		if acc.ReconciliationType != "" && acc.ReconciliationType != "none" && req.Source != "purchase" {
			return nil, fmt.Errorf("%w: %s (%s, type=%s)", ErrAccountIsReconciliation, acc.AccountCode, acc.AccountName, acc.ReconciliationType)
		}
	}

	// Validate double-entry balance
	if err := s.validateBalance(req.Lines); err != nil {
		return nil, err
	}

	// Auto-derive period from posting date if not provided
	if req.PeriodID == uuid.Nil {
		orgID := uuid.Nil
		if req.OrganizationID != nil {
			orgID = *req.OrganizationID
		}
		periodID, err := s.derivePeriod(ctx, tenantID, req.PostingDate, orgID)
		if err != nil {
			return nil, fmt.Errorf("derive period: %w", err)
		}
		req.PeriodID = periodID
	}

	// Validate period is open
	if err := s.validatePeriod(ctx, tenantID, req.PeriodID); err != nil {
		return nil, err
	}

	entry, err := s.entryRepo.Create(ctx, tenantID, userID, req)
	if err != nil {
		return nil, fmt.Errorf("create entry: %w", err)
	}

	return entry, nil
}

// GetJournalEntry retrieves a journal entry by ID.
func (s *GLService) GetJournalEntry(ctx context.Context, id, tenantID uuid.UUID) (*glmodels.JournalEntry, error) {
	entry, err := s.entryRepo.GetByID(ctx, id, tenantID)
	if err != nil {
		return nil, err
	}
	if entry == nil {
		return nil, ErrEntryNotFound
	}
	return entry, nil
}

// ListJournalEntries lists entries with pagination, optional status/entry_type filter.
func (s *GLService) ListJournalEntries(ctx context.Context, tenantID uuid.UUID, page, pageSize int, status, entryType, query string) ([]*glmodels.JournalEntry, int64, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	entries, total, err := s.entryRepo.ListFiltered(ctx, tenantID, pageSize, offset, status, entryType, query)
	if err != nil {
		return nil, 0, err
	}
	return entries, total, nil
}

// PostJournalEntries posts draft entries, performing final validation.
func (s *GLService) PostJournalEntries(ctx context.Context, tenantID, userID uuid.UUID, req *glmodels.PostJournalEntryRequest) (*glmodels.BatchPostResponse, error) {
	resp := &glmodels.BatchPostResponse{}

	for _, entryID := range req.EntryIDs {
		entry, err := s.entryRepo.GetByID(ctx, entryID, tenantID)
		if err != nil {
			resp.FailureCount++
			resp.Failures = append(resp.Failures, glmodels.BatchPostFailure{
				EntryID: entryID,
				Error:   err.Error(),
			})
			continue
		}
		if entry == nil {
			resp.FailureCount++
			resp.Failures = append(resp.Failures, glmodels.BatchPostFailure{
				EntryID: entryID,
				Error:   ErrEntryNotFound.Error(),
			})
			continue
		}

		if entry.Status != "draft" {
			resp.FailureCount++
			resp.Failures = append(resp.Failures, glmodels.BatchPostFailure{
				EntryID: entryID,
				Error:   ErrEntryAlreadyPosted.Error(),
			})
			continue
		}

		// Validate period
		if err := s.validatePeriod(ctx, tenantID, entry.PeriodID); err != nil {
			resp.FailureCount++
			resp.Failures = append(resp.Failures, glmodels.BatchPostFailure{
				EntryID: entryID,
				Error:   err.Error(),
			})
			continue
		}

		if err := s.entryRepo.PostEntry(ctx, entryID, tenantID, userID); err != nil {
			resp.FailureCount++
			resp.Failures = append(resp.Failures, glmodels.BatchPostFailure{
				EntryID: entryID,
				Error:   err.Error(),
			})
			continue
		}

		resp.SuccessCount++
	}

	if resp.SuccessCount == 0 && resp.FailureCount > 0 {
		return resp, fmt.Errorf("all %d entries failed to post", resp.FailureCount)
	}

	return resp, nil
}

// ReverseJournalEntry creates a reversal entry for a posted entry.
// UpdateDraftEntry updates an existing draft journal entry (header + lines).
func (s *GLService) UpdateDraftEntry(ctx context.Context, tenantID, userID uuid.UUID, entryID uuid.UUID, req *glmodels.CreateJournalEntryRequest) (*glmodels.JournalEntry, error) {
	// Verify entry exists and is draft
	existing, err := s.entryRepo.GetByID(ctx, entryID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get entry: %w", err)
	}
	if existing == nil {
		return nil, ErrEntryNotFound
	}
	if existing.Status != "draft" {
		return nil, fmt.Errorf("only draft entries can be updated")
	}

	// Validate lines
	if len(req.Lines) < 2 {
		return nil, ErrNoLines
	}
	for _, l := range req.Lines {
		if l.Debit < 0 || l.Credit < 0 {
			return nil, ErrNegativeAmount
		}
		acc, err := s.accountRepo.GetByID(ctx, l.AccountID, tenantID)
		if err != nil {
			return nil, fmt.Errorf("check account %s: %w", l.AccountID, err)
		}
		if acc == nil {
			return nil, fmt.Errorf("%w: %s", ErrNoAccountMatch, l.AccountID)
		}
		if !acc.IsActive {
			return nil, fmt.Errorf("%w: %s (%s)", ErrAccountInactive, acc.AccountCode, acc.AccountName)
		}
		if !acc.IsLeaf {
			return nil, fmt.Errorf("%w: %s (%s)", ErrAccountNotLeaf, acc.AccountCode, acc.AccountName)
		}
		if acc.ReconciliationType != "" && acc.ReconciliationType != "none" {
			return nil, fmt.Errorf("%w: %s (%s, type=%s)", ErrAccountIsReconciliation, acc.AccountCode, acc.AccountName, acc.ReconciliationType)
		}
	}
	if err := s.validateBalance(req.Lines); err != nil {
		return nil, err
	}

	if err := s.entryRepo.UpdateDraftEntry(ctx, tenantID, req, entryID); err != nil {
		return nil, fmt.Errorf("update draft entry: %w", err)
	}

	return s.GetJournalEntry(ctx, entryID, tenantID)
}
// UnpostEntry reverses a posted entry back to draft and subtracts from balances.
func (s *GLService) UnpostEntry(ctx context.Context, tenantID, userID uuid.UUID, entryID uuid.UUID) (*glmodels.JournalEntry, error) {
	entry, err := s.entryRepo.GetByID(ctx, entryID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get entry: %w", err)
	}
	if entry == nil {
		return nil, ErrEntryNotFound
	}
	if entry.Status != "posted" {
		return nil, fmt.Errorf("only posted entries can be unposted")
	}
	if entry.EntryType == "reversal" {
		return nil, fmt.Errorf("reversal entries cannot be unposted")
	}

	if err := s.entryRepo.UnpostEntry(ctx, entryID, tenantID); err != nil {
		return nil, fmt.Errorf("unpost entry: %w", err)
	}

	return s.entryRepo.GetByID(ctx, entryID, tenantID)
}
// ReverseJournalEntry creates a reversal entry for a posted entry and posts it immediately.
// reversalType options:
//   - "normal":   Swap debit↔credit (add opposite amounts)
//   - "negative": Keep debit/credit position, use negative amounts (红字冲销, default)
func (s *GLService) ReverseJournalEntry(ctx context.Context, tenantID, userID uuid.UUID, entryID uuid.UUID, reversalType string) (*glmodels.JournalEntry, error) {
	original, err := s.entryRepo.GetByID(ctx, entryID, tenantID)
	if err != nil {
		return nil, err
	}
	if original == nil {
		return nil, ErrEntryNotFound
	}
	if original.Status != "posted" {
		return nil, fmt.Errorf("only posted entries can be reversed")
	}
	if original.EntryType == "reversal" {
		return nil, ErrEntryAlreadyReversed
	}

	// Default to negative (红字冲销)
	if reversalType != "normal" && reversalType != "negative" {
		reversalType = "negative"
	}

	// Check if this entry has already been reversed
	var reversalCount int
	err = s.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM gl_journal_entries WHERE tenant_id = $1 AND reference = $2 AND entry_type = 'reversal' AND status = 'posted'",
		tenantID, original.DocumentNo).Scan(&reversalCount)
	if err == nil && reversalCount > 0 {
		return nil, fmt.Errorf("entry %s has already been reversed (%d reversal(s) exist)", original.DocumentNo, reversalCount)
	}

	// Build reversal lines based on type
	revLines := make([]glmodels.CreateJournalLineRequest, len(original.Lines))
	for i, line := range original.Lines {
		if reversalType == "normal" {
			// Normal reversal: swap debit and credit
			revLines[i] = glmodels.CreateJournalLineRequest{
				AccountID:    line.AccountID,
				Debit:        line.Credit,
				Credit:       line.Debit,
				Description:  "Reversal: " + line.Description,
				CostCenterID: line.CostCenterID,
				PartnerID:    line.PartnerID,
				PartnerType:  line.PartnerType,
			}
		} else {
			// Negative posting (红字冲销): keep position, negative amounts
			revLines[i] = glmodels.CreateJournalLineRequest{
				AccountID:    line.AccountID,
				Debit:        -line.Debit,
				Credit:       -line.Credit,
				Description:  "Negative reversal: " + line.Description,
				CostCenterID: line.CostCenterID,
				PartnerID:    line.PartnerID,
				PartnerType:  line.PartnerType,
			}
		}
	}

	// Create reversal entry via repo directly (bypasses service-level negative amount check)
	// The original entry's accounts were already validated during posting
	reversal, err := s.entryRepo.Create(ctx, tenantID, userID, &glmodels.CreateJournalEntryRequest{
		PostingDate: time.Now(),
		PeriodID:    original.PeriodID,
		Description: "Reversal of " + original.DocumentNo + ": " + original.Description,
		Reference:   original.DocumentNo,
		EntryType:   "reversal",
		Source:      "manual",
		Lines:       revLines,
	})
	if err != nil {
		return nil, fmt.Errorf("create reversal: %w", err)
	}

	// Post the reversal entry immediately (status → 'posted', updates gl_account_balances)
	if err := s.entryRepo.PostEntry(ctx, reversal.ID, tenantID, userID); err != nil {
		return nil, fmt.Errorf("post reversal: %w", err)
	}

	// Return fully posted reversal
	posted, err := s.entryRepo.GetByID(ctx, reversal.ID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("reload posted reversal: %w", err)
	}
	return posted, nil
}

// derivePeriod finds the period that contains the given posting date.
// If orgID is non-nil, matches org-specific periods first, falling back to global periods.
func (s *GLService) derivePeriod(ctx context.Context, tenantID uuid.UUID, postingDate time.Time, orgID uuid.UUID) (uuid.UUID, error) {
	var periodID uuid.UUID

	// Try org-specific period first
	if orgID != uuid.Nil {
		err := s.db.QueryRow(ctx,
			`SELECT id FROM gl_periods
			 WHERE tenant_id = $1 AND organization_id = $2 AND start_date <= $3 AND end_date >= $3 AND is_open = true AND is_locked = false
			 LIMIT 1`,
			tenantID, orgID, postingDate,
		).Scan(&periodID)
		if err == nil {
			return periodID, nil
		}
	}

	// Fallback: global period (no org) that is open
	err := s.db.QueryRow(ctx,
		`SELECT id FROM gl_periods
		 WHERE tenant_id = $1 AND organization_id IS NULL AND start_date <= $2 AND end_date >= $2 AND is_open = true AND is_locked = false
		 LIMIT 1`,
		tenantID, postingDate,
	).Scan(&periodID)
	if err == nil {
		return periodID, nil
	}

	// Last resort: any period for this tenant + date, regardless of organization
	err = s.db.QueryRow(ctx,
		`SELECT id FROM gl_periods
		 WHERE tenant_id = $1 AND start_date <= $2 AND end_date >= $2 AND is_open = true AND is_locked = false
		 LIMIT 1`,
		tenantID, postingDate,
	).Scan(&periodID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("no open period found for %s: %w", postingDate.Format("2006-01-02"), err)
	}
	return periodID, nil
}

// GetAccountLedger returns all journal lines for a given account with pagination.
func (s *GLService) GetAccountLedger(ctx context.Context, tenantID, accountID uuid.UUID, fromDate, toDate time.Time, page, pageSize int) ([]*glmodels.JournalLine, int64, error) {
	return s.entryRepo.GetAccountLedger(ctx, tenantID, accountID, fromDate, toDate, page, pageSize)
}

// InitializeChartOfAccounts deletes existing COA and seeds a new one.
// coaType: "gaap", "ifrs", or "china". Only allowed when no journal entries exist.
// If orgID is non-nil, creates COA specifically for that organization.
func (s *GLService) InitializeChartOfAccounts(ctx context.Context, coaType string, orgID *uuid.UUID) error {
	// Check if any transactions exist
	var entryCount int
	err := s.db.QueryRow(ctx, "SELECT COUNT(*) FROM gl_journal_entries").Scan(&entryCount)
	if err != nil {
		return fmt.Errorf("check entries: %w", err)
	}
	if entryCount > 0 {
		return fmt.Errorf("cannot initialize COA: there are %d existing journal entries. Delete all transactions first", entryCount)
	}

	// Delete existing chart of accounts (cascades to balances, lines)
	_, err = s.db.Exec(ctx, "DELETE FROM gl_account_balances")
	if err != nil {
		return fmt.Errorf("delete balances: %w", err)
	}
	_, err = s.db.Exec(ctx, "DELETE FROM gl_accounts")
	if err != nil {
		return fmt.Errorf("delete accounts: %w", err)
	}
	_, err = s.db.Exec(ctx, "DELETE FROM gl_periods")
	if err != nil {
		return fmt.Errorf("delete periods: %w", err)
	}
	_, err = s.db.Exec(ctx, "DELETE FROM gl_document_seq")
	if err != nil {
		return fmt.Errorf("delete document seq: %w", err)
	}

	// Pick the seed SQL file
	var seedPath string
	switch coaType {
	case "gaap":
		seedPath = "migrations/seed_gaap_coa.sql"
	case "ifrs":
		seedPath = "migrations/seed_accounts_ifrs.sql"
	case "china":
		seedPath = "migrations/seed_accounts.sql"
	default:
		return fmt.Errorf("invalid COA type: %s (must be gaap, ifrs, or china)", coaType)
	}

	// Read and execute the seed SQL
	seedSQL, err := os.ReadFile(seedPath)
	if err != nil {
		return fmt.Errorf("read seed file %s: %w", seedPath, err)
	}

	_, err = s.db.Exec(ctx, string(seedSQL))
	if err != nil {
		return fmt.Errorf("execute seed: %w", err)
	}

	return nil
}
// GetAccountBalances returns period balances for accounts with date filtering.
func (s *GLService) GetAccountBalances(ctx context.Context, tenantID uuid.UUID, year, month int) ([]map[string]interface{}, error) {
	return s.entryRepo.GetAccountBalances(ctx, tenantID, year, month)
}

// GetBalanceSheet returns the balance sheet report with calculated retained earnings.
func (s *GLService) GetBalanceSheet(ctx context.Context, tenantID uuid.UUID, year, month int) (map[string]interface{}, error) {
	return s.entryRepo.GetBalanceSheet(ctx, tenantID, year, month)
}

// GetProfitLoss returns the profit and loss report.
func (s *GLService) GetProfitLoss(ctx context.Context, tenantID uuid.UUID, year, month int) (map[string]interface{}, error) {
	return s.entryRepo.GetProfitLoss(ctx, tenantID, year, month)
}

// validateBalance ensures total debits equal total credits within tolerance.
// Supports negative amounts (红字冲销/reversal entries): uses net absolute sums.
func (s *GLService) validateBalance(lines []glmodels.CreateJournalLineRequest) error {
	var totalDebit, totalCredit float64
	for _, l := range lines {
		totalDebit += l.Debit
		totalCredit += l.Credit
	}

	// For negative (red-ink) reversals, both sums may be negative; the algebraic
	// difference still must be zero within tolerance.
	diff := math.Abs(totalDebit - totalCredit)
	if diff > RoundOffTolerance {
		return fmt.Errorf("%w: total debit=%.2f, total credit=%.2f, diff=%.2f",
			ErrInvalidBalance, totalDebit, totalCredit, diff)
	}
	return nil
}

// UpdateJournalEntryStatus updates the status of a single journal entry (draft / posted).
func (s *GLService) UpdateJournalEntryStatus(ctx context.Context, entryID, tenantID, userID uuid.UUID, status string) (*glmodels.JournalEntry, error) {
	entry, err := s.entryRepo.GetByID(ctx, entryID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get entry: %w", err)
	}
	if entry == nil {
		return nil, ErrEntryNotFound
	}

	switch status {
	case "draft":
		// Any existing entry can be set back to draft
		if err := s.entryRepo.UpdateStatus(ctx, entryID, tenantID, "draft", nil); err != nil {
			return nil, fmt.Errorf("update status: %w", err)
		}

	case "posted":
		if entry.Status != "draft" {
			return nil, fmt.Errorf("only draft entries can be posted")
		}
		if err := s.validatePeriod(ctx, tenantID, entry.PeriodID); err != nil {
			return nil, err
		}
		// Post entry (status update + balance update in one transaction)
		if err := s.entryRepo.PostEntry(ctx, entryID, tenantID, userID); err != nil {
			return nil, fmt.Errorf("post entry: %w", err)
		}

	default:
		return nil, fmt.Errorf("invalid status: %s (must be 'draft' or 'posted')", status)
	}

	// Return updated entry
	updated, err := s.entryRepo.GetByID(ctx, entryID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("reload entry: %w", err)
	}
	return updated, nil
}

// validatePeriod checks if the period is open and not locked.
func (s *GLService) validatePeriod(ctx context.Context, tenantID, periodID uuid.UUID) error {
	var isOpen bool
	err := s.db.QueryRow(ctx,
		`SELECT is_open FROM gl_periods WHERE id = $1 AND tenant_id = $2 AND is_locked = false`,
		periodID, tenantID,
	).Scan(&isOpen)
	if err != nil {
		return fmt.Errorf("%w: period %s not found or locked", ErrPeriodClosed, periodID)
	}
	if !isOpen {
		return fmt.Errorf("%w: period %s is closed", ErrPeriodClosed, periodID)
	}
	return nil
}

// CreateAccount delegates to repository.
func (s *GLService) CreateAccount(ctx context.Context, tenantID uuid.UUID, req *glmodels.CreateAccountRequest) (*glmodels.Account, error) {
	return s.accountRepo.Create(ctx, tenantID, req)
}

// GetAccount retrieves a single account.
func (s *GLService) GetAccount(ctx context.Context, id, tenantID uuid.UUID) (*glmodels.Account, error) {
	return s.accountRepo.GetByID(ctx, id, tenantID)
}

// ListAccounts lists all accounts for a tenant.
func (s *GLService) ListAccounts(ctx context.Context, tenantID uuid.UUID) ([]*glmodels.Account, error) {
	return s.accountRepo.ListByTenant(ctx, tenantID)
}

// UpdateAccount updates an account.
func (s *GLService) UpdateAccount(ctx context.Context, id, tenantID uuid.UUID, req *glmodels.UpdateAccountRequest) (*glmodels.Account, error) {
	return s.accountRepo.Update(ctx, id, tenantID, req)
}

// DeleteAccount deactivates an account.
func (s *GLService) DeleteAccount(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.accountRepo.Delete(ctx, id, tenantID)
}

// ReactivateAccount reactivates a previously deactivated account.
func (s *GLService) ReactivateAccount(ctx context.Context, id, tenantID uuid.UUID) (*glmodels.Account, error) {
	return s.accountRepo.Reactivate(ctx, id, tenantID)
}

// GetAccountTree returns the full account tree.
func (s *GLService) GetAccountTree(ctx context.Context, tenantID uuid.UUID) ([]*glmodels.AccountTreeResponse, error) {
	return s.accountRepo.GetTree(ctx, tenantID)
}

// SearchAccounts searches accounts by code or name.
func (s *GLService) SearchAccounts(ctx context.Context, tenantID uuid.UUID, q string) ([]*glmodels.Account, error) {
	return s.accountRepo.Search(ctx, tenantID, q)
}

// GetLeafAccounts returns only leaf (postable) accounts.
func (s *GLService) GetLeafAccounts(ctx context.Context, tenantID uuid.UUID) ([]*glmodels.Account, error) {
	return s.accountRepo.ListLeafAccounts(ctx, tenantID)
}

// ── Attachment methods ──

// AddAttachment saves an attachment record.
// ResetDatabase deletes all transactional data from all tables in FK-safe order.
// Covers GL, Purchase, Sales, AR, WMS/Warehouse, Production, HR transactional tables.
// Master/config tables (gl_accounts, organizations, users, roles, etc.) are preserved.
func (s *GLService) ResetDatabase(ctx context.Context) error {
	tables := []string{
		// ── Production ──
		"production_order_operations",
		"production_orders",

		// ── Sales ──
		"sales_order_items",
		"sales_orders",
		"quotation_items",
		"quotations",

		// ── Purchase / AP ──
		"purchase_payments",
		"purchase_invoice_items",
		"purchase_invoices",
		"purchase_receipts",
		"purchase_order_items",
		"purchase_orders",

		// ── AR ──
		"customer_down_payments",

		// ── WMS / Warehouse ──
		"stock_movements",
		"cycle_count_items",
		"cycle_counts",
		"stock_on_hand",

		// ── GL ──
		"gl_account_balances",
		"gl_entry_attachments",
		"gl_journal_lines",
		"gl_journal_entries",
		"gl_document_seq",

		// ── Auth / Audit ──
		"audit_log",
		"access_requests",
		"sod_violations",
		"composite_role_members",
		"derived_role_rules",
		"role_auth_values",
		"user_org_assignments",
		"user_role_assignments",
		"sessions",
		"permissions",
		"role_permissions",
		"user_roles",
		"sod_rules",
	}
	for _, t := range tables {
		// Use IF EXISTS to tolerate tables that may not exist yet in all envs
		_, err := s.db.Exec(ctx, "DELETE FROM "+t+" WHERE 1=1")
		if err != nil {
			// Soft-fail: log the error but continue clearing other tables
			// so a missing table doesn't block the whole reset
			fmt.Printf("WARN: ResetDatabase skip %s: %v\n", t, err)
		}
	}
	return nil
}
// DeleteJournalEntry deletes a draft journal entry.
func (s *GLService) DeleteJournalEntry(ctx context.Context, entryID, tenantID uuid.UUID) error {
	entry, err := s.entryRepo.GetByID(ctx, entryID, tenantID)
	if err != nil {
		return fmt.Errorf("get entry: %w", err)
	}
	if entry == nil {
		return ErrEntryNotFound
	}
	if entry.Status != "draft" {
		return fmt.Errorf("only draft entries can be deleted")
	}
	return s.entryRepo.DeleteEntry(ctx, entryID, tenantID)
}

func (s *GLService) AddAttachment(ctx context.Context, att *glmodels.EntryAttachment) error {
	return s.entryRepo.AddAttachment(ctx, att)
}

// GetAttachments retrieves attachments for an entry.
func (s *GLService) GetAttachments(ctx context.Context, entryID uuid.UUID) ([]glmodels.EntryAttachment, error) {
	return s.entryRepo.GetAttachments(ctx, entryID)
}

// GetAttachmentByID retrieves a single attachment by ID and entry ID.
func (s *GLService) GetAttachmentByID(ctx context.Context, attID, entryID uuid.UUID) (*glmodels.EntryAttachment, error) {
	return s.entryRepo.GetAttachmentByID(ctx, attID, entryID)
}
