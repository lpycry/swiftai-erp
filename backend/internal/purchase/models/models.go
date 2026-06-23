package models

import (
	"time"

	"github.com/google/uuid"
)

// ── Vendor Master ──

type Vendor struct {
	ID            uuid.UUID `json:"id"`
	OrgID         uuid.UUID `json:"org_id"`
	VendorCode    string    `json:"vendor_code"`
	Name          string    `json:"name"`
	TaxNumber     string    `json:"tax_number,omitempty"`
	Currency      string    `json:"currency"`
	PaymentTerms  string    `json:"payment_terms"`
	Status        string    `json:"status"`
	AIRating      float64   `json:"ai_rating"`
	LeadTimeDays  int       `json:"lead_time_days,omitempty"`
	Address       string    `json:"address,omitempty"`
	ContactPerson string    `json:"contact_person,omitempty"`
	ContactEmail  string    `json:"contact_email,omitempty"`
	ContactPhone  string    `json:"contact_phone,omitempty"`
	IsActive      bool      `json:"is_active"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type CreateVendorRequest struct {
	VendorCode    string `json:"vendor_code" binding:"required"`
	Name          string `json:"name" binding:"required"`
	TaxNumber     string `json:"tax_number,omitempty"`
	Currency      string `json:"currency,omitempty"`
	PaymentTerms  string `json:"payment_terms,omitempty"`
	LeadTimeDays  int    `json:"lead_time_days,omitempty"`
	Address       string `json:"address,omitempty"`
	ContactPerson string `json:"contact_person,omitempty"`
	ContactEmail  string `json:"contact_email,omitempty"`
	ContactPhone  string `json:"contact_phone,omitempty"`
}

type UpdateVendorRequest struct {
	Name          *string `json:"name,omitempty"`
	TaxNumber     *string `json:"tax_number,omitempty"`
	Currency      *string `json:"currency,omitempty"`
	PaymentTerms  *string `json:"payment_terms,omitempty"`
	Status        *string `json:"status,omitempty"`
	LeadTimeDays  *int    `json:"lead_time_days,omitempty"`
	Address       *string `json:"address,omitempty"`
	ContactPerson *string `json:"contact_person,omitempty"`
	ContactEmail  *string `json:"contact_email,omitempty"`
	ContactPhone  *string `json:"contact_phone,omitempty"`
	IsActive      *bool   `json:"is_active,omitempty"`
}

// ── Purchase Order ──

type PurchaseOrder struct {
	ID              uuid.UUID           `json:"id"`
	OrgID           uuid.UUID           `json:"org_id"`
	PONumber        string              `json:"po_number"`
	VendorID        uuid.UUID           `json:"vendor_id"`
	VendorName      string              `json:"vendor_name,omitempty"`
	VendorCode      string              `json:"vendor_code,omitempty"`
	TotalAmount     float64             `json:"total_amount"`
	Currency        string              `json:"currency"`
	Status          string              `json:"status"`
	Notes           string              `json:"notes,omitempty"`
	CreatedBy       *uuid.UUID          `json:"created_by,omitempty"`
	CreatedAt       time.Time           `json:"created_at"`
	UpdatedAt       time.Time           `json:"updated_at"`
	OrganizationID  *uuid.UUID          `json:"organization_id,omitempty"`
	OrgCode         string              `json:"org_code,omitempty"`
	OrgName         string              `json:"org_name,omitempty"`
	PODate          time.Time           `json:"po_date"`
	PaymentTermCode string              `json:"payment_term_code,omitempty"`
	DeliveryAddress string              `json:"delivery_address,omitempty"`
	IncotermCode    string              `json:"incoterm_code,omitempty"`
	Items           []PurchaseOrderItem `json:"items,omitempty"`
}

type PurchaseOrderItem struct {
	ID                   uuid.UUID  `json:"id"`
	POID                 uuid.UUID  `json:"po_id"`
	ItemID               uuid.UUID  `json:"item_id"`
	ItemSKU              string     `json:"item_sku,omitempty"`
	ItemName             string     `json:"item_name,omitempty"`
	Quantity             float64    `json:"quantity"`
	UnitPrice            float64    `json:"unit_price"`
	ReceivedQuantity     float64    `json:"received_quantity"`
	InvoicedQuantity     float64    `json:"invoiced_quantity"`
	OpenInvoiceQty       float64    `json:"open_invoice_qty,omitempty"`
	UnitOfMeasure        string     `json:"unit_of_measure"`
	LineTotal            float64    `json:"line_total"`
	ExpectedDeliveryDate *time.Time `json:"expected_delivery_date,omitempty"`
	DeliveryAddress      string     `json:"delivery_address,omitempty"`
}

type CreatePORequest struct {
	VendorID        uuid.UUID    `json:"vendor_id" binding:"required"`
	Currency        string       `json:"currency,omitempty"`
	Notes           string       `json:"notes,omitempty"`
	OrganizationID  *uuid.UUID   `json:"organization_id,omitempty"`
	PODate          string       `json:"po_date,omitempty"`
	PaymentTermCode string       `json:"payment_term_code,omitempty"`
	DeliveryAddress string       `json:"delivery_address,omitempty"`
	IncotermCode    string       `json:"incoterm_code,omitempty"`
	Items           []POLineItem `json:"items" binding:"required,min=1"`
}

type POLineItem struct {
	ItemID               uuid.UUID `json:"item_id" binding:"required"`
	Quantity             float64   `json:"quantity" binding:"required,gt=0"`
	UnitPrice            float64   `json:"unit_price"`
	UOM                  string    `json:"unit_of_measure,omitempty"`
	ExpectedDeliveryDate string    `json:"expected_delivery_date,omitempty"`
	DeliveryAddress      string    `json:"delivery_address,omitempty"`
}

type UpdatePOStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=DRAFT CONFIRMED CANCELLED"`
}

