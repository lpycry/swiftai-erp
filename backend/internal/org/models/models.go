package models

import (
	"time"

	"github.com/google/uuid"
)

// ==================== Organization (Company Code) ====================

type Organization struct {
	ID        uuid.UUID              `json:"id"`
	TenantID  uuid.UUID              `json:"tenant_id"`
	OrgCode   string                 `json:"org_code"`
	OrgName   string                 `json:"org_name"`
	Currency  string                 `json:"currency"`
	TaxID     string                 `json:"tax_id,omitempty"`
	TaxConfig map[string]interface{} `json:"tax_config,omitempty"`
	Address   string                 `json:"address,omitempty"`
	IsActive  bool                   `json:"is_active"`
	CreatedAt time.Time              `json:"created_at"`
	UpdatedAt time.Time              `json:"updated_at"`
}

type CreateOrganizationRequest struct {
	OrgCode   string                 `json:"org_code" binding:"required"`
	OrgName   string                 `json:"org_name" binding:"required"`
	Currency  string                 `json:"currency"`
	TaxID     string                 `json:"tax_id,omitempty"`
	TaxConfig map[string]interface{} `json:"tax_config,omitempty"`
	Address   string                 `json:"address,omitempty"`
}

type UpdateOrganizationRequest struct {
	OrgName   string                 `json:"org_name"`
	Currency  string                 `json:"currency"`
	TaxID     string                 `json:"tax_id,omitempty"`
	TaxConfig map[string]interface{} `json:"tax_config,omitempty"`
	Address   string                 `json:"address,omitempty"`
	IsActive  *bool                  `json:"is_active,omitempty"`
}

// ==================== Site (Business Unit) ====================

type Site struct {
	ID             uuid.UUID `json:"id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	SiteCode       string    `json:"site_code"`
	SiteName       string    `json:"site_name"`
	SiteType       string    `json:"site_type"` // warehouse, plant, store, office
	Address        string    `json:"address,omitempty"`
	IsActive       bool      `json:"is_active"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type CreateSiteRequest struct {
	OrganizationID uuid.UUID `json:"organization_id" binding:"required"`
	SiteCode       string    `json:"site_code" binding:"required"`
	SiteName       string    `json:"site_name" binding:"required"`
	SiteType       string    `json:"site_type"`
	Address        string    `json:"address,omitempty"`
}

type UpdateSiteRequest struct {
	SiteName  string `json:"site_name"`
	SiteType  string `json:"site_type"`
	Address   string `json:"address,omitempty"`
	IsActive  *bool  `json:"is_active,omitempty"`
}

// ==================== Response helpers ====================

type OrganizationWithSites struct {
	Organization
	Sites []Site `json:"sites,omitempty"`
}
