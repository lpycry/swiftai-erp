package models

import (
	"time"

	"github.com/google/uuid"
)

type OrderTypeConfig struct {
	ID        uuid.UUID `json:"id"`
	TenantID  uuid.UUID `json:"tenant_id"`
	OrderType  string    `json:"order_type"`
	Description string  `json:"description"`
	IsActive   bool      `json:"is_active"`
	IsSystem   bool      `json:"is_system"`
	SortOrder  int       `json:"sort_order"`

	// Logistics & Stock Control
	RequiresShipping     bool   `json:"requires_shipping"`
	ShippingDirection    string `json:"shipping_direction"`
	AutoCreateDelivery   bool   `json:"auto_create_delivery"`
	AutoPgiPgr           bool   `json:"auto_pgi_pgr"`
	TargetStockType      string `json:"target_stock_type"`
	AutoConfirmSO        bool   `json:"auto_confirm_so"`
	PackingSlip          bool   `json:"packing_slip"`

	// Risk & Validation Control
	CreditCheckRequired bool   `json:"credit_check_required"`
	AtpCheckLogic       string `json:"atp_check_logic"`
	ReferenceRequired   bool   `json:"reference_required"`

	// Pricing & Finance Control
	PricingProcedure   string `json:"pricing_procedure"`
	BillingTrigger     string `json:"billing_trigger"`
	BillingType        string `json:"billing_type"`
	GlAccountStrategy  string `json:"gl_account_strategy"`

	// Block Control
	BillingBlockDefault bool `json:"billing_block_default"`

	CreatedBy *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

type CreateOrderTypeConfigRequest struct {
	OrderType  string `json:"order_type" binding:"required,max=4"`
	Description string `json:"description" binding:"required,max=100"`
	SortOrder  int    `json:"sort_order"`

	RequiresShipping     bool   `json:"requires_shipping"`
	ShippingDirection    string `json:"shipping_direction"`
	AutoCreateDelivery   bool   `json:"auto_create_delivery"`
	AutoPgiPgr           bool   `json:"auto_pgi_pgr"`
	TargetStockType      string `json:"target_stock_type"`
	AutoConfirmSO        bool   `json:"auto_confirm_so"`
	PackingSlip          bool   `json:"packing_slip"`

	CreditCheckRequired bool   `json:"credit_check_required"`
	AtpCheckLogic       string `json:"atp_check_logic"`
	ReferenceRequired   bool   `json:"reference_required"`

	PricingProcedure  string `json:"pricing_procedure"`
	BillingTrigger    string `json:"billing_trigger"`
	BillingType       string `json:"billing_type"`
	GlAccountStrategy string `json:"gl_account_strategy"`

	BillingBlockDefault bool `json:"billing_block_default"`
}

// ── Delivery Block Reasons ──

type DeliveryBlockReason struct {
	ID          uuid.UUID `json:"id"`
	TenantID    uuid.UUID `json:"tenant_id"`
	BlockCode   string    `json:"block_code"`
	Description string    `json:"description"`
	IsActive    bool      `json:"is_active"`
	IsSystem    bool      `json:"is_system"`
	SortOrder   int       `json:"sort_order"`
	CreatedBy   *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type CreateDeliveryBlockReasonRequest struct {
	BlockCode   string `json:"block_code" binding:"required,max=10"`
	Description string `json:"description"`
	SortOrder   int    `json:"sort_order"`
}

type UpdateDeliveryBlockReasonRequest struct {
	Description *string `json:"description,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
	SortOrder   *int    `json:"sort_order,omitempty"`
}

// ── Order Type Configs ──

type UpdateOrderTypeConfigRequest struct {
	Description *string `json:"description,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
	SortOrder   *int    `json:"sort_order,omitempty"`

	RequiresShipping     *bool   `json:"requires_shipping,omitempty"`
	ShippingDirection    *string `json:"shipping_direction,omitempty"`
	AutoCreateDelivery   *bool   `json:"auto_create_delivery,omitempty"`
	AutoPgiPgr           *bool   `json:"auto_pgi_pgr,omitempty"`
	TargetStockType      *string `json:"target_stock_type,omitempty"`
	AutoConfirmSO        *bool   `json:"auto_confirm_so,omitempty"`
	PackingSlip          *bool   `json:"packing_slip,omitempty"`

	CreditCheckRequired *bool   `json:"credit_check_required,omitempty"`
	AtpCheckLogic       *string `json:"atp_check_logic,omitempty"`
	ReferenceRequired   *bool   `json:"reference_required,omitempty"`

	PricingProcedure  *string `json:"pricing_procedure,omitempty"`
	BillingTrigger    *string `json:"billing_trigger,omitempty"`
	BillingType       *string `json:"billing_type,omitempty"`
	GlAccountStrategy *string `json:"gl_account_strategy,omitempty"`

	BillingBlockDefault *bool `json:"billing_block_default,omitempty"`
}