type PostInvoiceRequest struct {
	PostToGL bool `json:"post_to_gl"`
}

type CreateReceiptRequest struct {
	POID        uuid.UUID  `json:"po_id" binding:"required"`
	ItemID      uuid.UUID  `json:"item_id" binding:"required"`
	SiteID      uuid.UUID  `json:"site_id" binding:"required"`
	WarehouseID *uuid.UUID `json:"warehouse_id,omitempty"`
	BinID       *uuid.UUID `json:"bin_id,omitempty"`
	Quantity    float64    `json:"quantity" binding:"required,gt=0"`
	UnitCost    float64    `json:"unit_cost"`
	BatchNo     string     `json:"batch_no,omitempty"`
}

type CreateWorkOrderReceiptRequest struct {
	ProductionOrderID uuid.UUID  `json:"production_order_id" binding:"required"`
	SiteID            uuid.UUID  `json:"site_id" binding:"required"`
	WarehouseID       *uuid.UUID `json:"warehouse_id,omitempty"`
	BinID             *uuid.UUID `json:"bin_id,omitempty"`
	Quantity          float64    `json:"quantity" binding:"required,gt=0"`
	BatchNo           string     `json:"batch_no,omitempty"`
}

// ── Purchase Receipt ──

type PurchaseReceipt struct {
	ID          uuid.UUID  `json:"id"`
	OrgID       uuid.UUID  `json:"org_id"`
	POID        uuid.UUID  `json:"po_id"`
	ItemID      uuid.UUID  `json:"item_id"`
	SiteID      uuid.UUID  `json:"site_id"`
	BinID       *uuid.UUID `json:"bin_id,omitempty"`
	WarehouseID *uuid.UUID `json:"warehouse_id,omitempty"`
	Quantity    float64    `json:"quantity"`
	UnitCost    float64    `json:"unit_cost"`
	TotalCost   float64    `json:"total_cost"`
	BatchNo     string     `json:"batch_no,omitempty"`
	ReceiptDate time.Time  `json:"receipt_date"`
	ReceivedBy  *uuid.UUID `json:"received_by,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	IsReversed  bool       `json:"is_reversed"`
	ReversedAt  *time.Time `json:"reversed_at,omitempty"`
	// Joined fields
	PONumber      string `json:"po_number,omitempty"`
	ItemSKU       string `json:"item_sku,omitempty"`
	ItemName      string `json:"item_name,omitempty"`
	SiteCode      string `json:"site_code,omitempty"`
	SiteName      string `json:"site_name,omitempty"`
	WhCode        string `json:"warehouse_code,omitempty"`
	WhName        string `json:"warehouse_name,omitempty"`
	ReceiptSource string `json:"receipt_source,omitempty"`
}

type WorkOrderReceipt struct {
	ID                uuid.UUID  `json:"id"`
	TenantID          uuid.UUID  `json:"tenant_id"`
	ProductionOrderID uuid.UUID  `json:"production_order_id"`
	OrderNumber       string     `json:"order_number,omitempty"`
	MaterialID        uuid.UUID  `json:"material_id"`
	MaterialSKU       string     `json:"material_sku,omitempty"`
	MaterialName      string     `json:"material_name,omitempty"`
	SiteID            uuid.UUID  `json:"site_id"`
	WarehouseID       uuid.UUID  `json:"warehouse_id"`
	BinID             *uuid.UUID `json:"bin_id,omitempty"`
	Quantity          float64    `json:"quantity"`
	UnitCost          float64    `json:"unit_cost"`
	TotalCost         float64    `json:"total_cost"`
	BatchNo           string     `json:"batch_no,omitempty"`
	ReceiptDate       time.Time  `json:"receipt_date"`
	ReceivedBy        *uuid.UUID `json:"received_by,omitempty"`
	GLJournalEntryID  *uuid.UUID `json:"gl_journal_entry_id,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
}

