package models

import (
	"time"

	"github.com/google/uuid"
)

type SalesOrder struct {
	ID             uuid.UUID  `json:"id"`
	TenantID       uuid.UUID  `json:"tenant_id"`
	CustomerID     uuid.UUID  `json:"customer_id"`
	QuotationID    *uuid.UUID `json:"quotation_id,omitempty"`
	SONumber       string     `json:"so_number"`
	SOType         string     `json:"so_type"`
	Status         string     `json:"status"`
	CustomerPONo   string     `json:"customer_po_no,omitempty"`
	PODate         *time.Time `json:"po_date,omitempty"`
	Currency       string     `json:"currency"`
	PaymentTerms   string     `json:"payment_terms"`
	Incoterm       string     `json:"incoterm,omitempty"`
	ValidFrom      time.Time  `json:"valid_from"`
	DeliveryDate   *time.Time `json:"delivery_date,omitempty"`
	RequestedDate  *time.Time `json:"requested_date,omitempty"`
	TotalAmount    float64    `json:"total_amount"`
	DiscountPct    float64    `json:"discount_pct"`
	DiscountAmount float64    `json:"discount_amount"`
	NetAmount      float64    `json:"net_amount"`
	TaxAmount      float64    `json:"tax_amount"`
	GrandTotal     float64    `json:"grand_total"`
	ReceiptMethod  string     `json:"receipt_method,omitempty"`
	ReceivedAmount float64    `json:"received_amount,omitempty"`
	Notes          string     `json:"notes,omitempty"`
	InternalNotes  string     `json:"internal_notes,omitempty"`
	// Shipping
	Carrier           string  `json:"carrier,omitempty"`
	ShippingMethod    string  `json:"shipping_method,omitempty"`
	ShipperAccount    string  `json:"shipper_account,omitempty"`
	SignatureRequired bool    `json:"signature_required"`
	SaturdayDelivery  bool    `json:"saturday_delivery"`
	InsuranceAmt      float64 `json:"insurance_amt,omitempty"`
	AllowEarlyShip    bool    `json:"allow_early_ship"`
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
	BillingBlocked bool `json:"billing_blocked"`
	// Delivery Block
	DeliveryBlockID   *uuid.UUID `json:"delivery_block_id,omitempty"`
	DeliveryBlockCode string     `json:"delivery_block_code,omitempty"`
	DeliveryBlockDesc string     `json:"delivery_block_description,omitempty"`
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
	ID                    uuid.UUID                `json:"id"`
	SOID                  uuid.UUID                `json:"so_id"`
	LineNo                int                      `json:"line_no"`
	ProductID             uuid.UUID                `json:"product_id"`
	DeliveringSiteID      *uuid.UUID               `json:"delivering_site_id,omitempty"`
	QuotationItemID       *uuid.UUID               `json:"quotation_item_id,omitempty"`
	Description           string                   `json:"description,omitempty"`
	Quantity              float64                  `json:"quantity"`
	AllocatedQty          float64                  `json:"allocated_qty"`
	DeliveredQty          float64                  `json:"delivered_qty"`
	OpenDeliveryQty       float64                  `json:"open_delivery_qty"`
	ATPStatus             string                   `json:"atp_status,omitempty"`
	UnitOfMeasure         string                   `json:"unit_of_measure"`
	UnitPrice             float64                  `json:"unit_price"`
	DiscountPct           float64                  `json:"discount_pct"`
	LineTotal             float64                  `json:"line_total"`
	DeliveryDate          *time.Time               `json:"delivery_date,omitempty"`
	ConfirmedDeliveryDate *time.Time               `json:"confirmed_delivery_date,omitempty"`
	CreatedAt             time.Time                `json:"created_at"`
	ScheduleLines         []SalesOrderScheduleLine `json:"schedule_lines,omitempty"`
	// Joined
	ProductSKU  string `json:"product_sku,omitempty"`
	ProductName string `json:"product_name,omitempty"`
}

