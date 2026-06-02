-- Product Taxability (for sales tax / VAT / GST)
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_category       VARCHAR(30) NOT NULL DEFAULT 'STANDARD';
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_rate           DECIMAL(6,4) DEFAULT NULL;
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_type           VARCHAR(30) NOT NULL DEFAULT 'SALES_TAX';
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_exempt_reason  VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS default_tax_jurisdiction_id UUID DEFAULT NULL;

COMMENT ON COLUMN products.tax_category IS 'STANDARD, REDUCED, ZERO, EXEMPT, SERVICE';
COMMENT ON COLUMN products.tax_type IS 'SALES_TAX, VAT, GST, CONSUMPTION_TAX, NONE';
COMMENT ON COLUMN products.tax_rate IS 'Override tax rate (NULL = use jurisdiction default)';
COMMENT ON COLUMN products.tax_exempt_reason IS 'RESALE, GOVERNMENT, NON_PROFIT, CHARITABLE, OTHER';
COMMENT ON COLUMN products.default_tax_jurisdiction_id IS 'FK to tax_jurisdictions';
