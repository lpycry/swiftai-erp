-- ============================================================
-- SwiftAI ERP - Employee Master Data (SAP Infotype Pattern)
-- ============================================================

-- ============================================================
-- 1. POSITIONS (Organizational Positions)
-- Linked to organization_units for department inheritance
-- ============================================================
CREATE TABLE IF NOT EXISTS positions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    position_code   VARCHAR(20) NOT NULL,                -- e.g. "P-1001"
    position_title  VARCHAR(255) NOT NULL,
    org_unit_id     UUID REFERENCES organization_units(id) ON DELETE SET NULL,  -- inheritable department
    parent_position_id UUID REFERENCES positions(id) ON DELETE SET NULL,       -- hierarchy
    is_active       BOOLEAN NOT NULL DEFAULT true,
    valid_from      DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to        DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, position_code)
);
CREATE INDEX IF NOT EXISTS idx_positions_tenant ON positions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_positions_org ON positions(org_unit_id);
CREATE INDEX IF NOT EXISTS idx_positions_parent ON positions(parent_position_id);
CREATE TRIGGER trg_positions_updated BEFORE UPDATE ON positions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 2. EMPLOYEE_BASE (Immutable identity)
-- ============================================================
CREATE TABLE IF NOT EXISTS employee_base (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    employee_code   VARCHAR(20) NOT NULL,                -- e.g. "EMP-0001"
    legal_name      VARCHAR(255) NOT NULL,
    tax_id          VARCHAR(50),                         -- encrypted storage in production
    date_of_birth   DATE,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, employee_code)
);
CREATE INDEX IF NOT EXISTS idx_emp_base_tenant ON employee_base(tenant_id);
CREATE TRIGGER trg_employee_base_updated BEFORE UPDATE ON employee_base
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 3. EMPLOYEE_DATA_HISTORY (SAP Infotype pattern)
-- All time-variant data stored with valid_from/valid_to
-- ============================================================
CREATE TABLE IF NOT EXISTS employee_data_history (
    record_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id     UUID NOT NULL REFERENCES employee_base(id) ON DELETE CASCADE,
    infotype_code   VARCHAR(30) NOT NULL,               -- POS_ASSIGN, SALARY, ADDRESS, CONTACT, etc.
    data_payload    JSONB NOT NULL DEFAULT '{}',
    valid_from      DATE NOT NULL,
    valid_to        DATE NOT NULL DEFAULT '9999-12-31',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_edh_employee ON employee_data_history(employee_id);
CREATE INDEX IF NOT EXISTS idx_edh_infotype ON employee_data_history(employee_id, infotype_code);
CREATE INDEX IF NOT EXISTS idx_edh_valid ON employee_data_history(employee_id, infotype_code, valid_from, valid_to);
CREATE TRIGGER trg_employee_data_history_updated BEFORE UPDATE ON employee_data_history
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 4. VIEW: Current employee data (simplifies queries)
-- ============================================================
CREATE OR REPLACE VIEW v_employee_current AS
SELECT
    eb.id AS employee_id,
    eb.employee_code,
    eb.legal_name,
    eb.tax_id,
    eb.date_of_birth,
    eb.is_active,

    -- Position assignment (current infotype)
    pos_data.data_payload->>'position_id' AS position_id,
    pos_data.data_payload->>'job_title' AS job_title,
    po.position_code,
    po.position_title,
    po.org_unit_id,
    ou.unit_code AS dept_code,
    ou.unit_name AS dept_name,
    ou.cost_center_id,

    -- Salary (current infotype)
    sal_data.data_payload->>'salary_amount' AS salary_amount,
    sal_data.data_payload->>'salary_currency' AS salary_currency,
    sal_data.data_payload->>'pay_frequency' AS pay_frequency,

    -- Validity
    pos_data.valid_from AS pos_valid_from,
    pos_data.valid_to   AS pos_valid_to

FROM employee_base eb
LEFT JOIN employee_data_history pos_data
    ON pos_data.employee_id = eb.id
    AND pos_data.infotype_code = 'POS_ASSIGN'
    AND CURRENT_DATE BETWEEN pos_data.valid_from AND pos_data.valid_to
LEFT JOIN positions po ON po.id = (pos_data.data_payload->>'position_id')::uuid
LEFT JOIN organization_units ou ON ou.id = po.org_unit_id
LEFT JOIN employee_data_history sal_data
    ON sal_data.employee_id = eb.id
    AND sal_data.infotype_code = 'SALARY'
    AND CURRENT_DATE BETWEEN sal_data.valid_from AND sal_data.valid_to;

COMMENT ON TABLE  employee_base           IS 'Immutable employee identity';
COMMENT ON TABLE  employee_data_history   IS 'Time-based employee data (SAP Infotype pattern)';
COMMENT ON COLUMN employee_data_history.infotype_code IS 'Data category: POS_ASSIGN, SALARY, ADDRESS, CONTACT, EDUCATION, etc.';
COMMENT ON COLUMN employee_data_history.data_payload  IS 'JSONB: all fields specific to the infotype';
COMMENT ON TABLE  positions               IS 'Organizational positions linked to org units';
