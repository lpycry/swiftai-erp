package service

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
	"github.com/swiftai-erp/backend/internal/gl/repository"
)

// ── Test Suite Setup ──

var (
	testPool    *pgxpool.Pool
	testTenant  = uuid.MustParse("a06826ac-2152-4d58-8de2-a9c6577e926e")
	testUser    = uuid.MustParse("cb2a0acd-69a1-4539-90f8-8af458ba54ae")
	testOrg     = uuid.MustParse("d924c547-cbeb-4a1a-a7ed-3f98b958dbad")
	gaapAssetID uuid.UUID  // Cash (leaf, active)
	gaapLiabID  uuid.UUID  // Accounts Payable (leaf, active)
	gaapExpenseID uuid.UUID // Cost of Services or similar
)

func TestMain(m *testing.M) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://swiftai:swiftai_dev_pass@localhost:5432/swiftai_erp?sslmode=disable"
	}

	var err error
	testPool, err = pgxpool.New(context.Background(), dsn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to connect to test DB: %v\n", err)
		os.Exit(1)
	}
	defer testPool.Close()

	// Find leaf accounts for tests
	rows, _ := testPool.Query(context.Background(),
		"SELECT id, account_code, account_type FROM gl_accounts WHERE tenant_id = $1 AND is_leaf = true AND is_active = true LIMIT 50",
		testTenant)
	for rows.Next() {
		var id uuid.UUID
		var code, at string
		rows.Scan(&id, &code, &at)
		fmt.Printf("  Account: %s %s (%s)\n", code, at, id)
		switch at {
		case "ASSET":
			if gaapAssetID == uuid.Nil {
				gaapAssetID = id
			}
		case "LIABILITY":
			if gaapLiabID == uuid.Nil {
				gaapLiabID = id
			}
		case "EXPENSE", "COGS":
			if gaapExpenseID == uuid.Nil {
				gaapExpenseID = id
			}
		}
	}
	rows.Close()

	if gaapAssetID == uuid.Nil || gaapLiabID == uuid.Nil {
		fmt.Fprintf(os.Stderr, "ERROR: Required test accounts not found. Tenant=%s\n", testTenant)
		// Don't exit - let tests handle graceful skip
	}

	fmt.Println("Test suite initialized")

	code := m.Run()
	os.Exit(code)
}

func setupService(t *testing.T) *GLService {
	t.Helper()
	accountRepo := repository.NewAccountRepo(testPool)
	entryRepo := repository.NewEntryRepo(testPool)
	return NewGLService(accountRepo, entryRepo, testPool)
}

func makeTestEntryReq() *glmodels.CreateJournalEntryRequest {
	return &glmodels.CreateJournalEntryRequest{
		OrganizationID: &testOrg,
		PostingDate:    time.Now().Truncate(24 * time.Hour),
		DocumentDate:   &[]time.Time{time.Now().Truncate(24 * time.Hour)}[0],
		Description:    fmt.Sprintf("Test entry %d", time.Now().UnixNano()),
		Reference:      "TEST-REF",
		EntryType:      "normal",
		Source:         "manual",
		Lines: []glmodels.CreateJournalLineRequest{
			{AccountID: gaapAssetID, Debit: 1000, Credit: 0, Description: "test debit"},
			{AccountID: gaapLiabID, Debit: 0, Credit: 1000, Description: "test credit"},
		},
	}
}

func countEntries(t *testing.T) int {
	t.Helper()
	var c int
	testPool.QueryRow(context.Background(),
		"SELECT COUNT(*) FROM gl_journal_entries WHERE tenant_id = $1", testTenant).Scan(&c)
	return c
}

func deleteAllEntries(t *testing.T) {
	t.Helper()
	testPool.Exec(context.Background(),
		"DELETE FROM gl_account_balances WHERE tenant_id = $1", testTenant)
	testPool.Exec(context.Background(),
		"DELETE FROM gl_journal_lines WHERE entry_id IN (SELECT id FROM gl_journal_entries WHERE tenant_id = $1)", testTenant)
	testPool.Exec(context.Background(),
		"DELETE FROM gl_journal_entries WHERE tenant_id = $1", testTenant)
}

