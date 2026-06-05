package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
	salesrepo "github.com/swiftai-erp/backend/internal/sales/repository"
)

type SalesService struct {
	repo *salesrepo.SalesRepo
}

func NewSalesService(repo *salesrepo.SalesRepo) *SalesService {
	return &SalesService{repo: repo}
}

// ── Customers ──

func (s *SalesService) ListCustomers(ctx context.Context, tenantID uuid.UUID, query, status string) ([]*salesmodels.Customer, error) {
	return s.repo.ListCustomers(ctx, tenantID, query, status)
}

func (s *SalesService) GetCustomer(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.Customer, error) {
	return s.repo.GetCustomer(ctx, id, tenantID)
}

func (s *SalesService) CreateCustomer(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateCustomerRequest) (*salesmodels.Customer, error) {
	return s.repo.CreateCustomer(ctx, tenantID, req)
}

func (s *SalesService) UpdateCustomer(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateCustomerRequest) error {
	return s.repo.UpdateCustomer(ctx, id, tenantID, req)
}

func (s *SalesService) DeleteCustomer(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteCustomer(ctx, id, tenantID)
}

// ── Customer Certificates ──

func (s *SalesService) ListCertificates(ctx context.Context, customerID, tenantID uuid.UUID) ([]*salesmodels.CustomerCertificate, error) {
	return s.repo.ListCertificates(ctx, customerID, tenantID)
}

func (s *SalesService) UploadCertificate(ctx context.Context, cert *salesmodels.CustomerCertificate) error {
	return s.repo.UploadCertificate(ctx, cert)
}

func (s *SalesService) DeleteCertificate(ctx context.Context, id, customerID, tenantID uuid.UUID) error {
	return s.repo.DeleteCertificate(ctx, id, customerID, tenantID)
}

// ── Material Prices ──

func (s *SalesService) ListMaterialPrices(ctx context.Context, tenantID uuid.UUID, productID uuid.UUID, activeOnly bool) ([]*salesmodels.MaterialPrice, error) {
	return s.repo.ListMaterialPrices(ctx, tenantID, productID, activeOnly)
}

func (s *SalesService) GetMaterialPrice(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.MaterialPrice, error) {
	return s.repo.GetMaterialPrice(ctx, id, tenantID)
}

func (s *SalesService) CreateMaterialPrice(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateMaterialPriceRequest) (*salesmodels.MaterialPrice, error) {
	return s.repo.CreateMaterialPrice(ctx, tenantID, req)
}

func (s *SalesService) UpdateMaterialPrice(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateMaterialPriceRequest) error {
	return s.repo.UpdateMaterialPrice(ctx, id, tenantID, req)
}

func (s *SalesService) DeleteMaterialPrice(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteMaterialPrice(ctx, id, tenantID)
}

func (s *SalesService) LookupMaterialPrice(ctx context.Context, tenantID, customerID, productID uuid.UUID) (*salesmodels.MaterialPrice, error) {
	return s.repo.LookupMaterialPrice(ctx, tenantID, customerID, productID)
}

// ── Quotations ──

func (s *SalesService) ListQuotations(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.Quotation, error) {
	return s.repo.ListQuotations(ctx, tenantID, status)
}

func (s *SalesService) GetQuotation(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.Quotation, error) {
	return s.repo.GetQuotation(ctx, id, tenantID)
}

