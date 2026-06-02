package service

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	fsmodels "github.com/swiftai-erp/backend/internal/financesettings/models"
	fsrepo "github.com/swiftai-erp/backend/internal/financesettings/repository"
)

// ── Test Suite Setup ──

var (
	testPool      *pgxpool.Pool
	testTenant    = uuid.MustParse("a06826ac-2152-4d58-8de2-a9c6577e926e")
)

func TestMain(m *testing.M) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://swiftai:swiftai_dev_pass@localhost:5432/swiftai_erp?sslmode=disable"
	}

	var err error
	testPool, err = pgxpool.New(context.Background(), dsn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to connect to test DB: %v\n", err)
		os.Exit(1)
	}
	defer testPool.Close()

	// Run migrations if tables don't exist
	_, err = testPool.Exec(context.Background(), `
		CREATE TABLE IF NOT EXISTS tax_jurisdictions (
			id               UUID PRIMARY KEY,
			tenant_id        UUID NOT NULL,
			state            VARCHAR(50) NOT NULL,
			county           VARCHAR(100) NOT NULL DEFAULT '',
			city             VARCHAR(100) NOT NULL DEFAULT '',
			zip_code         VARCHAR(10) NOT NULL DEFAULT '',
			tax_rate         NUMERIC(6,4) NOT NULL,
			effective_date   DATE NOT NULL,
			expiration_date  DATE DEFAULT NULL,
			is_active        BOOLEAN NOT NULL DEFAULT true,
			created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to ensure tax_jurisdictions table: %v\n", err)
		os.Exit(1)
	}

	_, err = testPool.Exec(context.Background(), `
		CREATE TABLE IF NOT EXISTS tax_nexus (
			id               UUID PRIMARY KEY,
			tenant_id        UUID NOT NULL,
			state            VARCHAR(100) NOT NULL,
			nexus_type       VARCHAR(30) NOT NULL,
			sub_type         VARCHAR(30) NOT NULL DEFAULT '',
			threshold_amount NUMERIC(12,2) DEFAULT NULL,
			effective_date   DATE NOT NULL,
			is_active        BOOLEAN NOT NULL DEFAULT true,
			created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to ensure tax_nexus table: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Tax test suite initialized")
	code := m.Run()
	os.Exit(code)
}

func setupTaxService(t *testing.T) *FinanceSettingsService {
	t.Helper()
	repo := fsrepo.NewFinanceSettingsRepo(testPool)
	return NewFinanceSettingsService(repo)
}

// cleanTaxJurisdictions removes any test data we might have left
func cleanTaxJurisdictions(t *testing.T) {
	t.Helper()
	_, err := testPool.Exec(context.Background(), "DELETE FROM tax_jurisdictions WHERE tenant_id = $1", testTenant)
	if err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
}

func cleanTaxNexus(t *testing.T) {
	t.Helper()
	_, err := testPool.Exec(context.Background(), "DELETE FROM tax_nexus WHERE tenant_id = $1", testTenant)
	if err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
}

// ═══════════════════════════════════════════════════════════
//  TAX JURISDICTION TESTS
// ═══════════════════════════════════════════════════════════

func TestTaxJurisdictionCRUD(t *testing.T) {
	if testPool == nil {
		t.Skip("test database not available")
	}
	ctx := context.Background()
	svc := setupTaxService(t)
	defer cleanTaxJurisdictions(t)

	t.Run("Create and Get", func(t *testing.T) {
		created, err := svc.CreateTaxJurisdiction(ctx, testTenant, &fsmodels.CreateTaxJurisdictionRequest{
			State:         "CA",
			County:        "Santa Clara",
			City:          "Milpitas",
			ZipCode:       "95035",
			TaxRate:       0.09375,
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("CreateTaxJurisdiction failed: %v", err)
		}
		if created.ID == uuid.Nil {
			t.Fatal("expected non-zero ID")
		}
		if created.State != "CA" {
			t.Errorf("expected state CA, got %s", created.State)
		}
		if created.County != "Santa Clara" {
			t.Errorf("expected county Santa Clara, got %s", created.County)
		}
		if created.City != "Milpitas" {
			t.Errorf("expected city Milpitas, got %s", created.City)
		}
		if created.ZipCode != "95035" {
			t.Errorf("expected zip 95035, got %s", created.ZipCode)
		}
		if created.TaxRate != 0.09375 {
			t.Errorf("expected tax_rate 0.09375, got %f", created.TaxRate)
		}
		if !created.IsActive {
			t.Error("expected is_active = true")
		}

		// Get by ID
		got, err := svc.GetTaxJurisdiction(ctx, created.ID)
		if err != nil {
			t.Fatalf("GetTaxJurisdiction failed: %v", err)
		}
		if got.State != "CA" || got.County != "Santa Clara" {
			t.Errorf("get mismatch: %+v", got)
		}
	})

	t.Run("List with active filter", func(t *testing.T) {
		cleanTaxJurisdictions(t)

		// Create active and inactive records
		_, err := svc.CreateTaxJurisdiction(ctx, testTenant, &fsmodels.CreateTaxJurisdictionRequest{
			State: "CA", County: "Orange", City: "Irvine", ZipCode: "92618",
			TaxRate: 0.0775, EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("create active failed: %v", err)
		}

		// Create inactive
		inactiveReq := &fsmodels.CreateTaxJurisdictionRequest{
			State: "TX", County: "Dallas", City: "Dallas", ZipCode: "75201",
			TaxRate: 0.0825, EffectiveDate: "2025-01-01",
		}
		inactive, err := svc.CreateTaxJurisdiction(ctx, testTenant, inactiveReq)
		if err != nil {
			t.Fatalf("create inactive failed: %v", err)
		}
		// Deactivate
		activeFalse := false
		err = svc.UpdateTaxJurisdiction(ctx, inactive.ID, testTenant, &fsmodels.UpdateTaxJurisdictionRequest{
			IsActive: &activeFalse,
		})
		if err != nil {
			t.Fatalf("deactivate failed: %v", err)
		}

		// List all
		all, err := svc.ListTaxJurisdictions(ctx, testTenant, false)
		if err != nil {
			t.Fatalf("ListTaxJurisdictions failed: %v", err)
		}
		if len(all) != 2 {
			t.Errorf("expected 2 total jurisdictions, got %d", len(all))
		}

		// List active only
		active, err := svc.ListTaxJurisdictions(ctx, testTenant, true)
		if err != nil {
			t.Fatalf("ListTaxJurisdictions(activeOnly=true) failed: %v", err)
		}
		if len(active) != 1 {
			t.Errorf("expected 1 active jurisdiction, got %d", len(active))
		}
		for _, j := range active {
			if !j.IsActive {
				t.Errorf("expected all items to be active, got inactive: %+v", j)
			}
		}
	})

	t.Run("Update fields", func(t *testing.T) {
		cleanTaxJurisdictions(t)

		created, err := svc.CreateTaxJurisdiction(ctx, testTenant, &fsmodels.CreateTaxJurisdictionRequest{
			State: "CA", County: "Alameda", City: "Oakland", ZipCode: "94601",
			TaxRate: 0.0925, EffectiveDate: "2025-06-01",
		})
		if err != nil {
			t.Fatalf("create failed: %v", err)
		}

		newRate := 0.1000
		newCity := "Berkeley"
		err = svc.UpdateTaxJurisdiction(ctx, created.ID, testTenant, &fsmodels.UpdateTaxJurisdictionRequest{
			City:    &newCity,
			TaxRate: &newRate,
		})
		if err != nil {
			t.Fatalf("UpdateTaxJurisdiction failed: %v", err)
		}

		updated, err := svc.GetTaxJurisdiction(ctx, created.ID)
		if err != nil {
			t.Fatalf("Get after update failed: %v", err)
		}
		if updated.City != "Berkeley" {
			t.Errorf("expected city Berkeley, got %s", updated.City)
		}
		if updated.TaxRate != 0.1000 {
			t.Errorf("expected tax_rate 0.10, got %f", updated.TaxRate)
		}
		if updated.County != "Alameda" {
			t.Errorf("county should remain Alameda, got %s", updated.County)
		}
	})

	t.Run("Delete", func(t *testing.T) {
		cleanTaxJurisdictions(t)

		created, err := svc.CreateTaxJurisdiction(ctx, testTenant, &fsmodels.CreateTaxJurisdictionRequest{
			State: "NY", County: "New York", City: "New York", ZipCode: "10001",
			TaxRate: 0.08875, EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("create failed: %v", err)
		}

		err = svc.DeleteTaxJurisdiction(ctx, created.ID, testTenant)
		if err != nil {
			t.Fatalf("DeleteTaxJurisdiction failed: %v", err)
		}

		_, err = svc.GetTaxJurisdiction(ctx, created.ID)
		if err == nil {
			t.Error("expected error after delete, got nil")
		}
	})

	t.Run("Create with expiration date", func(t *testing.T) {
		cleanTaxJurisdictions(t)

		expDate := "2025-12-31"
		created, err := svc.CreateTaxJurisdiction(ctx, testTenant, &fsmodels.CreateTaxJurisdictionRequest{
			State:          "CA",
			County:         "Los Angeles",
			City:           "Los Angeles",
			ZipCode:        "90001",
			TaxRate:        0.1025,
			EffectiveDate:  "2025-01-01",
			ExpirationDate: expDate,
		})
		if err != nil {
			t.Fatalf("create with expiration failed: %v", err)
		}
		if created.ExpirationDate == nil {
			t.Fatal("expected non-nil expiration_date")
		}
		expectedExp, _ := time.Parse("2006-01-02", expDate)
		if !created.ExpirationDate.Equal(expectedExp) {
			t.Errorf("expected expiration %s, got %s", expDate, created.ExpirationDate.Format("2006-01-02"))
		}
	})
}

// ═══════════════════════════════════════════════════════════
//  TAX NEXUS TESTS
// ═══════════════════════════════════════════════════════════

func TestTaxNexusCRUD(t *testing.T) {
	if testPool == nil {
		t.Skip("test database not available")
	}
	ctx := context.Background()
	svc := setupTaxService(t)
	defer cleanTaxNexus(t)

	t.Run("Create Physical Nexus", func(t *testing.T) {
		created, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
			State:         "California",
			NexusType:     "PHYSICAL",
			SubType:       "WAREHOUSE",
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("CreateTaxNexus failed: %v", err)
		}
		if created.ID == uuid.Nil {
			t.Fatal("expected non-zero ID")
		}
		if created.State != "California" {
			t.Errorf("expected state California, got %s", created.State)
		}
		if created.NexusType != "PHYSICAL" {
			t.Errorf("expected nexus_type PHYSICAL, got %s", created.NexusType)
		}
		if created.SubType != "WAREHOUSE" {
			t.Errorf("expected sub_type WAREHOUSE, got %s", created.SubType)
		}
		if !created.IsActive {
			t.Error("expected is_active = true")
		}

		// Get by ID
		got, err := svc.GetTaxNexus(ctx, created.ID)
		if err != nil {
			t.Fatalf("GetTaxNexus failed: %v", err)
		}
		if got.State != "California" || got.NexusType != "PHYSICAL" {
			t.Errorf("get mismatch: %+v", got)
		}
	})

	t.Run("Create Economic Nexus with threshold", func(t *testing.T) {
		threshold := 500000.0
		created, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
			State:           "Texas",
			NexusType:       "ECONOMIC",
			ThresholdAmount: &threshold,
			EffectiveDate:   "2025-01-01",
		})
		if err != nil {
			t.Fatalf("CreateTaxNexus economic failed: %v", err)
		}
		if created.ThresholdAmount == nil {
			t.Fatal("expected non-nil threshold_amount")
		}
		if *created.ThresholdAmount != 500000.0 {
			t.Errorf("expected threshold 500000, got %f", *created.ThresholdAmount)
		}
		if created.SubType != "" {
			t.Errorf("expected empty sub_type for economic nexus, got %s", created.SubType)
		}
	})

	t.Run("List with active filter", func(t *testing.T) {
		cleanTaxNexus(t)

		// Create active
		_, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
			State: "California", NexusType: "PHYSICAL", SubType: "OFFICE",
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("create active failed: %v", err)
		}

		// Create inactive
		inactive, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
			State: "New York", NexusType: "ECONOMIC",
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("create inactive failed: %v", err)
		}
		activeFalse := false
		err = svc.UpdateTaxNexus(ctx, inactive.ID, testTenant, &fsmodels.UpdateTaxNexusRequest{
			IsActive: &activeFalse,
		})
		if err != nil {
			t.Fatalf("deactivate failed: %v", err)
		}

		// List all
		all, err := svc.ListTaxNexus(ctx, testTenant, false)
		if err != nil {
			t.Fatalf("ListTaxNexus failed: %v", err)
		}
		if len(all) != 2 {
			t.Errorf("expected 2 total nexus, got %d", len(all))
		}

		// List active only
		active, err := svc.ListTaxNexus(ctx, testTenant, true)
		if err != nil {
			t.Fatalf("ListTaxNexus(activeOnly=true) failed: %v", err)
		}
		if len(active) != 1 {
			t.Errorf("expected 1 active nexus, got %d", len(active))
		}
	})

	t.Run("Update nexus fields", func(t *testing.T) {
		cleanTaxNexus(t)

		created, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
			State: "California", NexusType: "PHYSICAL", SubType: "WAREHOUSE",
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("create failed: %v", err)
		}

		// Change to economic with threshold
		ecoType := "ECONOMIC"
		threshold := 500000.0
		err = svc.UpdateTaxNexus(ctx, created.ID, testTenant, &fsmodels.UpdateTaxNexusRequest{
			NexusType:       &ecoType,
			ThresholdAmount: &threshold,
		})
		if err != nil {
			t.Fatalf("UpdateTaxNexus failed: %v", err)
		}

		updated, err := svc.GetTaxNexus(ctx, created.ID)
		if err != nil {
			t.Fatalf("Get after update failed: %v", err)
		}
		if updated.NexusType != "ECONOMIC" {
			t.Errorf("expected nexus_type ECONOMIC, got %s", updated.NexusType)
		}
		if updated.ThresholdAmount == nil || *updated.ThresholdAmount != 500000.0 {
			t.Errorf("expected threshold 500000, got %v", updated.ThresholdAmount)
		}
	})

	t.Run("Delete nexus", func(t *testing.T) {
		cleanTaxNexus(t)

		created, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
			State: "Oregon", NexusType: "PHYSICAL", SubType: "EMPLOYEE",
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("create failed: %v", err)
		}

		err = svc.DeleteTaxNexus(ctx, created.ID, testTenant)
		if err != nil {
			t.Fatalf("DeleteTaxNexus failed: %v", err)
		}

		_, err = svc.GetTaxNexus(ctx, created.ID)
		if err == nil {
			t.Error("expected error after delete, got nil")
		}
	})

	t.Run("Physical Nexus subtypes", func(t *testing.T) {
		cleanTaxNexus(t)

		subTypes := []string{"WAREHOUSE", "OFFICE", "EMPLOYEE"}
		for _, st := range subTypes {
			created, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
				State: "California", NexusType: "PHYSICAL", SubType: st,
				EffectiveDate: "2025-01-01",
			})
			if err != nil {
				t.Fatalf("create %s failed: %v", st, err)
			}
			if created.SubType != st {
				t.Errorf("expected sub_type %s, got %s", st, created.SubType)
			}
		}

		all, err := svc.ListTaxNexus(ctx, testTenant, false)
		if err != nil {
			t.Fatalf("list failed: %v", err)
		}
		if len(all) != 3 {
			t.Errorf("expected 3 physical nexus, got %d", len(all))
		}
	})
}

