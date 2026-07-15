package models

import (
	"time"

	"github.com/google/uuid"
)

// Account represents a chart of account item.
type Account struct {
	ID                 uuid.UUID  `json:"id"`
	TenantID           uuid.UUID  `json:"tenant_id"`
	AccountCode        string     `json:"account_code"`        // 1101, 2101, etc
	AccountName        string     `json:"account_name"`        // display name
	AccountType        string     `json:"account_type"`        // ASSET, LIABILITY, EQUITY, REVENUE, COGS, EXPENSE, OTHER_INCOME, OTHER_EXPENSE
	ParentID           *uuid.UUID `json:"parent_id,omitempty"` // parent account (tree structure)
	Level              int        `json:"level"`               // 1, 2, 3
	IsActive           bool       `json:"is_active"`
	IsLeaf             bool       `json:"is_leaf"`  // can post to this account
	Currency           string     `json:"currency"` // default currency (e.g. USD)
	Description        string     `json:"description,omitempty"`
	ReconciliationType string     `json:"reconciliation_type"` // none, customer, vendor, asset
	OpenItemManaged    bool       `json:"open_item_managed"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

// JournalEntry represents a general ledger journal entry header.
type JournalEntry struct {
	ID               uuid.UUID         `json:"id"`
	TenantID         uuid.UUID         `json:"tenant_id"`
	OrganizationID   *uuid.UUID        `json:"organization_id,omitempty"`
	OrganizationName string            `json:"organization_name,omitempty"`
	TotalDebit       float64           `json:"total_debit,omitempty"`
	TotalCredit      float64           `json:"total_credit,omitempty"`
	DocumentNo       string            `json:"document_no"` // auto-generated
	PostingDate      time.Time         `json:"posting_date"`
	DocumentDate     *time.Time        `json:"document_date,omitempty"`
	PeriodID         uuid.UUID         `json:"period_id"`
	Description      string            `json:"description"`         // header text
	Reference        string            `json:"reference,omitempty"` // external ref number
	EntryType        string            `json:"entry_type"`          // normal, adjusting, reversal, accrual
	Status           string            `json:"status"`              // draft, posted, reversed
	Lines            []JournalLine     `json:"lines"`
	Attachments      []EntryAttachment `json:"attachments,omitempty"`
	Source           string            `json:"source"`                  // manual, ai, import, bank, purchase, warehouse, production
	AIConfidence     float64           `json:"ai_confidence,omitempty"` // 0-1, if AI-generated
	CreatedBy        uuid.UUID         `json:"created_by"`
	CreatedAt        time.Time         `json:"created_at"`
	PostedAt         *time.Time        `json:"posted_at,omitempty"`
	PostedBy         *uuid.UUID        `json:"posted_by,omitempty"`
}

// JournalLine represents a single line in a journal entry.
type JournalLine struct {
	ID             uuid.UUID  `json:"id"`
	EntryID        uuid.UUID  `json:"entry_id"`
	AccountID      uuid.UUID  `json:"account_id"`
	AccountCode    string     `json:"account_code"` // denormalized
	AccountName    string     `json:"account_name"` // denormalized
	Debit          float64    `json:"debit"`
	Credit         float64    `json:"credit"`
	DocumentNo     string     `json:"document_no,omitempty"`  // from parent entry
	PostingDate    *time.Time `json:"posting_date,omitempty"` // from parent entry
	Description    string     `json:"description,omitempty"`  // line item text
	CostCenterID   *uuid.UUID `json:"cost_center_id,omitempty"`
	PartnerID      *uuid.UUID `json:"partner_id,omitempty"`       // customer/vendor id
	PartnerType    string     `json:"partner_type,omitempty"`     // customer, vendor
	OpenItemStatus string     `json:"open_item_status,omitempty"` // open, cleared
	ClearingDocID  *uuid.UUID `json:"clearing_doc_id,omitempty"`
	ClearingDocNo  string     `json:"clearing_doc_no,omitempty"`
	ClearedAt      *time.Time `json:"cleared_at,omitempty"`
	ClearingDate   *time.Time `json:"clearing_date,omitempty"`
}

// ── Request / Response types ──

type CreateAccountRequest struct {
	AccountCode        string     `json:"account_code" binding:"required"`
	AccountName        string     `json:"account_name" binding:"required"`
	AccountType        string     `json:"account_type" binding:"required,oneof=ASSET LIABILITY EQUITY REVENUE COGS EXPENSE OTHER_INCOME OTHER_EXPENSE"`
	ParentID           *uuid.UUID `json:"parent_id,omitempty"`
	Level              int        `json:"level" binding:"omitempty,min=1,max=3"`
	IsLeaf             bool       `json:"is_leaf"`
	Currency           string     `json:"currency"`
	Description        string     `json:"description,omitempty"`
	ReconciliationType string     `json:"reconciliation_type" binding:"omitempty,oneof=none customer vendor asset"`
	OpenItemManaged    *bool      `json:"open_item_managed,omitempty"`
}

type UpdateAccountRequest struct {
	AccountName        string     `json:"account_name"`
	AccountType        string     `json:"account_type" binding:"omitempty,oneof=ASSET LIABILITY EQUITY REVENUE COGS EXPENSE OTHER_INCOME OTHER_EXPENSE"`
	ParentID           *uuid.UUID `json:"parent_id,omitempty"`
	IsActive           *bool      `json:"is_active,omitempty"`
	IsLeaf             *bool      `json:"is_leaf,omitempty"`
	Currency           string     `json:"currency"`
	Description        string     `json:"description,omitempty"`
	ReconciliationType string     `json:"reconciliation_type" binding:"omitempty,oneof=none customer vendor asset"`
	OpenItemManaged    *bool      `json:"open_item_managed,omitempty"`
}

type CreateJournalEntryRequest struct {
	OrganizationID *uuid.UUID                 `json:"organization_id,omitempty"`
	PostingDate    time.Time                  `json:"posting_date" binding:"required"`
	DocumentDate   *time.Time                 `json:"document_date,omitempty"`
	PeriodID       uuid.UUID                  `json:"period_id,omitempty"`
	Description    string                     `json:"description" binding:"required"`
	Reference      string                     `json:"reference,omitempty"`
	EntryType      string                     `json:"entry_type" binding:"omitempty,oneof=normal adjusting reversal accrual"`
	Source         string                     `json:"source" binding:"omitempty,oneof=manual ai import bank purchase warehouse production clearing"`
	Lines          []CreateJournalLineRequest `json:"lines" binding:"required,min=2"`
}

type CreateJournalLineRequest struct {
	AccountID    uuid.UUID  `json:"account_id" binding:"required"`
	Debit        float64    `json:"debit"`
	Credit       float64    `json:"credit"`
	Description  string     `json:"description,omitempty"`
	CostCenterID *uuid.UUID `json:"cost_center_id,omitempty"`
	PartnerID    *uuid.UUID `json:"partner_id,omitempty"`
	PartnerType  string     `json:"partner_type,omitempty"`
}

type PostJournalEntryRequest struct {
	EntryIDs []uuid.UUID `json:"entry_ids" binding:"required,min=1"`
}

type AISuggestRequest struct {
	NaturalLanguage string  `json:"natural_language" binding:"required"`
	Amount          float64 `json:"amount,omitempty"`
}

type AISuggestResponse struct {
	Description    string            `json:"description"`
	SuggestedLines []AISuggestedLine `json:"suggested_lines"`
	Confidence     float64           `json:"confidence"`
}

type AISuggestedLine struct {
	AccountID   uuid.UUID `json:"account_id"`
	AccountCode string    `json:"account_code"`
	AccountName string    `json:"account_name"`
	Debit       float64   `json:"debit"`
	Credit      float64   `json:"credit"`
	Description string    `json:"description"`
	Confidence  float64   `json:"confidence"`
}

type AccountTreeResponse struct {
	Account
	Children []*AccountTreeResponse `json:"children,omitempty"`
}

type BatchPostResponse struct {
	SuccessCount int                `json:"success_count"`
	FailureCount int                `json:"failure_count"`
	Failures     []BatchPostFailure `json:"failures,omitempty"`
}

type BatchPostFailure struct {
	EntryID uuid.UUID `json:"entry_id"`
	Error   string    `json:"error"`
}

type OpenItem struct {
	LineID         uuid.UUID  `json:"line_id"`
	EntryID        uuid.UUID  `json:"entry_id"`
	DocumentNo     string     `json:"document_no"`
	PostingDate    time.Time  `json:"posting_date"`
	AccountID      uuid.UUID  `json:"account_id"`
	AccountCode    string     `json:"account_code"`
	AccountName    string     `json:"account_name"`
	PartnerID      *uuid.UUID `json:"partner_id,omitempty"`
	PartnerType    string     `json:"partner_type,omitempty"`
	OriginalSide   string     `json:"original_side"`
	Debit          float64    `json:"debit"`
	Credit         float64    `json:"credit"`
	AmountSigned   float64    `json:"amount_signed"`
	Currency       string     `json:"currency"`
	Description    string     `json:"description,omitempty"`
	Reference      string     `json:"reference,omitempty"`
	OpenItemStatus string     `json:"open_item_status"`
	ClearingDocID  *uuid.UUID `json:"clearing_doc_id,omitempty"`
	ClearingDocNo  string     `json:"clearing_doc_no,omitempty"`
	ClearingDate   *time.Time `json:"clearing_date,omitempty"`
	ClearedAt      *time.Time `json:"cleared_at,omitempty"`
}

type ClearingNewLineRequest struct {
	OffsettingAccountID uuid.UUID  `json:"offsetting_account_id" binding:"required"`
	Direction           string     `json:"direction" binding:"required,oneof=debit credit"`
	Amount              float64    `json:"amount" binding:"required,gt=0"`
	CostCenterID        *uuid.UUID `json:"cost_center_id,omitempty"`
	Description         string     `json:"description,omitempty"`
}

type CreateClearingRequest struct {
	MasterAccountID uuid.UUID               `json:"master_account_id" binding:"required"`
	ClearingDate    time.Time               `json:"clearing_date" binding:"required"`
	WithPosting     bool                    `json:"with_posting"`
	SelectedLineIDs []uuid.UUID             `json:"selected_line_ids" binding:"required,min=1"`
	NewLine         *ClearingNewLineRequest `json:"new_line,omitempty"`
	Description     string                  `json:"description,omitempty"`
}

type ClearingResult struct {
	ClearingEntryID uuid.UUID `json:"clearing_entry_id"`
	ClearingDocNo   string    `json:"clearing_doc_no"`
	ClearedCount    int       `json:"cleared_count"`
	Difference      float64   `json:"difference"`
}

type CancelClearingResult struct {
	ClearingEntryID uuid.UUID  `json:"clearing_entry_id"`
	ClearingDocNo   string     `json:"clearing_doc_no"`
	ReversalEntryID *uuid.UUID `json:"reversal_entry_id,omitempty"`
	ReversalDocNo   string     `json:"reversal_doc_no,omitempty"`
	ReopenedCount   int64      `json:"reopened_count"`
}

type ARCustomer struct {
	ID           uuid.UUID `json:"id"`
	CustomerCode string    `json:"customer_code"`
	Name         string    `json:"name"`
	Currency     string    `json:"currency"`
}

type AROpenInvoice struct {
	ID              uuid.UUID `json:"id"`
	InvoiceNo       string    `json:"invoice_no"`
	InvoiceDate     time.Time `json:"invoice_date"`
	CustomerID      uuid.UUID `json:"customer_id"`
	CustomerCode    string    `json:"customer_code,omitempty"`
	CustomerName    string    `json:"customer_name,omitempty"`
	Currency        string    `json:"currency"`
	TotalAmount     float64   `json:"total_amount"`
	RemainingAmount float64   `json:"remaining_amount"`
	AppliedAmount   float64   `json:"applied_amount,omitempty"`
	AgeDays         int       `json:"age_days"`
	Reference       string    `json:"reference,omitempty"`
	Status          string    `json:"status"`
}

type IncomingPaymentApplyRequest struct {
	InvoiceID   uuid.UUID `json:"invoice_id" binding:"required"`
	ApplyAmount float64   `json:"apply_amount" binding:"required,gt=0"`
}

type CreateIncomingPaymentRequest struct {
	CustomerID    uuid.UUID                     `json:"customer_id" binding:"required"`
	BankAccountID uuid.UUID                     `json:"bank_account_id" binding:"required"`
	ReceiptDate   time.Time                     `json:"receipt_date" binding:"required"`
	NetAmount     float64                       `json:"net_amount" binding:"required,gt=0"`
	Currency      string                        `json:"currency,omitempty"`
	ExchangeRate  float64                       `json:"exchange_rate,omitempty"`
	DiffType      string                        `json:"diff_type,omitempty"`
	DiffAmount    float64                       `json:"diff_amount,omitempty"`
	Description   string                        `json:"description,omitempty"`
	Applications  []IncomingPaymentApplyRequest `json:"applications" binding:"required,min=1"`
}

type IncomingPaymentResult struct {
	VoucherID      uuid.UUID `json:"voucher_id"`
	VoucherNo      string    `json:"voucher_no"`
	JournalEntryID uuid.UUID `json:"journal_entry_id"`
	JournalDocNo   string    `json:"journal_doc_no"`
	AppliedTotal   float64   `json:"applied_total"`
	Difference     float64   `json:"difference"`
}

type ARCreditMemo struct {
	ID              uuid.UUID  `json:"id"`
	MemoNo          string     `json:"memo_no"`
	CustomerID      uuid.UUID  `json:"customer_id"`
	CustomerCode    string     `json:"customer_code,omitempty"`
	CustomerName    string     `json:"customer_name,omitempty"`
	MemoDate        time.Time  `json:"memo_date"`
	Currency        string     `json:"currency"`
	ReasonCode      string     `json:"reason_code"`
	Amount          float64    `json:"amount"`
	RemainingAmount float64    `json:"remaining_amount"`
	Status          string     `json:"status"`
	Description     string     `json:"description,omitempty"`
	JournalEntryID  *uuid.UUID `json:"journal_entry_id,omitempty"`
	ClearingID      *uuid.UUID `json:"clearing_id,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

type CreditMemoNewLineRequest struct {
	ReasonCode  string  `json:"reason_code" binding:"required"`
	Amount      float64 `json:"amount" binding:"required,gt=0"`
	Description string  `json:"description,omitempty"`
}

type CreditMemoInvoiceApplyRequest struct {
	InvoiceID   uuid.UUID `json:"invoice_id" binding:"required"`
	ApplyAmount float64   `json:"apply_amount" binding:"required,gt=0"`
}

type CreateCreditMemoClearingRequest struct {
	CustomerID            uuid.UUID                       `json:"customer_id" binding:"required"`
	PostingDate           time.Time                       `json:"posting_date" binding:"required"`
	DocumentDate          time.Time                       `json:"document_date" binding:"required"`
	Currency              string                          `json:"currency,omitempty"`
	ControlType           string                          `json:"control_type,omitempty"`
	AllowPartial          bool                            `json:"allow_partial"`
	Description           string                          `json:"description,omitempty"`
	NewCredits            []CreditMemoNewLineRequest      `json:"new_credits,omitempty"`
	ExistingCreditMemoIDs []uuid.UUID                     `json:"existing_credit_memo_ids,omitempty"`
	Invoices              []CreditMemoInvoiceApplyRequest `json:"invoices,omitempty"`
}

type CreditMemoClearingResult struct {
	ClearingID          uuid.UUID `json:"clearing_id"`
	ClearingNo          string    `json:"clearing_no"`
	JournalEntryID      uuid.UUID `json:"journal_entry_id,omitempty"`
	JournalDocNo        string    `json:"journal_doc_no,omitempty"`
	CreditTotal         float64   `json:"credit_total"`
	InvoiceAppliedTotal float64   `json:"invoice_applied_total"`
	NetBalance          float64   `json:"net_balance"`
	Status              string    `json:"status"`
	CreatedMemos        []string  `json:"created_memos"`
}

// EntryAttachment represents a supporting document attached to a journal entry.
type EntryAttachment struct {
	ID          uuid.UUID `json:"id"`
	EntryID     uuid.UUID `json:"entry_id"`
	FileName    string    `json:"file_name"`
	FileType    string    `json:"file_type"`
	FileSize    int64     `json:"file_size"`
	FilePath    string    `json:"file_path"`
	Description string    `json:"description,omitempty"`
	UploadedBy  uuid.UUID `json:"uploaded_by,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// Period represents a fiscal period.
type Period struct {
	ID         uuid.UUID `json:"id"`
	TenantID   uuid.UUID `json:"tenant_id"`
	FiscalYear int       `json:"fiscal_year"`
	PeriodNo   int       `json:"period_no"` // 1-12
	StartDate  time.Time `json:"start_date"`
	EndDate    time.Time `json:"end_date"`
	IsOpen     bool      `json:"is_open"`
	IsLocked   bool      `json:"is_locked"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}
