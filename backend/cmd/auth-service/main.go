package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	ccHandler "github.com/swiftai-erp/backend/internal/costcenter/handler"
	ccRepo "github.com/swiftai-erp/backend/internal/costcenter/repository"

	ouHandler "github.com/swiftai-erp/backend/internal/orgunit/handler"
	ouRepo "github.com/swiftai-erp/backend/internal/orgunit/repository"

	posHandler "github.com/swiftai-erp/backend/internal/position/handler"
	posRepo "github.com/swiftai-erp/backend/internal/position/repository"

	empHandler "github.com/swiftai-erp/backend/internal/employee/handler"
	empRepo "github.com/swiftai-erp/backend/internal/employee/repository"

	dfHandler "github.com/swiftai-erp/backend/internal/dateformat/handler"
	dfRepo "github.com/swiftai-erp/backend/internal/dateformat/repository"

	"github.com/swiftai-erp/backend/internal/auth"
	"github.com/swiftai-erp/backend/internal/authz/engine"
	authzHandler "github.com/swiftai-erp/backend/internal/authz/handler"
	authzRepo "github.com/swiftai-erp/backend/internal/authz/repository"
	"github.com/swiftai-erp/backend/internal/config"
	"github.com/swiftai-erp/backend/internal/database"
	glhandler "github.com/swiftai-erp/backend/internal/gl/handler"
	glrepo "github.com/swiftai-erp/backend/internal/gl/repository"
	glsvc "github.com/swiftai-erp/backend/internal/gl/service"
	"github.com/swiftai-erp/backend/internal/middleware"
	orghandler "github.com/swiftai-erp/backend/internal/org/handler"
	orgrepo "github.com/swiftai-erp/backend/internal/org/repository"
	whhandler "github.com/swiftai-erp/backend/internal/warehouse/handler"
	whrepo "github.com/swiftai-erp/backend/internal/warehouse/repository"
	whsvc "github.com/swiftai-erp/backend/internal/warehouse/service"
	"github.com/swiftai-erp/backend/internal/rbac"

	purchaserepo "github.com/swiftai-erp/backend/internal/purchase/repository"
	purchasessvc "github.com/swiftai-erp/backend/internal/purchase/service"
	purchasehandler "github.com/swiftai-erp/backend/internal/purchase/handler"

	fsrepo "github.com/swiftai-erp/backend/internal/financesettings/repository"
	fssvc "github.com/swiftai-erp/backend/internal/financesettings/service"
	fshandler "github.com/swiftai-erp/backend/internal/financesettings/handler"

	salesrepo "github.com/swiftai-erp/backend/internal/sales/repository"
	salessvc "github.com/swiftai-erp/backend/internal/sales/service"
	saleshandler "github.com/swiftai-erp/backend/internal/sales/handler"

	arrepo "github.com/swiftai-erp/backend/internal/ar/repository"
	arsvc "github.com/swiftai-erp/backend/internal/ar/service"
	arhandler "github.com/swiftai-erp/backend/internal/ar/handler"
)

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
		log.Fatal().Err(err).Msg("failed to connect to postgres")
	}
	defer pool.Close()

	rdb, err := database.NewRedisClient(ctx, cfg.Redis)
	if err != nil {
		log.Warn().Err(err).Msg("redis unavailable, authz caching disabled")
	}
	if rdb != nil {
		defer rdb.Close()
	}

	// Auth
	authRepo := auth.NewRepository(pool, rdb)
	authSvc := auth.NewService(authRepo, cfg.JWT)
	authHandler := auth.NewHandler(authSvc)

	rbacRepo := rbac.NewRepository(pool)
	rbacHandler := rbac.NewHandler(rbacRepo)

	// AuthZ
	authObjRepo := authzRepo.NewAuthObjectRepo(pool)
	roleRepo := authzRepo.NewRoleRepo(pool)
	authValRepo := authzRepo.NewAuthValueRepo(pool)
	adminHandler := authzHandler.NewAdminHandler(authObjRepo, roleRepo, authValRepo)
	permEngine := engine.New(roleRepo, authValRepo, authObjRepo, rdb)

	// GL
	glAccountRepo := glrepo.NewAccountRepo(pool)
	glEntryRepo := glrepo.NewEntryRepo(pool)
	glSvc := glsvc.NewGLService(glAccountRepo, glEntryRepo, pool)
	aiSvc := glsvc.NewAIService(glAccountRepo)
	glHandler := glhandler.NewGLHandler(glSvc, aiSvc)

	// Org
	orgRepo := orgrepo.NewOrgRepo(pool)
	orgHandler := orghandler.NewOrgHandler(orgRepo)
	periodHandler := orghandler.NewPeriodHandler(pool)

	// Warehouse
	whProductRepo := whrepo.NewProductRepo(pool)
	whWarehouseRepo := whrepo.NewWarehouseRepo(pool)
	whSvc := whsvc.NewWarehouseService(pool, whProductRepo, whWarehouseRepo)
	whHandler := whhandler.NewWarehouseHandler(whSvc)

	// Purchase
	purchaseRepo := purchaserepo.NewPurchaseRepo(pool)
	purchaseSvc := purchasessvc.NewPurchaseService(pool, purchaseRepo, glSvc)
	purchaseHandler := purchasehandler.NewPurchaseHandler(purchaseSvc)

	// Finance Settings
	financeSettingsRepo := fsrepo.NewFinanceSettingsRepo(pool)
	financeSettingsSvc := fssvc.NewFinanceSettingsService(financeSettingsRepo)
	financeSettingsHandler := fshandler.NewFinanceSettingsHandler(financeSettingsSvc)

	// Cost Center
	costCenterRepo := ccRepo.NewCostCenterRepo(pool)
	costCenterHandler := ccHandler.NewCostCenterHandler(costCenterRepo)

	// Org Unit
	orgUnitRepo := ouRepo.NewOrgUnitRepo(pool)
	orgUnitHandler := ouHandler.NewOrgUnitHandler(orgUnitRepo)

	// Position
	positionRepo := posRepo.NewPositionRepo(pool)
	positionHandler := posHandler.NewPositionHandler(positionRepo)

	// Employee
	employeeRepo := empRepo.NewEmployeeRepo(pool)
	employeeHandler := empHandler.NewEmployeeHandler(employeeRepo)

	// Date Format
	dateFormatRepo := dfRepo.NewDateFormatRepo(pool)
	dateFormatHandler := dfHandler.NewDateFormatHandler(dateFormatRepo)

	// Sales
	salesRepo := salesrepo.NewSalesRepo(pool)
	salesSvc := salessvc.NewSalesService(salesRepo)
	salesHandler := saleshandler.NewSalesHandler(salesSvc)

	// AR (Accounts Receivable)
	arRepo := arrepo.NewARRepo(pool)
	arSvc := arsvc.NewARService(arRepo, pool, glSvc)
	arHandler := arhandler.NewARHandler(arSvc)

	// Router
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(gin.Logger())
	r.Use(middleware.CORS())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "auth-service"})
	})

	// Serve uploaded files (product photos, etc.)
	r.Static("/uploads", "./uploads")

	v1 := r.Group("/api/v1")
	{
		authGroup := v1.Group("/auth")
		{
			authGroup.POST("/register", authHandler.Register)
			authGroup.POST("/login", authHandler.Login)
			authGroup.POST("/refresh", authHandler.RefreshToken)
		}
	}

	protected := v1.Group("")
	protected.Use(middleware.AuthRequired(cfg.JWT))
	protected.Use(middleware.ProxyContext())
	{
		// Auth
		protected.GET("/auth/me", authHandler.Me)
		protected.POST("/roles", rbacHandler.CreateRole)
		protected.GET("/roles", rbacHandler.ListRoles)
		protected.POST("/roles/assign", rbacHandler.AssignUserRole)
		protected.GET("/users/:id/permissions", rbacHandler.GetUserPermissions)

		// Admin
		admin := protected.Group("/admin")
		admin.Use(middleware.RequirePermission(permEngine, "A_ROLE_MGMT", "manage"))
		{
			admin.POST("/auth-objects", adminHandler.CreateAuthObject)
			admin.GET("/auth-objects", adminHandler.ListAuthObjects)
			admin.GET("/auth-objects/:id", adminHandler.GetAuthObject)
			admin.PUT("/auth-objects/:id", adminHandler.UpdateAuthObject)
			admin.DELETE("/auth-objects/:id", adminHandler.DeleteAuthObject)
			admin.POST("/auth-objects/:id/fields", adminHandler.AddObjectField)
		}

		// Role Master
		protected.POST("/role-master", adminHandler.CreateRole)
		protected.GET("/role-master", adminHandler.ListRoles)
		protected.GET("/role-master/:id", adminHandler.GetRole)
		protected.DELETE("/role-master/:id", adminHandler.DeleteRole)

		// Role Auth Values
		protected.GET("/role-auth-values/:roleId", adminHandler.GetAuthValues)
		protected.PUT("/role-auth-values/:roleId", adminHandler.SetAuthValue)

		// User-Role
		protected.POST("/user-roles/assign", adminHandler.AssignUserRole)
		protected.DELETE("/user-roles/:userId/:roleId", adminHandler.RemoveUserRole)
		protected.GET("/user-permissions/:userId", adminHandler.GetUserPermissions)

		// Permission Check
		protected.GET("/permissions/check", adminHandler.CheckPermission)
		protected.POST("/permissions/check", adminHandler.CheckPermissionPOST)

		// ---- GL: Chart of Accounts ----
		protected.POST("/gl/accounts", glHandler.CreateAccount)
		protected.GET("/gl/accounts", glHandler.ListAccounts)
		protected.GET("/gl/accounts/tree", glHandler.GetAccountTree)
		protected.GET("/gl/accounts/search", glHandler.SearchAccounts)
		protected.GET("/gl/accounts/leaf", glHandler.GetLeafAccounts)
		protected.GET("/gl/accounts/:id", glHandler.GetAccount)
		protected.GET("/gl/accounts/:id/ledger", glHandler.GetAccountLedger)
		protected.GET("/gl/balances", glHandler.GetAccountBalances)
		protected.GET("/gl/reports/balance-sheet", glHandler.GetBalanceSheet)
		protected.GET("/gl/reports/profit-loss", glHandler.GetProfitLoss)
		protected.PUT("/gl/accounts/:id", glHandler.UpdateAccount)
		protected.DELETE("/gl/accounts/:id", glHandler.DeleteAccount)
		protected.PUT("/gl/accounts/:id/reactivate", glHandler.ReactivateAccount)

		// ---- GL: Journal Entries ----
		protected.POST("/gl/journal-entries", glHandler.CreateJournalEntry)
		protected.GET("/gl/journal-entries", glHandler.ListJournalEntries)
		protected.GET("/gl/journal-entries/:id", glHandler.GetJournalEntry)
		protected.POST("/gl/journal-entries/post", glHandler.PostJournalEntries)
		protected.PATCH("/gl/journal-entries/:id/status", glHandler.UpdateJournalEntryStatus)
		protected.PUT("/gl/journal-entries/:id", glHandler.UpdateDraftEntry)
		protected.DELETE("/gl/journal-entries/:id", glHandler.DeleteJournalEntry)
		protected.POST("/gl/journal-entries/:id/reverse", glHandler.ReverseJournalEntry)
				protected.POST("/gl/journal-entries/:id/unpost", glHandler.UnpostEntry)

		// ---- GL: AI ----
		protected.POST("/gl/ai/suggest", glHandler.AISuggest)
		protected.POST("/gl/ai/ocr", glHandler.AnalyzeOCR)
				protected.POST("/gl/reset-database", glHandler.ResetDatabase)
				protected.POST("/gl/initialize-coa", glHandler.InitializeCoA)

		// ---- GL: Attachments ----
		protected.POST("/gl/journal-entries/:id/attachments", glHandler.UploadAttachment)
		protected.GET("/gl/journal-entries/:id/attachments", glHandler.GetAttachments)
		protected.GET("/gl/journal-entries/:id/attachments/:attachmentId/download", glHandler.DownloadAttachment)

		// ---- Warehouse (REQ-WM-002/003/004/005) ----
		protected.POST("/warehouse/products", whHandler.CreateProduct)
		protected.GET("/warehouse/products", whHandler.ListProducts)
		protected.GET("/warehouse/products/:id", whHandler.GetProduct)
		protected.POST("/warehouse/warehouses", whHandler.CreateWarehouse)
		protected.GET("/warehouse/warehouses", whHandler.ListWarehouses)
		protected.GET("/warehouse/warehouses/:id", whHandler.GetWarehouse)
		protected.PUT("/warehouse/warehouses/:id", whHandler.UpdateWarehouse)
		protected.DELETE("/warehouse/warehouses/:id", whHandler.DeleteWarehouse)
		protected.POST("/warehouse/movements", whHandler.PostMovement)
		protected.GET("/warehouse/movements", whHandler.ListMovements)
		protected.GET("/warehouse/stock", whHandler.ListStock)
		protected.PUT("/warehouse/products/:id", whHandler.UpdateProduct)
		protected.DELETE("/warehouse/products/:id", whHandler.DeleteProduct)
		protected.POST("/warehouse/zones", whHandler.CreateZone)
		protected.GET("/warehouse/zones", whHandler.ListZones)
		protected.POST("/warehouse/bins", whHandler.CreateBin)
		protected.GET("/warehouse/bins", whHandler.ListBins)
		protected.GET("/warehouse/bins/:id", whHandler.GetBin)
		protected.PUT("/warehouse/bins/:id", whHandler.UpdateBin)
		protected.DELETE("/warehouse/bins/:id", whHandler.DeleteBin)
		// ---- Warehouse: Barcodes (REQ-MM-031) ----
		protected.GET("/warehouse/products/:id/barcodes", whHandler.ListBarcodes)
		protected.POST("/warehouse/products/:id/barcodes", whHandler.CreateBarcode)
		protected.DELETE("/warehouse/products/:id/barcodes/:barcodeId", whHandler.DeleteBarcode)
		// ---- Warehouse: Photos (REQ-MM-001~010) ----
		protected.GET("/warehouse/products/:id/photos", whHandler.ListPhotos)
		protected.POST("/warehouse/products/:id/photos", whHandler.UploadPhoto)
		protected.DELETE("/warehouse/products/:id/photos/:photoId", whHandler.DeletePhoto)

		// ---- Warehouse: Goods Receipt (REQ-IB-005~014) ----
		protected.GET("/warehouse/gr", whHandler.ListGRs)
		protected.POST("/warehouse/gr", whHandler.CreateGR)
		protected.POST("/warehouse/gr/:id/post", whHandler.PostGR)

		// ---- Warehouse: Outbound Order (REQ-OB-001~018) ----
		protected.GET("/warehouse/outbound", whHandler.ListOutbound)
		protected.POST("/warehouse/outbound", whHandler.CreateOutbound)
		protected.POST("/warehouse/outbound/:id/ship", whHandler.ShipOutbound)

		// ---- Warehouse: Cycle Count (REQ-CC-001~008) ----
		protected.GET("/warehouse/cycle-counts", whHandler.ListCycleCounts)
		protected.POST("/warehouse/cycle-counts", whHandler.CreateCycleCount)
		protected.POST("/warehouse/cycle-counts/ai-suggest", whHandler.AISuggestCycleCounts)

		// ---- Warehouse: Tasks (REQ-IO-014~018) ----
		protected.GET("/warehouse/tasks", whHandler.ListTasks)
		protected.POST("/warehouse/tasks/:id/complete", whHandler.CompleteTask)

		// ---- Orgs ----
		protected.POST("/orgs", orgHandler.CreateOrg)
		protected.GET("/orgs", orgHandler.ListOrgs)
		protected.GET("/orgs/:id", orgHandler.GetOrg)
		protected.PUT("/orgs/:id", orgHandler.UpdateOrg)
		protected.DELETE("/orgs/:id", orgHandler.DeleteOrg)
		protected.GET("/orgs/:id/sites", orgHandler.ListSites)

		// ---- Sites ----
		protected.POST("/sites", orgHandler.CreateSite)
		protected.GET("/sites", orgHandler.GetAllSites)
		protected.GET("/sites/:id", orgHandler.GetSite)
		protected.PUT("/sites/:id", orgHandler.UpdateSite)
		protected.DELETE("/sites/:id", orgHandler.DeleteSite)

		// ---- Periods ----
		protected.GET("/periods", periodHandler.ListPeriods)
		protected.PUT("/periods/:id", periodHandler.UpdatePeriod)
		protected.POST("/periods/generate", periodHandler.GeneratePeriods)

		// ---- Purchase Module ----
		protected.POST("/purchase/vendors", purchaseHandler.CreateVendor)
		protected.GET("/purchase/vendors", purchaseHandler.ListVendors)
		protected.GET("/purchase/vendors/:id", purchaseHandler.GetVendor)
		protected.PUT("/purchase/vendors/:id", purchaseHandler.UpdateVendor)
		protected.DELETE("/purchase/vendors/:id", purchaseHandler.DeleteVendor)
		protected.GET("/purchase/vendors/recommend", purchaseHandler.RecommendVendors)

		protected.POST("/purchase/orders", purchaseHandler.CreatePO)
		protected.GET("/purchase/orders", purchaseHandler.ListPOs)
		protected.GET("/purchase/orders/:id", purchaseHandler.GetPO)
		protected.PUT("/purchase/orders/:id/status", purchaseHandler.UpdatePOStatus)
		protected.POST("/purchase/orders/:id/attachments", purchaseHandler.UploadPOAttachment)
		protected.GET("/purchase/orders/:id/attachments", purchaseHandler.ListPOAttachments)
		protected.GET("/purchase/orders/:id/attachments/:attachId/download", purchaseHandler.DownloadPOAttachment)

		protected.GET("/purchase/pending-invoice-pos", purchaseHandler.ListPendingInvoicePOs)
		protected.GET("/purchase/outstanding-invoices", purchaseHandler.ListOutstandingInvoices)
		protected.GET("/purchase/payment-history", purchaseHandler.ListPaymentHistory)

		protected.POST("/purchase/receipts", purchaseHandler.ExecuteGoodsReceipt)
		protected.GET("/purchase/receipts", purchaseHandler.ListReceipts)
		protected.GET("/purchase/receipts/:id/journal", purchaseHandler.GetReceiptJournalEntry)
		protected.POST("/purchase/receipts/:id/reverse", purchaseHandler.ReverseGoodsReceipt)

		protected.POST("/purchase/invoices", purchaseHandler.CreateInvoice)
		protected.GET("/purchase/invoices", purchaseHandler.ListInvoices)
		protected.GET("/purchase/invoices/:id", purchaseHandler.GetInvoice)
		protected.POST("/purchase/invoices/:id/post", purchaseHandler.PostInvoice)
		protected.POST("/purchase/invoices/:id/cancel", purchaseHandler.CancelInvoice)

		protected.POST("/purchase/down-payments", purchaseHandler.CreateDownPayment)
		protected.GET("/purchase/down-payments", purchaseHandler.ListDownPayments)
		protected.GET("/purchase/down-payments/:id", purchaseHandler.GetDownPayment)
		protected.POST("/purchase/down-payments/:id/post", purchaseHandler.PostDownPayment)
		protected.POST("/purchase/down-payments/:id/refund", purchaseHandler.RefundDownPayment)
		protected.POST("/purchase/down-payments/:id/reverse", purchaseHandler.ReverseDownPayment)
		protected.GET("/purchase/down-payments/:id/clearings", purchaseHandler.GetDPClearings)
		protected.DELETE("/purchase/down-payments/:id", purchaseHandler.DeleteDownPayment)
		protected.GET("/purchase/vendor-open-items", purchaseHandler.GetVendorOpenItems)
		protected.POST("/purchase/vendor-payments", purchaseHandler.CreateVendorPayment)

		// ---- Finance Settings: Payment Terms ----
		protected.GET("/finance-settings/payment-terms", financeSettingsHandler.ListPaymentTerms)
		protected.POST("/finance-settings/payment-terms", financeSettingsHandler.CreatePaymentTerm)
		protected.PUT("/finance-settings/payment-terms/:id", financeSettingsHandler.UpdatePaymentTerm)
		protected.DELETE("/finance-settings/payment-terms/:id", financeSettingsHandler.DeletePaymentTerm)

		// ---- Finance Settings: Incoterms ----
		protected.GET("/finance-settings/incoterms", financeSettingsHandler.ListIncoterms)
		protected.POST("/finance-settings/incoterms", financeSettingsHandler.CreateIncoterm)
		protected.PUT("/finance-settings/incoterms/:id", financeSettingsHandler.UpdateIncoterm)
		protected.DELETE("/finance-settings/incoterms/:id", financeSettingsHandler.DeleteIncoterm)

		// ---- Finance Settings: Org Reconciliation Accounts ----
		protected.GET("/finance-settings/org-recon-accounts", financeSettingsHandler.ListOrgReconAccounts)
		protected.POST("/finance-settings/org-recon-accounts", financeSettingsHandler.CreateOrgReconAccount)
		protected.PUT("/finance-settings/org-recon-accounts/:id", financeSettingsHandler.UpdateOrgReconAccount)
		protected.DELETE("/finance-settings/org-recon-accounts/:id", financeSettingsHandler.DeleteOrgReconAccount)

		// ---- Tax Jurisdictions ----
		protected.GET("/finance-settings/tax-jurisdictions", financeSettingsHandler.ListTaxJurisdictions)
		protected.GET("/finance-settings/tax-jurisdictions/:id", financeSettingsHandler.GetTaxJurisdiction)
		protected.POST("/finance-settings/tax-jurisdictions", financeSettingsHandler.CreateTaxJurisdiction)
		protected.PUT("/finance-settings/tax-jurisdictions/:id", financeSettingsHandler.UpdateTaxJurisdiction)
		protected.DELETE("/finance-settings/tax-jurisdictions/:id", financeSettingsHandler.DeleteTaxJurisdiction)

		// ---- Tax Nexus ----
		protected.GET("/finance-settings/tax-nexus", financeSettingsHandler.ListTaxNexus)
		protected.GET("/finance-settings/tax-nexus/:id", financeSettingsHandler.GetTaxNexus)
		protected.POST("/finance-settings/tax-nexus", financeSettingsHandler.CreateTaxNexus)
		protected.PUT("/finance-settings/tax-nexus/:id", financeSettingsHandler.UpdateTaxNexus)
		protected.DELETE("/finance-settings/tax-nexus/:id", financeSettingsHandler.DeleteTaxNexus)

		// ---- Tax Jurisdiction Rules (Product Category × Tax Code) ----
		protected.GET("/finance-settings/tax-jurisdiction-rules", financeSettingsHandler.ListTaxJurisdictionRules)
		protected.GET("/finance-settings/tax-jurisdiction-rules/:rule_id", financeSettingsHandler.GetTaxJurisdictionRule)
		protected.POST("/finance-settings/tax-jurisdiction-rules", financeSettingsHandler.CreateTaxJurisdictionRule)
		protected.PUT("/finance-settings/tax-jurisdiction-rules/:rule_id", financeSettingsHandler.UpdateTaxJurisdictionRule)
		protected.DELETE("/finance-settings/tax-jurisdiction-rules/:rule_id", financeSettingsHandler.DeleteTaxJurisdictionRule)

		// ---- Tax Categories ----
		protected.GET("/finance-settings/tax-categories", financeSettingsHandler.ListTaxCategories)
		protected.GET("/finance-settings/tax-categories/:id", financeSettingsHandler.GetTaxCategory)
		protected.POST("/finance-settings/tax-categories", financeSettingsHandler.CreateTaxCategory)
		protected.PUT("/finance-settings/tax-categories/:id", financeSettingsHandler.UpdateTaxCategory)
		protected.DELETE("/finance-settings/tax-categories/:id", financeSettingsHandler.DeleteTaxCategory)

		// ---- Sales: Customer Certificates ----
		protected.POST("/sales/customers/:id/certificates", salesHandler.UploadCertificate)
		protected.GET("/sales/customers/:id/certificates", salesHandler.ListCertificates)
		protected.DELETE("/sales/customers/:id/certificates/:certId", salesHandler.DeleteCertificate)

		// ---- Sales: Customers ----
		protected.POST("/sales/customers", salesHandler.CreateCustomer)
		protected.GET("/sales/customers", salesHandler.ListCustomers)
		protected.GET("/sales/customers/:id", salesHandler.GetCustomer)
		protected.PUT("/sales/customers/:id", salesHandler.UpdateCustomer)
		protected.DELETE("/sales/customers/:id", salesHandler.DeleteCustomer)

		// ---- Sales: Material Prices ----
		protected.POST("/sales/material-prices", salesHandler.CreateMaterialPrice)
		protected.GET("/sales/material-prices", salesHandler.ListMaterialPrices)
		protected.GET("/sales/material-prices/lookup", salesHandler.LookupMaterialPrice)
		protected.GET("/sales/material-prices/:id", salesHandler.GetMaterialPrice)
		protected.PUT("/sales/material-prices/:id", salesHandler.UpdateMaterialPrice)
		protected.DELETE("/sales/material-prices/:id", salesHandler.DeleteMaterialPrice)

		// ---- AR: Credit Limits ----
		protected.POST("/ar/credit-limits", arHandler.CreateCreditLimit)
		protected.GET("/ar/credit-limits", arHandler.ListCreditLimits)
		protected.GET("/ar/credit-limits/:id", arHandler.GetCreditLimit)
		protected.PUT("/ar/credit-limits/:id", arHandler.UpdateCreditLimit)
		protected.DELETE("/ar/credit-limits/:id", arHandler.DeleteCreditLimit)

		// ---- AR: Customer Down Payments ----
		protected.POST("/ar/down-payments", arHandler.CreateDownPayment)
		protected.GET("/ar/down-payments", arHandler.ListDownPayments)
		protected.GET("/ar/down-payments/:id", arHandler.GetDownPayment)

		// ---- Sales: Tax Calculation ----
		protected.POST("/sales/quotations/calculate-tax", salesHandler.CalculateTax)

		// ---- Sales: Quotations ----
		protected.POST("/sales/quotations", salesHandler.CreateQuotation)
		protected.GET("/sales/quotations", salesHandler.ListQuotations)
		protected.GET("/sales/quotations/:id", salesHandler.GetQuotation)
		protected.PUT("/sales/quotations/:id/status", salesHandler.UpdateQuotationStatus)
		protected.DELETE("/sales/quotations/:id", salesHandler.DeleteQuotation)

		// ---- Sales: Sales Orders ----
		protected.POST("/sales/orders", salesHandler.CreateSalesOrder)
		protected.GET("/sales/orders", salesHandler.ListSalesOrders)
		protected.GET("/sales/orders/:id", salesHandler.GetSalesOrder)
		protected.PUT("/sales/orders/:id/status", salesHandler.UpdateSOStatus)
		protected.DELETE("/sales/orders/:id", salesHandler.DeleteSalesOrder)

		// ---- Cost Centers ----
		protected.POST("/cost-centers", costCenterHandler.CreateCostCenter)
		protected.GET("/cost-centers", costCenterHandler.ListCostCenters)
		protected.GET("/cost-centers/:id", costCenterHandler.GetCostCenter)
		protected.PUT("/cost-centers/:id", costCenterHandler.UpdateCostCenter)
		protected.DELETE("/cost-centers/:id", costCenterHandler.DeleteCostCenter)

		// ---- Org Units (Departments) ----
		protected.POST("/org-units", orgUnitHandler.CreateOrgUnit)
		protected.GET("/org-units", orgUnitHandler.ListOrgUnits)
		protected.GET("/org-units/:id", orgUnitHandler.GetOrgUnit)
		protected.PUT("/org-units/:id", orgUnitHandler.UpdateOrgUnit)
		protected.DELETE("/org-units/:id", orgUnitHandler.DeleteOrgUnit)

		// ---- Positions ----
		protected.POST("/positions", positionHandler.CreatePosition)
		protected.GET("/positions", positionHandler.ListPositions)     // ?mode=tree
		protected.GET("/positions/:id", positionHandler.GetPosition)
		protected.PUT("/positions/:id", positionHandler.UpdatePosition)
		protected.DELETE("/positions/:id", positionHandler.DeletePosition)

		// ---- Employees ----
		protected.POST("/employees", employeeHandler.CreateEmployee)
		protected.GET("/employees", employeeHandler.ListEmployees)     // ?mode=current for current view
		protected.GET("/employees/:id", employeeHandler.GetEmployee)    // ?include=all for full detail
		protected.PUT("/employees/:id", employeeHandler.UpdateEmployee)
		protected.DELETE("/employees/:id", employeeHandler.DeleteEmployee)

		// ---- Employee Data History (Infotype) ----
		protected.POST("/employees/:id/history", employeeHandler.CreateDataHistory)
		protected.GET("/employees/:id/history", employeeHandler.ListDataHistory)
		protected.PUT("/employee-records/:recordId", employeeHandler.UpdateDataHistory)
		protected.DELETE("/employee-records/:recordId", employeeHandler.DeleteDataHistory)

		// ---- Date Formats (SAP-style) ----
		protected.POST("/date-formats", dateFormatHandler.Create)
		protected.GET("/date-formats", dateFormatHandler.List)
		protected.GET("/date-formats/:id", dateFormatHandler.Get)
		protected.PUT("/date-formats/:id", dateFormatHandler.Update)
		protected.DELETE("/date-formats/:id", dateFormatHandler.Delete)

	}

	srv := &http.Server{
		Addr:         ":" + fmt.Sprintf("%d", cfg.Server.Port),
		Handler:      r,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	go func() {
		log.Info().Int("port", cfg.Server.Port).Msg("auth-service starting")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal().Err(err).Msg("auth-service failed")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Info().Msg("shutting down auth-service...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.Server.ShutdownTimeout)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatal().Err(err).Msg("auth-service forced shutdown")
	}
	log.Info().Msg("auth-service stopped")
}