func (s *SalesService) CreateQuotation(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateQuotationRequest, userID *uuid.UUID) (*salesmodels.Quotation, error) {
	customerID, _ := uuid.Parse(req.CustomerID)

	// Generate quotation number
	qNo, err := s.repo.GetNextQuotationNo(ctx, tenantID)
	if err != nil { return nil, fmt.Errorf("generate number: %w", err) }

	validFrom := time.Now()
	if req.ValidFrom != "" {
		if d, err := time.Parse("2006-01-02", req.ValidFrom); err == nil { validFrom = d }
	}
	var validTo *time.Time
	if req.ValidTo != "" {
		if d, err := time.Parse("2006-01-02", req.ValidTo); err == nil { validTo = &d }
	}
	var deliveryDate *time.Time
	if req.DeliveryDate != "" {
		if d, err := time.Parse("2006-01-02", req.DeliveryDate); err == nil { deliveryDate = &d }
	}

	qType := req.QuotationType
	if qType == "" { qType = "STANDARD" }
	currency := req.Currency
	if currency == "" { currency = "USD" }
	paymentTerms := req.PaymentTerms
	if paymentTerms == "" { paymentTerms = "Net 30" }

	// Calculate totals
	var totalAmount float64
	var items []*salesmodels.QuotationItem
	for i, it := range req.Items {
		prodID, _ := uuid.Parse(it.ProductID)
		uom := it.UOM
		if uom == "" { uom = "EA" }
		lineTotal := it.Quantity * it.UnitPrice * (1 - it.DiscountPct/100)
		totalAmount += lineTotal

		var itemDelDate *time.Time
		if it.DeliveryDate != "" {
			if d, err := time.Parse("2006-01-02", it.DeliveryDate); err == nil { itemDelDate = &d }
		}

		items = append(items, &salesmodels.QuotationItem{
			ID: uuid.New(), QuotationID: uuid.Nil, LineNo: i + 10,
			ProductID: prodID, Description: it.Description,
			Quantity: it.Quantity, UnitOfMeasure: uom, UnitPrice: it.UnitPrice,
			DiscountPct: it.DiscountPct, LineTotal: lineTotal,
			DeliveryDate: itemDelDate, CreatedAt: time.Now(),
		})
	}

	discountAmt := totalAmount * req.DiscountPct / 100
	netAmount := totalAmount - discountAmt
	grandTotal := netAmount + req.TaxAmount

	// Parse employee_id
	var empID *uuid.UUID
	if req.EmployeeID != "" { if e, err := uuid.Parse(req.EmployeeID); err == nil { empID = &e } }

	q := &salesmodels.Quotation{
		ID: uuid.New(), TenantID: tenantID, CustomerID: customerID,
		QuotationNo: qNo, QuotationType: qType, Status: "DRAFT",
		ValidFrom: validFrom, ValidTo: validTo,
		Currency: currency, PaymentTerms: paymentTerms, Incoterm: req.Incoterm,
		DeliveryDate: deliveryDate,
		TotalAmount: totalAmount, DiscountPct: req.DiscountPct, DiscountAmount: discountAmt,
		NetAmount: netAmount, TaxAmount: req.TaxAmount,
		TaxCalcSource: req.TaxCalcSource, TaxCalcDetail: req.TaxCalcDetail, TaxCalcRate: req.TaxCalcRate,
		GrandTotal: grandTotal,
		Notes: req.Notes, InternalNotes: req.InternalNotes,
		ReferenceInquiry: req.ReferenceInquiry,
		EmployeeID: empID,
		CreatedBy: userID, CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}

	// Set quotation_id on items after q.ID is known
	for _, item := range items {
		item.QuotationID = q.ID
	}

	if err := s.repo.CreateQuotation(ctx, q, items); err != nil {
		return nil, err
	}
	// Re-fetch to populate JOINed fields (employee_code, employee_name, customer_code, etc.)
	if full, err := s.repo.GetQuotation(ctx, q.ID, tenantID); err == nil && full != nil {
		q = full
	} else {
		// Fallback: set items from create
		for _, it := range items { q.Items = append(q.Items, *it) }
	}
	return q, nil
}

func (s *SalesService) UpdateQuotationStatus(ctx context.Context, id, tenantID uuid.UUID, status string) error {
	return s.repo.UpdateQuotationStatus(ctx, id, tenantID, status)
}

func (s *SalesService) DeleteQuotation(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteQuotation(ctx, id, tenantID)
}

func (s *SalesService) PrintQuotation(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.Quotation, error) {
	return s.repo.GetQuotationForPrint(ctx, id, tenantID)
}

// ── Sales Orders ──

func (s *SalesService) ListSalesOrders(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.SalesOrder, error) {
	return s.repo.ListSalesOrders(ctx, tenantID, status)
}

func (s *SalesService) GetSalesOrder(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.SalesOrder, error) {
	return s.repo.GetSalesOrder(ctx, id, tenantID)
}

