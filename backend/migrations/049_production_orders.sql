-- Production Orders table (SAP VA01-inspired, for production orders)
-- Migration 049

CREATE TABLE IF NOT EXISTS production_orders (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_number        VARCHAR(30) NOT NULL,
    material_id         UUID NOT NULL REFERENCES products(id),
    order_qty           DECIMAL(18,4) NOT NULL DEFAULT 1.0000,
    bom_id              UUID REFERENCES bom_headers(bom_id),
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    priority            VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
    planned_start_date  TIMESTAMPTZ,
    planned_end_date    TIMESTAMPTZ,
    actual_start_date   TIMESTAMPTZ,
    actual_end_date     TIMESTAMPTZ,
    notes               TEXT,
    created_by          UUID,
    updated_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, order_number)
);

CREATE INDEX IF NOT EXISTS idx_po_tenant ON production_orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_po_status ON production_orders(status);
CREATE INDEX IF NOT EXISTS idx_po_material ON production_orders(material_id);

-- status CHECK constraint
ALTER TABLE production_orders
  ADD CONSTRAINT chk_production_order_status
  CHECK (status IN ('DRAFT','RELEASED','IN_PROCESS','COMPLETED','CANCELLED'));
