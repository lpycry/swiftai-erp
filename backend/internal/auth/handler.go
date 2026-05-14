package auth

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog/log"
	"github.com/swiftai-erp/backend/internal/models"
	"github.com/swiftai-erp/backend/pkg/response"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// Register handles POST /api/v1/auth/register
func (h *Handler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	resp, err := h.svc.Register(c.Request.Context(), req)
	if err != nil {
		log.Err(err).Str("email", req.Email).Msg("register failed")
		switch err {
		case ErrEmailTaken:
			response.Conflict(c, "email already registered")
		default:
			response.InternalError(c, "registration failed, please try again")
		}
		return
	}

	response.Created(c, resp)
}

// Login handles POST /api/v1/auth/login
func (h *Handler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	resp, err := h.svc.Login(c.Request.Context(), req)
	if err != nil {
		log.Err(err).Str("email", req.Email).Msg("login failed")
		switch err {
		case ErrInvalidCredentials:
			response.Error(c, http.StatusUnauthorized, "invalid email or password")
		case ErrUserInactive:
			response.Forbidden(c, "account is inactive")
		default:
			response.InternalError(c, "login failed, please try again")
		}
		return
	}

	response.OK(c, resp)
}

// RefreshToken handles POST /api/v1/auth/refresh
func (h *Handler) RefreshToken(c *gin.Context) {
	var req models.RefreshTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	tokens, err := h.svc.RefreshToken(c.Request.Context(), req.RefreshToken)
	if err != nil {
		log.Err(err).Msg("token refresh failed")
		response.Unauthorized(c, "invalid or expired refresh token")
		return
	}

	response.OK(c, tokens)
}

// Me handles GET /api/v1/auth/me (requires auth)
func (h *Handler) Me(c *gin.Context) {
	userID := c.GetString("user_id")
	email := c.GetString("email")
	tenantID := c.GetString("tenant_id")
	roles, _ := c.Get("roles")

	response.OK(c, gin.H{
		"user_id":   userID,
		"email":     email,
		"tenant_id": tenantID,
		"roles":     roles,
	})
}
