package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Standard API response structures.
type (
	APIResponse struct {
		Success bool        `json:"success"`
		Message string      `json:"message,omitempty"`
		Data    interface{} `json:"data,omitempty"`
		Meta    *Meta       `json:"meta,omitempty"`
	}

	Meta struct {
		Page       int   `json:"page"`
		PageSize   int   `json:"page_size"`
		TotalCount int64 `json:"total_count"`
		TotalPages int   `json:"total_pages"`
	}

	ErrorDetail struct {
		Field   string `json:"field,omitempty"`
		Message string `json:"message"`
	}

	ErrorResponse struct {
		Success bool          `json:"success"`
		Message string        `json:"message"`
		Errors  []ErrorDetail `json:"errors,omitempty"`
		Code    string        `json:"code,omitempty"`
	}
)

// OK sends a 200 success response.
func OK(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Data:    data,
	})
}

// Created sends a 201 response.
func Created(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, APIResponse{
		Success: true,
		Data:    data,
	})
}

// OKWithMeta sends a 200 success response with pagination metadata.
func OKWithMeta(c *gin.Context, data interface{}, meta *Meta) {
	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Data:    data,
		Meta:    meta,
	})
}

// Error sends an error response with the given status code.
func Error(c *gin.Context, status int, message string, errs ...ErrorDetail) {
	resp := ErrorResponse{
		Success: false,
		Message: message,
	}
	if len(errs) > 0 {
		resp.Errors = errs
	}
	c.JSON(status, resp)
}

// BadRequest sends a 400 error.
func BadRequest(c *gin.Context, message string, errs ...ErrorDetail) {
	Error(c, http.StatusBadRequest, message, errs...)
}

// Unauthorized sends a 401 error.
func Unauthorized(c *gin.Context, message string) {
	Error(c, http.StatusUnauthorized, message)
}

// Forbidden sends a 403 error.
func Forbidden(c *gin.Context, message string) {
	Error(c, http.StatusForbidden, message)
}

// NotFound sends a 404 error.
func NotFound(c *gin.Context, message string) {
	Error(c, http.StatusNotFound, message)
}

// Conflict sends a 409 error.
func Conflict(c *gin.Context, message string) {
	Error(c, http.StatusConflict, message)
}

// InternalError sends a 500 error.
func InternalError(c *gin.Context, message string) {
	Error(c, http.StatusInternalServerError, message)
}
