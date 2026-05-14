package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/swiftai-erp/backend/internal/authz/models"
	"github.com/swiftai-erp/backend/internal/authz/repository"
	"github.com/swiftai-erp/backend/internal/config"
	"github.com/swiftai-erp/backend/internal/database"
)

type authObjectDef struct {
	Class      string
	Code       string
	Desc       string
	Activities []string
	Fields     []fieldDef
}

type fieldDef struct {
	Name     string
	Label    string
	FieldType string
	Required bool
	Order    int
}

func main() {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = zerolog.New(os.Stderr).With().Timestamp().Logger()

	cfgPath := os.Getenv("CONFIG_PATH")
	if cfgPath == "" {
		cfgPath = "config/config.dev.yaml"
	}
	cfg, err := config.Load(cfgPath)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to load config")
	}

	ctx := context.Background()
	pool, err := database.NewPostgresPool(ctx, cfg.Database)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect")
	}
	defer pool.Close()

	repo := repository.NewAuthObjectRepo(pool)
	now := time.Now()

	definitions := []authObjectDef{
		// ---- Finance ----
		{"finance", "F_GL_POST", "Post Journal Entries", []string{"create", "read", "update", "delete", "approve"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"gl_account", "GL Account", "account", false, 20},
			{"cost_center", "Cost Center", "org", false, 30},
		}},
		{"finance", "F_GL_DISPLAY", "Display General Ledger", []string{"read", "print"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
		}},
		{"finance", "F_AP_POST", "Post AP Documents", []string{"create", "read", "update", "delete", "approve", "print"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"vendor_group", "Vendor Group", "general", false, 20},
		}},
		{"finance", "F_AR_POST", "Post AR Documents", []string{"create", "read", "update", "delete", "approve", "print"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"customer_group", "Customer Group", "general", false, 20},
		}},
		{"finance", "F_BANK_POST", "Post Bank Transactions", []string{"create", "read", "update", "approve"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"bank_account", "Bank Account", "account", false, 20},
		}},
		{"finance", "F_REPORT_RUN", "Run Financial Reports", []string{"read", "print", "schedule"}, []fieldDef{
			{"company_code", "Company Code", "org", false, 10},
		}},
		{"finance", "F_PERIOD_MGMT", "Period Close/Open", []string{"read", "update", "close", "open"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"fiscal_year", "Fiscal Year", "general", true, 20},
		}},
		{"finance", "F_COST_ALLOC", "Cost Allocations", []string{"create", "read", "update", "approve"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"cost_center", "Cost Center", "org", false, 20},
		}},
		// ---- Logistics ----
		{"logistics", "M_MATE_STOCK", "Stock Movements", []string{"create", "read", "update", "delete", "transfer"}, []fieldDef{
			{"plant", "Plant", "org", true, 10},
			{"storage_loc", "Storage Location", "org", false, 20},
			{"material_type", "Material Type", "general", false, 30},
		}},
		{"logistics", "M_WAREHOUSE", "Warehouse Management", []string{"create", "read", "update", "delete"}, []fieldDef{
			{"warehouse", "Warehouse", "org", true, 10},
		}},
		{"logistics", "M_INV_COUNT", "Physical Inventory", []string{"create", "read", "update", "approve"}, []fieldDef{
			{"plant", "Plant", "org", true, 10},
		}},
		// ---- Procurement ----
		{"procurement", "P_PO_CREATE", "Purchase Orders", []string{"create", "read", "update", "delete", "approve", "print"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"purch_group", "Purchasing Group", "org", false, 20},
		}},
		{"procurement", "P_RFQ_MGMT", "Manage RFQs", []string{"create", "read", "update", "close"}, []fieldDef{
			{"company_code", "Company Code", "org", false, 10},
		}},
		{"procurement", "P_GR_POST", "Goods Receipt", []string{"create", "read", "update", "delete"}, []fieldDef{
			{"plant", "Plant", "org", true, 10},
		}},
		{"procurement", "P_VENDOR_MGMT", "Vendor Master", []string{"create", "read", "update", "delete"}, []fieldDef{
			{"company_code", "Company Code", "org", false, 10},
			{"vendor_group", "Vendor Group", "general", false, 20},
		}},
		// ---- Sales ----
		{"sales", "S_SO_CREATE", "Sales Orders", []string{"create", "read", "update", "delete", "approve"}, []fieldDef{
			{"company_code", "Company Code", "org", true, 10},
			{"sales_org", "Sales Organization", "org", true, 20},
			{"customer_group", "Customer Group", "general", false, 30},
		}},
		{"sales", "S_QUOTE_MGMT", "Manage Quotations", []string{"create", "read", "update", "delete"}, []fieldDef{
			{"sales_org", "Sales Organization", "org", true, 10},
		}},
		{"sales", "S_CUSTOMER_MGMT", "Customer Master", []string{"create", "read", "update", "delete"}, []fieldDef{
			{"company_code", "Company Code", "org", false, 10},
		}},
		// ---- Admin ----
		{"admin", "A_USER_MGMT", "User Management", []string{"create", "read", "update", "delete"}, nil},
		{"admin", "A_ROLE_MGMT", "Role Management", []string{"create", "read", "update", "delete"}, nil},
		{"admin", "A_TENANT_SETTINGS", "Tenant Settings", []string{"read", "update"}, nil},
		{"admin", "A_AUDIT_VIEW", "Audit Log Viewer", []string{"read"}, nil},
		{"admin", "A_SOD_MGMT", "SoD Rule Management", []string{"create", "read", "update", "delete"}, nil},
	}

	for _, def := range definitions {
		objID := uuid.New()
		obj := &models.AuthObject{
			ID:          objID,
			ObjectClass: def.Class,
			ObjectCode:  def.Code,
			Description: def.Desc,
			Activities:  def.Activities,
			IsActive:    true,
			CreatedAt:   now,
			UpdatedAt:   now,
		}

		if err := repo.Create(ctx, obj); err != nil {
			log.Warn().Err(err).Str("code", def.Code).Msg("already exists")
			// Get existing ID
			existing, _ := repo.GetByCode(ctx, def.Code)
			if existing != nil {
				objID = existing.ID
			}
		} else {
			log.Info().Str("code", def.Code).Msg("auth object created")
		}

		// Create fields
		for _, f := range def.Fields {
			field := &models.AuthObjectField{
				ID:           uuid.New(),
				AuthObjectID: objID,
				FieldName:    f.Name,
				FieldLabel:   f.Label,
				FieldType:    f.FieldType,
				IsRequired:   f.Required,
				DisplayOrder: f.Order,
			}
			if err := repo.CreateField(ctx, field); err != nil {
				log.Warn().Err(err).Str("field", f.Name).Msg("field already exists")
			}
		}
	}

	fmt.Println("Auth objects seeded successfully!")
	_ = pool.Close()
}
