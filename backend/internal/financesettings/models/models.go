package models

import (
	"time"

	"github.com/google/uuid"
)

// ── Payment Term ──

type PaymentTerm struct {
	ID           uuid.UUID `json:"id"`
	TenantID     uuid.UUID `json:"tenant_id"`
	Code         string    `json:"code"`
	Name         string    `json:"name"`
	Description  string    `json:"description,omitempty"`
	DueDays      int       `json:"due_days"`
	DiscountDays int       `json:"discount_days,omitempty"`
	DiscountPct  float64   `json:"discount_pct,omitempty"`
	IsStandard   bool      `json:"is_standard"`
	IsActive     bool      `json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type CreatePaymentTermRequest struct {
	Code         string  `json:"code" binding:"required"`
	Name         string  `json:"name" binding:"required"`
	Description  string  `json:"description,omitempty"`
	DueDays      int     `json:"due_days" binding:"required"`
	DiscountDays int     `json:"discount_days,omitempty"`
	DiscountPct  float64 `json:"discount_pct,omitempty"`
}

type UpdatePaymentTermRequest struct {
	Name        *string  `json:"name,omitempty"`
	Description *string  `json:"description,omitempty"`
	DueDays     *int     `json:"due_days,omitempty"`
	DiscountDays *int    `json:"discount_days,omitempty"`
	DiscountPct *float64 `json:"discount_pct,omitempty"`
	IsActive    *bool    `json:"is_active,omitempty"`
}

// ── Incoterm ──

type Incoterm struct {
	ID          uuid.UUID `json:"id"`
	TenantID    uuid.UUID `json:"tenant_id"`
	Code        string    `json:"code"`
	Name        string    `json:"name"`
	Description string    `json:"description,omitempty"`
	Category    string    `json:"category"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type CreateIncotermRequest struct {
	Code        string `json:"code" binding:"required"`
	Name        string `json:"name" binding:"required"`
	Description string `json:"description,omitempty"`
	Category    string `json:"category" binding:"required,oneof=E F C D OTHER"`
}

type UpdateIncotermRequest struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
	Category    *string `json:"category,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}

// ── Org Reconciliation Account ──

type OrgReconAccount struct {
	ID                uuid.UUID `json:"id"`
	OrgID             uuid.UUID `json:"org_id"`
	AccountID         uuid.UUID `json:"account_id"`
	ReconciliationType string   `json:"reconciliation_type"`
	AccountType       string    `json:"account_type"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
	// Joined fields
	OrgCode          string `json:"org_code,omitempty"`
	OrgName          string `json:"org_name,omitempty"`
	AccountCode      string `json:"account_code,omitempty"`
	AccountName      string `json:"account_name,omitempty"`
}

type CreateOrgReconAccountRequest struct {
	OrgID              uuid.UUID `json:"org_id" binding:"required"`
	AccountID          uuid.UUID `json:"account_id" binding:"required"`
	ReconciliationType string    `json:"reconciliation_type"`
	AccountType        string    `json:"account_type" binding:"required"`
}
