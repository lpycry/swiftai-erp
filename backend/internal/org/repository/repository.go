package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	orgmodels "github.com/swiftai-erp/backend/internal/org/models"
)

// OrgRepo handles organization and site CRUD.
type OrgRepo struct {
	db *pgxpool.Pool
}

func NewOrgRepo(db *pgxpool.Pool) *OrgRepo {
	return &OrgRepo{db: db}
}

// ── Organizations ──

const orgSelectCols = `id, tenant_id, org_code, org_name, currency,
	COALESCE(tax_id,'') as tax_id, tax_config,
	COALESCE(email,'') as email,
	COALESCE(phone,'') as phone,
	COALESCE(website,'') as website,
	COALESCE(address,'') as address,
	is_active, created_at, updated_at`

func (r *OrgRepo) CreateOrg(ctx context.Context, org *orgmodels.Organization) error {
	query := `
		INSERT INTO organizations (id, tenant_id, org_code, org_name, currency, tax_id, tax_config, email, phone, website, address, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
	`
	_, err := r.db.Exec(ctx, query,
		org.ID, org.TenantID, org.OrgCode, org.OrgName, org.Currency,
		org.TaxID, org.TaxConfig, org.Email, org.Phone, org.Website,
		org.Address, org.IsActive,
		org.CreatedAt, org.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create organization: %w", err)
	}
	return nil
}

func (r *OrgRepo) GetOrgByID(ctx context.Context, id, tenantID uuid.UUID) (*orgmodels.Organization, error) {
	query := `SELECT ` + orgSelectCols + ` FROM organizations WHERE id = $1 AND tenant_id = $2`
	org := &orgmodels.Organization{}
	err := r.db.QueryRow(ctx, query, id, tenantID).Scan(
		&org.ID, &org.TenantID, &org.OrgCode, &org.OrgName, &org.Currency,
		&org.TaxID, &org.TaxConfig, &org.Email, &org.Phone, &org.Website,
		&org.Address,
		&org.IsActive, &org.CreatedAt, &org.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get organization: %w", err)
	}
	return org, nil
}

func (r *OrgRepo) ListOrgs(ctx context.Context, tenantID uuid.UUID) ([]*orgmodels.Organization, error) {
	return r.ListOrgsFiltered(ctx, tenantID, "")
}

func (r *OrgRepo) ListOrgsFiltered(ctx context.Context, tenantID uuid.UUID, search string) ([]*orgmodels.Organization, error) {
	var query string
	var rows pgx.Rows
	var err error

	if search == "" {
		query = `SELECT ` + orgSelectCols + ` FROM organizations WHERE tenant_id = $1 ORDER BY org_code`
		rows, err = r.db.Query(ctx, query, tenantID)
	} else {
		query = `SELECT ` + orgSelectCols + ` FROM organizations WHERE tenant_id = $1 AND (org_code ILIKE $2 OR org_name ILIKE $2) ORDER BY org_code`
		like := "%" + search + "%"
		rows, err = r.db.Query(ctx, query, tenantID, like)
	}
	if err != nil {
		return nil, fmt.Errorf("list organizations: %w", err)
	}
	defer rows.Close()
	return scanOrgs(rows)
}

