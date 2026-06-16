package models

import (
	"time"

	"github.com/google/uuid"
)

type SalesOrder struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	CustomerID      uuid.UUID  `json:"customer_id"`
	QuotationID     *uuid.UUID `json:"quotation_id,omitempty"`
	SONumber        string     `json:"so_number"`
	SOType          string     `json:"so_type"`
	Status          string     `json:"status"`
	CustomerPONo    string     `json:"customer_po_no,omitempty"`
	PODate          *time.Time `json:"po_date,omitempty"`
	Currency        string     `json:"currency"`
	PaymentTerms    string     `json:"payment_terms"`
	Incoterm        string     `json:"incoterm,omitempty"`
	ValidFrom       time.Time  `json:"valid_from"`
	DeliveryDate    *time.Time `json:"delivery_date,omitempty"`
	RequestedDate   *time.Time `json:"requested_date,omitempty"`
	TotalAmount     float64    `json:"total_amount"`
	DiscountPct     float64    `json:"discount_pct"`
	DiscountAmount  float64    `json:"discount_amount"`
	NetAmount       float64    `json:"net_amount"`
	TaxAmount       float64    `json:"tax_amount"`
	GrandTotal      float64    `json:"grand_total"`
	Notes           string     `json:"notes,omitempty"`
	InternalNotes   string     `json:"internal_notes,omitempty"`
	// Shipping
	Carrier          string  `json:"carrier,omitempty"`
	ShippingMethod   string  `json:"shipping_method,omitempty"`
	ShipperAccount   string  `json:"shipper_account,omitempty"`
	SignatureRequired bool   `json:"signature_required"`
	SaturdayDelivery  bool   `json:"saturday_delivery"`
	InsuranceAmt     float64 `json:"insurance_amt,omitempty"`
	// Bill-to / Transport
	TransportationTo      string `json:"transportation_to,omitempty"`
	TransportPayerAccount string `json:"transport_payer_account,omitempty"`
	BillToAddress         string `json:"bill_to_address,omitempty"`
	// Check statuses
	CreditCheckStatus    string `json:"credit_check_status"`
	InventoryCheckStatus string `json:"inventory_check_status"`
	TaxCalcStatus        string `json:"tax_calc_status"`
	AllocationStatus     string `json:"allocation_status"`
	// Config-driven fields
	BillingBlocked      bool   `json:"billing_blocked"`
	// Delivery Block
	DeliveryBlockID        *uuid.UUID `json:"delivery_block_id,omitempty"`
	DeliveryBlockCode      string     `json:"delivery_block_code,omitempty"`
	DeliveryBlockDesc      string     `json:"delivery_block_description,omitempty"`
	// Meta
	CreatedBy *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	// Joined
	CustomerCode string           `json:"customer_code,omitempty"`
	CustomerName string           `json:"customer_name,omitempty"`
	QuotationNo  string           `json:"quotation_no,omitempty"`
	Items        []SalesOrderItem `json:"items,omitempty"`
}

