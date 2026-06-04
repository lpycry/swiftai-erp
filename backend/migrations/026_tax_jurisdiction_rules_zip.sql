-- Add zip_code column to tax_jurisdiction_rules
ALTER TABLE tax_jurisdiction_rules ADD COLUMN IF NOT EXISTS zip_code VARCHAR(10) NOT NULL DEFAULT '';

COMMENT ON COLUMN tax_jurisdiction_rules.zip_code IS 'Postal/ZIP code for more granular jurisdiction matching';
