-- 027: Add tax calculation metadata columns to quotations

ALTER TABLE quotations ADD COLUMN IF NOT EXISTS tax_calc_source VARCHAR(30) NOT NULL DEFAULT '';
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS tax_calc_detail TEXT NOT NULL DEFAULT '';
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS tax_calc_rate DECIMAL(6,4) NOT NULL DEFAULT 0;
