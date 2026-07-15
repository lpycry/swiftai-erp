package bootstrap

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"github.com/swiftai-erp/backend/internal/authz/models"
	"github.com/swiftai-erp/backend/internal/authz/repository"
)

type ObjectDef struct {
	Class      string
	Code       string
	Desc       string
	Activities []string
	Fields     []FieldDef
}

type FieldDef struct {
	Name      string
	Label     string
	FieldType string
	Required  bool
	Order     int
}

func EnsureDefaultAuthObjects(ctx context.Context, repo *repository.AuthObjectRepo) {
	now := time.Now()
	for _, def := range DefaultAuthObjects() {
		obj, _ := repo.GetByCode(ctx, def.Code)
		if obj == nil {
			obj = &models.AuthObject{
				ID:          uuid.New(),
				ObjectClass: def.Class,
				ObjectCode:  def.Code,
				Description: def.Desc,
				Activities:  def.Activities,
				IsActive:    true,
				CreatedAt:   now,
				UpdatedAt:   now,
			}
			if err := repo.Create(ctx, obj); err != nil {
				log.Warn().Err(err).Str("code", def.Code).Msg("default auth object create skipped")
				continue
			}
		}
		for _, f := range def.Fields {
			field := &models.AuthObjectField{
				ID:           uuid.New(),
				AuthObjectID: obj.ID,
				FieldName:    f.Name,
				FieldLabel:   f.Label,
				FieldType:    f.FieldType,
				IsRequired:   f.Required,
				DisplayOrder: f.Order,
			}
			if err := repo.CreateField(ctx, field); err != nil && !strings.Contains(err.Error(), "duplicate") {
				log.Warn().Err(err).Str("object", def.Code).Str("field", f.Name).Msg("default auth field create skipped")
			}
		}
	}
}

