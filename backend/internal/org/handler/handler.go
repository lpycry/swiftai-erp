package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	orgmodels "github.com/swiftai-erp/backend/internal/org/models"
	"github.com/swiftai-erp/backend/internal/org/repository"
	"github.com/swiftai-erp/backend/pkg/response"
)

type OrgHandler struct {
	repo *repository.OrgRepo
}

func NewOrgHandler(repo *repository.OrgRepo) *OrgHandler {
	return &OrgHandler{repo: repo}
}

// ==================== Organizations ====================

// CreateOrg handles POST /api/v1/orgs
func (h *OrgHandler) CreateOrg(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req orgmodels.CreateOrganizationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	currency := req.Currency
	if currency == "" {
		currency = "USD"
	}

	now := time.Now()
	org := &orgmodels.Organization{
		ID:        uuid.New(),
		TenantID:  tenantID,
		OrgCode:   req.OrgCode,
		OrgName:   req.OrgName,
		Currency:  currency,
		TaxID:     req.TaxID,
		TaxConfig: req.TaxConfig,
		Email:     req.Email,
		Phone:     req.Phone,
		Website:   req.Website,
		Address:   req.Address,
		IsActive:  true,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if org.TaxConfig == nil {
		org.TaxConfig = make(map[string]interface{})
	}

	if err := h.repo.CreateOrg(c.Request.Context(), org); err != nil {
		log.Err(err).Msg("create organization failed")
		response.InternalError(c, "failed to create organization")
		return
	}

	response.Created(c, org)
}

// ListOrgs handles GET /api/v1/orgs
func (h *OrgHandler) ListOrgs(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	search := c.Query("search")

	orgs, err := h.repo.ListOrgsFiltered(c.Request.Context(), tenantID, search)
	if err != nil {
		log.Err(err).Msg("list organizations failed")
		response.InternalError(c, "failed to list organizations")
		return
	}

	response.OK(c, orgs)
}

// GetOrg handles GET /api/v1/orgs/:id
func (h *OrgHandler) GetOrg(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	orgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid organization id")
		return
	}

	org, err := h.repo.GetOrgWithSites(c.Request.Context(), orgID, tenantID)
	if err != nil {
		log.Err(err).Msg("get organization failed")
		response.InternalError(c, "failed to get organization")
		return
	}
	if org == nil {
		response.NotFound(c, "organization not found")
		return
	}

	response.OK(c, org)
}

// UpdateOrg handles PUT /api/v1/orgs/:id
func (h *OrgHandler) UpdateOrg(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	orgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid organization id")
		return
	}

	var req orgmodels.UpdateOrganizationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	org, err := h.repo.UpdateOrg(c.Request.Context(), orgID, tenantID, &req)
	if err != nil {
		log.Err(err).Msg("update organization failed")
		response.InternalError(c, "failed to update organization")
		return
	}
	if org == nil {
		response.NotFound(c, "organization not found")
		return
	}

	response.OK(c, org)
}

// DeleteOrg handles DELETE /api/v1/orgs/:id
func (h *OrgHandler) DeleteOrg(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	orgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid organization id")
		return
	}

	if err := h.repo.DeleteOrg(c.Request.Context(), orgID, tenantID); err != nil {
		response.InternalError(c, err.Error())
		return
	}

	response.OK(c, gin.H{"message": "organization deactivated"})
}

// ==================== Sites ====================

// CreateSite handles POST /api/v1/sites
func (h *OrgHandler) CreateSite(c *gin.Context) {
	var req orgmodels.CreateSiteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	siteType := req.SiteType
	if siteType == "" {
		siteType = "warehouse"
	}

	now := time.Now()
	site := &orgmodels.Site{
		ID:             uuid.New(),
		OrganizationID: req.OrganizationID,
		SiteCode:       req.SiteCode,
		SiteName:       req.SiteName,
		SiteType:       siteType,
		Address:        req.Address,
		IsActive:       true,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := h.repo.CreateSite(c.Request.Context(), site); err != nil {
		log.Err(err).Msg("create site failed")
		response.InternalError(c, "failed to create site")
		return
	}

	response.Created(c, site)
}

// ListSites handles GET /api/v1/orgs/:id/sites
func (h *OrgHandler) ListSites(c *gin.Context) {
	orgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid organization id")
		return
	}

	sites, err := h.repo.ListSites(c.Request.Context(), orgID)
	if err != nil {
		log.Err(err).Msg("list sites failed")
		response.InternalError(c, "failed to list sites")
		return
	}

	response.OK(c, sites)
}

// GetAllSites handles GET /api/v1/sites (all sites across all orgs for this tenant)
func (h *OrgHandler) GetAllSites(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	sites, err := h.repo.ListSitesByTenant(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list all sites failed")
		response.InternalError(c, "failed to list sites")
		return
	}

	response.OK(c, sites)
}

// GetSite handles GET /api/v1/sites/:id
func (h *OrgHandler) GetSite(c *gin.Context) {
	siteID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid site id")
		return
	}

	site, err := h.repo.GetSiteByID(c.Request.Context(), siteID)
	if err != nil {
		log.Err(err).Msg("get site failed")
		response.InternalError(c, "failed to get site")
		return
	}
	if site == nil {
		response.NotFound(c, "site not found")
		return
	}

	response.OK(c, site)
}

// UpdateSite handles PUT /api/v1/sites/:id
func (h *OrgHandler) UpdateSite(c *gin.Context) {
	siteID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid site id")
		return
	}

	var req orgmodels.UpdateSiteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{
			Field:   "body",
			Message: err.Error(),
		})
		return
	}

	site, err := h.repo.UpdateSite(c.Request.Context(), siteID, &req)
	if err != nil {
		log.Err(err).Msg("update site failed")
		response.InternalError(c, "failed to update site")
		return
	}
	if site == nil {
		response.NotFound(c, "site not found")
		return
	}

	response.OK(c, site)
}

// DeleteSite handles DELETE /api/v1/sites/:id
func (h *OrgHandler) DeleteSite(c *gin.Context) {
	siteID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid site id")
		return
	}

	if err := h.repo.DeleteSite(c.Request.Context(), siteID); err != nil {
		log.Err(err).Msg("delete site failed")
		response.InternalError(c, "failed to delete site")
		return
	}

	response.OK(c, gin.H{"message": "site deleted"})
}

// ==================== Helpers ====================

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tenantIDStr := c.GetString("tenant_id")
	if tenantIDStr == "" {
		return uuid.Nil, http.ErrNoLocation
	}
	return uuid.Parse(tenantIDStr)
}