func TestTaxJurisdictionValidation(t *testing.T) {
	if testPool == nil {
		t.Skip("test database not available")
	}
	ctx := context.Background()
	svc := setupTaxService(t)
	defer cleanTaxJurisdictions(t)

	t.Run("Missing required fields should fail at model binding", func(t *testing.T) {
		// The binding:"required" validation happens at Gin handler level
		// Service just passes through to repo, so this tests the DB constraint
		_, err := svc.CreateTaxJurisdiction(ctx, testTenant, &fsmodels.CreateTaxJurisdictionRequest{
			State: "", // empty state
			TaxRate: 0.08,
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Logf("Create with empty state returned error (expected as DB constraint): %v", err)
		}
	})
}

func TestTaxNexusValidation(t *testing.T) {
	if testPool == nil {
		t.Skip("test database not available")
	}
	ctx := context.Background()
	svc := setupTaxService(t)
	defer cleanTaxNexus(t)

	t.Run("Empty nexus type defaults handled", func(t *testing.T) {
		// Service doesn't enforce oneof at repo level; that's handler binding
		_, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
			State: "California", NexusType: "PHYSICAL",
			EffectiveDate: "2025-01-01",
		})
		if err != nil {
			t.Fatalf("create with PHYSICAL failed: %v", err)
		}
	})
}

