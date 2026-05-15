package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

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
	"github.com/swiftai-erp/backend/internal/rbac"
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

	// Router
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(gin.Logger())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "auth-service"})
	})

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
		protected.POST("/gl/journal-entries/:id/reverse", glHandler.ReverseJournalEntry)
				protected.POST("/gl/journal-entries/:id/unpost", glHandler.UnpostEntry)

		// ---- GL: AI ----
		protected.POST("/gl/ai/suggest", glHandler.AISuggest)
				protected.POST("/gl/reset-database", glHandler.ResetDatabase)
				protected.POST("/gl/initialize-coa", glHandler.InitializeCoA)

		// ---- GL: Attachments ----
		protected.POST("/gl/journal-entries/:id/attachments", glHandler.UploadAttachment)
		protected.GET("/gl/journal-entries/:id/attachments", glHandler.GetAttachments)

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
	}

	srv := &http.Server{
		Addr:         ":" + "8081",
		Handler:      r,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	go func() {
		log.Info().Str("port", "8081").Msg("auth-service starting")
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
