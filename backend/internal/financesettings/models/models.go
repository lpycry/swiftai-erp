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

// ── Tax Jurisdiction ──

type TaxJurisdiction struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	State           string     `json:"state"`
	County          string     `json:"county"`
	City            string     `json:"city"`
	ZipCode         string     `json:"zip_code"`
	TaxRate         float64    `json:"tax_rate"`
	EffectiveDate   time.Time  `json:"effective_date"`
	ExpirationDate  *time.Time `json:"expiration_date,omitempty"`
	IsActive        bool       `json:"is_active"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type CreateTaxJurisdictionRequest struct {
	State          string  `json:"state" binding:"required"`
	County         string  `json:"county"`
	City           string  `json:"city"`
	ZipCode        string  `json:"zip_code"`
	TaxRate        float64 `json:"tax_rate" binding:"required,gt=0,lte=1"`
	EffectiveDate  string  `json:"effective_date" binding:"required"`
	ExpirationDate string  `json:"expiration_date,omitempty"`
}

type UpdateTaxJurisdictionRequest struct {
	State          *string  `json:"state,omitempty"`
	County         *string  `json:"county,omitempty"`
	City           *string  `json:"city,omitempty"`
	ZipCode        *string  `json:"zip_code,omitempty"`
	TaxRate        *float64 `json:"tax_rate,omitempty"`
	EffectiveDate  *string  `json:"effective_date,omitempty"`
	ExpirationDate *string  `json:"expiration_date,omitempty"`
	IsActive       *bool    `json:"is_active,omitempty"`
}

// ── Tax Nexus ──

type TaxNexus struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	State           string     `json:"state"`
	NexusType       string     `json:"nexus_type"`
	SubType         string     `json:"sub_type"`
	ThresholdAmount *float64   `json:"threshold_amount,omitempty"`
	EffectiveDate   time.Time  `json:"effective_date"`
	IsActive        bool       `json:"is_active"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type CreateTaxNexusRequest struct {
	State           string  `json:"state" binding:"required"`
	NexusType       string  `json:"nexus_type" binding:"required,oneof=PHYSICAL ECONOMIC"`
	SubType         string  `json:"sub_type"`
	ThresholdAmount *float64 `json:"threshold_amount,omitempty"`
	EffectiveDate   string  `json:"effective_date" binding:"required"`
}

type UpdateTaxNexusRequest struct {
	State           *string  `json:"state,omitempty"`
	NexusType       *string  `json:"nexus_type,omitempty"`
	SubType         *string  `json:"sub_type,omitempty"`
	ThresholdAmount *float64 `json:"threshold_amount,omitempty"`
	EffectiveDate   *string  `json:"effective_date,omitempty"`
	IsActive        *bool    `json:"is_active,omitempty"`
}

type CreateOrgReconAccountRequest struct {
	OrgID              uuid.UUID `json:"org_id" binding:"required"`
	AccountID          uuid.UUID `json:"account_id" binding:"required"`
	ReconciliationType string    `json:"reconciliation_type"`
	AccountType        string    `json:"account_type" binding:"required"`
}

// ── Tax Jurisdiction Rule (Product Category × Tax Code) ──

type TaxJurisdictionRule struct {
	RuleID           int        `json:"rule_id"`
	TenantID         uuid.UUID  `json:"tenant_id"`
	JurisdictionCode string     `json:"jurisdiction_code"`
	StateCode        string     `json:"state_code"`
	ZipCode          string     `json:"zip_code"`
	TaxCategoryCode  string     `json:"tax_category_code"`
	IsTaxable        bool       `json:"is_taxable"`
	BaseRate         float64    `json:"base_rate"`
	ConditionType    string     `json:"condition_type"`
	ConditionValue   *float64   `json:"condition_value,omitempty"`
	EffectiveFrom    time.Time  `json:"effective_from"`
	EffectiveTo      *time.Time `json:"effective_to,omitempty"`
	UpdatedBy        string     `json:"updated_by"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

type CreateTaxJurisdictionRuleRequest struct {
	JurisdictionCode string  `json:"jurisdiction_code" binding:"required"`
	StateCode        string  `json:"state_code" binding:"required,len=2"`
	ZipCode          string  `json:"zip_code"`
	TaxCategoryCode  string  `json:"tax_category_code" binding:"required"`
	IsTaxable        *bool   `json:"is_taxable,omitempty"`
	BaseRate         float64 `json:"base_rate"`
	ConditionType    string  `json:"condition_type"`
	ConditionValue   *float64 `json:"condition_value,omitempty"`
	EffectiveFrom    string  `json:"effective_from" binding:"required"`
	EffectiveTo      string  `json:"effective_to,omitempty"`
	UpdatedBy        string  `json:"updated_by"`
}

type UpdateTaxJurisdictionRuleRequest struct {
	JurisdictionCode *string   `json:"jurisdiction_code,omitempty"`
	StateCode        *string   `json:"state_code,omitempty"`
	ZipCode          *string   `json:"zip_code,omitempty"`
	TaxCategoryCode  *string   `json:"tax_category_code,omitempty"`
	IsTaxable        *bool     `json:"is_taxable,omitempty"`
	BaseRate         *float64  `json:"base_rate,omitempty"`
	ConditionType    *string   `json:"condition_type,omitempty"`
	ConditionValue   *float64  `json:"condition_value,omitempty"`
	EffectiveFrom    *string   `json:"effective_from,omitempty"`
	EffectiveTo      *string   `json:"effective_to,omitempty"`
	UpdatedBy        *string   `json:"updated_by,omitempty"`
}

// ── Tax Category ──

type TaxCategory struct {
	ID          uuid.UUID `json:"id"`
	TenantID    uuid.UUID `json:"tenant_id"`
	Code        string    `json:"code"`
	Description string    `json:"description"`
	Example     string    `json:"example"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type CreateTaxCategoryRequest struct {
	Code        string `json:"code" binding:"required,max=4"`
	Description string `json:"description"`
	Example     string `json:"example"`
}

type UpdateTaxCategoryRequest struct {
	Code        *string `json:"code,omitempty"`
	Description *string `json:"description,omitempty"`
	Example     *string `json:"example,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}
