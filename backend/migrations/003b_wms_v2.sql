-- ============================================================
-- SwiftAI ERP - WMS Schema Upgrade v2 (per SRD v1.0)
-- Adds: Material Master multi-view, warehouse 6-level hierarchy,
--        ASN, inbound/outbound, cycle counting, photo management
-- ============================================================

-- ============================================================
-- MATERIAL MASTER ENHANCEMENTS (Section 4)
-- ============================================================

-- Product photos (REQ-MM-001 ~ 010)
CREATE TABLE IF NOT EXISTS product_photos (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id  UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    is_primary  BOOLEAN NOT NULL DEFAULT false,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    file_path   VARCHAR(500) NOT NULL,
    file_name   VARCHAR(255) NOT NULL,
    file_size   INTEGER NOT NULL DEFAULT 0,
    mime_type   VARCHAR(50) NOT NULL DEFAULT 'image/jpeg',
    -- AI-generated tags (REQ-MM-006)
    ai_tags     JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_prod_photos_product ON product_photos(product_id);

-- Add missing columns to products
ALTER TABLE products ADD COLUMN IF NOT EXISTS dimension_length DECIMAL(12,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS dimension_width  DECIMAL(12,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS dimension_height DECIMAL(12,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS dimension_unit   VARCHAR(10) NOT NULL DEFAULT 'cm';
ALTER TABLE products ADD COLUMN IF NOT EXISTS gross_weight     DECIMAL(12,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS net_weight       DECIMAL(12,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS weight_unit      VARCHAR(10) NOT NULL DEFAULT 'kg';
ALTER TABLE products ADD COLUMN IF NOT EXISTS moving_avg_cost  DECIMAL(18,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS valuation_class  VARCHAR(30);
ALTER TABLE products ADD COLUMN IF NOT EXISTS abc_classification VARCHAR(10); -- A/B/C
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_blocked       BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS block_reason     TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS min_stock_qty    DECIMAL(18,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS max_stock_qty    DECIMAL(18,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS reorder_point    DECIMAL(18,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS reorder_qty      DECIMAL(18,4);
ALTER TABLE products ADD COLUMN IF NOT EXISTS lead_time_days   INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS procurement_type VARCHAR(20); -- in-house, external, both
ALTER TABLE products ADD COLUMN IF NOT EXISTS storage_condition VARCHAR(50); -- ambient, chilled, frozen, hazardous
ALTER TABLE products ADD COLUMN IF NOT EXISTS country_of_origin VARCHAR(10);
ALTER TABLE products ADD COLUMN IF NOT EXISTS hs_code          VARCHAR(20);
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_serialized    BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS uom_group        VARCHAR(20); -- base UOM group

-- Product barcodes (multiple barcodes per product, REQ-MM-031)
CREATE TABLE IF NOT EXISTS product_barcodes (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id  UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    barcode     VARCHAR(100) NOT NULL,
    barcode_type VARCHAR(30) NOT NULL DEFAULT 'EAN-13', -- EAN-13, EAN-8, UPC-A, Code128, QR, SSCC
    is_primary  BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(product_id, barcode)
);
CREATE INDEX IF NOT EXISTS idx_prod_barcodes_barcode ON product_barcodes(barcode);

-- ============================================================
-- WAREHOUSE 6-LEVEL HIERARCHY (Section 5)
-- ============================================================

-- Warehouse (L1) - already exists
ALTER TABLE warehouses ADD COLUMN IF NOT EXISTS warehouse_type VARCHAR(30) NOT NULL DEFAULT 'standard'; -- standard, cold_storage, hazardous, cross_dock
ALTER TABLE warehouses ADD COLUMN IF NOT EXISTS timezone       VARCHAR(50) DEFAULT 'UTC';
ALTER TABLE warehouses ADD COLUMN IF NOT EXISTS is_system      BOOLEAN NOT NULL DEFAULT false;

-- Zone (L2) - already exists, add more fields
ALTER TABLE warehouse_zones ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE warehouse_zones ADD COLUMN IF NOT EXISTS capacity_weight_kg DECIMAL(12,4);
ALTER TABLE warehouse_zones ADD COLUMN IF NOT EXISTS capacity_volume_m3 DECIMAL(12,4);
ALTER TABLE warehouse_zones ADD COLUMN IF NOT EXISTS temperature_min DECIMAL(6,2);
ALTER TABLE warehouse_zones ADD COLUMN IF NOT EXISTS temperature_max DECIMAL(6,2);
ALTER TABLE warehouse_zones ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;

-- Aisle (L3)
CREATE TABLE IF NOT EXISTS warehouse_aisles (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id     UUID NOT NULL REFERENCES warehouse_zones(id) ON DELETE CASCADE,
    code        VARCHAR(50) NOT NULL,
    name        VARCHAR(255),
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(zone_id, code)
);

-- Rack/Bay (L4)
CREATE TABLE IF NOT EXISTS warehouse_racks (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    aisle_id    UUID NOT NULL REFERENCES warehouse_aisles(id) ON DELETE CASCADE,
    code        VARCHAR(50) NOT NULL,
    name        VARCHAR(255),
    rack_type   VARCHAR(30) DEFAULT 'standard', -- standard, drive_in, push_back, flow, cantilever
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(aisle_id, code)
);

-- Level (L5)
CREATE TABLE IF NOT EXISTS warehouse_levels (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rack_id     UUID NOT NULL REFERENCES warehouse_racks(id) ON DELETE CASCADE,
    code        VARCHAR(50) NOT NULL,
    level_no    INTEGER NOT NULL DEFAULT 1,
    max_weight_kg DECIMAL(12,4),
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(rack_id, code)
);

-- Bin (L6) - upgrade existing warehouse_bins
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS aisle_id    UUID REFERENCES warehouse_aisles(id);
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS rack_id     UUID REFERENCES warehouse_racks(id);
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS level_id    UUID REFERENCES warehouse_levels(id);
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS bin_type    VARCHAR(30) NOT NULL DEFAULT 'storage'; -- storage, picking, staging, dock
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS bin_status  VARCHAR(30) NOT NULL DEFAULT 'available'; -- available, occupied, blocked, damaged, locked
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS temp_zone   VARCHAR(20); -- ambient, chilled, frozen
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS putaway_zone BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS picking_zone BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE warehouse_bins ADD COLUMN IF NOT EXISTS fixed_bin    BOOLEAN NOT NULL DEFAULT false; -- fixed bin for specific SKU

-- ============================================================
-- ASN - ADVANCE SHIPMENT NOTICE (Section 6.2, REQ-IB-001~004)
-- ============================================================
CREATE TABLE IF NOT EXISTS asn_headers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    asn_no          VARCHAR(100) NOT NULL,
    po_id           UUID, -- reference to procurement PO
    po_no           VARCHAR(100),
    supplier_id     UUID,
    supplier_name   VARCHAR(255),
    warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
    expected_date   DATE NOT NULL,
    arrival_date    DATE,
    status          VARCHAR(30) NOT NULL DEFAULT 'expected',
    -- status: expected, in_transit, partially_received, fully_received, cancelled
    notes           TEXT,
    created_by      UUID NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, asn_no)
);

CREATE TABLE IF NOT EXISTS asn_lines (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asn_id          UUID NOT NULL REFERENCES asn_headers(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id),
    expected_qty    DECIMAL(18,4) NOT NULL,
    received_qty    DECIMAL(18,4) NOT NULL DEFAULT 0,
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'EA',
    batch_no        VARCHAR(100),
    expiry_date     DATE,
    notes           TEXT
);

-- ============================================================
-- GOODS RECEIPT (Section 6.3, REQ-IB-005~014)
-- ============================================================
CREATE TABLE IF NOT EXISTS goods_receipts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    gr_no           VARCHAR(100) NOT NULL,
    receipt_type    VARCHAR(30) NOT NULL DEFAULT 'po', -- po, asn, production, return, initial
    reference_type  VARCHAR(30), -- po, asn, production_order
    reference_id    UUID,
    reference_no    VARCHAR(100),
    warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
    supplier_id     UUID,
    supplier_name   VARCHAR(255),
    receipt_date    DATE NOT NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'draft',
    -- draft, inspected, partially_posted, posted, cancelled
    inspection_status VARCHAR(30), -- pending, in_progress, passed, failed
    notes           TEXT,
    created_by      UUID NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    posted_at       TIMESTAMPTZ,
    posted_by       UUID,
    UNIQUE(tenant_id, gr_no)
);

CREATE TABLE IF NOT EXISTS goods_receipt_lines (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gr_id           UUID NOT NULL REFERENCES goods_receipts(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id),
    asn_line_id     UUID REFERENCES asn_lines(id),
    expected_qty    DECIMAL(18,4) NOT NULL,
    received_qty    DECIMAL(18,4) NOT NULL,
    accepted_qty    DECIMAL(18,4),
    rejected_qty    DECIMAL(18,4) DEFAULT 0,
    unit_cost       DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_cost      DECIMAL(18,4) NOT NULL DEFAULT 0,
    batch_no        VARCHAR(100),
    manufacture_date DATE,
    expiry_date     DATE,
    putaway_status  VARCHAR(30) DEFAULT 'pending', -- pending, in_progress, completed
    putaway_bin_id  UUID REFERENCES warehouse_bins(id),
    notes           TEXT
);

-- ============================================================
-- OUTBOUND / GOODS ISSUE (Section 8)
-- ============================================================
CREATE TABLE IF NOT EXISTS outbound_orders (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_no        VARCHAR(100) NOT NULL,
    order_type      VARCHAR(30) NOT NULL, -- sales_order, production, transfer, return
    reference_type  VARCHAR(30),
    reference_id    UUID,
    reference_no    VARCHAR(100),
    warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
    customer_id     UUID,
    customer_name   VARCHAR(255),
    delivery_address TEXT,
    carrier         VARCHAR(100),
    tracking_no     VARCHAR(100),
    status          VARCHAR(30) NOT NULL DEFAULT 'draft',
    -- draft, picking, packed, shipped, delivered, cancelled
    priority        VARCHAR(10) DEFAULT 'normal', -- urgent, high, normal, low
    notes           TEXT,
    created_by      UUID NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    shipped_at      TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    UNIQUE(tenant_id, order_no)
);

CREATE TABLE IF NOT EXISTS outbound_order_lines (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        UUID NOT NULL REFERENCES outbound_orders(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id),
    ordered_qty     DECIMAL(18,4) NOT NULL,
    picked_qty      DECIMAL(18,4) NOT NULL DEFAULT 0,
    shipped_qty     DECIMAL(18,4) NOT NULL DEFAULT 0,
    unit_cost       DECIMAL(18,4) DEFAULT 0,
    total_cost      DECIMAL(18,4) DEFAULT 0,
    batch_no        VARCHAR(100),
    from_bin_id     UUID REFERENCES warehouse_bins(id),
    pick_status     VARCHAR(30) DEFAULT 'pending', -- pending, assigned, in_progress, picked, verified
    notes           TEXT
);

-- ============================================================
-- CYCLE COUNTING (Section 9, REQ-CC-001~008)
-- ============================================================
CREATE TABLE IF NOT EXISTS cycle_counts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    count_no        VARCHAR(100) NOT NULL,
    count_type      VARCHAR(30) NOT NULL DEFAULT 'cycle', -- cycle, annual, adhoc, aiprompted
    warehouse_id    UUID NOT NULL REFERENCES warehouses(id),
    zone_id         UUID REFERENCES warehouse_zones(id),
    bin_id          UUID REFERENCES warehouse_bins(id),
    product_id      UUID REFERENCES products(id),
    status          VARCHAR(30) NOT NULL DEFAULT 'open',
    -- open, in_progress, counted, verified, closed
    scheduled_date  DATE,
    counted_date    DATE,
    counted_by      UUID,
    verified_by     UUID,
    ai_suggested    BOOLEAN DEFAULT false, -- AI-suggested count (REQ-CC-001)
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    UNIQUE(tenant_id, count_no)
);

-- ============================================================
-- WAREHOUSE TASKS (Section 7.4, REQ-IO-014~018)
-- ============================================================
CREATE TABLE IF NOT EXISTS warehouse_tasks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    task_type       VARCHAR(30) NOT NULL,
    -- putaway, picking, transfer, cycle_count, replenishment, quality_check
    reference_type  VARCHAR(30),
    reference_id    UUID,
    product_id      UUID REFERENCES products(id),
    -- Source
    from_warehouse_id UUID REFERENCES warehouses(id),
    from_zone_id    UUID REFERENCES warehouse_zones(id),
    from_bin_id     UUID REFERENCES warehouse_bins(id),
    -- Target
    to_warehouse_id UUID REFERENCES warehouses(id),
    to_zone_id      UUID REFERENCES warehouse_zones(id),
    to_bin_id       UUID REFERENCES warehouse_bins(id),
    -- Quantity
    quantity        DECIMAL(18,4) NOT NULL,
    uom             VARCHAR(20) NOT NULL DEFAULT 'EA',
    -- Batch/Serial
    batch_id        UUID REFERENCES batches(id),
    batch_no        VARCHAR(100),
    -- Status
    status          VARCHAR(30) NOT NULL DEFAULT 'open',
    -- open, assigned, in_progress, completed, cancelled
    priority        VARCHAR(10) DEFAULT 'normal',
    assigned_to     UUID,
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    notes           TEXT,
    created_by      UUID NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wh_tasks_type ON warehouse_tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_wh_tasks_status ON warehouse_tasks(status);
CREATE INDEX IF NOT EXISTS idx_wh_tasks_assigned ON warehouse_tasks(assigned_to);

-- Triggers
CREATE TRIGGER trg_warehouse_aisles_updated BEFORE UPDATE ON warehouse_aisles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_warehouse_racks_updated BEFORE UPDATE ON warehouse_racks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_warehouse_levels_updated BEFORE UPDATE ON warehouse_levels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_asn_headers_updated BEFORE UPDATE ON asn_headers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_warehouse_tasks_updated BEFORE UPDATE ON warehouse_tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_outbound_orders_updated BEFORE UPDATE ON outbound_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
