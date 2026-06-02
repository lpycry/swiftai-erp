-- Tax Jurisdictions (Sales Tax Rates)
CREATE TABLE IF NOT EXISTS tax_jurisdictions (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id        UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    state            VARCHAR(50) NOT NULL,
    county           VARCHAR(100) NOT NULL DEFAULT '',
    city             VARCHAR(100) NOT NULL DEFAULT '',
    zip_code         VARCHAR(10) NOT NULL DEFAULT '',
    tax_rate         NUMERIC(6,4) NOT NULL,
    effective_date   DATE NOT NULL,
    expiration_date  DATE DEFAULT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tax_jurisdictions_tenant ON tax_jurisdictions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tax_jurisdictions_state ON tax_jurisdictions(tenant_id, state);
CREATE INDEX IF NOT EXISTS idx_tax_jurisdictions_active ON tax_jurisdictions(tenant_id, is_active) WHERE is_active = true;

-- Tax Nexus
CREATE TABLE IF NOT EXISTS tax_nexus (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id        UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    state            VARCHAR(100) NOT NULL,
    nexus_type       VARCHAR(30) NOT NULL CHECK (nexus_type IN ('PHYSICAL','ECONOMIC')),
    sub_type         VARCHAR(30) NOT NULL DEFAULT '',
    threshold_amount NUMERIC(12,2) DEFAULT NULL,
    effective_date   DATE NOT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tax_nexus_tenant ON tax_nexus(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tax_nexus_state ON tax_nexus(tenant_id, state);

-- Triggers
CREATE OR REPLACE FUNCTION update_tax_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tax_jurisdictions_updated ON tax_jurisdictions;
CREATE TRIGGER trg_tax_jurisdictions_updated
    BEFORE UPDATE ON tax_jurisdictions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_tax_nexus_updated ON tax_nexus;
CREATE TRIGGER trg_tax_nexus_updated
    BEFORE UPDATE ON tax_nexus
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE tax_jurisdictions IS 'Sales tax rates by jurisdiction';
COMMENT ON TABLE tax_nexus IS 'Tax nexus (physical / economic) by state';
