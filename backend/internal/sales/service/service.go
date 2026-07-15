package service

import (
	"context"
	"fmt"
	"strings"
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
	if err != nil {
		return nil, fmt.Errorf("generate number: %w", err)
	}

	q, items, err := s.buildQuotationFromRequest(req)
	if err != nil {
		return nil, err
	}

	q.ID = uuid.New()
	q.TenantID = tenantID
	q.CustomerID = customerID
	q.QuotationNo = qNo
	q.Status = "DRAFT"
	q.CreatedBy = userID
	q.CreatedAt = time.Now()
	q.UpdatedAt = time.Now()

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
		for _, it := range items {
			q.Items = append(q.Items, *it)
		}
	}
	return q, nil
}

func (s *SalesService) UpdateQuotation(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.CreateQuotationRequest) (*salesmodels.Quotation, error) {
	existing, err := s.repo.GetQuotation(ctx, id, tenantID)
	if err != nil {
		return nil, err
	}
	q, items, err := s.buildQuotationFromRequest(req)
	if err != nil {
		return nil, err
	}
	q.ID = existing.ID
	q.TenantID = tenantID
	q.QuotationNo = existing.QuotationNo
	q.Status = existing.Status
	q.CreatedBy = existing.CreatedBy
	q.CreatedAt = existing.CreatedAt
	q.UpdatedAt = time.Now()
	for _, item := range items {
		item.QuotationID = q.ID
	}
	if err := s.repo.UpdateQuotation(ctx, q, items); err != nil {
		return nil, err
	}
	if full, err := s.repo.GetQuotation(ctx, q.ID, tenantID); err == nil && full != nil {
		return full, nil
	}
	for _, it := range items {
		q.Items = append(q.Items, *it)
	}
	return q, nil
}

