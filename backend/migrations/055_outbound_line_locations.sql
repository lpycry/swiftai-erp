ALTER TABLE outbound_order_lines
    ADD COLUMN IF NOT EXISTS warehouse_id UUID REFERENCES warehouses(id);

UPDATE outbound_order_lines l
SET warehouse_id = o.warehouse_id
FROM outbound_orders o
WHERE l.order_id = o.id
  AND l.warehouse_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_outbound_order_lines_warehouse ON outbound_order_lines(warehouse_id);
