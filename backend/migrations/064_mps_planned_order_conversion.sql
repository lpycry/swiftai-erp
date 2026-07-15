ALTER TABLE mps_planned_orders
ADD COLUMN IF NOT EXISTS converted_production_order_id UUID REFERENCES production_orders(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS converted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_mps_planned_orders_converted_po
ON mps_planned_orders(converted_production_order_id);

COMMENT ON COLUMN mps_planned_orders.converted_production_order_id IS 'Production order created from this MPS planned order';
