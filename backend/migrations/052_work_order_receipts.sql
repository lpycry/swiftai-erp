-- Work Order Receiving
-- Records production order finished/semi-finished goods receipts into inventory.

ALTER TABLE production_orders
  ADD COLUMN IF NOT EXISTS completed_qty DECIMAL(18,4) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS work_order_receipts (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id            UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    production_order_id  UUID NOT NULL REFERENCES production_orders(id),
    material_id          UUID NOT NULL REFERENCES products(id),
    site_id              UUID NOT NULL REFERENCES sites(id),
    warehouse_id         UUID NOT NULL REFERENCES warehouses(id),
    bin_id               UUID REFERENCES warehouse_bins(id),
    quantity             DECIMAL(18,4) NOT NULL,
    unit_cost            DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_cost           DECIMAL(18,4) NOT NULL DEFAULT 0,
    batch_no             VARCHAR(100),
    receipt_date         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    received_by          UUID,
    gl_je_id             UUID,
    is_reversed          BOOLEAN NOT NULL DEFAULT false,
    reversed_at          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE work_order_receipts
  ADD COLUMN IF NOT EXISTS is_reversed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS reversed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_wor_tenant ON work_order_receipts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_wor_production_order ON work_order_receipts(production_order_id);
CREATE INDEX IF NOT EXISTS idx_wor_material ON work_order_receipts(material_id);
CREATE INDEX IF NOT EXISTS idx_wor_warehouse_bin ON work_order_receipts(warehouse_id, bin_id);