func (s *SalesService) CreateSalesOrder(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateSalesOrderRequest, userID *uuid.UUID) (*salesmodels.SalesOrder, error) {
	customerID, _ := uuid.Parse(req.CustomerID)
	soNo, err := s.repo.GetNextSONo(ctx, tenantID)
	if err != nil { return nil, fmt.Errorf("generate so number: %w", err) }

	// Parse the quotation if provided
	var quotationID *uuid.UUID
	if req.QuotationID != "" {
		if qid, err := uuid.Parse(req.QuotationID); err == nil { quotationID = &qid }
	}

	validFrom := time.Now()
	if req.ValidFrom != "" { if d, err := time.Parse("2006-01-02", req.ValidFrom); err == nil { validFrom = d } }
	var deliveryDate, requestedDate, poDate *time.Time
	if req.DeliveryDate != "" { if d, err := time.Parse("2006-01-02", req.DeliveryDate); err == nil { deliveryDate = &d } }
	if req.RequestedDate != "" { if d, err := time.Parse("2006-01-02", req.RequestedDate); err == nil { requestedDate = &d } }
	if req.PODate != "" { if d, err := time.Parse("2006-01-02", req.PODate); err == nil { poDate = &d } }

	currency := req.Currency; if currency == "" { currency = "USD" }
	paymentTerms := req.PaymentTerms; if paymentTerms == "" { paymentTerms = "Net 30" }

	// Build items and calculate totals
	var totalAmount float64
	var items []*salesmodels.SalesOrderItem
	for i, it := range req.Items {
		prodID, _ := uuid.Parse(it.ProductID)
		uom := it.UOM; if uom == "" { uom = "EA" }
		lineTotal := it.Quantity * it.UnitPrice * (1 - it.DiscountPct/100)
		totalAmount += lineTotal
		var itemDelDate *time.Time
		if it.DeliveryDate != "" { if d, err := time.Parse("2006-01-02", it.DeliveryDate); err == nil { itemDelDate = &d } }
		items = append(items, &salesmodels.SalesOrderItem{
			ID: uuid.New(), SOID: uuid.Nil, LineNo: i + 10,
			ProductID: prodID, Description: it.Description,
			Quantity: it.Quantity, UnitOfMeasure: uom, UnitPrice: it.UnitPrice,
			DiscountPct: it.DiscountPct, LineTotal: lineTotal,
			DeliveryDate: itemDelDate, CreatedAt: time.Now(),
		})
	}

	discountAmt := totalAmount * req.DiscountPct / 100
	netAmount := totalAmount - discountAmt
	grandTotal := netAmount + req.TaxAmount

	soType := req.OrderType
	if soType == "" { soType = "OR" }

	so := &salesmodels.SalesOrder{
		ID: uuid.New(), TenantID: tenantID, CustomerID: customerID, QuotationID: quotationID,
		SONumber: soNo, SOType: soType, Status: "DRAFT",
		CustomerPONo: req.CustomerPONo, PODate: poDate,
		Currency: currency, PaymentTerms: paymentTerms, Incoterm: req.Incoterm,
		ValidFrom: validFrom, DeliveryDate: deliveryDate, RequestedDate: requestedDate,
		TotalAmount: totalAmount, DiscountPct: req.DiscountPct, DiscountAmount: discountAmt,
		NetAmount: netAmount, TaxAmount: req.TaxAmount, GrandTotal: grandTotal,
		Notes: req.Notes, InternalNotes: req.InternalNotes,
		Carrier: req.Carrier, ShippingMethod: req.ShippingMethod, ShipperAccount: req.ShipperAccount,
		SignatureRequired: req.SignatureRequired, SaturdayDelivery: req.SaturdayDelivery, InsuranceAmt: req.InsuranceAmt,
		TransportationTo: req.TransportationTo, TransportPayerAccount: req.TransportPayerAcct, BillToAddress: req.BillToAddress,
		CreditCheckStatus: "PENDING", InventoryCheckStatus: "PENDING", TaxCalcStatus: "PENDING", AllocationStatus: "PENDING",
		CreatedBy: userID, CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}

	for _, item := range items { item.SOID = so.ID }

	if err := s.repo.CreateSalesOrder(ctx, so, items); err != nil { return nil, err }

	// ── Automated Checks ──
	// 1. Inventory Check
	invStatus, _ := s.repo.CheckInventory(ctx, tenantID, items)
	so.InventoryCheckStatus = invStatus

	// 2. Credit Check
	creditStatus, _ := s.repo.CheckCreditLimit(ctx, tenantID, customerID, grandTotal)
	so.CreditCheckStatus = creditStatus

	// 3. Tax Calculation
	taxAmount, taxStatus, _ := s.repo.CalculateTax(ctx, tenantID, customerID, netAmount)
	if (taxStatus == "CALCULATED" || taxStatus == "EXEMPT") && req.TaxAmount == 0 {
		so.TaxAmount = taxAmount
		so.GrandTotal = netAmount + taxAmount
		// Persist the calculated/zero tax amount
		_ = s.repo.UpdateTaxAmount(ctx, so.ID, tenantID, so.TaxAmount, so.GrandTotal)
	}
	so.TaxCalcStatus = taxStatus

	// 4. Inventory Allocation
	allocStatus, _ := s.repo.AllocateInventory(ctx, tenantID, items)
	so.AllocationStatus = allocStatus

	// ── Approval Flow ──
	// If inventory is available and credit passes → CONFIRMED
	// If inventory is partial/unavailable or needs review → PENDING_APPROVAL
	// If credit fails → stays DRAFT with FAILED credit status
	if creditStatus == "FAILED" {
		so.Status = "DRAFT" // stays draft for review
	} else if invStatus == "AVAILABLE" && (creditStatus == "PASSED" || creditStatus == "SKIPPED") {
		so.Status = "CONFIRMED"
		_ = s.repo.UpdateSOStatus(ctx, so.ID, tenantID, "CONFIRMED")
	} else {
		// Partial inventory or unavailable → needs approval
		so.Status = "PENDING_APPROVAL"
		_ = s.repo.UpdateSOStatus(ctx, so.ID, tenantID, "PENDING_APPROVAL")
	}

	for _, it := range items { so.Items = append(so.Items, *it) }
	return so, nil
}

