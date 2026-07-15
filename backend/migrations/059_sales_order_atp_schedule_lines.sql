-- Sales Order ATP confirmations and schedule lines

ALTER TABLE sales_order_items
    ADD COLUMN IF NOT EXISTS atp_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS confirmed_delivery_date DATE DEFAULT NULL;

CREATE TABLE IF NOT EXISTS sales_order_item_schedule_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    so_item_id UUID NOT NULL REFERENCES sales_order_items(id) ON DELETE CASCADE,
    schedule_line_no INTEGER NOT NULL DEFAULT 1,
    confirmed_qty DECIMAL(18,4) NOT NULL DEFAULT 0,
    confirmed_date DATE,
    source_type VARCHAR(30) NOT NULL DEFAULT 'STOCK',
    source_ref VARCHAR(80) DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_so_item_sched_item ON sales_order_item_schedule_lines(so_item_id);

COMMENT ON COLUMN sales_order_items.atp_status IS 'PENDING, RELEASED, PARTIALLY_ALLOCATED, ATP_HOLD';
COMMENT ON TABLE sales_order_item_schedule_lines IS 'ATP schedule lines generated during sales order save/check';