type SalesOrderScheduleLine struct {
	ID             uuid.UUID  `json:"id"`
	SOItemID       uuid.UUID  `json:"so_item_id"`
	ScheduleLineNo int        `json:"schedule_line_no"`
	ConfirmedQty   float64    `json:"confirmed_qty"`
	ConfirmedDate  *time.Time `json:"confirmed_date,omitempty"`
	SourceType     string     `json:"source_type"`
	SourceRef      string     `json:"source_ref,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

type ATPPreviewScheduleLine struct {
	ConfirmedQty  float64 `json:"confirmed_qty"`
	ConfirmedDate string  `json:"confirmed_date,omitempty"`
	SourceType    string  `json:"source_type"`
	SourceRef     string  `json:"source_ref,omitempty"`
}

type CreateSalesOrderRequest struct {
	CustomerID         string                `json:"customer_id" binding:"required"`
	OrderType          string                `json:"order_type,omitempty"`
	QuotationID        string                `json:"quotation_id,omitempty"`
	CustomerPONo       string                `json:"customer_po_no,omitempty"`
	PODate             string                `json:"po_date,omitempty"`
	Currency           string                `json:"currency,omitempty"`
	PaymentTerms       string                `json:"payment_terms,omitempty"`
	Incoterm           string                `json:"incoterm,omitempty"`
	ValidFrom          string                `json:"valid_from,omitempty"`
	DeliveryDate       string                `json:"delivery_date,omitempty"`
	RequestedDate      string                `json:"requested_date,omitempty"`
	DiscountPct        float64               `json:"discount_pct,omitempty"`
	TaxAmount          float64               `json:"tax_amount,omitempty"`
	Notes              string                `json:"notes,omitempty"`
	InternalNotes      string                `json:"internal_notes,omitempty"`
	Carrier            string                `json:"carrier,omitempty"`
	ShippingMethod     string                `json:"shipping_method,omitempty"`
	ShipperAccount     string                `json:"shipper_account,omitempty"`
	SignatureRequired  bool                  `json:"signature_required"`
	SaturdayDelivery   bool                  `json:"saturday_delivery"`
	InsuranceAmt       float64               `json:"insurance_amt,omitempty"`
	AllowEarlyShip     bool                  `json:"allow_early_ship"`
	TransportationTo   string                `json:"transportation_to,omitempty"`
	TransportPayerAcct string                `json:"transport_payer_account,omitempty"`
	BillToAddress      string                `json:"bill_to_address,omitempty"`
	ReceiptMethod      string                `json:"receipt_method,omitempty"`
	ReceivedAmount     *float64              `json:"received_amount,omitempty"`
	DeliveryBlockID    string                `json:"delivery_block_id,omitempty"`
	BillingBlocked     bool                  `json:"billing_blocked"`
	Items              []CreateSOItemRequest `json:"items" binding:"required,min=1"`
}

type CreateSOItemRequest struct {
	ProductID        string  `json:"product_id" binding:"required"`
	DeliveringSiteID string  `json:"delivering_site_id,omitempty"`
	Description      string  `json:"description,omitempty"`
	Quantity         float64 `json:"quantity" binding:"required,gt=0"`
	UOM              string  `json:"unit_of_measure,omitempty"`
	UnitPrice        float64 `json:"unit_price" binding:"required,gte=0"`
	DiscountPct      float64 `json:"discount_pct,omitempty"`
	DeliveryDate     string  `json:"delivery_date,omitempty"`
}

type UpdateSOStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=DRAFT PENDING_APPROVAL APPROVED CONFIRMED SHIPPED INVOICED COMPLETED CANCELLED"`
}