type SalesOrderItem struct {
	ID              uuid.UUID  `json:"id"`
	SOID            uuid.UUID  `json:"so_id"`
	LineNo          int        `json:"line_no"`
	ProductID       uuid.UUID  `json:"product_id"`
	QuotationItemID *uuid.UUID `json:"quotation_item_id,omitempty"`
	Description     string     `json:"description,omitempty"`
	Quantity        float64    `json:"quantity"`
	AllocatedQty    float64    `json:"allocated_qty"`
	UnitOfMeasure   string     `json:"unit_of_measure"`
	UnitPrice       float64    `json:"unit_price"`
	DiscountPct     float64    `json:"discount_pct"`
	LineTotal       float64    `json:"line_total"`
	DeliveryDate    *time.Time `json:"delivery_date,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	// Joined
	ProductSKU  string `json:"product_sku,omitempty"`
	ProductName string `json:"product_name,omitempty"`
}

type CreateSalesOrderRequest struct {
	CustomerID          string                `json:"customer_id" binding:"required"`
	OrderType           string                `json:"order_type,omitempty"`
	QuotationID         string                `json:"quotation_id,omitempty"`
	CustomerPONo        string                `json:"customer_po_no,omitempty"`
	PODate              string                `json:"po_date,omitempty"`
	Currency            string                `json:"currency,omitempty"`
	PaymentTerms        string                `json:"payment_terms,omitempty"`
	Incoterm            string                `json:"incoterm,omitempty"`
	ValidFrom           string                `json:"valid_from,omitempty"`
	DeliveryDate        string                `json:"delivery_date,omitempty"`
	RequestedDate       string                `json:"requested_date,omitempty"`
	DiscountPct         float64               `json:"discount_pct,omitempty"`
	TaxAmount           float64               `json:"tax_amount,omitempty"`
	Notes               string                `json:"notes,omitempty"`
	InternalNotes       string                `json:"internal_notes,omitempty"`
	Carrier             string                `json:"carrier,omitempty"`
	ShippingMethod      string                `json:"shipping_method,omitempty"`
	ShipperAccount      string                `json:"shipper_account,omitempty"`
	SignatureRequired   bool                  `json:"signature_required"`
	SaturdayDelivery    bool                  `json:"saturday_delivery"`
	InsuranceAmt        float64               `json:"insurance_amt,omitempty"`
	TransportationTo    string                `json:"transportation_to,omitempty"`
	TransportPayerAcct  string                `json:"transport_payer_account,omitempty"`
	BillToAddress       string                `json:"bill_to_address,omitempty"`
	DeliveryBlockID      string                 `json:"delivery_block_id,omitempty"`
	BillingBlocked       bool                   `json:"billing_blocked"`
	Items                []CreateSOItemRequest `json:"items" binding:"required,min=1"`
}

type CreateSOItemRequest struct {
	ProductID   string  `json:"product_id" binding:"required"`
	Description string  `json:"description,omitempty"`
	Quantity    float64 `json:"quantity" binding:"required,gt=0"`
	UOM         string  `json:"unit_of_measure,omitempty"`
	UnitPrice   float64 `json:"unit_price" binding:"required,gte=0"`
	DiscountPct float64 `json:"discount_pct,omitempty"`
	DeliveryDate string `json:"delivery_date,omitempty"`
}

type UpdateSOStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=DRAFT PENDING_APPROVAL APPROVED CONFIRMED SHIPPED INVOICED COMPLETED CANCELLED"`
}

type UpdateSalesOrderRequest struct {
	CustomerID          string                `json:"customer_id,omitempty"`
	OrderType           string                `json:"order_type,omitempty"`
	CustomerPONo        string                `json:"customer_po_no,omitempty"`
	PODate              string                `json:"po_date,omitempty"`
	Currency            string                `json:"currency,omitempty"`
	PaymentTerms        string                `json:"payment_terms,omitempty"`
	Incoterm            string                `json:"incoterm,omitempty"`
	ValidFrom           string                `json:"valid_from,omitempty"`
	DeliveryDate        string                `json:"delivery_date,omitempty"`
	RequestedDate       string                `json:"requested_date,omitempty"`
	EmployeeID          string                `json:"employee_id,omitempty"`
	DiscountPct         *float64              `json:"discount_pct,omitempty"`
	TaxAmount           *float64              `json:"tax_amount,omitempty"`
	Notes               string                `json:"notes,omitempty"`
	InternalNotes       string                `json:"internal_notes,omitempty"`
	Carrier             string                `json:"carrier,omitempty"`
	ShippingMethod      string                `json:"shipping_method,omitempty"`
	ShipperAccount      string                `json:"shipper_account,omitempty"`
	SignatureRequired   *bool                 `json:"signature_required,omitempty"`
	SaturdayDelivery    *bool                 `json:"saturday_delivery,omitempty"`
	InsuranceAmt        *float64              `json:"insurance_amt,omitempty"`
	TransportationTo    string                `json:"transportation_to,omitempty"`
	TransportPayerAcct  string                `json:"transport_payer_account,omitempty"`
	BillToAddress       string                `json:"bill_to_address,omitempty"`
	DeliveryBlockID     *string               `json:"delivery_block_id,omitempty"`
	Items               []CreateSOItemRequest `json:"items,omitempty"`
}

type ImportQuotationRequest struct {
	QuotationID string `json:"quotation_id" binding:"required"`
}

// ══════════════════════════════════════════
//  CARRIER SERVICE TYPES
// ══════════════════════════════════════════

type CarrierServiceType struct {
	ID          uuid.UUID `json:"id"`
	TenantID    uuid.UUID `json:"tenant_id"`
	Carrier     string    `json:"carrier"`
	ServiceType string    `json:"service_type"`
	IsActive    bool      `json:"is_active"`
	IsSystem    bool      `json:"is_system"`
	SortOrder   int       `json:"sort_order"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type CreateCarrierServiceTypeRequest struct {
	Carrier     string `json:"carrier" binding:"required"`
	ServiceType string `json:"service_type" binding:"required"`
	SortOrder   int    `json:"sort_order"`
}

type UpdateCarrierServiceTypeRequest struct {
	Carrier     *string `json:"carrier,omitempty"`
	ServiceType *string `json:"service_type,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
	SortOrder   *int    `json:"sort_order,omitempty"`
}
