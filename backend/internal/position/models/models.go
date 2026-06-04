package models

import (
	"time"

	"github.com/google/uuid"
)

type Position struct {
	ID               uuid.UUID  `json:"id"`
	TenantID         uuid.UUID  `json:"tenant_id"`
	PositionCode     string     `json:"position_code"`
	PositionTitle    string     `json:"position_title"`
	OrgUnitID        *uuid.UUID `json:"org_unit_id,omitempty"`
	ParentPositionID *uuid.UUID `json:"parent_position_id,omitempty"`
	IsActive         bool       `json:"is_active"`
	ValidFrom        string     `json:"valid_from"`
	ValidTo          string     `json:"valid_to,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

type CreatePositionRequest struct {
	PositionCode     string `json:"position_code" binding:"required"`
	PositionTitle    string `json:"position_title" binding:"required"`
	OrgUnitID        string `json:"org_unit_id,omitempty"`
	ParentPositionID string `json:"parent_position_id,omitempty"`
	IsActive         *bool  `json:"is_active,omitempty"`
	ValidFrom        string `json:"valid_from"`
	ValidTo          string `json:"valid_to,omitempty"`
}

type UpdatePositionRequest struct {
	PositionTitle    string `json:"position_title"`
	OrgUnitID        string `json:"org_unit_id,omitempty"`
	ParentPositionID string `json:"parent_position_id,omitempty"`
	IsActive         *bool  `json:"is_active,omitempty"`
	ValidFrom        string `json:"valid_from"`
	ValidTo          string `json:"valid_to,omitempty"`
}

type PositionNode struct {
	Position
	Children []*PositionNode `json:"children,omitempty"`
}
