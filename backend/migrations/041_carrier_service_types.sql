-- Carrier / Service Type master data
-- Table-only (no seed defaults — users enter carrier + service_type freely).

CREATE TABLE IF NOT EXISTS carrier_service_types (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    carrier     VARCHAR(50) NOT NULL,
    service_type VARCHAR(100) NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    is_system   BOOLEAN NOT NULL DEFAULT false,
    sort_order  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_carrier_service_types_tenant
    ON carrier_service_types(tenant_id);
CREATE INDEX IF NOT EXISTS idx_carrier_service_types_carrier
    ON carrier_service_types(carrier);