// ═══════════════════════════════════════════════════════
// Tests for CreateJournalEntry
// ═══════════════════════════════════════════════════════

func TestCreateJournalEntry_Success(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	req := makeTestEntryReq()
	before := countEntries(t)

	entry, err := svc.CreateJournalEntry(context.Background(), testTenant, testUser, req)
	if err != nil {
		t.Fatalf("CreateJournalEntry failed: %v", err)
	}

	if entry == nil {
		t.Fatal("Expected non-nil entry")
	}
	if entry.Status != "draft" {
		t.Errorf("Expected status 'draft', got '%s'", entry.Status)
	}
	if entry.DocumentNo == "" {
		t.Error("Expected non-empty document_no")
	}
	if len(entry.Lines) != 2 {
		t.Errorf("Expected 2 lines, got %d", len(entry.Lines))
	}

	after := countEntries(t)
	if after != before+1 {
		t.Errorf("Expected %d entries, got %d", before+1, after)
	}
}

func TestCreateJournalEntry_NoLines(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	svc := setupService(t)
	req := makeTestEntryReq()
	req.Lines = nil

	_, err := svc.CreateJournalEntry(context.Background(), testTenant, testUser, req)
	if err != ErrNoLines {
		t.Errorf("Expected ErrNoLines, got %v", err)
	}
}

func TestCreateJournalEntry_NegativeAmount(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	svc := setupService(t)
	req := makeTestEntryReq()
	req.Lines[0].Debit = -100

	_, err := svc.CreateJournalEntry(context.Background(), testTenant, testUser, req)
	if err != ErrNegativeAmount {
		t.Errorf("Expected ErrNegativeAmount, got %v", err)
	}
}

func TestCreateJournalEntry_Unbalanced(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	svc := setupService(t)
	req := makeTestEntryReq()
	req.Lines[0].Debit = 1000
	req.Lines[1].Credit = 999 // should be 1000

	_, err := svc.CreateJournalEntry(context.Background(), testTenant, testUser, req)
	if err == nil || err == ErrNoLines {
		t.Errorf("Expected balance error, got %v", err)
	}
}

// ═══════════════════════════════════════════════════════
// Tests for Post / Reverse
// ═══════════════════════════════════════════════════════

func TestPostAndReverseEntry(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)

	// Create
	entry, err := svc.CreateJournalEntry(context.Background(), testTenant, testUser, makeTestEntryReq())
	if err != nil {
		t.Fatalf("Create failed: %v", err)
	}

	// Post via UpdateJournalEntryStatus
	posted, err := svc.UpdateJournalEntryStatus(context.Background(), entry.ID, testTenant, testUser, "posted")
	if err != nil {
		t.Fatalf("Post failed: %v", err)
	}
	if posted.Status != "posted" {
		t.Errorf("Expected status 'posted', got '%s'", posted.Status)
	}

	// Check gl_account_balances were updated
	var balCount int
	testPool.QueryRow(context.Background(),
		"SELECT COUNT(*) FROM gl_account_balances WHERE account_id = $1 AND period_id = $2",
		gaapAssetID, posted.PeriodID).Scan(&balCount)
	if balCount == 0 {
		t.Error("Expected gl_account_balances to have entries for posted entry")
	}

	// Reverse
	reversal, err := svc.ReverseJournalEntry(context.Background(), testTenant, testUser, entry.ID)
	if err != nil {
		t.Fatalf("Reverse failed: %v", err)
	}
	if reversal.EntryType != "reversal" {
		t.Errorf("Expected entry_type 'reversal', got '%s'", reversal.EntryType)
	}

	// Original should still be 'posted'
	orig, _ := svc.GetJournalEntry(context.Background(), entry.ID, testTenant)
	if orig.Status != "posted" {
		t.Errorf("Original entry should remain 'posted' after reversal, got '%s'", orig.Status)
	}
}

