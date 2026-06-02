package models

import (
	"time"

	"github.com/google/uuid"
)

// ── Material Price ──

type MaterialPrice struct {
	ID         uuid.UUID  `json:"id"`
	TenantID   uuid.UUID  `json:"tenant_id"`
	ProductID  uuid.UUID  `json:"product_id"`
	CustomerID *uuid.UUID `json:"customer_id,omitempty"`
	PriceType  string     `json:"price_type"`
	Price      float64    `json:"price"`
	Currency   string     `json:"currency"`
	PriceUnit  int        `json:"price_unit"`
	UOM        *string    `json:"uom,omitempty"`
	ValidFrom  time.Time  `json:"valid_from"`
	ValidTo    *time.Time `json:"valid_to,omitempty"`
	IsActive   bool       `json:"is_active"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
	// Joined fields
	ProductSKU  string `json:"product_sku,omitempty"`
	ProductName string `json:"product_name,omitempty"`
	CustomerCode string `json:"customer_code,omitempty"`
	CustomerName string `json:"customer_name,omitempty"`
}

type CreateMaterialPriceRequest struct {
	ProductID  string  `json:"product_id" binding:"required"`
	CustomerID string  `json:"customer_id,omitempty"`
	PriceType  string  `json:"price_type,omitempty"`
	Price      float64 `json:"price" binding:"required,gt=0"`
	Currency   string  `json:"currency,omitempty"`
	PriceUnit  int     `json:"price_unit,omitempty"`
	UOM        string  `json:"uom,omitempty"`
	ValidFrom  string  `json:"valid_from" binding:"required"`
	ValidTo    string  `json:"valid_to,omitempty"`
}

type UpdateMaterialPriceRequest struct {
	CustomerID *string  `json:"customer_id,omitempty"`
	PriceType  *string  `json:"price_type,omitempty"`
	Price      *float64 `json:"price,omitempty"`
	Currency   *string  `json:"currency,omitempty"`
	PriceUnit  *int     `json:"price_unit,omitempty"`
	UOM        *string  `json:"uom,omitempty"`
	ValidFrom  *string  `json:"valid_from,omitempty"`
	ValidTo    *string  `json:"valid_to,omitempty"`
	IsActive   *bool    `json:"is_active,omitempty"`
}
