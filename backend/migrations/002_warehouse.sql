-- ============================================================
-- SwiftAI ERP - Warehouse & Inventory Module
-- Migration 002: Products, Warehouses, Stock, Batches, Movements
-- ============================================================

-- ============================================================
-- PRODUCT MASTER (REQ-WM-002)
-- ============================================================
CREATE TABLE IF NOT EXISTS product_categories (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code        VARCHAR(50) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    parent_id   UUID REFERENCES product_categories(id),
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_prod_cat_tenant ON product_categories(tenant_id);

CREATE TABLE IF NOT EXISTS products (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    category_id       UUID REFERENCES product_categories(id),
    sku               VARCHAR(100) NOT NULL,
    barcode           VARCHAR(100),
    name              VARCHAR(255) NOT NULL,
    description       TEXT,
    unit_of_measure   VARCHAR(20) NOT NULL DEFAULT 'EA',
    -- Batch/Serial tracking
    batch_tracked     BOOLEAN NOT NULL DEFAULT false,
    serial_tracked    BOOLEAN NOT NULL DEFAULT false,
    shelf_life_days   INTEGER,
    -- Valuation
    standard_cost     DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_cost         DECIMAL(18,4) NOT NULL DEFAULT 0,
    avg_cost          DECIMAL(18,4) NOT NULL DEFAULT 0,
    -- Physical
    weight_kg         DECIMAL(12,4),
    volume_m3         DECIMAL(12,4),
    -- Status
    is_active         BOOLEAN NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, sku),
    UNIQUE(tenant_id, barcode)
);

CREATE INDEX IF NOT EXISTS idx_products_tenant ON products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);

-- ============================================================
-- WAREHOUSE STRUCTURE (REQ-WM-002)
-- ============================================================
CREATE TABLE IF NOT EXISTS warehouses (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code        VARCHAR(50) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    address     TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_wh_tenant ON warehouses(tenant_id);

CREATE TABLE IF NOT EXISTS warehouse_zones (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    warehouse_id  UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    code          VARCHAR(50) NOT NULL,
    name          VARCHAR(255) NOT NULL,
    zone_type     VARCHAR(30) NOT NULL DEFAULT 'storage',
    -- zone_type: storage, picking, receiving, shipping, quarantine
    is_active     BOOLEAN NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(warehouse_id, code)
);

CREATE INDEX IF NOT EXISTS idx_wh_zone_wh ON warehouse_zones(warehouse_id);

CREATE TABLE IF NOT EXISTS warehouse_bins (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id       UUID NOT NULL REFERENCES warehouse_zones(id) ON DELETE CASCADE,
    code          VARCHAR(50) NOT NULL,
    name          VARCHAR(255),
    barcode       VARCHAR(100),
    max_weight_kg DECIMAL(12,4),
    max_volume_m3 DECIMAL(12,4),
    is_active     BOOLEAN NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(zone_id, code)
);

CREATE INDEX IF NOT EXISTS idx_wh_bin_zone ON warehouse_bins(zone_id);

-- ============================================================
-- STOCK & INVENTORY
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_items (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id        UUID NOT NULL REFERENCES products(id),
    warehouse_id      UUID NOT NULL REFERENCES warehouses(id),
    bin_id            UUID REFERENCES warehouse_bins(id),
    batch_id          UUID,  -- FK to batches, added after batches table exists
    lot_no            VARCHAR(100),
    -- Quantities
    quantity_on_hand  DECIMAL(18,4) NOT NULL DEFAULT 0,
    quantity_reserved DECIMAL(18,4) NOT NULL DEFAULT 0,
    quantity_in_transit DECIMAL(18,4) NOT NULL DEFAULT 0,
    -- Valuation
    unit_cost         DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_cost        DECIMAL(18,4) NOT NULL DEFAULT 0,
    -- Tracking
    last_movement_at  TIMESTAMPTZ,
    last_counted_at   TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, product_id, warehouse_id, bin_id)
);