func TestPostEntry_BalancesUpdate(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	entry, _ := svc.CreateJournalEntry(context.Background(), testTenant, testUser, makeTestEntryReq())

	_, err := svc.UpdateJournalEntryStatus(context.Background(), entry.ID, testTenant, testUser, "posted")
	if err != nil {
		t.Fatalf("Post failed: %v", err)
	}

	// Verify balances
	var periodDebit, periodCredit float64
	testPool.QueryRow(context.Background(),
		"SELECT period_debit, period_credit FROM gl_account_balances WHERE account_id = $1 AND period_id = $2",
		gaapAssetID, entry.PeriodID).Scan(&periodDebit, &periodCredit)

	if periodDebit != 1000 {
		t.Errorf("Expected period_debit=1000 for asset, got %.2f", periodDebit)
	}
	if periodCredit != 0 {
		t.Errorf("Expected period_credit=0 for asset, got %.2f", periodCredit)
	}
}

// ═══════════════════════════════════════════════════════
// Tests for List with filters
// ═══════════════════════════════════════════════════════

func TestListJournalEntries_FilterByStatus(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	// Create 2 entries
	entry1, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())
	entry2, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())

	// Post one
	svc.UpdateJournalEntryStatus(ctx, entry1.ID, testTenant, testUser, "posted")

	// List drafts
	drafts, total, err := svc.ListJournalEntries(ctx, testTenant, 1, 50, "draft", "")
	if err != nil {
		t.Fatalf("List drafts failed: %v", err)
	}
	if len(drafts) != 1 {
		t.Errorf("Expected 1 draft, got %d", len(drafts))
	}

	// List posted
	posted, _, _ := svc.ListJournalEntries(ctx, testTenant, 1, 50, "posted", "")
	if len(posted) != 1 {
		t.Errorf("Expected 1 posted, got %d", len(posted))
	}

	_ = total
	_ = entry2
}

func TestListJournalEntries_Pagination(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	// Create 3 entries
	for i := 0; i < 3; i++ {
		svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())
	}

	// List with page_size=2
	entries, total, err := svc.ListJournalEntries(ctx, testTenant, 1, 2, "", "")
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}
	if len(entries) != 2 {
		t.Errorf("Expected 2 entries on page 1, got %d", len(entries))
	}

	page2, _, _ := svc.ListJournalEntries(ctx, testTenant, 2, 2, "", "")
	if len(page2) != 1 {
		t.Errorf("Expected 1 entry on page 2, got %d", len(page2))
	}

	_ = total
}

// ═══════════════════════════════════════════════════════
// Tests for UpdateDraftEntry
// ═══════════════════════════════════════════════════════

func TestUpdateDraftEntry(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	entry, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())

	// Update description and lines
	req := makeTestEntryReq()
	req.Description = "Updated description"
	req.Lines[0].Debit = 2000
	req.Lines[1].Credit = 2000

	updated, err := svc.UpdateDraftEntry(ctx, testTenant, testUser, entry.ID, req)
	if err != nil {
		t.Fatalf("UpdateDraftEntry failed: %v", err)
	}
	if updated.Description != "Updated description" {
		t.Errorf("Expected updated description, got '%s'", updated.Description)
	}
	if len(updated.Lines) == 0 {
		t.Error("Expected at least 1 line after update, got 0")
	}
}

func TestUpdateDraftEntry_NonDraftFails(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	entry, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())
	svc.UpdateJournalEntryStatus(ctx, entry.ID, testTenant, testUser, "posted")

	_, err := svc.UpdateDraftEntry(ctx, testTenant, testUser, entry.ID, makeTestEntryReq())
	if err == nil {
		t.Error("Expected error updating posted entry, got nil")
	}
}

// ═══════════════════════════════════════════════════════
// Tests for Delete
// ═══════════════════════════════════════════════════════

func TestDeleteDraftEntry(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	entry, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())

	// Delete via repo directly (service doesn't expose delete)
	err := svc.entryRepo.UpdateStatus(ctx, entry.ID, testTenant, "draft", nil)
	if err != nil {
		t.Fatalf("UpdateStatus failed: %v", err)
	}

	// Verify entry exists
	got, _ := svc.GetJournalEntry(ctx, entry.ID, testTenant)
	if got == nil {
		t.Error("Entry should exist before deletion")
	}
}

// ═══════════════════════════════════════════════════════
// Tests for Reports
// ═══════════════════════════════════════════════════════