func (r *OrgRepo) UpdateOrg(ctx context.Context, id, tenantID uuid.UUID, req *orgmodels.UpdateOrganizationRequest) (*orgmodels.Organization, error) {
	setClauses := make([]string, 0, 6)
	args := []interface{}{}
	argIdx := 1

	if req.OrgName != "" {
		setClauses = append(setClauses, fmt.Sprintf("org_name = $%d", argIdx))
		args = append(args, req.OrgName)
		argIdx++
	}
	if req.Currency != "" {
		setClauses = append(setClauses, fmt.Sprintf("currency = $%d", argIdx))
		args = append(args, req.Currency)
		argIdx++
	}
	if req.TaxID != "" {
		setClauses = append(setClauses, fmt.Sprintf("tax_id = $%d", argIdx))
		args = append(args, req.TaxID)
		argIdx++
	}
	if req.TaxConfig != nil {
		setClauses = append(setClauses, fmt.Sprintf("tax_config = $%d", argIdx))
		args = append(args, req.TaxConfig)
		argIdx++
	}
	if req.Email != "" {
		setClauses = append(setClauses, fmt.Sprintf("email = $%d", argIdx))
		args = append(args, req.Email)
		argIdx++
	}
	if req.Phone != "" {
		setClauses = append(setClauses, fmt.Sprintf("phone = $%d", argIdx))
		args = append(args, req.Phone)
		argIdx++
	}
	if req.Website != "" {
		setClauses = append(setClauses, fmt.Sprintf("website = $%d", argIdx))
		args = append(args, req.Website)
		argIdx++
	}
	if req.Address != "" {
		setClauses = append(setClauses, fmt.Sprintf("address = $%d", argIdx))
		args = append(args, req.Address)
		argIdx++
	}
	if req.IsActive != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_active = $%d", argIdx))
		args = append(args, *req.IsActive)
		argIdx++
	}

	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now())
	argIdx++

	args = append(args, id, tenantID)

	query := fmt.Sprintf(`
		UPDATE organizations SET %s
		WHERE id = $%d AND tenant_id = $%d
		RETURNING `+orgSelectCols+`
	`, joinClauses(setClauses, ", "), argIdx, argIdx+1)

	if len(setClauses) <= 1 {
		return r.GetOrgByID(ctx, id, tenantID)
	}

	org := &orgmodels.Organization{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&org.ID, &org.TenantID, &org.OrgCode, &org.OrgName, &org.Currency,
		&org.TaxID, &org.TaxConfig, &org.Email, &org.Phone, &org.Website,
		&org.Address,
		&org.IsActive, &org.CreatedAt, &org.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("update organization: %w", err)
	}
	return org, nil
}

func (r *OrgRepo) DeleteOrg(ctx context.Context, id, tenantID uuid.UUID) error {
	// Check if org has sites
	var siteCount int
	err := r.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM sites WHERE organization_id = $1", id,
	).Scan(&siteCount)
	if err != nil {
		return fmt.Errorf("check sites: %w", err)
	}
	if siteCount > 0 {
		return fmt.Errorf("cannot deactivate organization with %d active site(s)", siteCount)
	}

	_, err = r.db.Exec(ctx,
		"UPDATE organizations SET is_active = false, updated_at = $1 WHERE id = $2 AND tenant_id = $3",
		time.Now(), id, tenantID,
	)
	if err != nil {
		return fmt.Errorf("deactivate organization: %w", err)
	}
	return nil
}

// ── Sites ──

const siteSelectCols = `id, organization_id, site_code, site_name, site_type,
	COALESCE(address,'') as address,
	is_active, created_at, updated_at`

