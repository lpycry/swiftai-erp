-- Tax Jurisdiction Rules (Product Category × Tax Code mapping)
-- Each row links a product tax category to a jurisdictional tax rule.
CREATE TABLE IF NOT EXISTS tax_jurisdiction_rules (
    rule_id            SERIAL PRIMARY KEY,
    tenant_id          UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    jurisdiction_code  VARCHAR(50) NOT NULL,
    state_code         VARCHAR(2) NOT NULL,
    tax_category_code  VARCHAR(10) NOT NULL,
    is_taxable         BOOLEAN NOT NULL DEFAULT true,
    base_rate          DECIMAL(6,4) NOT NULL DEFAULT 0.0000,
    condition_type     VARCHAR(20) NOT NULL DEFAULT 'NONE',
    condition_value    DECIMAL(15,2) DEFAULT NULL,
    effective_from     DATE NOT NULL,
    effective_to       DATE DEFAULT NULL,
    updated_by         VARCHAR(50) NOT NULL DEFAULT '',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tax_jur_rules_tenant ON tax_jurisdiction_rules(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tax_jur_rules_lookup ON tax_jurisdiction_rules(jurisdiction_code, tax_category_code, effective_from);

COMMENT ON TABLE tax_jurisdiction_rules IS 'Product tax category × jurisdiction rule mapping';
COMMENT ON COLUMN tax_jurisdiction_rules.jurisdiction_code IS 'e.g. CA_MILPITAS, TX_STATE';
COMMENT ON COLUMN tax_jurisdiction_rules.state_code IS '2-letter US state code';
COMMENT ON COLUMN tax_jurisdiction_rules.tax_category_code IS 'Product tax code, e.g. STANDARD, REDUCED, ZERO, EXEMPT, SERVICE';
COMMENT ON COLUMN tax_jurisdiction_rules.is_taxable IS 'Whether this category is taxable in this jurisdiction';
COMMENT ON COLUMN tax_jurisdiction_rules.base_rate IS 'Base tax rate (decimal), e.g. 0.0975 = 9.75%';
COMMENT ON COLUMN tax_jurisdiction_rules.condition_type IS 'THRESHOLD, FLAT, or NONE';
COMMENT ON COLUMN tax_jurisdiction_rules.condition_value IS 'Threshold/flat amount for condition_type';
COMMENT ON COLUMN tax_jurisdiction_rules.effective_from IS 'Start date of this rule';
COMMENT ON COLUMN tax_jurisdiction_rules.effective_to IS 'End date (NULL = currently active)';
COMMENT ON COLUMN tax_jurisdiction_rules.updated_by IS 'User who last updated this rule';