type UpdateSalesOrderRequest struct {
	CustomerID         string                `json:"customer_id,omitempty"`
	OrderType          string                `json:"order_type,omitempty"`
	CustomerPONo       string                `json:"customer_po_no,omitempty"`
	PODate             string                `json:"po_date,omitempty"`
	Currency           string                `json:"currency,omitempty"`
	PaymentTerms       string                `json:"payment_terms,omitempty"`
	Incoterm           string                `json:"incoterm,omitempty"`
	ValidFrom          string                `json:"valid_from,omitempty"`
	DeliveryDate       string                `json:"delivery_date,omitempty"`
	RequestedDate      string                `json:"requested_date,omitempty"`
	EmployeeID         string                `json:"employee_id,omitempty"`
	DiscountPct        *float64              `json:"discount_pct,omitempty"`
	TaxAmount          *float64              `json:"tax_amount,omitempty"`
	Notes              string                `json:"notes,omitempty"`
	InternalNotes      string                `json:"internal_notes,omitempty"`
	Carrier            string                `json:"carrier,omitempty"`
	ShippingMethod     string                `json:"shipping_method,omitempty"`
	ShipperAccount     string                `json:"shipper_account,omitempty"`
	SignatureRequired  *bool                 `json:"signature_required,omitempty"`
	SaturdayDelivery   *bool                 `json:"saturday_delivery,omitempty"`
	InsuranceAmt       *float64              `json:"insurance_amt,omitempty"`
	AllowEarlyShip     *bool                 `json:"allow_early_ship,omitempty"`
	TransportationTo   string                `json:"transportation_to,omitempty"`
	TransportPayerAcct string                `json:"transport_payer_account,omitempty"`
	BillToAddress      string                `json:"bill_to_address,omitempty"`
	ReceiptMethod      string                `json:"receipt_method,omitempty"`
	ReceivedAmount     *float64              `json:"received_amount,omitempty"`
	DeliveryBlockID    *string               `json:"delivery_block_id,omitempty"`
	Items              []CreateSOItemRequest `json:"items,omitempty"`
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

type DeliveryNote struct {
	ID               uuid.UUID          `json:"id"`
	TenantID         uuid.UUID          `json:"tenant_id"`
	DeliveryNo       string             `json:"delivery_no"`
	SONumber         string             `json:"so_number,omitempty"`
	CustomerPONo     string             `json:"customer_po_no,omitempty"`
	CompanyName      string             `json:"company_name,omitempty"`
	SalesOrderID     uuid.UUID          `json:"sales_order_id"`
	CustomerID       uuid.UUID          `json:"customer_id"`
	CustomerCode     string             `json:"customer_code,omitempty"`
	CustomerName     string             `json:"customer_name,omitempty"`
	WarehouseID      uuid.UUID          `json:"warehouse_id"`
	WarehouseCode    string             `json:"warehouse_code,omitempty"`
	WarehouseName    string             `json:"warehouse_name,omitempty"`
	WarehouseAddress string             `json:"warehouse_address,omitempty"`
	SelectionDate    time.Time          `json:"selection_date"`
	ShipToName       string             `json:"ship_to_name,omitempty"`
	ShipToPhone      string             `json:"ship_to_phone,omitempty"`
	ShipToAddress    string             `json:"ship_to_address,omitempty"`
	ShippingMethod   string             `json:"shipping_method,omitempty"`
	Route            string             `json:"route,omitempty"`
	Status           string             `json:"status"`
	CreatedAt        time.Time          `json:"created_at"`
	UpdatedAt        time.Time          `json:"updated_at"`
	PGIAt            *time.Time         `json:"pgi_at,omitempty"`
	Items            []DeliveryNoteItem `json:"items,omitempty"`
}

type DeliveryNoteItem struct {
	ID             uuid.UUID `json:"id"`
	DeliveryID     uuid.UUID `json:"delivery_id"`
	SOItemID       uuid.UUID `json:"so_item_id"`
	ItemNo         int       `json:"item_no"`
	ProductID      uuid.UUID `json:"product_id"`
	SKUCode        string    `json:"sku_code"`
	GoodsName      string    `json:"goods_name"`
	OrderQty       float64   `json:"order_qty"`
	DeliveryQty    float64   `json:"delivery_qty"`
	PickedQty      float64   `json:"picked_qty"`
	BilledQty      float64   `json:"billed_qty"`
	OpenBillingQty float64   `json:"open_billing_qty"`
	UnitOfMeasure  string    `json:"unit_of_measure"`
	StockLoc       string    `json:"stock_loc,omitempty"`
	PGIStatus      string    `json:"pgi_status"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type CreateDeliveryNoteRequest struct {
	WarehouseID   string                   `json:"warehouse_id" binding:"required"`
	SelectionDate string                   `json:"selection_date,omitempty"`
	ReferenceNo   string                   `json:"reference_no" binding:"required"`
	Items         []CreateDeliveryNoteItem `json:"items,omitempty"`
}

type CreateDeliveryNoteItem struct {
	SOItemID    string  `json:"so_item_id" binding:"required"`
	DeliveryQty float64 `json:"delivery_qty" binding:"required"`
}

type UpdateDeliveryPickingRequest struct {
	Items []UpdateDeliveryPickingItem `json:"items" binding:"required,min=1"`
}

type UpdateDeliveryPickingItem struct {
	ID        string  `json:"id" binding:"required"`
	PickedQty float64 `json:"picked_qty"`
	StockLoc  string  `json:"stock_loc,omitempty"`
}

type SalesInvoice struct {
	ID                      uuid.UUID          `json:"id"`
	TenantID                uuid.UUID          `json:"tenant_id"`
	InvoiceNo               string             `json:"invoice_no"`
	DeliveryID              uuid.UUID          `json:"delivery_id"`
	DeliveryNo              string             `json:"delivery_no,omitempty"`
	SalesOrderID            uuid.UUID          `json:"sales_order_id"`
	SONumber                string             `json:"so_number,omitempty"`
	CustomerID              uuid.UUID          `json:"customer_id"`
	CustomerCode            string             `json:"customer_code,omitempty"`
	CustomerName            string             `json:"customer_name,omitempty"`
	InvoiceDate             time.Time          `json:"invoice_date"`
	Currency                string             `json:"currency"`
	NetAmount               float64            `json:"net_amount"`
	TaxAmount               float64            `json:"tax_amount"`
	TotalAmount             float64            `json:"total_amount"`
	Status                  string             `json:"status"`
	JournalEntryID          *uuid.UUID         `json:"journal_entry_id,omitempty"`
	JournalEntryNo          string             `json:"journal_entry_no,omitempty"`
	JournalEntryDescription string             `json:"journal_entry_description,omitempty"`
	CreatedBy               *uuid.UUID         `json:"created_by,omitempty"`
	CreatedAt               time.Time          `json:"created_at"`
	UpdatedAt               time.Time          `json:"updated_at"`
	PostedAt                *time.Time         `json:"posted_at,omitempty"`
	Items                   []SalesInvoiceItem `json:"items,omitempty"`
}

type SalesInvoiceItem struct {
	ID             uuid.UUID `json:"id"`
	InvoiceID      uuid.UUID `json:"invoice_id"`
	DeliveryItemID uuid.UUID `json:"delivery_item_id"`
	SOItemID       uuid.UUID `json:"so_item_id"`
	ItemNo         int       `json:"item_no"`
	ProductID      uuid.UUID `json:"product_id"`
	SKUCode        string    `json:"sku_code,omitempty"`
	GoodsName      string    `json:"goods_name,omitempty"`
	Quantity       float64   `json:"quantity"`
	UnitOfMeasure  string    `json:"unit_of_measure"`
	UnitPrice      float64   `json:"unit_price"`
	DiscountPct    float64   `json:"discount_pct"`
	NetAmount      float64   `json:"net_amount"`
	TaxAmount      float64   `json:"tax_amount"`
	LineTotal      float64   `json:"line_total"`
	CreatedAt      time.Time `json:"created_at"`
}

type CreateSalesInvoiceRequest struct {
	DeliveryID      string                          `json:"delivery_id" binding:"required"`
	InvoiceDate     string                          `json:"invoice_date,omitempty"`
	PostImmediately bool                            `json:"post_immediately"`
	Items           []CreateSalesInvoiceItemRequest `json:"items,omitempty"`
}

type CreateSalesInvoiceItemRequest struct {
	DeliveryItemID string  `json:"delivery_item_id" binding:"required"`
	BillingQty     float64 `json:"billing_qty" binding:"required"`
}