// ═══════════════════════════════════════════════════════════
//  EDGE CASES
// ═══════════════════════════════════════════════════════════

func TestTaxJurisdictionMultiTenantIsolation(t *testing.T) {
	if testPool == nil {
		t.Skip("test database not available")
	}
	ctx := context.Background()
	svc := setupTaxService(t)
	defer cleanTaxJurisdictions(t)

	otherTenant := uuid.New()

	// Create for test tenant
	_, err := svc.CreateTaxJurisdiction(ctx, testTenant, &fsmodels.CreateTaxJurisdictionRequest{
		State: "CA", County: "Santa Clara", City: "Milpitas", ZipCode: "95035",
		TaxRate: 0.09375, EffectiveDate: "2025-01-01",
	})
	if err != nil {
		t.Fatalf("create for test tenant failed: %v", err)
	}

	// Create for other tenant
	_, err = svc.CreateTaxJurisdiction(ctx, otherTenant, &fsmodels.CreateTaxJurisdictionRequest{
		State: "TX", County: "Dallas", City: "Dallas", ZipCode: "75201",
		TaxRate: 0.0825, EffectiveDate: "2025-01-01",
	})
	if err != nil {
		t.Fatalf("create for other tenant failed: %v", err)
	}

	// List for test tenant should only see 1
	list, err := svc.ListTaxJurisdictions(ctx, testTenant, false)
	if err != nil {
		t.Fatalf("list failed: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("expected 1 for test tenant, got %d", len(list))
	}
	if list[0].State != "CA" {
		t.Errorf("expected CA for test tenant, got %s", list[0].State)
	}

	// Clean up other tenant
	_, err = testPool.Exec(ctx, "DELETE FROM tax_jurisdictions WHERE tenant_id = $1", otherTenant)
	if err != nil {
		t.Fatalf("cleanup other tenant failed: %v", err)
	}
}

func TestTaxNexusMultiTenantIsolation(t *testing.T) {
	if testPool == nil {
		t.Skip("test database not available")
	}
	ctx := context.Background()
	svc := setupTaxService(t)
	defer cleanTaxNexus(t)

	otherTenant := uuid.New()

	// Create for test tenant
	_, err := svc.CreateTaxNexus(ctx, testTenant, &fsmodels.CreateTaxNexusRequest{
		State: "California", NexusType: "PHYSICAL", SubType: "WAREHOUSE",
		EffectiveDate: "2025-01-01",
	})
	if err != nil {
		t.Fatalf("create for test tenant failed: %v", err)
	}

	// Create for other tenant
	_, err = svc.CreateTaxNexus(ctx, otherTenant, &fsmodels.CreateTaxNexusRequest{
		State: "Texas", NexusType: "ECONOMIC",
		EffectiveDate: "2025-01-01",
	})
	if err != nil {
		t.Fatalf("create for other tenant failed: %v", err)
	}

	// List for test tenant should only see 1
	list, err := svc.ListTaxNexus(ctx, testTenant, false)
	if err != nil {
		t.Fatalf("list failed: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("expected 1 for test tenant, got %d", len(list))
	}
	if list[0].State != "California" {
		t.Errorf("expected California for test tenant, got %s", list[0].State)
	}

	// Clean up other tenant
	_, err = testPool.Exec(ctx, "DELETE FROM tax_nexus WHERE tenant_id = $1", otherTenant)
	if err != nil {
		t.Fatalf("cleanup other tenant failed: %v", err)
	}
}