// ── Purchase Invoice ──

type InvoiceItem struct {
	ID          uuid.UUID  `json:"id"`
	InvoiceID   uuid.UUID  `json:"invoice_id"`
	POItemID    *uuid.UUID `json:"po_item_id,omitempty"`
	ItemID      uuid.UUID  `json:"item_id"`
	ItemSKU     string     `json:"item_sku,omitempty"`
	ItemName    string     `json:"item_name,omitempty"`
	Quantity    float64    `json:"quantity"`
	UnitPrice   float64    `json:"unit_price"`
	LineTotal   float64    `json:"line_total"`
	GRQuantity  float64    `json:"gr_quantity"`
	POUnitPrice float64    `json:"po_unit_price"`
	PriceDiff   float64    `json:"price_diff"`
}

type PurchaseInvoice struct {
	ID            uuid.UUID     `json:"id"`
	OrgID         uuid.UUID     `json:"org_id"`
	InvoiceNumber string        `json:"invoice_number"`
	VendorID      uuid.UUID     `json:"vendor_id"`
	POID          *uuid.UUID    `json:"po_id,omitempty"`
	InvoiceDate   time.Time     `json:"invoice_date"`
	TotalAmount   float64       `json:"total_amount"`
	TaxAmount     float64       `json:"tax_amount"`
	Currency      string        `json:"currency"`
	Status        string        `json:"status"`
	MatchStatus   string        `json:"match_status,omitempty"`
	OCRData       *string       `json:"ocr_data,omitempty"`
	Notes         string        `json:"notes,omitempty"`
	CreatedBy     *uuid.UUID    `json:"created_by,omitempty"`
	CreatedAt     time.Time     `json:"created_at"`
	UpdatedAt     time.Time     `json:"updated_at"`
	VendorName    string        `json:"vendor_name,omitempty"`
	PONumber      string        `json:"po_number,omitempty"`
	Items         []InvoiceItem `json:"items,omitempty"`
}

type CreateInvoiceItemRequest struct {
	POItemID  *uuid.UUID `json:"po_item_id,omitempty"`
	ItemID    uuid.UUID  `json:"item_id" binding:"required"`
	Quantity  float64    `json:"quantity" binding:"required,gt=0"`
	UnitPrice float64    `json:"unit_price" binding:"required,gt=0"`
}

type CreateInvoiceRequest struct {
	InvoiceNumber string                     `json:"invoice_number" binding:"required"`
	VendorID      uuid.UUID                  `json:"vendor_id" binding:"required"`
	POID          *uuid.UUID                 `json:"po_id,omitempty"`
	InvoiceDate   string                     `json:"invoice_date,omitempty"`
	TotalAmount   float64                    `json:"total_amount" binding:"required,gt=0"`
	TaxAmount     float64                    `json:"tax_amount"`
	Currency      string                     `json:"currency,omitempty"`
	Notes         string                     `json:"notes,omitempty"`
	Items         []CreateInvoiceItemRequest `json:"items,omitempty"`
}

// ── Outstanding Invoice (for AP aging report) ──

type OutstandingInvoice struct {
	ID            string  `json:"id"`
	OrgID         string  `json:"org_id"`
	OrgCode       string  `json:"org_code"`
	OrgName       string  `json:"org_name"`
	InvoiceNumber string  `json:"invoice_number"`
	InvoiceDate   string  `json:"invoice_date"`
	DueDate       string  `json:"due_date"`
	TotalAmount   float64 `json:"total_amount"`
	PaidAmount    float64 `json:"paid_amount"`
	OpenAmount    float64 `json:"open_amount"`
	Currency      string  `json:"currency"`
	VendorID      string  `json:"vendor_id"`
	VendorCode    string  `json:"vendor_code"`
	VendorName    string  `json:"vendor_name"`
	PONumber      string  `json:"po_number"`
	Status        string  `json:"status"`
	DaysOverdue   int     `json:"days_overdue"`
}

// ── Business Event (async GL posting trigger) ──

