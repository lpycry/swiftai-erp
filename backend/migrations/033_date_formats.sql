-- ============================================================
-- SwiftAI ERP - Date Formats (SAP User Profile Style)
-- ============================================================

CREATE TABLE IF NOT EXISTS date_formats (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    format_code     VARCHAR(20) NOT NULL,               -- e.g. "DD_MM_YYYY", "MM_DD_YYYY"
    display_name    VARCHAR(100) NOT NULL,              -- e.g. "DD.MM.YYYY"
    date_pattern    VARCHAR(50) NOT NULL,               -- e.g. "dd.MM.yyyy", "MM/dd/yyyy"
    separator       VARCHAR(5) NOT NULL DEFAULT '.',    -- ., /, -
    example_output  VARCHAR(20),                        -- e.g. "31.12.2026"
    sort_order      INT NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, format_code)
);

CREATE INDEX IF NOT EXISTS idx_date_formats_tenant ON date_formats(tenant_id);
CREATE INDEX IF NOT EXISTS idx_date_formats_active ON date_formats(tenant_id, is_active);

CREATE TRIGGER trg_date_formats_updated
    BEFORE UPDATE ON date_formats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Seed standard SAP date formats
INSERT INTO date_formats (tenant_id, format_code, display_name, date_pattern, separator, example_output, sort_order, is_active)
SELECT t.id, 'DD_MM_YYYY', 'DD.MM.YYYY', 'dd.MM.yyyy', '.', '31.12.2026', 1, true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM date_formats d WHERE d.tenant_id = t.id AND d.format_code = 'DD_MM_YYYY');

INSERT INTO date_formats (tenant_id, format_code, display_name, date_pattern, separator, example_output, sort_order, is_active)
SELECT t.id, 'MM_DD_YYYY', 'MM/DD/YYYY', 'MM/dd/yyyy', '/', '12/31/2026', 2, true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM date_formats d WHERE d.tenant_id = t.id AND d.format_code = 'MM_DD_YYYY');

INSERT INTO date_formats (tenant_id, format_code, display_name, date_pattern, separator, example_output, sort_order, is_active)
SELECT t.id, 'YYYY_MM_DD', 'YYYY-MM-DD', 'yyyy-MM-dd', '-', '2026-12-31', 3, true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM date_formats d WHERE d.tenant_id = t.id AND d.format_code = 'YYYY_MM_DD');

INSERT INTO date_formats (tenant_id, format_code, display_name, date_pattern, separator, example_output, sort_order, is_active)
SELECT t.id, 'DD_MM_YYYY_SLASH', 'DD/MM/YYYY', 'dd/MM/yyyy', '/', '31/12/2026', 4, true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM date_formats d WHERE d.tenant_id = t.id AND d.format_code = 'DD_MM_YYYY_SLASH');

INSERT INTO date_formats (tenant_id, format_code, display_name, date_pattern, separator, example_output, sort_order, is_active)
SELECT t.id, 'YYYYMMDD', 'YYYYMMDD', 'yyyyMMdd', '', '20261231', 5, true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM date_formats d WHERE d.tenant_id = t.id AND d.format_code = 'YYYYMMDD');

COMMENT ON TABLE  date_formats              IS 'SAP-style date format definitions';
COMMENT ON COLUMN date_formats.format_code  IS 'Internal code (DD_MM_YYYY, MM_DD_YYYY, etc.)';
COMMENT ON COLUMN date_formats.display_name IS 'Human-readable format name';
COMMENT ON COLUMN date_formats.date_pattern IS 'Intl/Java date pattern (dd.MM.yyyy)';
COMMENT ON COLUMN date_formats.separator    IS 'Date separator character';
COMMENT ON COLUMN date_formats.example_output IS 'Example rendered date';
