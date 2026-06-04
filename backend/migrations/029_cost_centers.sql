-- ============================================================
-- SwiftAI ERP - Cost Centers
-- ============================================================

CREATE TABLE IF NOT EXISTS cost_centers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    cost_center_id  VARCHAR(20) NOT NULL,                -- e.g. "CC-1001"
    description     VARCHAR(255) NOT NULL,               -- cost center name
    cost_center_type VARCHAR(100) NOT NULL DEFAULT '',   -- Admin, Production, R&D, etc. (free text)
    is_active       BOOLEAN NOT NULL DEFAULT true,
    valid_from      DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to        DATE,                                -- NULL = indefinitely valid
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, cost_center_id)
);

CREATE INDEX IF NOT EXISTS idx_cost_centers_tenant ON cost_centers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_cost_centers_active ON cost_centers(tenant_id, is_active);

CREATE TRIGGER trg_cost_centers_updated
    BEFORE UPDATE ON cost_centers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE  cost_centers            IS 'Cost centers for financial accounting';
COMMENT ON COLUMN cost_centers.cost_center_id  IS 'User-facing cost center code, e.g. CC-1001';
COMMENT ON COLUMN cost_centers.description     IS 'Cost center name / description';
COMMENT ON COLUMN cost_centers.cost_center_type IS 'Free-text type: Admin, Production, R&D, etc.';
COMMENT ON COLUMN cost_centers.valid_from      IS 'Validity period start';
COMMENT ON COLUMN cost_centers.valid_to        IS 'Validity period end (NULL = open)';
