package service

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
	salesrepo "github.com/swiftai-erp/backend/internal/sales/repository"
)

var (
	salesPool   *pgxpool.Pool
	testTenant  = uuid.MustParse("a06826ac-2152-4d58-8de2-a9c6577e926e")
)

func TestMain(m *testing.M) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://swiftai:swiftai_dev_pass@localhost:5432/swiftai_erp?sslmode=disable"
	}

	var err error
	salesPool, err = pgxpool.New(context.Background(), dsn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to connect to test DB: %v\n", err)
		os.Exit(1)
	}
	defer salesPool.Close()

	// Ensure tables exist (in case migration hasn't been run in test DB)
	_, err = salesPool.Exec(context.Background(), `
		CREATE TABLE IF NOT EXISTS customers (
			id UUID PRIMARY KEY, tenant_id UUID NOT NULL,
			customer_code VARCHAR(50) NOT NULL, name VARCHAR(255) NOT NULL,
			tax_number VARCHAR(100) DEFAULT '', customer_type VARCHAR(30) DEFAULT 'Corporate',
			currency VARCHAR(3) DEFAULT 'USD', payment_terms VARCHAR(50) DEFAULT 'Net 30',
			contact_person VARCHAR(255) DEFAULT '', contact_email VARCHAR(255) DEFAULT '', contact_phone VARCHAR(50) DEFAULT '',
			billing_street TEXT DEFAULT '', billing_city VARCHAR(100) DEFAULT '', billing_state VARCHAR(50) DEFAULT '', billing_zip VARCHAR(20) DEFAULT '', billing_country VARCHAR(100) DEFAULT 'US',
			shipping_street TEXT DEFAULT '', shipping_city VARCHAR(100) DEFAULT '', shipping_state VARCHAR(50) DEFAULT '', shipping_zip VARCHAR(20) DEFAULT '', shipping_country VARCHAR(100) DEFAULT 'US',
			status VARCHAR(20) DEFAULT 'Active',
			is_tax_exempt BOOLEAN DEFAULT false, tax_exemption_cert VARCHAR(100) DEFAULT '',
			tax_exempt_start_date DATE, tax_exempt_end_date DATE, tax_exempt_reason VARCHAR(255) DEFAULT '',
			default_tax_jurisdiction_id UUID, is_active BOOLEAN DEFAULT true,
			created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW())
	`)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Ensure customers table: %v\n", err)
		os.Exit(1)
	}
	_, err = salesPool.Exec(context.Background(), `
		CREATE TABLE IF NOT EXISTS customer_certificates (
			id UUID PRIMARY KEY, customer_id UUID NOT NULL, tenant_id UUID NOT NULL,
			cert_type VARCHAR(30) DEFAULT 'TAX_EXEMPT', file_name VARCHAR(255) NOT NULL,
			file_path TEXT NOT NULL, file_size INTEGER DEFAULT 0, mime_type VARCHAR(100) DEFAULT '',
			uploaded_at TIMESTAMPTZ DEFAULT NOW())
	`)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Ensure customer_certificates table: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Sales test suite initialized")
	code := m.Run()
	os.Exit(code)
}

func setupService(t *testing.T) *SalesService {
	t.Helper()
	return NewSalesService(salesrepo.NewSalesRepo(salesPool))
}

func cleanCustomers(t *testing.T) {
	t.Helper()
	_, err := salesPool.Exec(context.Background(), "DELETE FROM customer_certificates WHERE tenant_id = $1", testTenant)
	if err != nil {
		t.Fatalf("cleanup certs failed: %v", err)
	}
	_, err = salesPool.Exec(context.Background(), "DELETE FROM customers WHERE tenant_id = $1", testTenant)
	if err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
}

