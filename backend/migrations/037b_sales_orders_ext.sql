-- Add modern columns to existing sales_orders table
ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS order_date DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS requested_ship_date DATE;
ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES employee_base(id) ON DELETE SET NULL;

ALTER TABLE sales_order_items ADD COLUMN IF NOT EXISTS discount_pct NUMERIC(5,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN sales_orders.order_date IS 'Date the order was placed';
COMMENT ON COLUMN sales_orders.requested_ship_date IS 'Customer requested ship date';
COMMENT ON COLUMN sales_orders.employee_id IS 'Assigned salesperson';
