-- SwiftAI ERP - Sales Order receipt capture fields
ALTER TABLE sales_orders
  ADD COLUMN IF NOT EXISTS receipt_method VARCHAR(30) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS received_amount NUMERIC(18,2) NOT NULL DEFAULT 0;