type BusinessEvent struct {
	ID           uuid.UUID              `json:"id"`
	OrgID        uuid.UUID              `json:"org_id"`
	EventType    string                 `json:"event_type"`
	SourceID     uuid.UUID              `json:"source_id"`
	SourceType   string                 `json:"source_type"`
	EventData    map[string]interface{} `json:"event_data,omitempty"`
	Status       string                 `json:"status"`
	ErrorMessage string                 `json:"error_message,omitempty"`
	ProcessedAt  *time.Time             `json:"processed_at,omitempty"`
	CreatedAt    time.Time              `json:"created_at"`
}

// ── Down Payment ──

type DownPayment struct {
	ID                 uuid.UUID  `json:"id"`
	OrgID              uuid.UUID  `json:"org_id"`
	DPNumber           string     `json:"dp_number"`
	VendorID           uuid.UUID  `json:"vendor_id"`
	VendorCode         string     `json:"vendor_code,omitempty"`
	VendorName         string     `json:"vendor_name,omitempty"`
	POID               uuid.UUID  `json:"po_id"`
	PONumber           string     `json:"po_number,omitempty"`
	TotalAmount        float64    `json:"total_amount"`
	PaidAmount         float64    `json:"paid_amount"`
	RefundedAmount     float64    `json:"refunded_amount"`
	ClearedAmount      float64    `json:"cleared_amount"`
	RemainingAmount    float64    `json:"remaining_amount"`
	Currency           string     `json:"currency"`
	ExchangeRate       float64    `json:"exchange_rate"`
	APDPAccountID      uuid.UUID  `json:"ap_dp_account_id"`
	APDPAccountCode    string     `json:"ap_dp_account_code,omitempty"`
	APDPAccountName    string     `json:"ap_dp_account_name,omitempty"`
	CreditAccountID    uuid.UUID  `json:"credit_account_id"`
	CreditAccountCode  string     `json:"credit_account_code,omitempty"`
	CreditAccountName  string     `json:"credit_account_name,omitempty"`
	Status             string     `json:"status"`         // DRAFT, POSTED, PARTIALLY_CLEARED, FULLY_CLEARED, PARTIALLY_REFUNDED, FULLY_REFUNDED
	PaymentStatus      string     `json:"payment_status"` // UNPAID, PAID, REFUNDED
	GLJEID             *uuid.UUID `json:"gl_je_id,omitempty"`
	PaymentGLJEID      *uuid.UUID `json:"payment_gl_je_id,omitempty"`
	Description        string     `json:"description,omitempty"`
	ReferenceNo        string     `json:"reference_no,omitempty"`
	SpecialGLIndicator string     `json:"special_gl_indicator"`
	CreatedBy          *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedBy          *uuid.UUID `json:"updated_by,omitempty"`
	UpdatedAt          time.Time  `json:"updated_at"`
	PostedBy           *uuid.UUID `json:"posted_by,omitempty"`
	PostedAt           *time.Time `json:"posted_at,omitempty"`
}

