CREATE TABLE IF NOT EXISTS purchasing_info_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    purchase_uom VARCHAR(20) NOT NULL DEFAULT 'EA',
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    min_order_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    rounding_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    lead_time_days INTEGER NOT NULL DEFAULT 0,
    overdelivery_tolerance_pct NUMERIC(8,4) NOT NULL DEFAULT 0,
    underdelivery_tolerance_pct NUMERIC(8,4) NOT NULL DEFAULT 0,
    incoterm VARCHAR(20) DEFAULT '',
    payment_terms VARCHAR(80) DEFAULT '',
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE,
    is_preferred BOOLEAN NOT NULL DEFAULT false,
    is_blocked BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_purchasing_info_records_scope
ON purchasing_info_records(org_id, vendor_id, product_id, COALESCE(site_id, '00000000-0000-0000-0000-000000000000'::uuid));

CREATE INDEX IF NOT EXISTS idx_purchasing_info_records_product_site
ON purchasing_info_records(org_id, product_id, site_id, is_active, is_blocked);

COMMENT ON TABLE purchasing_info_records IS 'Purchasing info records for Vendor + Material + Plant procurement defaults used by MRP';
