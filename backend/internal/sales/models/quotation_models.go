package models

import (
	"time"

	"github.com/google/uuid"
)

// ── Quotation ──

type Quotation struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	CustomerID      uuid.UUID  `json:"customer_id"`
	QuotationNo     string     `json:"quotation_no"`
	QuotationType   string     `json:"quotation_type"`
	Status          string     `json:"status"`
	ValidFrom       time.Time  `json:"valid_from"`
	ValidTo         *time.Time `json:"valid_to,omitempty"`
	Currency        string     `json:"currency"`
	PaymentTerms    string     `json:"payment_terms"`
	Incoterm        string     `json:"incoterm,omitempty"`
	DeliveryDate    *time.Time `json:"delivery_date,omitempty"`
	TotalAmount     float64    `json:"total_amount"`
	DiscountPct     float64    `json:"discount_pct"`
	DiscountAmount  float64    `json:"discount_amount"`
	NetAmount       float64    `json:"net_amount"`
	TaxAmount       float64    `json:"tax_amount"`
	TaxCalcSource   string     `json:"tax_calc_source,omitempty"`
	TaxCalcDetail   string     `json:"tax_calc_detail,omitempty"`
	TaxCalcRate     float64    `json:"tax_calc_rate,omitempty"`
	GrandTotal      float64    `json:"grand_total"`
	Notes           string     `json:"notes,omitempty"`
	InternalNotes   string     `json:"internal_notes,omitempty"`
	ReferenceInquiry string   `json:"reference_inquiry,omitempty"`
	EmployeeID      *uuid.UUID `json:"employee_id,omitempty"`
	CreatedBy       *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	// Joined
	CustomerCode string           `json:"customer_code,omitempty"`
	CustomerName string           `json:"customer_name,omitempty"`
	EmployeeCode string           `json:"employee_code,omitempty"`
	EmployeeName string           `json:"employee_name,omitempty"`
	Items        []QuotationItem  `json:"items,omitempty"`
}

type QuotationItem struct {
	ID            uuid.UUID  `json:"id"`
	QuotationID   uuid.UUID  `json:"quotation_id"`
	LineNo        int        `json:"line_no"`
	ProductID     uuid.UUID  `json:"product_id"`
	Description   string     `json:"description,omitempty"`
	Quantity      float64    `json:"quantity"`
	UnitOfMeasure string     `json:"unit_of_measure"`
	UnitPrice     float64    `json:"unit_price"`
	DiscountPct   float64    `json:"discount_pct,omitempty"`
	LineTotal     float64    `json:"line_total"`
	DeliveryDate  *time.Time `json:"delivery_date,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	// Joined
	ProductSKU string `json:"product_sku,omitempty"`
	ProductName string `json:"product_name,omitempty"`
}

type CreateQuotationRequest struct {
	CustomerID      string                  `json:"customer_id" binding:"required"`
	QuotationType   string                  `json:"quotation_type,omitempty"`
	ValidFrom       string                  `json:"valid_from,omitempty"`
	ValidTo         string                  `json:"valid_to,omitempty"`
	Currency        string                  `json:"currency,omitempty"`
	PaymentTerms    string                  `json:"payment_terms,omitempty"`
	Incoterm        string                  `json:"incoterm,omitempty"`
	DeliveryDate    string                  `json:"delivery_date,omitempty"`
	DiscountPct     float64                 `json:"discount_pct,omitempty"`
	TaxAmount       float64                 `json:"tax_amount,omitempty"`
	TaxCalcSource   string                  `json:"tax_calc_source,omitempty"`
	TaxCalcDetail   string                  `json:"tax_calc_detail,omitempty"`
	TaxCalcRate     float64                 `json:"tax_calc_rate,omitempty"`
	Notes           string                  `json:"notes,omitempty"`
	InternalNotes   string                  `json:"internal_notes,omitempty"`
	ReferenceInquiry string                `json:"reference_inquiry,omitempty"`
	EmployeeID      string                  `json:"employee_id,omitempty"`
	Items           []CreateQuotationItem   `json:"items" binding:"required,min=1"`
}

type CreateQuotationItem struct {
	ProductID   string  `json:"product_id" binding:"required"`
	Description string  `json:"description,omitempty"`
	Quantity    float64 `json:"quantity" binding:"required,gt=0"`
	UOM         string  `json:"unit_of_measure,omitempty"`
	UnitPrice   float64 `json:"unit_price" binding:"required,gte=0"`
	DiscountPct float64 `json:"discount_pct,omitempty"`
	DeliveryDate string `json:"delivery_date,omitempty"`
}

type UpdateQuotationStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=DRAFT OPEN ACCEPTED REJECTED EXPIRED CONVERTED"`
}
