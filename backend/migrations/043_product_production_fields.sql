-- Product Master — Production Tab Fields
-- Adds production-related columns between Dimensions & Costing sections

ALTER TABLE products ADD COLUMN IF NOT EXISTS mrp_enabled            BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE products ADD COLUMN IF NOT EXISTS phantom_assembly       BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS production_lead_time   INTEGER;       -- hours (前置生产工时)
ALTER TABLE products ADD COLUMN IF NOT EXISTS in_house_production_days INTEGER;      -- days

COMMENT ON COLUMN products.mrp_enabled              IS 'MRP enabled flag (default true)';
COMMENT ON COLUMN products.phantom_assembly         IS 'Phantom/bulld-to-order assembly flag (default false)';
COMMENT ON COLUMN products.production_lead_time     IS 'Production lead time in hours (前置生产工时)';
COMMENT ON COLUMN products.in_house_production_days IS 'In-house production days';
