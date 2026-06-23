ALTER TABLE production_orders
DROP CONSTRAINT IF EXISTS chk_production_order_status;

ALTER TABLE production_orders
ADD CONSTRAINT chk_production_order_status
CHECK (status IN ('DRAFT','RELEASED','IN_PROCESS','PARTIALLY_PRODUCED','COMPLETED','CANCELLED'));
