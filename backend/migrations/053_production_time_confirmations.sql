-- Production order time confirmations, CO11N-inspired.

CREATE TABLE IF NOT EXISTS production_order_time_confirmations (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id            UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    production_order_id  UUID NOT NULL REFERENCES production_orders(id) ON DELETE CASCADE,
    operation_id         UUID REFERENCES template_operations(id),
    work_center_id       UUID REFERENCES work_centers(id),
    yield_qty            DECIMAL(18,4) NOT NULL,
    scrap_qty            DECIMAL(18,4) NOT NULL DEFAULT 0,
    rework_qty           DECIMAL(18,4) NOT NULL DEFAULT 0,
    setup_hours          DECIMAL(18,4) NOT NULL DEFAULT 0,
    labor_hours          DECIMAL(18,4) NOT NULL DEFAULT 0,
    machine_hours        DECIMAL(18,4) NOT NULL DEFAULT 0,
    actual_work_hours    DECIMAL(18,4) NOT NULL DEFAULT 0,
    confirmation_date    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes                TEXT,
    confirmed_by         UUID,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_potc_tenant ON production_order_time_confirmations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_potc_order ON production_order_time_confirmations(production_order_id);
CREATE INDEX IF NOT EXISTS idx_potc_operation ON production_order_time_confirmations(operation_id);
CREATE INDEX IF NOT EXISTS idx_potc_work_center ON production_order_time_confirmations(work_center_id);
CREATE INDEX IF NOT EXISTS idx_potc_date ON production_order_time_confirmations(confirmation_date);

ALTER TABLE production_order_time_confirmations
  ADD COLUMN IF NOT EXISTS operation_id UUID REFERENCES template_operations(id),
  ADD COLUMN IF NOT EXISTS work_center_id UUID REFERENCES work_centers(id),
  ADD COLUMN IF NOT EXISTS scrap_qty DECIMAL(18,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rework_qty DECIMAL(18,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS setup_hours DECIMAL(18,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS labor_hours DECIMAL(18,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS machine_hours DECIMAL(18,4) NOT NULL DEFAULT 0;
