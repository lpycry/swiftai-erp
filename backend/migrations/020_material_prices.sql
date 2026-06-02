-- Material Prices (Sales Prices with SAP-style validity)
CREATE TABLE IF NOT EXISTS material_prices (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id        UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    customer_id       UUID DEFAULT NULL REFERENCES customers(id) ON DELETE SET NULL,
    price_type        VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    price             DECIMAL(18,4) NOT NULL,
    currency          VARCHAR(3) NOT NULL DEFAULT 'USD',
    price_unit        INTEGER NOT NULL DEFAULT 1,
    uom               VARCHAR(20) DEFAULT NULL,
    valid_from        DATE NOT NULL,
    valid_to          DATE DEFAULT NULL,
    is_active         BOOLEAN NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_material_prices_tenant ON material_prices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_material_prices_product ON material_prices(tenant_id, product_id);
CREATE INDEX IF NOT EXISTS idx_material_prices_customer ON material_prices(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_material_prices_active ON material_prices(tenant_id, is_active) WHERE is_active = true;

COMMENT ON TABLE material_prices IS 'Material sales prices with validity periods (SAP material price concept)';
COMMENT ON COLUMN material_prices.price_type IS 'STANDARD, PROMOTIONAL, VOLUME, CONTRACT, CUSTOMER_SPECIFIC';
COMMENT ON COLUMN material_prices.price_unit IS 'Price per N units (e.g. 100 = price per 100 pieces)';
COMMENT ON COLUMN material_prices.uom IS 'Unit of measure override (NULL = use product UOM)';
