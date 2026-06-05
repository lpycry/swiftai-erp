-- Stock on Hand (ATP base table)
CREATE TABLE IF NOT EXISTS stock_on_hand (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    product_id UUID NOT NULL REFERENCES products(id),
    warehouse_id UUID DEFAULT NULL,  -- optional warehouse/location
    quantity DECIMAL(15,4) NOT NULL DEFAULT 0,
    reserved_qty DECIMAL(15,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stock_on_hand_tenant_product ON stock_on_hand(tenant_id, product_id);
CREATE INDEX idx_stock_on_hand_warehouse ON stock_on_hand(warehouse_id);

-- Seed: set on_hand=100 for each existing product (tenant default)
-- Using a simple approach: check for products first
INSERT INTO stock_on_hand (tenant_id, product_id, quantity)
SELECT
    (SELECT id FROM tenants LIMIT 1),
    p.id,
    100.0
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM stock_on_hand soh WHERE soh.product_id = p.id AND soh.quantity > 0
);