type DownPaymentClearing struct {
	ID             uuid.UUID  `json:"id"`
	DPID           uuid.UUID  `json:"dp_id"`
	InvoiceID      uuid.UUID  `json:"invoice_id"`
	InvoiceNumber  string     `json:"invoice_number,omitempty"`
	ClearingAmount float64    `json:"clearing_amount"`
	Currency       string     `json:"currency"`
	GLJEID         *uuid.UUID `json:"gl_je_id,omitempty"`
	Notes          string     `json:"notes,omitempty"`
	CreatedBy      *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

type DownPaymentRefund struct {
	ID                uuid.UUID  `json:"id"`
	DPID              uuid.UUID  `json:"dp_id"`
	RefundAmount      float64    `json:"refund_amount"`
	RefundDate        time.Time  `json:"refund_date"`
	RefundMethod      string     `json:"refund_method"` // BANK_TRANSFER, CASH, CHECK, OTHER
	SourceAccountID   uuid.UUID  `json:"source_account_id"`
	SourceAccountCode string     `json:"source_account_code,omitempty"`
	SourceAccountName string     `json:"source_account_name,omitempty"`
	GLJEID            *uuid.UUID `json:"gl_je_id,omitempty"`
	PaymentGLJEID     *uuid.UUID `json:"payment_gl_je_id,omitempty"`
	Reason            string     `json:"reason"`
	CreatedBy         *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
}

// ── Request / Response ──

type CreateDownPaymentRequest struct {
	VendorID        uuid.UUID `json:"vendor_id" binding:"required"`
	POID            uuid.UUID `json:"po_id" binding:"required"`
	Amount          float64   `json:"amount" binding:"required,gt=0"`
	Currency        string    `json:"currency,omitempty"`
	ExchangeRate    float64   `json:"exchange_rate,omitempty"`
	CreditAccountID uuid.UUID `json:"credit_account_id" binding:"required"`
	PostImmediately bool      `json:"post_immediately"`
	Description     string    `json:"description,omitempty"`
	ReferenceNo     string    `json:"reference_no,omitempty"`
}

type CreateDownPaymentRefundRequest struct {
	RefundAmount    float64   `json:"refund_amount" binding:"required,gt=0"`
	RefundDate      string    `json:"refund_date,omitempty"`
	RefundMethod    string    `json:"refund_method" binding:"required"`
	SourceAccountID uuid.UUID `json:"source_account_id" binding:"required"`
	Reason          string    `json:"reason" binding:"required"`
}

type CreateDPClearingRequest struct {
	InvoiceID      string  `json:"invoice_id" binding:"required"`
	ClearingAmount float64 `json:"clearing_amount" binding:"required,gt=0"`
}

// ── Vendor Payment & Open Items ──

type OpenItem struct {
	ID            string  `json:"id"`
	Type          string  `json:"type"`
	DocumentNo    string  `json:"document_no"`
	Date          string  `json:"date"`
	DueDate       string  `json:"due_date"`
	TotalAmount   float64 `json:"total_amount"`
	OpenAmount    float64 `json:"open_amount"`
	Currency      string  `json:"currency"`
	IsDownPayment bool    `json:"is_down_payment"`
}

type CreateVendorPaymentRequest struct {
	VendorID        string   `json:"vendor_id" binding:"required"`
	OrgID           string   `json:"org_id" binding:"required"`
	BankAccountID   string   `json:"bank_account_id" binding:"required"`
	PaymentAmount   float64  `json:"payment_amount" binding:"required,gt=0"`
	SelectedItemIDs []string `json:"selected_item_ids" binding:"required,min=1"`
	PaymentDate     string   `json:"payment_date,omitempty"`
	Description     string   `json:"description,omitempty"`
}

type VendorPayment struct {
	ID            uuid.UUID                 `json:"id"`
	OrgID         uuid.UUID                 `json:"org_id"`
	VendorID      uuid.UUID                 `json:"vendor_id"`
	VendorCode    string                    `json:"vendor_code,omitempty"`
	VendorName    string                    `json:"vendor_name,omitempty"`
	BankAccountID uuid.UUID                 `json:"bank_account_id"`
	PaymentAmount float64                   `json:"payment_amount"`
	PaymentDate   time.Time                 `json:"payment_date"`
	Currency      string                    `json:"currency"`
	Status        string                    `json:"status"`
	GLJEID        *uuid.UUID                `json:"gl_je_id,omitempty"`
	Description   string                    `json:"description,omitempty"`
	CreatedBy     *uuid.UUID                `json:"created_by,omitempty"`
	CreatedAt     time.Time                 `json:"created_at"`
	UpdatedAt     time.Time                 `json:"updated_at"`
	Allocations   []VendorPaymentAllocation `json:"allocations,omitempty"`
}

type VendorPaymentAllocation struct {
	ID              uuid.UUID `json:"id"`
	PaymentID       uuid.UUID `json:"payment_id"`
	SourceType      string    `json:"source_type"`
	SourceID        uuid.UUID `json:"source_id"`
	AllocatedAmount float64   `json:"allocated_amount"`
	CreatedAt       time.Time `json:"created_at"`
}

// ── Payment History ──

type PaymentHistoryItem struct {
	ID            string  `json:"id"`
	OrgID         string  `json:"org_id"`
	OrgCode       string  `json:"org_code"`
	OrgName       string  `json:"org_name"`
	VendorID      string  `json:"vendor_id"`
	VendorCode    string  `json:"vendor_code"`
	VendorName    string  `json:"vendor_name"`
	PaymentAmount float64 `json:"payment_amount"`
	PaymentDate   string  `json:"payment_date"`
	Currency      string  `json:"currency"`
	Status        string  `json:"status"`
	Description   string  `json:"description"`
	GLJEID        string  `json:"gl_je_id,omitempty"`
}

// ── AI Vendor Recommendation ──

type VendorRecommendation struct {
	Vendor      Vendor  `json:"vendor"`
	Score       float64 `json:"score"`
	Reason      string  `json:"reason"`
	AvgPrice    float64 `json:"avg_price"`
	AvgLeadTime float64 `json:"avg_lead_time"`
	OnTimeRate  float64 `json:"on_time_rate"`
}