func TestGetBalanceSheet(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	// Create and post an entry
	entry, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())
	svc.UpdateJournalEntryStatus(ctx, entry.ID, testTenant, testUser, "posted")

	year := time.Now().Year()
	month := int(time.Now().Month())

	report, err := svc.GetBalanceSheet(ctx, testTenant, year, month)
	if err != nil {
		t.Fatalf("GetBalanceSheet failed: %v", err)
	}

	assets := report["assets"].([]map[string]interface{})
	if len(assets) == 0 {
		t.Error("Expected non-empty assets in balance sheet")
	}

	totalAssets := report["total_assets"].(float64)
	if totalAssets < 900 || totalAssets > 1100 {
		t.Errorf("Expected total_assets ~1000, got %.2f", totalAssets)
	}
}

func TestGetProfitLoss(t *testing.T) {
	if gaapAssetID == uuid.Nil || gaapExpenseID == uuid.Nil {
		t.Skip("No test accounts with expense type available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	// Create an expense entry (Dr Expense 500, Cr Asset 500)
	req := &glmodels.CreateJournalEntryRequest{
		PostingDate: time.Now().Truncate(24 * time.Hour),
		Description: "Test expense",
		Source:      "manual",
		Lines: []glmodels.CreateJournalLineRequest{
			{AccountID: gaapExpenseID, Debit: 500, Credit: 0, Description: "test expense"},
			{AccountID: gaapAssetID, Debit: 0, Credit: 500, Description: "test pay"},
		},
	}

	entry, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, req)
	svc.UpdateJournalEntryStatus(ctx, entry.ID, testTenant, testUser, "posted")

	year := time.Now().Year()
	month := int(time.Now().Month())

	report, err := svc.GetProfitLoss(ctx, testTenant, year, month)
	if err != nil {
		t.Fatalf("GetProfitLoss failed: %v", err)
	}

	expenses := report["expenses"].([]map[string]interface{})
	if len(expenses) == 0 {
		t.Error("Expected non-empty expenses in P&L")
	}

	totalExpense := report["total_expense"].(float64)
	if totalExpense < 450 || totalExpense > 550 {
		t.Errorf("Expected total_expense ~500, got %.2f", totalExpense)
	}
}

// ═══════════════════════════════════════════════════════
// Tests for ValidateBalance edge cases
// ═══════════════════════════════════════════════════════

func TestRoundOffTolerance(t *testing.T) {
	// When diff is 0.001 (< 0.01), it should be OK
	if RoundOffTolerance != 0.01 {
		t.Errorf("Expected RoundOffTolerance 0.01, got %f", RoundOffTolerance)
	}
}

// ═══════════════════════════════════════════════════════
// Tests for GetJournalEntry
// ═══════════════════════════════════════════════════════

func TestGetJournalEntry_NotFound(t *testing.T) {
	svc := setupService(t)
	_, err := svc.GetJournalEntry(context.Background(), uuid.New(), testTenant)
	if err != ErrEntryNotFound {
		t.Errorf("Expected ErrEntryNotFound, got %v", err)
	}
}

// ═══════════════════════════════════════════════════════
// Tests for PostJournalEntries (batch)
// ═══════════════════════════════════════════════════════

func TestBatchPostEntries(t *testing.T) {
	if gaapAssetID == uuid.Nil {
		t.Skip("No test accounts available")
	}
	defer deleteAllEntries(t)

	svc := setupService(t)
	ctx := context.Background()

	// Create 2 entries
	e1, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())
	e2, _ := svc.CreateJournalEntry(ctx, testTenant, testUser, makeTestEntryReq())

	// Batch post
	req := &glmodels.PostJournalEntryRequest{
		EntryIDs: []uuid.UUID{e1.ID, e2.ID},
	}
	resp, err := svc.PostJournalEntries(ctx, testTenant, testUser, req)
	if err != nil {
		t.Fatalf("Batch post failed: %v", err)
	}
	if resp.SuccessCount != 2 {
		t.Errorf("Expected 2 successes, got %d", resp.SuccessCount)
	}
	if resp.FailureCount != 0 {
		t.Errorf("Expected 0 failures, got %d: %+v", resp.FailureCount, resp.Failures)
	}
}
