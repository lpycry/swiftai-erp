package models

import (
	"time"

	"github.com/google/uuid"
)

// ── Credit Limit (SAP Credit Management) ──

type CreditLimit struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	CustomerID      uuid.UUID  `json:"customer_id"`
	CreditLimit     float64    `json:"credit_limit"`
	UsedCredit      float64    `json:"used_credit"`
	AvailableCredit float64    `json:"available_credit"`
	Currency        string     `json:"currency"`
	RiskCategory    string     `json:"risk_category"`
	CreditStatus    string     `json:"credit_status"`
	LastReviewed    *time.Time `json:"last_reviewed,omitempty"`
	ReviewedBy      *uuid.UUID `json:"reviewed_by,omitempty"`
	Notes           string     `json:"notes,omitempty"`
	IsActive        bool       `json:"is_active"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	// Joined fields
	CustomerCode     string `json:"customer_code,omitempty"`
	CustomerName     string `json:"customer_name,omitempty"`
}

type CreateCreditLimitRequest struct {
	CustomerID   string  `json:"customer_id" binding:"required"`
	CreditLimit  float64 `json:"credit_limit" binding:"required,gte=0"`
	UsedCredit   float64 `json:"used_credit,omitempty"`
	Currency     string  `json:"currency,omitempty"`
	RiskCategory string  `json:"risk_category,omitempty"`
	Notes        string  `json:"notes,omitempty"`
}

type UpdateCreditLimitRequest struct {
	CreditLimit  *float64 `json:"credit_limit,omitempty"`
	UsedCredit   *float64 `json:"used_credit,omitempty"`
	Currency     *string  `json:"currency,omitempty"`
	RiskCategory *string  `json:"risk_category,omitempty"`
	CreditStatus *string  `json:"credit_status,omitempty"`
	LastReviewed *string  `json:"last_reviewed,omitempty"`
	Notes        *string  `json:"notes,omitempty"`
	IsActive     *bool    `json:"is_active,omitempty"`
}

// ── Customer Down Payment (AR) ──

type CustomerDownPayment struct {
	ID               uuid.UUID  `json:"id"`
	TenantID         uuid.UUID  `json:"tenant_id"`
	CustomerID       uuid.UUID  `json:"customer_id"`
	OrgID            uuid.UUID  `json:"org_id"`
	DPType           string     `json:"dp_type"`
	DPNumber         string     `json:"dp_number"`
	Amount           float64    `json:"amount"`
	Currency         string     `json:"currency"`
	PaymentMethod    string     `json:"payment_method"`
	ReferenceNo      string     `json:"reference_no,omitempty"`
	Status           string     `json:"status"`
	DPDate           time.Time  `json:"dp_date"`
	ClearingDate     *time.Time `json:"clearing_date,omitempty"`
	Description      string     `json:"description,omitempty"`
	GLJEID           *uuid.UUID `json:"gl_je_id,omitempty"`
	GLPostingStatus  string     `json:"gl_posting_status"`
	CreatedBy        *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
	// Joined
	CustomerCode string `json:"customer_code,omitempty"`
	CustomerName string `json:"customer_name,omitempty"`
}

type CreateCustomerDownPaymentRequest struct {
	CustomerID    string  `json:"customer_id" binding:"required"`
	OrgID         string  `json:"org_id"`
	DPType        string  `json:"dp_type,omitempty"`
	Amount        float64 `json:"amount" binding:"required,gt=0"`
	Currency      string  `json:"currency,omitempty"`
	PaymentMethod string  `json:"payment_method,omitempty"`
	ReferenceNo   string  `json:"reference_no,omitempty"`
	DPDate        string  `json:"dp_date,omitempty"`
	Description   string  `json:"description,omitempty"`
	// For GL auto-posting — user selects the debit account
	DebitAccountID string `json:"debit_account_id" binding:"required"`
}
