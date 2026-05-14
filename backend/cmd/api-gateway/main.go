package main

import (
	"context"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/swiftai-erp/backend/internal/config"
	"github.com/swiftai-erp/backend/internal/middleware"
	jwtpkg "github.com/swiftai-erp/backend/pkg/jwt"
	"github.com/swiftai-erp/backend/pkg/response"
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

	authTarget := os.Getenv("AUTH_SERVICE_URL")
	if authTarget == "" {
		authTarget = "http://localhost:8081"
	}
	authURL, _ := url.Parse(authTarget)

	// Public routes prefix patterns (no JWT needed)
	publicPrefixes := []string{"/api/v1/auth/register", "/api/v1/auth/login", "/api/v1/auth/refresh"}

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORS())
	r.Use(gin.Logger())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "api-gateway", "version": "1.0.0"})
	})

	// Catch-all: route ALL /api/v1/* requests
	r.Any("/api/v1/*proxyPath", func(c *gin.Context) {
		fullPath := c.Param("proxyPath") // e.g. /auth/login, /roles, /admin/auth-objects

		// Check if this is a public route (no JWT required)
		isPublic := false
		for _, p := range publicPrefixes {
			if strings.HasPrefix("/api/v1"+fullPath, p) {
				isPublic = true
				break
			}
		}

		if !isPublic {
			// Validate JWT
			authHeader := c.GetHeader("Authorization")
			if authHeader == "" {
				response.Unauthorized(c, "missing authorization header")
				c.Abort()
				return
			}
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				response.Unauthorized(c, "invalid authorization format")
				c.Abort()
				return
			}
			claims, err := jwtpkg.ValidateToken(cfg.JWT, parts[1])
			if err != nil {
				response.Unauthorized(c, "invalid or expired token")
				c.Abort()
				return
			}
			// Set user context for downstream
			c.Set("user_id", claims.UserID)
			c.Set("tenant_id", claims.TenantID)
			c.Set("email", claims.Email)
			c.Set("roles", claims.Roles)
		}

		// Forward user context headers to downstream services
		c.Request.Header.Set("X-Forwarded-Host", c.Request.Host)
		c.Request.Header.Set("X-Real-IP", c.ClientIP())
		c.Request.Header.Set("X-User-Id", c.GetString("user_id"))
		c.Request.Header.Set("X-Tenant-Id", c.GetString("tenant_id"))
		c.Request.Header.Set("X-Email", c.GetString("email"))

		// Proxy to auth service (keep /api/v1 prefix)
		c.Request.URL.Path = "/api/v1" + fullPath

		proxy := httputil.NewSingleHostReverseProxy(authURL)
		proxy.ServeHTTP(c.Writer, c.Request)
	})

	srv := &http.Server{
		Addr:         "0.0.0.0:8080",
		Handler:      r,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	go func() {
		log.Info().Str("addr", srv.Addr).Msg("api-gateway starting")
		log.Info().Str("proxy_to", authTarget).Msg("proxying api requests to")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal().Err(err).Msg("api-gateway failed")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Info().Msg("shutting down api-gateway...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.Server.ShutdownTimeout)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatal().Err(err).Msg("api-gateway forced shutdown")
	}
	log.Info().Msg("api-gateway stopped")
}
