package models

import (
	"time"

	"github.com/google/uuid"
)

// Account represents a chart of account item.
type Account struct {
	ID                 uuid.UUID  `json:"id"`
	TenantID           uuid.UUID  `json:"tenant_id"`
	AccountCode        string     `json:"account_code"`          // 1101, 2101, etc
	AccountName        string     `json:"account_name"`          // display name
	AccountType        string     `json:"account_type"`          // ASSET, LIABILITY, EQUITY, REVENUE, COGS, EXPENSE, OTHER_INCOME, OTHER_EXPENSE
	ParentID           *uuid.UUID `json:"parent_id,omitempty"`  // parent account (tree structure)
	Level              int        `json:"level"`                 // 1, 2, 3
	IsActive           bool       `json:"is_active"`
	IsLeaf             bool       `json:"is_leaf"`              // can post to this account
	Currency           string     `json:"currency"`             // default currency (e.g. USD)
	Description        string     `json:"description,omitempty"`
	ReconciliationType string     `json:"reconciliation_type"`  // none, customer, vendor, asset
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

// JournalEntry represents a general ledger journal entry header.
type JournalEntry struct {
	ID             uuid.UUID        `json:"id"`
	TenantID       uuid.UUID        `json:"tenant_id"`
	OrganizationID *uuid.UUID       `json:"organization_id,omitempty"`
	DocumentNo     string           `json:"document_no"`   // auto-generated
	PostingDate    time.Time        `json:"posting_date"`
	DocumentDate   *time.Time       `json:"document_date,omitempty"`
	PeriodID       uuid.UUID        `json:"period_id"`
	Description    string           `json:"description"`   // header text
	Reference      string           `json:"reference,omitempty"` // external ref number
	EntryType      string           `json:"entry_type"`     // normal, adjusting, reversal, accrual
	Status         string           `json:"status"`         // draft, posted, reversed
	Lines          []JournalLine    `json:"lines"`
	Attachments    []EntryAttachment `json:"attachments,omitempty"`
	Source         string           `json:"source"`                   // manual, ai, import, bank
	AIConfidence   float64          `json:"ai_confidence,omitempty"`  // 0-1, if AI-generated
	CreatedBy      uuid.UUID        `json:"created_by"`
	CreatedAt      time.Time        `json:"created_at"`
	PostedAt       *time.Time       `json:"posted_at,omitempty"`
	PostedBy       *uuid.UUID       `json:"posted_by,omitempty"`
}

// JournalLine represents a single line in a journal entry.
type JournalLine struct {
	ID           uuid.UUID  `json:"id"`
	EntryID      uuid.UUID  `json:"entry_id"`
	AccountID    uuid.UUID  `json:"account_id"`
	AccountCode  string     `json:"account_code"`  // denormalized
	AccountName  string     `json:"account_name"`  // denormalized
	Debit        float64    `json:"debit"`
	Credit       float64    `json:"credit"`
	Description  string     `json:"description,omitempty"` // line item text
	CostCenterID *uuid.UUID `json:"cost_center_id,omitempty"`
	PartnerID    *uuid.UUID `json:"partner_id,omitempty"`   // customer/vendor id
	PartnerType  string     `json:"partner_type,omitempty"` // customer, vendor
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
}

type CreateJournalEntryRequest struct {
	OrganizationID *uuid.UUID                  `json:"organization_id,omitempty"`
	PostingDate    time.Time                   `json:"posting_date" binding:"required"`
	DocumentDate   *time.Time                  `json:"document_date,omitempty"`
	PeriodID       uuid.UUID                   `json:"period_id,omitempty"`
	Description    string                      `json:"description" binding:"required"`
	Reference      string                      `json:"reference,omitempty"`
	EntryType      string                      `json:"entry_type" binding:"omitempty,oneof=normal adjusting reversal accrual"`
	Source         string                      `json:"source" binding:"omitempty,oneof=manual ai import bank"`
	Lines          []CreateJournalLineRequest  `json:"lines" binding:"required,min=2"`
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
	NaturalLanguage string `json:"natural_language" binding:"required"`
	Amount          float64 `json:"amount,omitempty"`
}

type AISuggestResponse struct {
	Description    string             `json:"description"`
	SuggestedLines []AISuggestedLine  `json:"suggested_lines"`
	Confidence     float64            `json:"confidence"`
}

type AISuggestedLine struct {
	AccountID    uuid.UUID `json:"account_id"`
	AccountCode  string    `json:"account_code"`
	AccountName  string    `json:"account_name"`
	Debit        float64   `json:"debit"`
	Credit       float64   `json:"credit"`
	Description  string    `json:"description"`
	Confidence   float64   `json:"confidence"`
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