func (s *SalesService) UpdateSOStatus(ctx context.Context, id, tenantID uuid.UUID, status string) error {
	return s.repo.UpdateSOStatus(ctx, id, tenantID, status)
}

func (s *SalesService) DeleteSalesOrder(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteSalesOrder(ctx, id, tenantID)
}

// ── ATP Check ──

type ATPResult struct {
	ProductID     uuid.UUID `json:"product_id"`
	Quantity      float64   `json:"quantity"`
	OnHand        float64   `json:"on_hand"`
	Available     float64   `json:"available"`
	Status        string    `json:"status"` // AVAILABLE / PARTIAL / UNAVAILABLE
	SuggestedDate string    `json:"suggested_date,omitempty"`
}

func (s *SalesService) CheckATP(ctx context.Context, tenantID uuid.UUID, productID uuid.UUID, quantity float64) (*ATPResult, error) {
	var onHand float64
	err := s.repo.GetStockOnHand(ctx, tenantID, productID, &onHand)
	if err != nil { return nil, err }

	avail := onHand
	status := "AVAILABLE"
	if avail < quantity {
		if avail <= 0 {
			status = "UNAVAILABLE"
		} else {
			status = "PARTIAL"
		}
	}

	return &ATPResult{
		ProductID: productID,
		Quantity:  quantity,
		OnHand:    onHand,
		Available: avail,
		Status:    status,
	}, nil
}

// ── Pricing Engine ──

type PricingLineItem struct {
	ProductID   string  `json:"product_id"`
	Quantity    float64 `json:"quantity"`
	BasePrice   float64 `json:"base_price"`
	DiscountPct float64 `json:"discount_pct"`
	LineTotal   float64 `json:"line_total"`
}

type PricingCondition struct {
	Type    string  `json:"type"`    // BASE_PRICE, QUANTITY_DISCOUNT, PROMOTION, SURCHARGE
	Label   string  `json:"label"`
	Amount  float64 `json:"amount"`
}

type PricingResult struct {
	Items       []PricingLineItem   `json:"items"`
	Conditions  []PricingCondition  `json:"conditions"`
	Subtotal    float64             `json:"subtotal"`
	TotalDisc   float64             `json:"total_discount"`
	NetAmount   float64             `json:"net_amount"`
}

type PricingRequest struct {
	CustomerID string            `json:"customer_id" binding:"required"`
	Items      []PricingLineItem `json:"items" binding:"required,min=1"`
}

func (s *SalesService) CalculatePrice(ctx context.Context, tenantID uuid.UUID, req *PricingRequest) (*PricingResult, error) {
	customerID, _ := uuid.Parse(req.CustomerID)
	result := &PricingResult{Conditions: []PricingCondition{}, Items: []PricingLineItem{}}

	for _, it := range req.Items {
		prodID, _ := uuid.Parse(it.ProductID)
		// Get customer-specific price from material price
		mp, _ := s.repo.LookupMaterialPrice(ctx, tenantID, customerID, prodID)
		basePrice := it.BasePrice
		if mp != nil && mp.Price > 0 {
			basePrice = mp.Price
		}

		disc := it.DiscountPct
		// Tiered quantity discount
		if it.Quantity >= 100 {
			disc = 15.0
		} else if it.Quantity >= 50 {
			disc = 10.0
		} else if it.Quantity >= 10 {
			disc = 5.0
		}

		lineTotal := it.Quantity * basePrice * (1 - disc/100)
		result.Items = append(result.Items, PricingLineItem{
			ProductID: it.ProductID, Quantity: it.Quantity,
			BasePrice: basePrice, DiscountPct: disc, LineTotal: lineTotal,
		})
		result.Subtotal += it.Quantity * basePrice
		result.TotalDisc += it.Quantity*basePrice - lineTotal
	}

	result.NetAmount = result.Subtotal - result.TotalDisc

	// Add condition breakdown
	result.Conditions = append(result.Conditions, PricingCondition{
		Type: "BASE_PRICE", Label: "Base Price", Amount: result.Subtotal,
	})
	if result.TotalDisc > 0 {
		result.Conditions = append(result.Conditions, PricingCondition{
			Type: "QUANTITY_DISCOUNT", Label: "Volume Discount", Amount: -result.TotalDisc,
		})
	}
	result.Conditions = append(result.Conditions, PricingCondition{
		Type: "NET_AMOUNT", Label: "Net Amount", Amount: result.NetAmount,
	})

	return result, nil
}