CREATE INDEX IF NOT EXISTS idx_stock_tenant ON stock_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_product ON stock_items(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_warehouse ON stock_items(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_bin ON stock_items(bin_id);

-- ============================================================
-- BATCH & SERIAL TRACKING (REQ-WM-002)
-- ============================================================
CREATE TABLE IF NOT EXISTS batches (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id        UUID NOT NULL REFERENCES products(id),
    batch_no          VARCHAR(100) NOT NULL,
    -- Manufacturing
    manufacture_date  DATE,
    expiry_date       DATE,
    shelf_life_days   INTEGER,
    -- Receipt
    received_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    supplier_id       UUID,  -- FK to vendor master (future)
    -- Status
    is_blocked        BOOLEAN NOT NULL DEFAULT false,
    block_reason      TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, product_id, batch_no)
);

CREATE INDEX IF NOT EXISTS idx_batches_tenant ON batches(tenant_id);
CREATE INDEX IF NOT EXISTS idx_batches_product ON batches(product_id);
CREATE INDEX IF NOT EXISTS idx_batches_expiry ON batches(expiry_date);

-- Add FK from stock_items.batch_id to batches
ALTER TABLE stock_items ADD CONSTRAINT fk_stock_batch
    FOREIGN KEY (batch_id) REFERENCES batches(id);

-- ============================================================
-- SERIAL NUMBERS (for serial-tracked products)
-- ============================================================
CREATE TABLE IF NOT EXISTS serial_numbers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id),
    serial_no       VARCHAR(100) NOT NULL,
    batch_id        UUID REFERENCES batches(id),
    warehouse_id    UUID REFERENCES warehouses(id),
    bin_id          UUID REFERENCES warehouse_bins(id),
    status          VARCHAR(30) NOT NULL DEFAULT 'in_stock',
    -- status: in_stock, reserved, shipped, returned, scrapped
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, product_id, serial_no)
);

CREATE INDEX IF NOT EXISTS idx_serial_tenant ON serial_numbers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_serial_product ON serial_numbers(product_id);
CREATE INDEX IF NOT EXISTS idx_serial_status ON serial_numbers(status);

-- ============================================================
-- STOCK MOVEMENTS (REQ-WM-003, REQ-WM-004, REQ-WM-005)
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_movements (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    transaction_type  VARCHAR(30) NOT NULL,
    -- transaction_type: goods_receipt, goods_issue, transfer_out, transfer_in, adjustment
    reference_type    VARCHAR(50),
    reference_id      UUID,
    reference_no      VARCHAR(100),
    -- Product
    product_id        UUID NOT NULL REFERENCES products(id),
    warehouse_id      UUID NOT NULL REFERENCES warehouses(id),
    bin_id            UUID REFERENCES warehouse_bins(id),
    batch_id          UUID REFERENCES batches(id),
    -- Quantities & Values
    quantity          DECIMAL(18,4) NOT NULL,
    unit_cost         DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_cost        DECIMAL(18,4) NOT NULL DEFAULT 0,
    -- Transfer fields (REQ-WM-005)
    to_warehouse_id   UUID REFERENCES warehouses(id),
    to_bin_id         UUID REFERENCES warehouse_bins(id),
    -- Status
    status            VARCHAR(30) NOT NULL DEFAULT 'draft',
    -- status: draft, posted, cancelled
    description       TEXT,
    -- Audit
    created_by        UUID NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    posted_at         TIMESTAMPTZ,
    posted_by         UUID
);

CREATE INDEX IF NOT EXISTS idx_sm_tenant ON stock_movements(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sm_type ON stock_movements(transaction_type);
CREATE INDEX IF NOT EXISTS idx_sm_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_sm_warehouse ON stock_movements(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_sm_reference ON stock_movements(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_sm_status ON stock_movements(status);

-- ============================================================
-- UOM CONVERSIONS (REQ-WM-002)
-- ============================================================
CREATE TABLE IF NOT EXISTS uom_conversions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id),
    from_uom        VARCHAR(20) NOT NULL,
    to_uom          VARCHAR(20) NOT NULL,
    conversion_rate DECIMAL(18,6) NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    UNIQUE(tenant_id, product_id, from_uom, to_uom)
);

-- ============================================================
-- TRIGGER: auto update updated_at
-- ============================================================
CREATE TRIGGER trg_products_updated
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_warehouses_updated
    BEFORE UPDATE ON warehouses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_warehouse_zones_updated
    BEFORE UPDATE ON warehouse_zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_warehouse_bins_updated
    BEFORE UPDATE ON warehouse_bins
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_stock_items_updated
    BEFORE UPDATE ON stock_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_batches_updated
    BEFORE UPDATE ON batches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_serial_numbers_updated
    BEFORE UPDATE ON serial_numbers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_product_categories_updated
    BEFORE UPDATE ON product_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