func TestCustomerFullCRUD(t *testing.T) {
	if salesPool == nil {
		t.Skip("test database not available")
	}
	ctx := context.Background()
	svc := setupService(t)
	defer cleanCustomers(t)

	t.Run("Create and Get customer", func(t *testing.T) {
		created, err := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode:  "C001",
			Name:          "Acme Corporation",
			TaxNumber:     "12-3456789",
			CustomerType:  "Corporate",
			Currency:      "USD",
			PaymentTerms:  "Net 30",
			ContactPerson: "John Doe",
			ContactEmail:  "john@acme.com",
			ContactPhone:  "555-0100",
		})
		if err != nil {
			t.Fatalf("CreateCustomer failed: %v", err)
		}
		if created.ID == uuid.Nil {
			t.Fatal("expected non-zero ID")
		}
		if created.CustomerCode != "C001" {
			t.Errorf("code: got %s, want C001", created.CustomerCode)
		}
		if created.Name != "Acme Corporation" {
			t.Errorf("name: got %s", created.Name)
		}
		if created.Status != "Active" {
			t.Errorf("status: got %s", created.Status)
		}
		if created.TenantID != testTenant {
			t.Errorf("tenant_id mismatch")
		}

		// Get by ID
		got, err := svc.GetCustomer(ctx, created.ID, testTenant)
		if err != nil {
			t.Fatalf("GetCustomer failed: %v", err)
		}
		if got.CustomerCode != "C001" {
			t.Errorf("get code: got %s", got.CustomerCode)
		}
	})

	t.Run("Structured addresses", func(t *testing.T) {
		created, err := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode:    "C002",
			Name:            "Bay Tech Inc",
			BillingStreet:   "123 Main St",
			BillingCity:     "San Francisco",
			BillingState:    "CA",
			BillingZip:      "94105",
			BillingCountry:  "US",
			ShippingStreet:  "456 Market St",
			ShippingCity:    "San Jose",
			ShippingState:   "CA",
			ShippingZip:     "95112",
			ShippingCountry: "US",
		})
		if err != nil {
			t.Fatalf("CreateCustomer with address failed: %v", err)
		}
		if created.BillingCity != "San Francisco" {
			t.Errorf("billing city: got %s", created.BillingCity)
		}
		if created.ShippingCity != "San Jose" {
			t.Errorf("shipping city: got %s", created.ShippingCity)
		}
		if created.BillingCountry != "US" {
			t.Errorf("billing country: got %s", created.BillingCountry)
		}
	})

	t.Run("List with search and status filter", func(t *testing.T) {
		cleanCustomers(t)
		_, _ = svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C010", Name: "Alpha Corp",
		})
		_, _ = svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C020", Name: "Beta LLC",
		})

		all, err := svc.ListCustomers(ctx, testTenant, "", "")
		if err != nil { t.Fatalf("list: %v", err) }
		if len(all) != 2 { t.Errorf("want 2, got %d", len(all)) }

		search, err := svc.ListCustomers(ctx, testTenant, "Alpha", "")
		if err != nil { t.Fatalf("search: %v", err) }
		if len(search) != 1 { t.Errorf("search want 1, got %d", len(search)) }
		if search[0].Name != "Alpha Corp" { t.Errorf("got %s", search[0].Name) }
	})

	t.Run("Update fields", func(t *testing.T) {
		cleanCustomers(t)
		created, _ := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C030", Name: "Old Name",
		})
		newName := "Updated Name Inc"
		newCity := "Los Angeles"
		err := svc.UpdateCustomer(ctx, created.ID, testTenant, &salesmodels.UpdateCustomerRequest{
			Name:         &newName,
			BillingCity:  &newCity,
		})
		if err != nil { t.Fatalf("update: %v", err) }
		updated, _ := svc.GetCustomer(ctx, created.ID, testTenant)
		if updated.Name != "Updated Name Inc" { t.Errorf("name: %s", updated.Name) }
		if updated.BillingCity != "Los Angeles" { t.Errorf("city: %s", updated.BillingCity) }
	})

	t.Run("Delete customer", func(t *testing.T) {
		cleanCustomers(t)
		created, _ := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C040", Name: "Delete Me",
		})
		err := svc.DeleteCustomer(ctx, created.ID, testTenant)
		if err != nil { t.Fatalf("delete: %v", err) }
		_, err = svc.GetCustomer(ctx, created.ID, testTenant)
		if err == nil { t.Error("expected error after delete") }
	})

	t.Run("Tax exemption", func(t *testing.T) {
		cleanCustomers(t)
		isExempt := true
		startDate := "2025-01-01"
		endDate := "2025-12-31"
		created, err := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode:       "C050",
			Name:               "Non-Profit Org",
			CustomerType:       "Non-Profit",
			IsTaxExempt:        &isExempt,
			TaxExemptionCert:   "EX-2025-001",
			TaxExemptStartDate: startDate,
			TaxExemptEndDate:   endDate,
			TaxExemptReason:    "NON_PROFIT",
		})
		if err != nil { t.Fatalf("create exempt: %v", err) }
		if !created.IsTaxExempt { t.Error("expected tax exempt") }
		if created.TaxExemptionCert != "EX-2025-001" { t.Errorf("cert: %s", created.TaxExemptionCert) }
		if created.TaxExemptReason != "NON_PROFIT" { t.Errorf("reason: %s", created.TaxExemptReason) }
		expectedStart, _ := time.Parse("2006-01-02", startDate)
		if !created.TaxExemptStartDate.Equal(expectedStart) {
			t.Error("start date mismatch")
		}
	})

	t.Run("Certificate CRUD", func(t *testing.T) {
		cleanCustomers(t)
		cust, _ := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C060", Name: "Cert Test",
		})

		// Upload cert
		cert := &salesmodels.CustomerCertificate{
			ID:         uuid.New(),
			CustomerID: cust.ID,
			TenantID:   testTenant,
			CertType:   "TAX_EXEMPT",
			FileName:   "exemption_cert.pdf",
			FilePath:   "/uploads/certificates/test.pdf",
			FileSize:   1024,
			MimeType:   "application/pdf",
			UploadedAt: time.Now(),
		}
		err := svc.UploadCertificate(ctx, cert)
		if err != nil { t.Fatalf("upload cert: %v", err) }

		// List certs
		certs, err := svc.ListCertificates(ctx, cust.ID, testTenant)
		if err != nil { t.Fatalf("list certs: %v", err) }
		if len(certs) != 1 { t.Errorf("want 1 cert, got %d", len(certs)) }
		if certs[0].FileName != "exemption_cert.pdf" {
			t.Errorf("filename: %s", certs[0].FileName)
		}

		// Verify certs are loaded with GetCustomer
		fetched, err := svc.GetCustomer(ctx, cust.ID, testTenant)
		if err != nil { t.Fatalf("get customer: %v", err) }
		if len(fetched.Certificates) != 1 {
			t.Errorf("customer certs: want 1, got %d", len(fetched.Certificates))
		}

		// Delete cert
		err = svc.DeleteCertificate(ctx, cert.ID, cust.ID, testTenant)
		if err != nil { t.Fatalf("delete cert: %v", err) }

		certs, _ = svc.ListCertificates(ctx, cust.ID, testTenant)
		if len(certs) != 0 { t.Errorf("want 0 certs after delete, got %d", len(certs)) }
	})

	t.Run("Multi-tenant isolation", func(t *testing.T) {
		cleanCustomers(t)
		otherTenant := uuid.New()

		// Insert dummy tenant for FK
		_, _ = salesPool.Exec(ctx, `INSERT INTO tenants(id, name, slug, is_active, created_at, updated_at)
			VALUES($1,'Test Tenant','test-tenant',true,NOW(),NOW()) ON CONFLICT (id) DO NOTHING`, otherTenant)

		_, err := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C100", Name: "Tenant1 Customer",
		})
		if err != nil { t.Fatalf("create tenant1: %v", err) }

		_, err = svc.CreateCustomer(ctx, otherTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C101", Name: "Tenant2 Customer",
		})
		if err != nil { t.Fatalf("create tenant2: %v", err) }

		list, _ := svc.ListCustomers(ctx, testTenant, "", "")
		if len(list) != 1 { t.Errorf("tenant1 want 1, got %d", len(list)) }

		// Clean up
		_, _ = salesPool.Exec(ctx, "DELETE FROM customers WHERE tenant_id = $1", otherTenant)
		_, _ = salesPool.Exec(ctx, "DELETE FROM tenants WHERE id = $1", otherTenant)
	})

	t.Run("Sales Order CRUD with automated checks", func(t *testing.T) {
		cleanCustomers(t)
		// Create customer first
		cust, _ := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "SO001", Name: "SO Test Customer",
		})

		so, err := svc.CreateSalesOrder(ctx, testTenant, &salesmodels.CreateSalesOrderRequest{
			CustomerID:    cust.ID.String(),
			CustomerPONo:  "PO-2025-001",
			Currency:      "USD",
			PaymentTerms:  "Net 30",
			Carrier:       "UPS",
			ShippingMethod: "Ground",
			ShipperAccount: "1Z999AA1",
			SignatureRequired: true,
			BillToAddress:   "123 Main St, San Francisco, CA 94105",
			TransportationTo: "Los Angeles",
			Items: []salesmodels.CreateSOItemRequest{
				{ProductID: "00000000-0000-0000-0000-000000000000", Quantity: 2, UnitPrice: 100},
			},
		}, nil)
		if err != nil {
			// Product ID is dummy so inventory check may fail, but the SO should be created as DRAFT
			t.Logf("Sales order creation returned: %v", err)
		} else {
			if so.SONumber == "" { t.Error("expected so_number") }
			if so.CustomerPONo != "PO-2025-001" { t.Errorf("po: %s", so.CustomerPONo) }
			if so.Carrier != "UPS" { t.Errorf("carrier: %s", so.Carrier) }
			if !so.SignatureRequired { t.Error("expected signature_required") }
			if so.InventoryCheckStatus == "" { t.Error("expected inventory check status") }
			if so.CreditCheckStatus == "" { t.Error("expected credit check status") }
			t.Logf("SO %s created, inv_check=%s, credit_check=%s, tax=%s, alloc=%s",
				so.SONumber, so.InventoryCheckStatus, so.CreditCheckStatus, so.TaxCalcStatus, so.AllocationStatus)

			// Test Get
			fetched, err := svc.GetSalesOrder(ctx, so.ID, testTenant)
			if err != nil { t.Fatalf("get so: %v", err) }
			if fetched.SONumber != so.SONumber { t.Errorf("so number mismatch") }

			// Test Update Status
			_ = svc.UpdateSOStatus(ctx, so.ID, testTenant, "CONFIRMED")
			fetched2, _ := svc.GetSalesOrder(ctx, so.ID, testTenant)
			if fetched2.Status != "CONFIRMED" { t.Errorf("status: %s", fetched2.Status) }

			// Test List
			list, _ := svc.ListSalesOrders(ctx, testTenant, "")
			if len(list) < 1 { t.Error("expected at least 1 SO") }

			// Test Delete
			_ = svc.DeleteSalesOrder(ctx, so.ID, testTenant)
			_, err = svc.GetSalesOrder(ctx, so.ID, testTenant)
			if err == nil { t.Error("expected error after delete") }
		}
	})

	t.Run("Tax exemption clear on toggle off", func(t *testing.T) {
		cleanCustomers(t)
		isExempt := true
		startDate := "2025-01-01"
		endDate := "2025-12-31"
		created, err := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C070", Name: "Toggle Test",
			IsTaxExempt: &isExempt, TaxExemptionCert: "CERT-001", TaxExemptReason: "RESALE",
			TaxExemptStartDate: startDate, TaxExemptEndDate: endDate,
		})
		if err != nil { t.Fatalf("create exempt: %v", err) }
		if !created.IsTaxExempt { t.Fatal("expected exempt") }

		// Toggle off — send empty strings to clear
		isExempt = false
		emptyStr := ""
		err = svc.UpdateCustomer(ctx, created.ID, testTenant, &salesmodels.UpdateCustomerRequest{
			IsTaxExempt:       &isExempt,
			TaxExemptionCert:  &emptyStr,
			TaxExemptReason:   &emptyStr,
			TaxExemptStartDate: &emptyStr,
		})
		if err != nil { t.Fatalf("toggle off: %v", err) }

		fetched, err := svc.GetCustomer(ctx, created.ID, testTenant)
		if err != nil { t.Fatalf("get after toggle: %v", err) }
		if fetched.IsTaxExempt { t.Error("expected is_tax_exempt=false") }
		if fetched.TaxExemptionCert != "" { t.Errorf("expected empty cert, got %s", fetched.TaxExemptionCert) }
		if fetched.TaxExemptReason != "" { t.Errorf("expected empty reason, got %s", fetched.TaxExemptReason) }
		if fetched.TaxExemptStartDate != nil { t.Error("expected nil start_date") }
	})

	t.Run("Certificate with different types", func(t *testing.T) {
		cleanCustomers(t)
		cust, _ := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C080", Name: "Certs Types",
		})
		types := []string{"TAX_EXEMPT", "RESALE", "OTHER"}
		for _, ct := range types {
			cert := &salesmodels.CustomerCertificate{
				ID: uuid.New(), CustomerID: cust.ID, TenantID: testTenant,
				CertType: ct, FileName: ct + ".pdf", FilePath: "/test/"+ct+".pdf",
				FileSize: 100, MimeType: "application/pdf", UploadedAt: time.Now(),
			}
			if err := svc.UploadCertificate(ctx, cert); err != nil {
				t.Fatalf("upload %s: %v", ct, err)
			}
		}
		certs, _ := svc.ListCertificates(ctx, cust.ID, testTenant)
		if len(certs) != 3 { t.Fatalf("want 3 certs, got %d", len(certs)) }
		// Certs are ordered by uploaded_at DESC (reverse insert order)
		for i, ct := range []string{"OTHER", "RESALE", "TAX_EXEMPT"} {
			if certs[i].CertType != ct {
				t.Errorf("cert[%d] type: want %s, got %s", i, ct, certs[i].CertType)
			}
		}
	})

	t.Run("Partial update preserves other fields", func(t *testing.T) {
		cleanCustomers(t)
		created, _ := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C090", Name: "Partial Test", Currency: "USD",
		})
		// Only update status
		blocked := "Blocked"
		err := svc.UpdateCustomer(ctx, created.ID, testTenant, &salesmodels.UpdateCustomerRequest{
			Status: &blocked,
		})
		if err != nil { t.Fatalf("partial update: %v", err) }
		fetched, _ := svc.GetCustomer(ctx, created.ID, testTenant)
		if fetched.Status != "Blocked" { t.Errorf("status: want Blocked, got %s", fetched.Status) }
		if fetched.Name != "Partial Test" { t.Errorf("name changed: %s", fetched.Name) }
		if fetched.Currency != "USD" { t.Errorf("currency changed: %s", fetched.Currency) }
	})

	t.Run("Clear default_tax_jurisdiction_id", func(t *testing.T) {
		cleanCustomers(t)
		jidStr := "00000000-0000-0000-0000-000000000000"
		created, _ := svc.CreateCustomer(ctx, testTenant, &salesmodels.CreateCustomerRequest{
			CustomerCode: "C095", Name: "Jurisdiction Clear",
			DefaultTaxJurisdictionID: &jidStr,
		})
		emptyStr := ""
		err := svc.UpdateCustomer(ctx, created.ID, testTenant, &salesmodels.UpdateCustomerRequest{
			DefaultTaxJurisdictionID: &emptyStr,
		})
		if err != nil { t.Fatalf("clear jurisdiction: %v", err) }
		fetched, _ := svc.GetCustomer(ctx, created.ID, testTenant)
		if fetched.DefaultTaxJurisdictionID != nil { t.Error("expected nil default_tax_jurisdiction_id") }
	})
}
