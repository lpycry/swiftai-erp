-- Tax Categories (master data for product tax classification codes)
CREATE TABLE IF NOT EXISTS tax_categories (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id    UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code         VARCHAR(4) NOT NULL,
    description  TEXT NOT NULL DEFAULT '',
    example      TEXT NOT NULL DEFAULT '',
    is_active    BOOLEAN NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tax_categories_code_tenant ON tax_categories(tenant_id, code);

COMMENT ON TABLE tax_categories IS 'Product tax classification codes (e.g. STANDARD, REDUCED, ZERO, EXEMPT, SERVICE)';
COMMENT ON COLUMN tax_categories.code IS 'Tax category code, max 4 characters';
COMMENT ON COLUMN tax_categories.description IS 'Description of the tax category';
COMMENT ON COLUMN tax_categories.example IS 'Example products or use cases for this category';

-- Seed default tax categories
INSERT INTO tax_categories (id, tenant_id, code, description, example, is_active) VALUES
    (uuid_generate_v4(), (SELECT id FROM tenants LIMIT 1), 'STD', 'Standard rate', 'General merchandise, electronics, clothing', true),
    (uuid_generate_v4(), (SELECT id FROM tenants LIMIT 1), 'RED', 'Reduced rate', 'Groceries, utilities, medical supplies', true),
    (uuid_generate_v4(), (SELECT id FROM tenants LIMIT 1), 'ZER', 'Zero rate', 'Exported goods, basic food items', true),
    (uuid_generate_v4(), (SELECT id FROM tenants LIMIT 1), 'EXP', 'Exempt', 'Government sales, non-profit, education', true),
    (uuid_generate_v4(), (SELECT id FROM tenants LIMIT 1), 'SRV', 'Service', 'Consulting, repair, professional services', true)
ON CONFLICT DO NOTHING;
