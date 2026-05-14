-- ============================================================
-- SwiftAI ERP - Organizational Structure
-- Phase: Org Management (Tenant > Company > Business Unit)
-- Design: Flat hierarchy + Event-driven data structure
-- ============================================================

-- ============================================================
-- 1. ORGANIZATIONS (Legal Entities / Company Codes)
--    独立核算主体，拥有独立资产负债表、本位币、税号
-- ============================================================
CREATE TABLE IF NOT EXISTS organizations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    org_code        VARCHAR(20) NOT NULL,           -- company code: "1000", "2000"
    org_name        VARCHAR(255) NOT NULL,           -- legal entity name
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    tax_id          VARCHAR(50),                     -- tax registration number
    tax_config      JSONB NOT NULL DEFAULT '{}',     -- tax regime configuration
    address         TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, org_code)
);

CREATE INDEX IF NOT EXISTS idx_org_tenant ON organizations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_org_active ON organizations(tenant_id, is_active) WHERE is_active = true;

-- ============================================================
-- 2. SITES (Business Units / Physical Locations)
--    工厂、仓库、门店 - 库存、生产和销售发生的具体地点
-- ============================================================
CREATE TABLE IF NOT EXISTS sites (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_code       VARCHAR(20) NOT NULL,           -- "WH01", "PLANT01", "STORE01"
    site_name       VARCHAR(255) NOT NULL,
    site_type       VARCHAR(20) NOT NULL DEFAULT 'warehouse',  -- warehouse, plant, store, office
    address         TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id, site_code)
);

CREATE INDEX IF NOT EXISTS idx_sites_org ON sites(organization_id);
CREATE INDEX IF NOT EXISTS idx_sites_type ON sites(organization_id, site_type);

-- ============================================================
-- 3. TRIGGERS
-- ============================================================
CREATE TRIGGER trg_organizations_updated
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_sites_updated
    BEFORE UPDATE ON sites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 4. COMMENTS
-- ============================================================
COMMENT ON TABLE organizations IS 'Legal entities / company codes with independent accounting';
COMMENT ON COLUMN organizations.currency IS 'Base currency for this legal entity';
COMMENT ON COLUMN organizations.tax_config IS 'Tax regime config (JSON) for AI auto-tax calculation';
COMMENT ON TABLE sites IS 'Physical business units: warehouses, plants, stores';
COMMENT ON COLUMN sites.site_type IS 'Type: warehouse, plant, store, office';