func DefaultAuthObjects() []ObjectDef {
	return []ObjectDef{
		{Class: "finance", Code: "F_GL_POST", Desc: "Post Journal Entries", Activities: []string{"create", "read", "update", "delete", "approve"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "gl_account", Label: "GL Account", FieldType: "account", Required: false, Order: 20},
			{Name: "cost_center", Label: "Cost Center", FieldType: "org", Required: false, Order: 30},
		}},
		{Class: "finance", Code: "F_GL_DISPLAY", Desc: "Display General Ledger", Activities: []string{"read", "print"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
		}},
		{Class: "finance", Code: "F_AP_POST", Desc: "Post AP Documents", Activities: []string{"create", "read", "update", "delete", "approve", "print"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "vendor_group", Label: "Vendor Group", FieldType: "general", Required: false, Order: 20},
		}},
		{Class: "finance", Code: "F_AR_POST", Desc: "Post AR Documents", Activities: []string{"create", "read", "update", "delete", "approve", "print"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "customer_group", Label: "Customer Group", FieldType: "general", Required: false, Order: 20},
		}},
		{Class: "finance", Code: "F_BANK_POST", Desc: "Post Bank Transactions", Activities: []string{"create", "read", "update", "approve"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "bank_account", Label: "Bank Account", FieldType: "account", Required: false, Order: 20},
		}},
		{Class: "finance", Code: "F_REPORT_RUN", Desc: "Run Financial Reports", Activities: []string{"read", "print", "schedule"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: false, Order: 10},
		}},
		{Class: "finance", Code: "F_PERIOD_MGMT", Desc: "Period Close/Open", Activities: []string{"read", "update", "close", "open"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "fiscal_year", Label: "Fiscal Year", FieldType: "general", Required: true, Order: 20},
		}},
		{Class: "finance", Code: "F_COST_ALLOC", Desc: "Cost Allocations", Activities: []string{"create", "read", "update", "approve"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "cost_center", Label: "Cost Center", FieldType: "org", Required: false, Order: 20},
		}},
		{Class: "logistics", Code: "M_MATE_STOCK", Desc: "Stock Movements", Activities: []string{"create", "read", "update", "delete", "transfer"}, Fields: []FieldDef{
			{Name: "plant", Label: "Plant", FieldType: "org", Required: true, Order: 10},
			{Name: "storage_loc", Label: "Storage Location", FieldType: "org", Required: false, Order: 20},
			{Name: "material_type", Label: "Material Type", FieldType: "general", Required: false, Order: 30},
		}},
		{Class: "logistics", Code: "M_WAREHOUSE", Desc: "Warehouse Management", Activities: []string{"create", "read", "update", "delete"}, Fields: []FieldDef{
			{Name: "warehouse", Label: "Warehouse", FieldType: "org", Required: true, Order: 10},
		}},
		{Class: "logistics", Code: "M_INV_COUNT", Desc: "Physical Inventory", Activities: []string{"create", "read", "update", "approve"}, Fields: []FieldDef{
			{Name: "plant", Label: "Plant", FieldType: "org", Required: true, Order: 10},
		}},
		{Class: "procurement", Code: "P_PO_CREATE", Desc: "Purchase Orders", Activities: []string{"create", "read", "update", "delete", "approve", "print"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "purch_group", Label: "Purchasing Group", FieldType: "org", Required: false, Order: 20},
		}},
		{Class: "procurement", Code: "P_PR_MGMT", Desc: "Purchase Requisitions", Activities: []string{"create", "read", "update", "delete", "approve", "print"}, Fields: []FieldDef{
			{Name: "plant", Label: "Plant", FieldType: "org", Required: true, Order: 10},
			{Name: "purch_group", Label: "Purchasing Group", FieldType: "org", Required: false, Order: 20},
		}},
		{Class: "procurement", Code: "P_VENDOR_MGMT", Desc: "Vendor Master", Activities: []string{"create", "read", "update", "delete"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: false, Order: 10},
			{Name: "vendor_group", Label: "Vendor Group", FieldType: "general", Required: false, Order: 20},
		}},
		{Class: "sales", Code: "S_SO_CREATE", Desc: "Sales Orders", Activities: []string{"create", "read", "update", "delete", "approve"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "sales_org", Label: "Sales Organization", FieldType: "org", Required: true, Order: 20},
			{Name: "customer_group", Label: "Customer Group", FieldType: "general", Required: false, Order: 30},
		}},
		{Class: "sales", Code: "S_DELIVERY", Desc: "Delivery Notes and PGI", Activities: []string{"create", "read", "update", "delete", "approve", "print"}, Fields: []FieldDef{
			{Name: "plant", Label: "Delivering Plant", FieldType: "org", Required: true, Order: 10},
			{Name: "warehouse", Label: "Warehouse", FieldType: "org", Required: false, Order: 20},
		}},
		{Class: "sales", Code: "S_BILLING", Desc: "Sales Billing and Invoices", Activities: []string{"create", "read", "update", "delete", "approve", "print"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: true, Order: 10},
			{Name: "sales_org", Label: "Sales Organization", FieldType: "org", Required: false, Order: 20},
		}},
		{Class: "sales", Code: "S_CUSTOMER_MGMT", Desc: "Customer Master", Activities: []string{"create", "read", "update", "delete"}, Fields: []FieldDef{
			{Name: "company_code", Label: "Company Code", FieldType: "org", Required: false, Order: 10},
		}},
		{Class: "production", Code: "P_PROD_ORDER", Desc: "Production Orders", Activities: []string{"create", "read", "update", "delete", "approve", "print"}, Fields: []FieldDef{
			{Name: "plant", Label: "Plant", FieldType: "org", Required: true, Order: 10},
			{Name: "work_center", Label: "Work Center", FieldType: "org", Required: false, Order: 20},
		}},
		{Class: "production", Code: "P_MPS_MRP", Desc: "MPS/MRP Planning", Activities: []string{"create", "read", "update", "approve", "schedule"}, Fields: []FieldDef{
			{Name: "plant", Label: "Plant", FieldType: "org", Required: true, Order: 10},
			{Name: "material_type", Label: "Material Type", FieldType: "general", Required: false, Order: 20},
		}},
		{Class: "admin", Code: "A_USER_MGMT", Desc: "User Management", Activities: []string{"create", "read", "update", "delete"}, Fields: nil},
		{Class: "admin", Code: "A_ROLE_MGMT", Desc: "Role and Authorization Management", Activities: []string{"create", "read", "update", "delete"}, Fields: nil},
		{Class: "admin", Code: "A_TENANT_SETTINGS", Desc: "Tenant Settings", Activities: []string{"read", "update"}, Fields: nil},
		{Class: "admin", Code: "A_AUDIT_VIEW", Desc: "Audit Log Viewer", Activities: []string{"read"}, Fields: nil},
	}
}
