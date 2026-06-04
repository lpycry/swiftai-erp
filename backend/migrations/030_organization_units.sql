-- ============================================================
-- SwiftAI ERP - Organization Units (Departments)
-- Administrative hierarchy with cost center binding
-- ============================================================

CREATE TABLE IF NOT EXISTS organization_units (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    unit_code       VARCHAR(20) NOT NULL,                -- e.g. "D-1001", "G-2001"
    unit_name       VARCHAR(255) NOT NULL,               -- department/group name
    parent_id       UUID REFERENCES organization_units(id) ON DELETE SET NULL, -- tree hierarchy
    manager_id      VARCHAR(50),                          -- employee ID (e.g. EMP-001)
    cost_center_id  VARCHAR(20),                         -- hard bind: cost_center_id from cost_centers table
    is_active       BOOLEAN NOT NULL DEFAULT true,
    valid_from      DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to        DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, unit_code)
);

CREATE INDEX IF NOT EXISTS idx_org_unit_tenant ON organization_units(tenant_id);
CREATE INDEX IF NOT EXISTS idx_org_unit_parent ON organization_units(parent_id);
CREATE INDEX IF NOT EXISTS idx_org_unit_active ON organization_units(tenant_id, is_active);

CREATE TRIGGER trg_organization_units_updated
    BEFORE UPDATE ON organization_units
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE  organization_units            IS 'Organizational units (departments/groups) for administrative hierarchy';
COMMENT ON COLUMN organization_units.unit_code   IS 'User-facing code, e.g. D-1001';
COMMENT ON COLUMN organization_units.unit_name   IS 'Department or group name';
COMMENT ON COLUMN organization_units.parent_id   IS 'Parent unit for multi-level hierarchy (company → dept → group)';
COMMENT ON COLUMN organization_units.manager_id  IS 'Unit manager (future FK to employees)';
COMMENT ON COLUMN organization_units.cost_center_id IS 'Bound cost center for financial routing';
COMMENT ON COLUMN organization_units.valid_from  IS 'Validity period start';
COMMENT ON COLUMN organization_units.valid_to    IS 'Validity period end (NULL = open)';
