package models

import (
	"time"

	"github.com/google/uuid"
)

type DateFormat struct {
	ID            uuid.UUID `json:"id"`
	TenantID      uuid.UUID `json:"tenant_id"`
	FormatCode    string    `json:"format_code"`
	DisplayName   string    `json:"display_name"`
	DatePattern   string    `json:"date_pattern"`
	Separator     string    `json:"separator"`
	ExampleOutput string    `json:"example_output,omitempty"`
	SortOrder     int       `json:"sort_order"`
	IsActive      bool      `json:"is_active"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type CreateDateFormatRequest struct {
	FormatCode    string `json:"format_code" binding:"required"`
	DisplayName   string `json:"display_name" binding:"required"`
	DatePattern   string `json:"date_pattern" binding:"required"`
	Separator     string `json:"separator"`
	ExampleOutput string `json:"example_output,omitempty"`
	SortOrder     int    `json:"sort_order"`
	IsActive      *bool  `json:"is_active,omitempty"`
}

type UpdateDateFormatRequest struct {
	DisplayName   string `json:"display_name"`
	DatePattern   string `json:"date_pattern"`
	Separator     string `json:"separator"`
	ExampleOutput string `json:"example_output,omitempty"`
	SortOrder     *int   `json:"sort_order,omitempty"`
	IsActive      *bool  `json:"is_active,omitempty"`
}
