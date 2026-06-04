package models

import (
	"time"

	"github.com/google/uuid"
)

type CostCenter struct {
	ID             uuid.UUID `json:"id"`
	TenantID       uuid.UUID `json:"tenant_id"`
	CostCenterID   string    `json:"cost_center_id"`
	Description    string    `json:"description"`
	CostCenterType string    `json:"cost_center_type,omitempty"`
	IsActive       bool      `json:"is_active"`
	ValidFrom      string    `json:"valid_from"`
	ValidTo        string    `json:"valid_to,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type CreateCostCenterRequest struct {
	CostCenterID   string `json:"cost_center_id" binding:"required"`
	Description    string `json:"description" binding:"required"`
	CostCenterType string `json:"cost_center_type"`
	IsActive       *bool  `json:"is_active,omitempty"`
	ValidFrom      string `json:"valid_from"`
	ValidTo        string `json:"valid_to,omitempty"`
}

type UpdateCostCenterRequest struct {
	Description    string `json:"description"`
	CostCenterType string `json:"cost_center_type"`
	IsActive       *bool  `json:"is_active,omitempty"`
	ValidFrom      string `json:"valid_from"`
	ValidTo        string `json:"valid_to,omitempty"`
}
