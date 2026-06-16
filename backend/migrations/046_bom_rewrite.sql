-- BOM Schema Rewrite per FSD v1.0
-- Replaces the previous 044_production_bom_workcenter.sql BOM tables

-- ════════════════════════════════════════════════════════════
-- BOM HEADERS (bom_headers) — FSD §3.1
-- ════════════════════════════════════════════════════════════
-- First drop old tables if they exist (CASCADE handles dependencies)
DROP TABLE IF EXISTS bom_items CASCADE;
DROP TABLE IF EXISTS bom_headers CASCADE;

CREATE TABLE IF NOT EXISTS bom_headers (
    bom_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    material_id     UUID NOT NULL REFERENCES products(id),
    bom_version     VARCHAR(10) NOT NULL,
    bom_usage       VARCHAR(10) NOT NULL DEFAULT 'PRODUCTION',
    status          VARCHAR(10) NOT NULL DEFAULT 'NEW',
    base_qty        DECIMAL(18,4) NOT NULL DEFAULT 1.0000,
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to        TIMESTAMPTZ NOT NULL DEFAULT '2099-12-31 23:59:59+00',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by      UUID,
    CONSTRAINT chk_status CHECK (status IN ('NEW', 'ACTIVE', 'INACTIVE')),
    CONSTRAINT chk_usage CHECK (bom_usage IN ('PRODUCTION', 'COSTING')),
    UNIQUE(tenant_id, material_id, bom_version)
);

CREATE INDEX IF NOT EXISTS idx_bomh_tenant ON bom_headers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_bomh_material ON bom_headers(material_id);
CREATE INDEX IF NOT EXISTS idx_bomh_status ON bom_headers(status);

COMMENT ON COLUMN bom_headers.status IS 'NEW=草稿, ACTIVE=激活, INACTIVE=失效';
COMMENT ON COLUMN bom_headers.bom_usage IS 'PRODUCTION=生产BOM, COSTING=成本BOM';
COMMENT ON COLUMN bom_headers.base_qty IS '基本数量（如生产1个成品需要...）';

-- ════════════════════════════════════════════════════════════
-- BOM LINE ITEMS (bom_items) — FSD §3.2
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bom_items (
    item_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bom_id          UUID NOT NULL REFERENCES bom_headers(bom_id) ON DELETE CASCADE,
    item_position   INTEGER NOT NULL,
    component_id    UUID NOT NULL REFERENCES products(id),
    quantity        DECIMAL(18,4) NOT NULL,
    unit_of_measure VARCHAR(10) NOT NULL DEFAULT 'EA',
    scrap_factor    DECIMAL(5,4) NOT NULL DEFAULT 0.0000,
    is_phantom_item BOOLEAN NOT NULL DEFAULT FALSE,
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to        TIMESTAMPTZ NOT NULL DEFAULT '2099-12-31 23:59:59+00',
    remark          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bomi_bom ON bom_items(bom_id);
CREATE INDEX IF NOT EXISTS idx_bomi_component ON bom_items(component_id);

COMMENT ON COLUMN bom_items.item_position IS '行号（如10, 20, 30）';
COMMENT ON COLUMN bom_items.is_phantom_item IS '虚拟件（不产生物理仓储，直接穿透）';
COMMENT ON COLUMN bom_items.scrap_factor IS '物料损耗率（0.02=2%）';

-- ════════════════════════════════════════════════════════════
-- TRIGGERS
-- ════════════════════════════════════════════════════════════
CREATE TRIGGER trg_bom_headers_updated
    BEFORE UPDATE ON bom_headers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_bom_items_updated
    BEFORE UPDATE ON bom_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
