package models

import (
	"time"

	"github.com/google/uuid"
)

// ---- Authorization Objects ----

type AuthObject struct {
	ID          uuid.UUID `json:"id"`
	ObjectClass string    `json:"object_class"`
	ObjectCode  string    `json:"object_code"`
	Description string    `json:"description,omitempty"`
	Activities  []string  `json:"activities"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type AuthObjectField struct {
	ID           uuid.UUID `json:"id"`
	AuthObjectID uuid.UUID `json:"auth_object_id"`
	FieldName    string    `json:"field_name"`
	FieldLabel   string    `json:"field_label"`
	FieldType    string    `json:"field_type"`
	IsRequired   bool      `json:"is_required"`
	DisplayOrder int       `json:"display_order"`
}

// ---- Role Master (Enhanced) ----

type RoleMaster struct {
	ID           uuid.UUID  `json:"id"`
	TenantID     uuid.UUID  `json:"tenant_id"`
	RoleID       string     `json:"role_id"`
	Description  string     `json:"description,omitempty"`
	RoleType     string     `json:"role_type"`
	RoleCategory string     `json:"role_category,omitempty"`
	ParentRoleID *uuid.UUID `json:"parent_role_id,omitempty"`
	InheritLevel int        `json:"inherit_level"`
	IsSystem     bool       `json:"is_system"`
	IsActive     bool       `json:"is_active"`
	ValidFrom    *time.Time `json:"valid_from,omitempty"`
	ValidTo      *time.Time `json:"valid_to,omitempty"`
	CreatedBy    *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

// ---- Admin User Management ----

type AdminUser struct {
	ID           uuid.UUID    `json:"id"`
	TenantID     uuid.UUID    `json:"tenant_id"`
	Email        string       `json:"email"`
	DisplayName  string       `json:"display_name"`
	Phone        string       `json:"phone,omitempty"`
	AvatarURL    string       `json:"avatar_url,omitempty"`
	IsActive     bool         `json:"is_active"`
	IsMFAEnabled bool         `json:"is_mfa_enabled"`
	LastLoginAt  *time.Time   `json:"last_login_at,omitempty"`
	CreatedAt    time.Time    `json:"created_at"`
	UpdatedAt    time.Time    `json:"updated_at"`
	Roles        []RoleMaster `json:"roles"`
}

// ---- Role Authorization Values ----

type RoleAuthValue struct {
	ID               uuid.UUID             `json:"id"`
	RoleID           uuid.UUID             `json:"role_id"`
	AuthObjectID     uuid.UUID             `json:"auth_object_id"`
	ActivityCreate   bool                  `json:"activity_create"`
	ActivityRead     bool                  `json:"activity_read"`
	ActivityUpdate   bool                  `json:"activity_update"`
	ActivityDelete   bool                  `json:"activity_delete"`
	ActivityApprove  bool                  `json:"activity_approve"`
	ActivityPrint    bool                  `json:"activity_print"`
	ActivityTransfer bool                  `json:"activity_transfer"`
	ActivityClose    bool                  `json:"activity_close"`
	FieldValues      map[string]string     `json:"field_values"`
	FieldRanges      map[string]FieldRange `json:"field_ranges"`
}

type FieldRange struct {
	From string `json:"from"`
	To   string `json:"to"`
}

// ---- User Role Assignment ----

type UserRoleAssignment struct {
	ID             uuid.UUID  `json:"id"`
	UserID         uuid.UUID  `json:"user_id"`
	RoleID         uuid.UUID  `json:"role_id"`
	AssignmentType string     `json:"assignment_type"`
	ValidFrom      time.Time  `json:"valid_from"`
	ValidTo        *time.Time `json:"valid_to,omitempty"`
	IsActive       bool       `json:"is_active"`
}

// ---- Org Units ----

type OrgUnit struct {
	ID        uuid.UUID  `json:"id"`
	TenantID  uuid.UUID  `json:"tenant_id"`
	ParentID  *uuid.UUID `json:"parent_id,omitempty"`
	OrgCode   string     `json:"org_code"`
	OrgName   string     `json:"org_name"`
	OrgType   string     `json:"org_type"`
	IsActive  bool       `json:"is_active"`
	Level     int        `json:"level"`
	Path      string     `json:"path"`
	ManagerID *uuid.UUID `json:"manager_id,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

// ---- Permission Check ----

// PermissionCheckRequest is what endpoints send to verify access.
type PermissionCheckRequest struct {
	UserID   string            `json:"user_id"`
	TenantID string            `json:"tenant_id"`
	Object   string            `json:"object"`           // F_GL_POST
	Activity string            `json:"activity"`         // create
	Fields   map[string]string `json:"fields,omitempty"` // company_code=1000
}

type PermissionCheckResult struct {
	Granted      bool              `json:"granted"`
	MatchedBy    string            `json:"matched_by,omitempty"`    // role_id that granted
	UnmatchedReq map[string]string `json:"unmatched_req,omitempty"` // fields not satisfied
}

// ---- SoD ----

type SoDRule struct {
	ID           uuid.UUID `json:"id"`
	TenantID     uuid.UUID `json:"tenant_id"`
	RuleCode     string    `json:"rule_code"`
	Description  string    `json:"description"`
	Severity     string    `json:"severity"`
	RiskCategory string    `json:"risk_category"`
	ObjectAID    uuid.UUID `json:"object_a_id"`
	ActivityA    string    `json:"activity_a"`
	ObjectBID    uuid.UUID `json:"object_b_id"`
	ActivityB    string    `json:"activity_b"`
	IsActive     bool      `json:"is_active"`
}
