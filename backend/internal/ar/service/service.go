package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	armodels "github.com/swiftai-erp/backend/internal/ar/models"
	arrepo "github.com/swiftai-erp/backend/internal/ar/repository"
	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
	glsvc "github.com/swiftai-erp/backend/internal/gl/service"
)

type ARService struct {
	repo  *arrepo.ARRepo
	db    *pgxpool.Pool
	glSvc *glsvc.GLService
}

func NewARService(repo *arrepo.ARRepo, db *pgxpool.Pool, glSvc *glsvc.GLService) *ARService {
	return &ARService{repo: repo, db: db, glSvc: glSvc}
}

// ── Credit Limits ──

func (s *ARService) ListCreditLimits(ctx context.Context, tenantID uuid.UUID) ([]*armodels.CreditLimit, error) {
	return s.repo.ListCreditLimits(ctx, tenantID)
}

func (s *ARService) GetCreditLimit(ctx context.Context, id, tenantID uuid.UUID) (*armodels.CreditLimit, error) {
	return s.repo.GetCreditLimit(ctx, id, tenantID)
}

func (s *ARService) CreateCreditLimit(ctx context.Context, tenantID uuid.UUID, req *armodels.CreateCreditLimitRequest) (*armodels.CreditLimit, error) {
	return s.repo.CreateCreditLimit(ctx, tenantID, req)
}

func (s *ARService) UpdateCreditLimit(ctx context.Context, id, tenantID uuid.UUID, req *armodels.UpdateCreditLimitRequest) error {
	return s.repo.UpdateCreditLimit(ctx, id, tenantID, req)
}

func (s *ARService) DeleteCreditLimit(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteCreditLimit(ctx, id, tenantID)
}

// ── Customer Down Payments (with auto GL posting) ──

func (s *ARService) ListDownPayments(ctx context.Context, tenantID uuid.UUID) ([]*armodels.CustomerDownPayment, error) {
	return s.repo.ListDownPayments(ctx, tenantID)
}

func (s *ARService) GetDownPayment(ctx context.Context, id, tenantID uuid.UUID) (*armodels.CustomerDownPayment, error) {
	return s.repo.GetDownPayment(ctx, id, tenantID)
}

func (s *ARService) CreateDownPayment(ctx context.Context, tenantID uuid.UUID, req *armodels.CreateCustomerDownPaymentRequest, userID *uuid.UUID) (*armodels.CustomerDownPayment, error) {
	customerID, _ := uuid.Parse(req.CustomerID)

	// Resolve org
	var orgID uuid.UUID
	if req.OrgID != "" {
		orgID, _ = uuid.Parse(req.OrgID)
	}
	if orgID == uuid.Nil {
		_ = s.db.QueryRow(ctx, "SELECT id FROM organizations WHERE tenant_id = $1 LIMIT 1", tenantID).Scan(&orgID)
	}

	dpDate := time.Now()
	if req.DPDate != "" {
		if d, err := time.Parse("2006-01-02", req.DPDate); err == nil { dpDate = d }
	}

	dpType := req.DPType
	if dpType == "" { dpType = "STANDARD" }

	// Generate DP number
	var seq int
	_ = s.db.QueryRow(ctx, "SELECT COALESCE(MAX(SUBSTRING(dp_number FROM 'ARDP-(\\d+)')::int), 0)+1 FROM customer_down_payments WHERE tenant_id = $1", tenantID).Scan(&seq)
	dpNumber := fmt.Sprintf("ARDP-%05d", seq)

	dp := &armodels.CustomerDownPayment{
		ID: uuid.New(), TenantID: tenantID, CustomerID: customerID, OrgID: orgID,
		DPType: dpType, DPNumber: dpNumber, Amount: req.Amount,
		Currency: req.Currency, PaymentMethod: req.PaymentMethod,
		ReferenceNo: req.ReferenceNo, Status: "DRAFT",
		DPDate: dpDate, Description: req.Description,
		GLPostingStatus: "PENDING", CreatedBy: userID,
		CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}
	if dp.Currency == "" { dp.Currency = "USD" }
	if dp.PaymentMethod == "" { dp.PaymentMethod = "BANK_TRANSFER" }

	// Save DP
	if err := s.repo.CreateDownPayment(ctx, dp); err != nil {
		return nil, fmt.Errorf("create down payment: %w", err)
	}

	// ── Auto-create GL Journal Entry ──
	// Dr: user-selected debit account
	// Cr: AR_DP reconciliation account

	// 1. Parse user's debit account
	debitAccountID, _ := uuid.Parse(req.DebitAccountID)
	if debitAccountID == uuid.Nil {
		return dp, fmt.Errorf("debit account is required for GL posting")
	}

	// 2. Look up AR_DP account from org_reconciliation_accounts
	var arDPAccountID uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT account_id FROM org_reconciliation_accounts WHERE account_type = 'AR_DP'
		AND (org_id = $1 OR org_id IN (SELECT id FROM organizations WHERE tenant_id = $2)) LIMIT 1`, orgID, tenantID).Scan(&arDPAccountID)
	if err != nil {
		return dp, fmt.Errorf("AR_DP account not configured. Go to Finance Settings > Account Types to set it up")
	}

	// 3. Determine effective tenant_id for GL
	glTenantID := tenantID
	var foundTenant uuid.UUID
	if orgID != uuid.Nil {
		_ = s.db.QueryRow(ctx, "SELECT tenant_id FROM organizations WHERE id = $1", orgID).Scan(&foundTenant)
		if foundTenant != uuid.Nil { glTenantID = foundTenant }
	}

	// 4. Resolve user ID for GL
	glUserID := uuid.Nil
	if userID != nil { glUserID = *userID }
	if glUserID == uuid.Nil {
		_ = s.db.QueryRow(ctx, "SELECT id FROM users WHERE tenant_id = $1 LIMIT 1", glTenantID).Scan(&glUserID)
	}

	// 5. Build journal entry
	entryReq := &glmodels.CreateJournalEntryRequest{
		PostingDate: dpDate,
		Reference:   dpNumber,
		Description: fmt.Sprintf("AR Down Payment %s - %s", dpNumber, req.Description),
		Source:      "manual",
		Lines: []glmodels.CreateJournalLineRequest{
			{AccountID: debitAccountID, Debit: req.Amount, Credit: 0, Description: "Customer down payment (Dr)"},
			{AccountID: arDPAccountID, Debit: 0, Credit: req.Amount, Description: "AR down payment liability (Cr)"},
		},
	}

	// 6. Create and post
	entry, err := s.glSvc.CreateJournalEntry(ctx, glTenantID, glUserID, entryReq)
	if err != nil {
		return dp, fmt.Errorf("create GL entry: %w", err)
	}
	if _, err := s.glSvc.UpdateJournalEntryStatus(ctx, entry.ID, glTenantID, glUserID, "posted"); err != nil {
		return dp, fmt.Errorf("post GL entry: %w", err)
	}

	// 7. Link GL JE to DP and update status
	dp.Status = "POSTED"
	dp.GLJEID = &entry.ID
	dp.GLPostingStatus = "POSTED"
	_ = s.repo.UpdateDownPaymentGLJE(ctx, dp.ID, entry.ID, glUserID)

	return dp, nil
}