func (r *OrgRepo) CreateSite(ctx context.Context, site *orgmodels.Site) error {
	query := `
		INSERT INTO sites (id, organization_id, site_code, site_name, site_type, address, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	_, err := r.db.Exec(ctx, query,
		site.ID, site.OrganizationID, site.SiteCode, site.SiteName,
		site.SiteType, site.Address, site.IsActive,
		site.CreatedAt, site.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create site: %w", err)
	}
	return nil
}

func (r *OrgRepo) GetSiteByID(ctx context.Context, id uuid.UUID) (*orgmodels.Site, error) {
	query := `SELECT ` + siteSelectCols + ` FROM sites WHERE id = $1`
	site := &orgmodels.Site{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&site.ID, &site.OrganizationID, &site.SiteCode, &site.SiteName, &site.SiteType,
		&site.Address, &site.IsActive, &site.CreatedAt, &site.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get site: %w", err)
	}
	return site, nil
}

func (r *OrgRepo) ListSites(ctx context.Context, orgID uuid.UUID) ([]*orgmodels.Site, error) {
	query := `SELECT ` + siteSelectCols + ` FROM sites WHERE organization_id = $1 ORDER BY site_code`
	rows, err := r.db.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("list sites: %w", err)
	}
	defer rows.Close()
	return scanSites(rows)
}

func (r *OrgRepo) ListSitesByTenant(ctx context.Context, tenantID uuid.UUID) ([]*orgmodels.Site, error) {
	query := `SELECT s.id, s.organization_id, s.site_code, s.site_name, s.site_type,
		COALESCE(s.address,'') as address,
		s.is_active, s.created_at, s.updated_at
		FROM sites s
		INNER JOIN organizations o ON o.id = s.organization_id
		WHERE o.tenant_id = $1 ORDER BY s.site_code`
	rows, err := r.db.Query(ctx, query, tenantID)
	if err != nil {
		return nil, fmt.Errorf("list sites by tenant: %w", err)
	}
	defer rows.Close()
	return scanSites(rows)
}

func (r *OrgRepo) UpdateSite(ctx context.Context, id uuid.UUID, req *orgmodels.UpdateSiteRequest) (*orgmodels.Site, error) {
	setClauses := make([]string, 0, 4)
	args := []interface{}{}
	argIdx := 1

	if req.SiteName != "" {
		setClauses = append(setClauses, fmt.Sprintf("site_name = $%d", argIdx))
		args = append(args, req.SiteName)
		argIdx++
	}
	if req.SiteType != "" {
		setClauses = append(setClauses, fmt.Sprintf("site_type = $%d", argIdx))
		args = append(args, req.SiteType)
		argIdx++
	}
	if req.Address != "" {
		setClauses = append(setClauses, fmt.Sprintf("address = $%d", argIdx))
		args = append(args, req.Address)
		argIdx++
	}
	if req.IsActive != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_active = $%d", argIdx))
		args = append(args, *req.IsActive)
		argIdx++
	}

	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now())
	argIdx++

	args = append(args, id)

	query := fmt.Sprintf(`
		UPDATE sites SET %s
		WHERE id = $%d
		RETURNING `+siteSelectCols+`
	`, joinClauses(setClauses, ", "), argIdx)

	if len(setClauses) <= 1 {
		return r.GetSiteByID(ctx, id)
	}

	site := &orgmodels.Site{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&site.ID, &site.OrganizationID, &site.SiteCode, &site.SiteName, &site.SiteType,
		&site.Address, &site.IsActive, &site.CreatedAt, &site.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("update site: %w", err)
	}
	return site, nil
}

func (r *OrgRepo) DeleteSite(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		"DELETE FROM sites WHERE id = $1", id,
	)
	if err != nil {
		return fmt.Errorf("delete site: %w", err)
	}
	return nil
}

// ── Combined ──

// GetOrgWithSites returns an organization with all its sites.
func (r *OrgRepo) GetOrgWithSites(ctx context.Context, id, tenantID uuid.UUID) (*orgmodels.OrganizationWithSites, error) {
	org, err := r.GetOrgByID(ctx, id, tenantID)
	if err != nil {
		return nil, err
	}
	if org == nil {
		return nil, nil
	}

	sites, err := r.ListSites(ctx, id)
	if err != nil {
		return nil, err
	}

	result := &orgmodels.OrganizationWithSites{
		Organization: *org,
		Sites:        make([]orgmodels.Site, 0),
	}
	for _, s := range sites {
		result.Sites = append(result.Sites, *s)
	}
	return result, nil
}

// ── Scanners ──

func scanOrgs(rows pgx.Rows) ([]*orgmodels.Organization, error) {
	var orgs []*orgmodels.Organization
	for rows.Next() {
		o := &orgmodels.Organization{}
		err := rows.Scan(
			&o.ID, &o.TenantID, &o.OrgCode, &o.OrgName, &o.Currency,
			&o.TaxID, &o.TaxConfig, &o.Email, &o.Phone, &o.Website,
			&o.Address,
			&o.IsActive, &o.CreatedAt, &o.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan organization: %w", err)
		}
		orgs = append(orgs, o)
	}
	return orgs, nil
}

func scanSites(rows pgx.Rows) ([]*orgmodels.Site, error) {
	var sites []*orgmodels.Site
	for rows.Next() {
		s := &orgmodels.Site{}
		err := rows.Scan(
			&s.ID, &s.OrganizationID, &s.SiteCode, &s.SiteName, &s.SiteType,
			&s.Address, &s.IsActive, &s.CreatedAt, &s.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan site: %w", err)
		}
		sites = append(sites, s)
	}
	return sites, nil
}

func joinClauses(clauses []string, sep string) string {
	if len(clauses) == 0 {
		return ""
	}
	result := clauses[0]
	for _, c := range clauses[1:] {
		result += sep + c
	}
	return result
}
