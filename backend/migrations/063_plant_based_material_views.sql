CREATE TABLE IF NOT EXISTS product_plant_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    mrp_type VARCHAR(10) NOT NULL DEFAULT 'MPS',
    procurement_type VARCHAR(20) NOT NULL DEFAULT 'in-house',
    safety_stock NUMERIC(18,4),
    reorder_point NUMERIC(18,4),
    reorder_qty NUMERIC(18,4),
    lead_time_days INTEGER,
    planning_time_fence_days INTEGER NOT NULL DEFAULT 5,
    default_production_warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
    default_receiving_warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
    standard_cost NUMERIC(18,4),
    moving_avg_cost NUMERIC(18,4),
    valuation_class VARCHAR(30),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, product_id, site_id),
    CHECK (mrp_type IN ('MPS', 'MRP', 'NO')),
    CHECK (procurement_type IN ('in-house', 'purchase', 'mixed'))
);

CREATE INDEX IF NOT EXISTS idx_product_plant_data_product
ON product_plant_data(tenant_id, product_id);

CREATE INDEX IF NOT EXISTS idx_product_plant_data_site
ON product_plant_data(tenant_id, site_id);

ALTER TABLE production_orders
ADD COLUMN IF NOT EXISTS site_id UUID REFERENCES sites(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_production_orders_site
ON production_orders(tenant_id, site_id);

ALTER TABLE sales_order_items
ADD COLUMN IF NOT EXISTS delivering_site_id UUID REFERENCES sites(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sales_order_items_delivering_site
ON sales_order_items(delivering_site_id);

ALTER TABLE purchase_order_items
ADD COLUMN IF NOT EXISTS site_id UUID REFERENCES sites(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_site
ON purchase_order_items(site_id);

COMMENT ON TABLE product_plant_data IS 'Plant-specific material master view for PP/MM/SD/FICO planning and valuation';
COMMENT ON COLUMN product_plant_data.site_id IS 'Plant; maps to sites.id where site_type = plant';
COMMENT ON COLUMN production_orders.site_id IS 'Production plant boundary';
COMMENT ON COLUMN sales_order_items.delivering_site_id IS 'Delivering plant for ATP and shipping';
COMMENT ON COLUMN purchase_order_items.site_id IS 'Receiving plant for procurement and MRP supply';

INSERT INTO product_plant_data (
    tenant_id, product_id, site_id, mrp_type, procurement_type, safety_stock,
    reorder_point, reorder_qty, lead_time_days, planning_time_fence_days,
    standard_cost, moving_avg_cost, valuation_class, is_active
)
SELECT
    p.tenant_id, p.id, s.id, COALESCE(NULLIF(p.mrp_type, ''), 'MPS'),
    COALESCE(NULLIF(p.procurement_type, ''), 'in-house'),
    p.min_stock_qty, p.reorder_point, p.reorder_qty, p.lead_time_days, 5,
    p.standard_cost, p.moving_avg_cost, p.valuation_class, p.is_active
FROM products p
JOIN sites s ON s.site_type = 'plant'
JOIN organizations o ON o.id = s.organization_id AND o.tenant_id = p.tenant_id
ON CONFLICT (tenant_id, product_id, site_id) DO NOTHING;
