package models

import (
	"time"

	"github.com/google/uuid"
)

type OrgUnit struct {
	ID            uuid.UUID `json:"id"`
	TenantID      uuid.UUID `json:"tenant_id"`
	UnitCode      string    `json:"unit_code"`
	UnitName      string    `json:"unit_name"`
	ParentID      *uuid.UUID `json:"parent_id,omitempty"`
	ManagerID     string    `json:"manager_id,omitempty"`
	CostCenterID  string    `json:"cost_center_id,omitempty"`
	IsActive      bool      `json:"is_active"`
	ValidFrom     string    `json:"valid_from"`
	ValidTo       string    `json:"valid_to,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type CreateOrgUnitRequest struct {
	UnitCode     string `json:"unit_code" binding:"required"`
	UnitName     string `json:"unit_name" binding:"required"`
	ParentID     string `json:"parent_id,omitempty"`
	ManagerID    string `json:"manager_id,omitempty"`
	CostCenterID string `json:"cost_center_id,omitempty"`
	IsActive     *bool  `json:"is_active,omitempty"`
	ValidFrom    string `json:"valid_from"`
	ValidTo      string `json:"valid_to,omitempty"`
}

type UpdateOrgUnitRequest struct {
	UnitName     string `json:"unit_name"`
	ParentID     string `json:"parent_id,omitempty"`
	ManagerID    string `json:"manager_id,omitempty"`
	CostCenterID string `json:"cost_center_id,omitempty"`
	IsActive     *bool  `json:"is_active,omitempty"`
	ValidFrom    string `json:"valid_from"`
	ValidTo      string `json:"valid_to,omitempty"`
}

// OrgUnitNode is used for tree representation
type OrgUnitNode struct {
	OrgUnit
	Children []*OrgUnitNode `json:"children,omitempty"`
}