func (s *SalesService) buildQuotationFromRequest(req *salesmodels.CreateQuotationRequest) (*salesmodels.Quotation, []*salesmodels.QuotationItem, error) {
	customerID, err := uuid.Parse(req.CustomerID)
	if err != nil {
		return nil, nil, fmt.Errorf("invalid customer id")
	}
	validFrom := time.Now()
	if req.ValidFrom != "" {
		if d, err := time.Parse("2006-01-02", req.ValidFrom); err == nil {
			validFrom = d
		}
	}
	var validTo *time.Time
	if req.ValidTo != "" {
		if d, err := time.Parse("2006-01-02", req.ValidTo); err == nil {
			validTo = &d
		}
	}
	var deliveryDate *time.Time
	if req.DeliveryDate != "" {
		if d, err := time.Parse("2006-01-02", req.DeliveryDate); err == nil {
			deliveryDate = &d
		}
	}
	qType := req.QuotationType
	if qType == "" {
		qType = "STANDARD"
	}
	currency := req.Currency
	if currency == "" {
		currency = "USD"
	}
	paymentTerms := req.PaymentTerms
	if paymentTerms == "" {
		paymentTerms = "Net 30"
	}

	var totalAmount float64
	var items []*salesmodels.QuotationItem
	for i, it := range req.Items {
		prodID, err := uuid.Parse(it.ProductID)
		if err != nil {
			return nil, nil, fmt.Errorf("invalid product id on line %d", i+1)
		}
		uom := it.UOM
		if uom == "" {
			uom = "EA"
		}
		lineTotal := it.Quantity * it.UnitPrice * (1 - it.DiscountPct/100)
		totalAmount += lineTotal

		var itemDelDate *time.Time
		if it.DeliveryDate != "" {
			if d, err := time.Parse("2006-01-02", it.DeliveryDate); err == nil {
				itemDelDate = &d
			}
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
	var empID *uuid.UUID
	if req.EmployeeID != "" {
		if e, err := uuid.Parse(req.EmployeeID); err == nil {
			empID = &e
		}
	}

	q := &salesmodels.Quotation{
		CustomerID: customerID, QuotationType: qType,
		ValidFrom: validFrom, ValidTo: validTo,
		Currency: currency, PaymentTerms: paymentTerms, Incoterm: req.Incoterm,
		DeliveryDate: deliveryDate,
		TotalAmount:  totalAmount, DiscountPct: req.DiscountPct, DiscountAmount: discountAmt,
		NetAmount: netAmount, TaxAmount: req.TaxAmount,
		TaxCalcSource: req.TaxCalcSource, TaxCalcDetail: req.TaxCalcDetail, TaxCalcRate: req.TaxCalcRate,
		GrandTotal: grandTotal,
		Notes:      req.Notes, InternalNotes: req.InternalNotes,
		ReferenceInquiry: req.ReferenceInquiry,
		EmployeeID:       empID,
	}
	return q, items, nil
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
	if req.DeliveryDate == "" {
		return nil, fmt.Errorf("delivery date is required")
	}
	soNo, err := s.repo.GetNextSONo(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("generate so number: %w", err)
	}

	// Parse the quotation if provided
	var quotationID *uuid.UUID
	if req.QuotationID != "" {
		if qid, err := uuid.Parse(req.QuotationID); err == nil {
			quotationID = &qid
		}
	}
	if quotationID != nil {
		q, err := s.repo.GetQuotation(ctx, *quotationID, tenantID)
		if err != nil {
			return nil, fmt.Errorf("load quotation: %w", err)
		}
		if q.Status != "ACCEPTED" {
			return nil, fmt.Errorf("quotation %s must be ACCEPTED before creating sales order", q.QuotationNo)
		}
		exists, soNumber, err := s.repo.SalesOrderExistsForQuotation(ctx, tenantID, *quotationID)
		if err != nil {
			return nil, fmt.Errorf("check quotation conversion: %w", err)
		}
		if exists {
			return nil, fmt.Errorf("quotation %s already created sales order %s", q.QuotationNo, soNumber)
		}
	}

	validFrom := time.Now()
	if req.ValidFrom != "" {
		if d, err := time.Parse("2006-01-02", req.ValidFrom); err == nil {
			validFrom = d
		}
	}
	var deliveryDate, requestedDate, poDate *time.Time
	if req.DeliveryDate != "" {
		if d, err := time.Parse("2006-01-02", req.DeliveryDate); err == nil {
			deliveryDate = &d
		}
	}
	if req.RequestedDate != "" {
		if d, err := time.Parse("2006-01-02", req.RequestedDate); err == nil {
			requestedDate = &d
		}
	}
	if req.PODate != "" {
		if d, err := time.Parse("2006-01-02", req.PODate); err == nil {
			poDate = &d
		}
	}

	currency := req.Currency
	if currency == "" {
		currency = "USD"
	}
	paymentTerms := req.PaymentTerms
	if paymentTerms == "" {
		return nil, fmt.Errorf("payment terms is required")
	}
	if req.Incoterm == "" {
		return nil, fmt.Errorf("incoterm is required")
	}

	soType := req.OrderType
	if soType == "" {
		soType = "OR"
	}

	// ── Load order type config (for config-driven behavior) ──
	var otc *salesmodels.OrderTypeConfig
	if cfg, err := s.repo.GetOrderTypeConfigByType(ctx, tenantID, soType); err == nil {
		otc = cfg
	}

	// Apply reference_required check
	if otc != nil && otc.ReferenceRequired && quotationID == nil {
		return nil, fmt.Errorf("order type %s requires a reference document (quotation)", soType)
	}

	// Build items and calculate totals
	var totalAmount float64
	var items []*salesmodels.SalesOrderItem
	for i, it := range req.Items {
		prodID, _ := uuid.Parse(it.ProductID)
		var deliveringSiteID *uuid.UUID
		if it.DeliveringSiteID != "" {
			if sid, err := uuid.Parse(it.DeliveringSiteID); err == nil {
				deliveringSiteID = &sid
			}
		}
		uom := it.UOM
		if uom == "" {
			uom = "EA"
		}
		unitPrice := it.UnitPrice
		// Apply zero_price pricing procedure
		if otc != nil && otc.PricingProcedure == "zero_price" {
			unitPrice = 0
		}
		lineTotal := it.Quantity * unitPrice * (1 - it.DiscountPct/100)
		totalAmount += lineTotal
		var itemDelDate *time.Time
		if it.DeliveryDate != "" {
			if d, err := time.Parse("2006-01-02", it.DeliveryDate); err == nil {
				itemDelDate = &d
			}
		} else {
			itemDelDate = deliveryDate
		}
		items = append(items, &salesmodels.SalesOrderItem{
			ID: uuid.New(), SOID: uuid.Nil, LineNo: i + 10,
			ProductID: prodID, DeliveringSiteID: deliveringSiteID, Description: it.Description,
			Quantity: it.Quantity, UnitOfMeasure: uom, UnitPrice: unitPrice,
			DiscountPct: it.DiscountPct, LineTotal: lineTotal,
			DeliveryDate: itemDelDate, CreatedAt: time.Now(),
		})
	}

	discountAmt := totalAmount * req.DiscountPct / 100
	netAmount := totalAmount - discountAmt
	effectiveTaxAmount := req.TaxAmount
	preTaxStatus := "PENDING"
	if effectiveTaxAmount == 0 {
		if calculatedTax, status, err := s.repo.CalculateTax(ctx, tenantID, customerID, netAmount); err == nil {
			preTaxStatus = status
			if status == "CALCULATED" || status == "EXEMPT" {
				effectiveTaxAmount = calculatedTax
			}
		}
	}
	grandTotal := netAmount + effectiveTaxAmount
	receivedAmount := 0.0
	if req.ReceivedAmount != nil {
		receivedAmount = *req.ReceivedAmount
	}
	willAutoCreateDelivery := otc != nil && otc.AutoCreateDelivery && otc.AutoConfirmSO
	if isReceiptSalesOrderType(soType, otc) && willAutoCreateDelivery && receivedAmount+0.005 < grandTotal {
		return nil, fmt.Errorf("received amount %.2f is less than sales total plus tax %.2f; automatic delivery note cannot be created", receivedAmount, grandTotal)
	}

	so := &salesmodels.SalesOrder{
		ID: uuid.New(), TenantID: tenantID, CustomerID: customerID, QuotationID: quotationID,
		SONumber: soNo, SOType: soType, Status: "DRAFT",
		CustomerPONo: req.CustomerPONo, PODate: poDate,
		Currency: currency, PaymentTerms: paymentTerms, Incoterm: req.Incoterm,
		ValidFrom: validFrom, DeliveryDate: deliveryDate, RequestedDate: requestedDate,
		TotalAmount: totalAmount, DiscountPct: req.DiscountPct, DiscountAmount: discountAmt,
		NetAmount: netAmount, TaxAmount: effectiveTaxAmount, GrandTotal: grandTotal,
		ReceiptMethod: normalizeReceiptMethod(req.ReceiptMethod), ReceivedAmount: receivedAmount,
		Notes: req.Notes, InternalNotes: req.InternalNotes,
		Carrier: req.Carrier, ShippingMethod: req.ShippingMethod, ShipperAccount: req.ShipperAccount,
		SignatureRequired: req.SignatureRequired, SaturdayDelivery: req.SaturdayDelivery, InsuranceAmt: req.InsuranceAmt,
		AllowEarlyShip:   req.AllowEarlyShip,
		TransportationTo: req.TransportationTo, TransportPayerAccount: req.TransportPayerAcct, BillToAddress: req.BillToAddress,
		CreditCheckStatus: "PENDING", InventoryCheckStatus: "PENDING", TaxCalcStatus: "PENDING", AllocationStatus: "PENDING",
		DeliveryBlockID: parseUUIDPtr(req.DeliveryBlockID),
		BillingBlocked:  false,
		CreatedBy:       userID, CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}

	for _, item := range items {
		item.SOID = so.ID
		so.Items = append(so.Items, *item)
	}

	if err := s.repo.CreateSalesOrder(ctx, so, items); err != nil {
		return nil, err
	}

	// ── Config-Driven Automated Checks ──

	var creditStatus string
	var taxAmount float64
	taxStatus := preTaxStatus

	// 1. ATP / Inventory Check — controlled by atp_check_logic
	if otc != nil && otc.AtpCheckLogic == "none" {
		_ = s.repo.UpdateInventoryStatuses(ctx, so.ID, tenantID, "SKIPPED", "SKIPPED")
	}

	// 2. Credit Check — controlled by credit_check_required
	if otc != nil && !otc.CreditCheckRequired {
		creditStatus = "SKIPPED"
	} else {
		creditStatus, _ = s.repo.CheckCreditLimit(ctx, tenantID, customerID, grandTotal)
	}
	so.CreditCheckStatus = creditStatus

	// 3. Tax Calculation
	if req.TaxAmount == 0 && taxStatus == "PENDING" {
		taxAmount, taxStatus, _ = s.repo.CalculateTax(ctx, tenantID, customerID, netAmount)
	} else {
		taxAmount = effectiveTaxAmount
	}
	if (taxStatus == "CALCULATED" || taxStatus == "EXEMPT") && req.TaxAmount == 0 && so.TaxAmount != taxAmount {
		so.TaxAmount = taxAmount
		so.GrandTotal = netAmount + taxAmount
		_ = s.repo.UpdateTaxAmount(ctx, so.ID, tenantID, so.TaxAmount, so.GrandTotal)
	}
	so.TaxCalcStatus = taxStatus

	// 4. Inventory Allocation — skip if ATP is none
	// 5. Billing Block — controlled by billing_block_default
	if otc != nil && otc.BillingBlockDefault {
		so.BillingBlocked = true
	}

	// 6. Auto-create delivery (placeholder — future delivery module integration)
	// if otc != nil && otc.AutoCreateDelivery { ... }

	// ── Status: Driven by Order Type Config's auto_confirm_so ──
	if otc != nil && otc.AutoConfirmSO {
		so.Status = "CONFIRMED"
		_ = s.repo.UpdateSOStatus(ctx, so.ID, tenantID, "CONFIRMED")
	} else {
		so.Status = "DRAFT"
	}

	if otc != nil && otc.AutoCreateDelivery && so.Status == "CONFIRMED" {
		warehouseID, err := s.repo.DefaultDeliveryWarehouseForSO(ctx, tenantID, so.ID)
		if err != nil {
			return nil, fmt.Errorf("resolve delivery warehouse: %w", err)
		}
		dn, err := s.repo.CreateDeliveryNote(ctx, tenantID, &salesmodels.CreateDeliveryNoteRequest{
			WarehouseID:   warehouseID.String(),
			SelectionDate: deliveryDateString(so.DeliveryDate),
			ReferenceNo:   so.SONumber,
			Items:         deliveryItemsFromSO(so),
		})
		if err != nil {
			return nil, fmt.Errorf("auto create delivery note: %w", err)
		}
		if otc.AutoPgiPgr {
			pickingReq := &salesmodels.UpdateDeliveryPickingRequest{Items: make([]salesmodels.UpdateDeliveryPickingItem, 0, len(dn.Items))}
			for _, item := range dn.Items {
				pickingReq.Items = append(pickingReq.Items, salesmodels.UpdateDeliveryPickingItem{
					ID:        item.ID.String(),
					PickedQty: item.DeliveryQty,
					StockLoc:  item.StockLoc,
				})
			}
			if _, err := s.repo.UpdateDeliveryPicking(ctx, dn.ID, tenantID, pickingReq); err != nil {
				return nil, fmt.Errorf("auto pick delivery note: %w", err)
			}
			if _, err := s.repo.PostDeliveryPGI(ctx, dn.ID, tenantID, userIDOrNil(userID)); err != nil {
				return nil, fmt.Errorf("auto post PGI: %w", err)
			}
			if isReceiptSalesOrderType(soType, otc) {
				if _, err := s.repo.CreateSalesInvoice(ctx, tenantID, userIDOrNil(userID), &salesmodels.CreateSalesInvoiceRequest{
					DeliveryID:      dn.ID.String(),
					InvoiceDate:     time.Now().Format("2006-01-02"),
					PostImmediately: true,
				}); err != nil {
					return nil, fmt.Errorf("auto create and post invoice: %w", err)
				}
			}
		}
		if isReceiptSalesOrderType(soType, otc) {
			if _, err := s.repo.PostSalesOrderReceiptJournal(ctx, tenantID, userIDOrNil(userID), so.ID, warehouseID); err != nil {
				return nil, fmt.Errorf("post sales order receipt journal: %w", err)
			}
		}
	}

	if full, err := s.repo.GetSalesOrder(ctx, so.ID, tenantID); err == nil && full != nil {
		so = full
	}

	return so, nil
}

func isReceiptSalesOrderType(orderType string, otc *salesmodels.OrderTypeConfig) bool {
	code := strings.ToUpper(strings.TrimSpace(orderType))
	description := ""
	if otc != nil {
		description = strings.ToUpper(strings.TrimSpace(otc.Description))
	}
	return code == "EC" ||
		code == "CS" ||
		code == "CASH" ||
		strings.Contains(code, "ECOM") ||
		strings.Contains(code, "E-COM") ||
		strings.Contains(code, "ECOMMERCE") ||
		strings.Contains(description, "E-COMMERCE") ||
		strings.Contains(description, "ECOMMERCE") ||
		strings.Contains(description, "CASH SALE")
}

func normalizeReceiptMethod(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "CREDIT_CARD", "CREDIT CARD", "CARD":
		return "CREDIT_CARD"
	case "CHECK", "CHEQUE":
		return "CHECK"
	case "CASH":
		return "CASH"
	default:
		return ""
	}
}

func userIDOrNil(userID *uuid.UUID) uuid.UUID {
	if userID == nil {
		return uuid.Nil
	}
	return *userID
}

func deliveryDateString(value *time.Time) string {
	if value == nil {
		return time.Now().Format("2006-01-02")
	}
	return value.Format("2006-01-02")
}

func deliveryItemsFromSO(so *salesmodels.SalesOrder) []salesmodels.CreateDeliveryNoteItem {
	items := make([]salesmodels.CreateDeliveryNoteItem, 0, len(so.Items))
	for _, item := range so.Items {
		items = append(items, salesmodels.CreateDeliveryNoteItem{
			SOItemID:    item.ID.String(),
			DeliveryQty: item.Quantity,
		})
	}
	return items
}

func (s *SalesService) UpdateSOStatus(ctx context.Context, id, tenantID uuid.UUID, status string) error {
	return s.repo.UpdateSOStatus(ctx, id, tenantID, status)
}

func (s *SalesService) UpdateSalesOrder(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateSalesOrderRequest) (*salesmodels.SalesOrder, error) {
	// Fetch existing order to merge updates
	existing, err := s.repo.GetSalesOrder(ctx, id, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get existing so: %w", err)
	}

	// Merge fields
	if req.CustomerID != "" {
		existing.CustomerID, _ = uuid.Parse(req.CustomerID)
	}
	if req.OrderType != "" {
		existing.SOType = req.OrderType
	}
	if req.CustomerPONo != "" {
		existing.CustomerPONo = req.CustomerPONo
	}
	if req.PODate != "" {
		if d, err := time.Parse("2006-01-02", req.PODate); err == nil {
			existing.PODate = &d
		}
	}
	if req.Currency != "" {
		existing.Currency = req.Currency
	}
	if req.PaymentTerms != "" {
		existing.PaymentTerms = req.PaymentTerms
	}
	if req.Incoterm != "" {
		existing.Incoterm = req.Incoterm
	}
	if existing.PaymentTerms == "" {
		return nil, fmt.Errorf("payment terms is required")
	}
	if existing.Incoterm == "" {
		return nil, fmt.Errorf("incoterm is required")
	}
	if req.ValidFrom != "" {
		if d, err := time.Parse("2006-01-02", req.ValidFrom); err == nil {
			existing.ValidFrom = d
		}
	}
	if req.DeliveryDate != "" {
		if d, err := time.Parse("2006-01-02", req.DeliveryDate); err == nil {
			existing.DeliveryDate = &d
		}
	}
	if existing.DeliveryDate == nil {
		return nil, fmt.Errorf("delivery date is required")
	}
	if req.RequestedDate != "" {
		if d, err := time.Parse("2006-01-02", req.RequestedDate); err == nil {
			existing.RequestedDate = &d
		}
	}
	if req.Notes != "" {
		existing.Notes = req.Notes
	}
	if req.InternalNotes != "" {
		existing.InternalNotes = req.InternalNotes
	}
	if req.Carrier != "" {
		existing.Carrier = req.Carrier
	}
	if req.ShippingMethod != "" {
		existing.ShippingMethod = req.ShippingMethod
	}
	if req.ShipperAccount != "" {
		existing.ShipperAccount = req.ShipperAccount
	}
	if req.TransportationTo != "" {
		existing.TransportationTo = req.TransportationTo
	}
	if req.TransportPayerAcct != "" {
		existing.TransportPayerAccount = req.TransportPayerAcct
	}
	if req.BillToAddress != "" {
		existing.BillToAddress = req.BillToAddress
	}
	if req.ReceiptMethod != "" {
		existing.ReceiptMethod = req.ReceiptMethod
	}
	if req.ReceivedAmount != nil {
		existing.ReceivedAmount = *req.ReceivedAmount
	}
	if req.DiscountPct != nil {
		existing.DiscountPct = *req.DiscountPct
	}
	if req.TaxAmount != nil {
		existing.TaxAmount = *req.TaxAmount
	}
	if req.SignatureRequired != nil {
		existing.SignatureRequired = *req.SignatureRequired
	}
	if req.SaturdayDelivery != nil {
		existing.SaturdayDelivery = *req.SaturdayDelivery
	}
	if req.InsuranceAmt != nil {
		existing.InsuranceAmt = *req.InsuranceAmt
	}
	if req.AllowEarlyShip != nil {
		existing.AllowEarlyShip = *req.AllowEarlyShip
	}
	if req.DeliveryBlockID != nil {
		existing.DeliveryBlockID = parseUUIDPtr(*req.DeliveryBlockID)
	}

	// ── Load order type config for config-driven behavior ──
	soType := existing.SOType
	var otc *salesmodels.OrderTypeConfig
	if cfg, err := s.repo.GetOrderTypeConfigByType(ctx, tenantID, soType); err == nil {
		otc = cfg
	}

	// Apply billing_blocked from config if not explicitly set
	if otc != nil && otc.BillingBlockDefault {
		existing.BillingBlocked = true
	}

	// Build items if provided
	var items []*salesmodels.SalesOrderItem
	if len(req.Items) > 0 {
		var totalAmount float64
		for i, it := range req.Items {
			prodID, _ := uuid.Parse(it.ProductID)
			var deliveringSiteID *uuid.UUID
			if it.DeliveringSiteID != "" {
				if sid, err := uuid.Parse(it.DeliveringSiteID); err == nil {
					deliveringSiteID = &sid
				}
			}
			uom := it.UOM
			if uom == "" {
				uom = "EA"
			}
			unitPrice := it.UnitPrice
			if otc != nil && otc.PricingProcedure == "zero_price" {
				unitPrice = 0
			}
			lineTotal := it.Quantity * unitPrice * (1 - it.DiscountPct/100)
			totalAmount += lineTotal
			var itemDelDate *time.Time
			if it.DeliveryDate != "" {
				if d, err := time.Parse("2006-01-02", it.DeliveryDate); err == nil {
					itemDelDate = &d
				}
			} else {
				itemDelDate = existing.DeliveryDate
			}
			items = append(items, &salesmodels.SalesOrderItem{
				ID: uuid.New(), SOID: existing.ID, LineNo: i + 10,
				ProductID: prodID, DeliveringSiteID: deliveringSiteID, Description: it.Description,
				Quantity: it.Quantity, UnitOfMeasure: uom, UnitPrice: unitPrice,
				DiscountPct: it.DiscountPct, LineTotal: lineTotal,
				DeliveryDate: itemDelDate, CreatedAt: time.Now(),
			})
		}

		discountAmt := totalAmount * existing.DiscountPct / 100
		netAmount := totalAmount - discountAmt
		grandTotal := netAmount + existing.TaxAmount

		existing.TotalAmount = totalAmount
		existing.DiscountAmount = discountAmt
		existing.NetAmount = netAmount
		existing.GrandTotal = grandTotal
	} else {
		// Recalculate with existing items (keep them)
		items = make([]*salesmodels.SalesOrderItem, len(existing.Items))
		for i := range existing.Items {
			items[i] = &existing.Items[i]
		}
		// Recalculate totals from existing items
		var totalAmount float64
		for _, it := range items {
			totalAmount += it.LineTotal
		}
		discountAmt := totalAmount * existing.DiscountPct / 100
		netAmount := totalAmount - discountAmt
		grandTotal := netAmount + existing.TaxAmount
		existing.TotalAmount = totalAmount
		existing.DiscountAmount = discountAmt
		existing.NetAmount = netAmount
		existing.GrandTotal = grandTotal
	}

	if err := s.repo.UpdateSalesOrder(ctx, existing, items); err != nil {
		return nil, fmt.Errorf("update so: %w", err)
	}

	// Re-fetch full SO with items
	if full, err := s.repo.GetSalesOrder(ctx, existing.ID, tenantID); err == nil && full != nil {
		existing = full
	}
	return existing, nil
}

func (s *SalesService) DeleteSalesOrder(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteSalesOrder(ctx, id, tenantID)
}

func (s *SalesService) CreateDeliveryNote(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateDeliveryNoteRequest) (*salesmodels.DeliveryNote, error) {
	return s.repo.CreateDeliveryNote(ctx, tenantID, req)
}

func (s *SalesService) ListDeliveryNotes(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.DeliveryNote, error) {
	return s.repo.ListDeliveryNotes(ctx, tenantID, status)
}

func (s *SalesService) GetDeliveryNote(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.DeliveryNote, error) {
	return s.repo.GetDeliveryNote(ctx, id, tenantID)
}

func (s *SalesService) DeleteDeliveryNote(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteDeliveryNote(ctx, id, tenantID)
}

func (s *SalesService) UpdateDeliveryPicking(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateDeliveryPickingRequest) (*salesmodels.DeliveryNote, error) {
	return s.repo.UpdateDeliveryPicking(ctx, id, tenantID, req)
}

func (s *SalesService) PostDeliveryPGI(ctx context.Context, id, tenantID, userID uuid.UUID) (*salesmodels.DeliveryNote, error) {
	return s.repo.PostDeliveryPGI(ctx, id, tenantID, userID)
}

func (s *SalesService) ListPendingInvoiceDeliveries(ctx context.Context, tenantID uuid.UUID) ([]*salesmodels.DeliveryNote, error) {
	return s.repo.ListPendingInvoiceDeliveries(ctx, tenantID)
}

func (s *SalesService) CreateSalesInvoice(ctx context.Context, tenantID, userID uuid.UUID, req *salesmodels.CreateSalesInvoiceRequest) (*salesmodels.SalesInvoice, error) {
	return s.repo.CreateSalesInvoice(ctx, tenantID, userID, req)
}

func (s *SalesService) ListSalesInvoices(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.SalesInvoice, error) {
	return s.repo.ListSalesInvoices(ctx, tenantID, status)
}

func (s *SalesService) GetSalesInvoice(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.SalesInvoice, error) {
	return s.repo.GetSalesInvoice(ctx, id, tenantID)
}

func (s *SalesService) PostSalesInvoice(ctx context.Context, id, tenantID, userID uuid.UUID) (*salesmodels.SalesInvoice, error) {
	return s.repo.PostSalesInvoice(ctx, id, tenantID, userID)
}

// ── ATP Check ──

type ATPResult struct {
	ProductID     uuid.UUID                            `json:"product_id"`
	Quantity      float64                              `json:"quantity"`
	OnHand        float64                              `json:"on_hand"`
	Available     float64                              `json:"available"`
	ConfirmedQty  float64                              `json:"confirmed_qty"`
	Status        string                               `json:"status"` // RELEASED / PARTIALLY_ALLOCATED / ATP_HOLD
	SuggestedDate string                               `json:"suggested_date,omitempty"`
	ScheduleLines []salesmodels.ATPPreviewScheduleLine `json:"schedule_lines,omitempty"`
}

// ── Delivery Block Reasons ──

func (s *SalesService) ListDeliveryBlockReasons(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*salesmodels.DeliveryBlockReason, error) {
	return s.repo.ListDeliveryBlockReasons(ctx, tenantID, activeOnly)
}

func (s *SalesService) GetDeliveryBlockReason(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.DeliveryBlockReason, error) {
	return s.repo.GetDeliveryBlockReason(ctx, id, tenantID)
}

func (s *SalesService) CreateDeliveryBlockReason(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateDeliveryBlockReasonRequest) (*salesmodels.DeliveryBlockReason, error) {
	now := time.Now()
	d := &salesmodels.DeliveryBlockReason{
		ID: uuid.New(), TenantID: tenantID,
		BlockCode:   req.BlockCode,
		Description: req.Description,
		IsActive:    true,
		SortOrder:   req.SortOrder,
		CreatedAt:   now, UpdatedAt: now,
	}
	if err := s.repo.CreateDeliveryBlockReason(ctx, d); err != nil {
		return nil, err
	}
	return d, nil
}

func (s *SalesService) UpdateDeliveryBlockReason(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateDeliveryBlockReasonRequest) (*salesmodels.DeliveryBlockReason, error) {
	existing, err := s.repo.GetDeliveryBlockReason(ctx, id, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get dbr: %w", err)
	}
	if req.Description != nil {
		existing.Description = *req.Description
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}
	if req.SortOrder != nil {
		existing.SortOrder = *req.SortOrder
	}
	if err := s.repo.UpdateDeliveryBlockReason(ctx, id, tenantID, existing); err != nil {
		return nil, err
	}
	return existing, nil
}

func (s *SalesService) DeleteDeliveryBlockReason(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteDeliveryBlockReason(ctx, id, tenantID)
}

func (s *SalesService) ListCarrierServiceTypes(ctx context.Context, tenantID uuid.UUID, carrier string) ([]*salesmodels.CarrierServiceType, error) {
	return s.repo.ListCarrierServiceTypes(ctx, tenantID, carrier)
}

func (s *SalesService) GetCarrierServiceType(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.CarrierServiceType, error) {
	return s.repo.GetCarrierServiceType(ctx, id, tenantID)
}

func (s *SalesService) CreateCarrierServiceType(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateCarrierServiceTypeRequest) (*salesmodels.CarrierServiceType, error) {
	now := time.Now()
	d := &salesmodels.CarrierServiceType{
		ID:          uuid.New(),
		TenantID:    tenantID,
		Carrier:     req.Carrier,
		ServiceType: req.ServiceType,
		IsActive:    true,
		IsSystem:    false,
		SortOrder:   req.SortOrder,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if err := s.repo.CreateCarrierServiceType(ctx, d); err != nil {
		return nil, err
	}
	return d, nil
}

func (s *SalesService) UpdateCarrierServiceType(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateCarrierServiceTypeRequest) (*salesmodels.CarrierServiceType, error) {
	existing, err := s.repo.GetCarrierServiceType(ctx, id, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get carrier service type: %w", err)
	}
	if req.Carrier != nil {
		existing.Carrier = *req.Carrier
	}
	if req.ServiceType != nil {
		existing.ServiceType = *req.ServiceType
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}
	if req.SortOrder != nil {
		existing.SortOrder = *req.SortOrder
	}
	if err := s.repo.UpdateCarrierServiceType(ctx, id, tenantID, existing); err != nil {
		return nil, err
	}
	return existing, nil
}

func (s *SalesService) DeleteCarrierServiceType(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteCarrierServiceType(ctx, id, tenantID)
}

func parseUUIDPtr(s string) *uuid.UUID {
	if s == "" {
		return nil
	}
	if id, err := uuid.Parse(s); err == nil {
		return &id
	}
	return nil
}

// ── Order Type Configs ──

func (s *SalesService) ListOrderTypeConfigs(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*salesmodels.OrderTypeConfig, error) {
	return s.repo.ListOrderTypeConfigs(ctx, tenantID, activeOnly)
}

func (s *SalesService) GetOrderTypeConfig(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.OrderTypeConfig, error) {
	return s.repo.GetOrderTypeConfig(ctx, id, tenantID)
}

func (s *SalesService) GetOrderTypeConfigByType(ctx context.Context, tenantID uuid.UUID, orderType string) (*salesmodels.OrderTypeConfig, error) {
	return s.repo.GetOrderTypeConfigByType(ctx, tenantID, orderType)
}

func (s *SalesService) CreateOrderTypeConfig(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateOrderTypeConfigRequest, userID *uuid.UUID) (*salesmodels.OrderTypeConfig, error) {
	oType := req.OrderType
	desc := req.Description
	if desc == "" {
		desc = oType
	}
	if req.ShippingDirection == "" {
		req.ShippingDirection = "outbound"
	}
	if req.TargetStockType == "" {
		req.TargetStockType = "unrestricted"
	}
	if req.AtpCheckLogic == "" {
		req.AtpCheckLogic = "hard"
	}
	if req.PricingProcedure == "" {
		req.PricingProcedure = "standard"
	}
	if req.BillingTrigger == "" {
		req.BillingTrigger = "post_delivery"
	}
	if req.BillingType == "" {
		req.BillingType = "invoice"
	}
	if req.GlAccountStrategy == "" {
		req.GlAccountStrategy = "standard_sales"
	}

	// Find max sort_order
	configs, err := s.repo.ListOrderTypeConfigs(ctx, tenantID, false)
	if err != nil {
		return nil, err
	}
	maxOrder := 0
	for _, c := range configs {
		if c.SortOrder > maxOrder {
			maxOrder = c.SortOrder
		}
	}

	now := time.Now()
	otc := &salesmodels.OrderTypeConfig{
		ID: uuid.New(), TenantID: tenantID,
		OrderType: oType, Description: desc,
		IsActive: true, IsSystem: false, SortOrder: maxOrder + 10,
		RequiresShipping:    req.RequiresShipping,
		ShippingDirection:   req.ShippingDirection,
		AutoCreateDelivery:  req.AutoCreateDelivery,
		AutoPgiPgr:          req.AutoPgiPgr,
		TargetStockType:     req.TargetStockType,
		AutoConfirmSO:       req.AutoConfirmSO,
		PackingSlip:         req.PackingSlip,
		CreditCheckRequired: req.CreditCheckRequired,
		AtpCheckLogic:       req.AtpCheckLogic,
		ReferenceRequired:   req.ReferenceRequired,
		PricingProcedure:    req.PricingProcedure,
		BillingTrigger:      req.BillingTrigger,
		BillingType:         req.BillingType,
		GlAccountStrategy:   req.GlAccountStrategy,
		BillingBlockDefault: req.BillingBlockDefault,
		CreatedBy:           userID, CreatedAt: now, UpdatedAt: now,
	}
	if err := s.repo.CreateOrderTypeConfig(ctx, otc); err != nil {
		return nil, err
	}
	return otc, nil
}

func (s *SalesService) UpdateOrderTypeConfig(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateOrderTypeConfigRequest) (*salesmodels.OrderTypeConfig, error) {
	existing, err := s.repo.GetOrderTypeConfig(ctx, id, tenantID)
	if err != nil {
		return nil, fmt.Errorf("get otc: %w", err)
	}

	if req.Description != nil {
		existing.Description = *req.Description
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}
	if req.SortOrder != nil {
		existing.SortOrder = *req.SortOrder
	}
	if req.RequiresShipping != nil {
		existing.RequiresShipping = *req.RequiresShipping
	}
	if req.ShippingDirection != nil {
		existing.ShippingDirection = *req.ShippingDirection
	}
	if req.AutoCreateDelivery != nil {
		existing.AutoCreateDelivery = *req.AutoCreateDelivery
	}
	if req.AutoPgiPgr != nil {
		existing.AutoPgiPgr = *req.AutoPgiPgr
	}
	if req.TargetStockType != nil {
		existing.TargetStockType = *req.TargetStockType
	}
	if req.CreditCheckRequired != nil {
		existing.CreditCheckRequired = *req.CreditCheckRequired
	}
	if req.AtpCheckLogic != nil {
		existing.AtpCheckLogic = *req.AtpCheckLogic
	}
	if req.ReferenceRequired != nil {
		existing.ReferenceRequired = *req.ReferenceRequired
	}
	if req.PricingProcedure != nil {
		existing.PricingProcedure = *req.PricingProcedure
	}
	if req.BillingTrigger != nil {
		existing.BillingTrigger = *req.BillingTrigger
	}
	if req.BillingType != nil {
		existing.BillingType = *req.BillingType
	}
	if req.GlAccountStrategy != nil {
		existing.GlAccountStrategy = *req.GlAccountStrategy
	}
	if req.BillingBlockDefault != nil {
		existing.BillingBlockDefault = *req.BillingBlockDefault
	}
	if req.AutoConfirmSO != nil {
		existing.AutoConfirmSO = *req.AutoConfirmSO
	}
	if req.PackingSlip != nil {
		existing.PackingSlip = *req.PackingSlip
	}
	existing.UpdatedAt = time.Now()

	if err := s.repo.UpdateOrderTypeConfig(ctx, id, tenantID, existing); err != nil {
		return nil, err
	}
	return existing, nil
}

func (s *SalesService) DeleteOrderTypeConfig(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteOrderTypeConfig(ctx, id, tenantID)
}

func (s *SalesService) CheckATP(ctx context.Context, tenantID uuid.UUID, productID uuid.UUID, quantity float64, deliveryDate *time.Time, siteID *uuid.UUID) (*ATPResult, error) {
	onHand, available, confirmed, status, schedules, err := s.repo.PreviewATP(ctx, tenantID, productID, quantity, deliveryDate, siteID)
	if err != nil {
		return nil, err
	}
	suggestedDate := ""
	if len(schedules) > 0 && confirmed >= quantity {
		suggestedDate = schedules[len(schedules)-1].ConfirmedDate
	}

	return &ATPResult{
		ProductID:     productID,
		Quantity:      quantity,
		OnHand:        onHand,
		Available:     available,
		ConfirmedQty:  confirmed,
		Status:        status,
		SuggestedDate: suggestedDate,
		ScheduleLines: schedules,
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
	Type   string  `json:"type"` // BASE_PRICE, QUANTITY_DISCOUNT, PROMOTION, SURCHARGE
	Label  string  `json:"label"`
	Amount float64 `json:"amount"`
}

type PricingResult struct {
	Items      []PricingLineItem  `json:"items"`
	Conditions []PricingCondition `json:"conditions"`
	Subtotal   float64            `json:"subtotal"`
	TotalDisc  float64            `json:"total_discount"`
	NetAmount  float64            `json:"net_amount"`
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
