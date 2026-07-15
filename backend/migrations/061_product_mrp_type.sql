ALTER TABLE products
ADD COLUMN IF NOT EXISTS mrp_type VARCHAR(10) NOT NULL DEFAULT 'MPS';

UPDATE products
SET mrp_type = 'MPS'
WHERE mrp_type IS NULL OR TRIM(mrp_type) = '';

ALTER TABLE products
DROP CONSTRAINT IF EXISTS chk_products_mrp_type;

ALTER TABLE products
ADD CONSTRAINT chk_products_mrp_type
CHECK (mrp_type IN ('MPS', 'MRP', 'NO'));

COMMENT ON COLUMN products.mrp_type IS 'MRP type: MPS, MRP, NO';
