-- ============================================================
-- SwiftAI ERP - Delivery Block Reasons (SAP-like)
-- ============================================================

CREATE TABLE IF NOT EXISTS delivery_block_reasons (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id     UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    block_code    VARCHAR(10) NOT NULL,
    description   VARCHAR(200) NOT NULL DEFAULT '',
    is_active     BOOLEAN NOT NULL DEFAULT true,
    is_system     BOOLEAN NOT NULL DEFAULT false,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    created_by    UUID REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, block_code)
);

CREATE INDEX IF NOT EXISTS idx_dbr_tenant ON delivery_block_reasons(tenant_id);

CREATE TRIGGER trg_delivery_block_reasons_updated
    BEFORE UPDATE ON delivery_block_reasons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE  delivery_block_reasons IS 'Delivery block reasons (credit hold, missing docs, etc.)';

-- Seed data
INSERT INTO delivery_block_reasons (id, tenant_id, block_code, description, is_system, sort_order)
SELECT gen_random_uuid(), t.id, d.*
FROM tenants t
CROSS JOIN (VALUES
    ('01', 'Credit Hold',           true, 1),
    ('02', 'Missing Documents',     true, 2),
    ('03', 'Payment Pending',       true, 3),
    ('04', 'Customer Blocked',      true, 4),
    ('05', 'Quality Hold',          true, 5),
    ('06', 'Regulatory Hold',       true, 6)
) AS d(block_code, description, is_system, sort_order)
ON CONFLICT (tenant_id, block_code) DO NOTHING;
