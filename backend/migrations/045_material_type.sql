-- Add material_type column to products table
ALTER TABLE products ADD COLUMN IF NOT EXISTS material_type VARCHAR(30) NOT NULL DEFAULT 'other';

COMMENT ON COLUMN products.material_type IS 'Material type: finished_goods, half_finished_goods, raw_material, other';
