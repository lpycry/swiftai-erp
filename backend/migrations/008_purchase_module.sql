-- ============================================================
-- SwiftAI ERP - Purchase & Vendor Module
-- Migration 008: Vendors, Purchase Orders, Receipts, Invoices
-- ============================================================

-- ============================================================
-- VENDOR MASTER (供应商主数据)
-- ============================================================
CREATE TABLE IF NOT EXISTS vendors (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    vendor_code     VARCHAR(30) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    tax_number      VARCHAR(50),
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_terms   VARCHAR(50) NOT NULL DEFAULT 'Net 30',
    status          VARCHAR(20) NOT NULL DEFAULT 'active',         -- active, blocked
    ai_rating       DECIMAL(3,2) NOT NULL DEFAULT 0,               -- 0.00 ~ 5.00
    lead_time_days  INTEGER DEFAULT 0,
    address         TEXT,
    contact_person  VARCHAR(100),
    contact_email   VARCHAR(100),
    contact_phone   VARCHAR(30),
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, vendor_code)
);
CREATE INDEX IF NOT EXISTS idx_vendors_org ON vendors(org_id);
CREATE INDEX IF NOT EXISTS idx_vendors_ai_rating ON vendors(ai_rating DESC);
CREATE INDEX IF NOT EXISTS idx_vendors_status ON vendors(status);

-- ============================================================
-- PURCHASE ORDERS (采购订单)
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_orders (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    po_number       VARCHAR(30) NOT NULL,
    vendor_id       UUID NOT NULL REFERENCES vendors(id),
    total_amount    DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT',   -- DRAFT, CONFIRMED, RECEIVED, INVOICED, CANCELLED
    notes           TEXT,
    created_by      UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, po_number)
);
CREATE INDEX IF NOT EXISTS idx_po_org ON purchase_orders(org_id);
CREATE INDEX IF NOT EXISTS idx_po_vendor ON purchase_orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_po_status ON purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_po_created ON purchase_orders(created_at DESC);

-- ============================================================
-- PURCHASE ORDER ITEMS (采购订单明细)
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_id               UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    item_id             UUID NOT NULL REFERENCES products(id),
    quantity            DECIMAL(18,4) NOT NULL,
    unit_price          DECIMAL(18,4) NOT NULL DEFAULT 0,
    received_quantity   DECIMAL(18,4) NOT NULL DEFAULT 0,
    unit_of_measure     VARCHAR(20) NOT NULL DEFAULT 'EA',
    line_total          DECIMAL(18,4) NOT NULL DEFAULT 0,
    UNIQUE(po_id, item_id)
);
CREATE INDEX IF NOT EXISTS idx_po_items_po ON purchase_order_items(po_id);
CREATE INDEX IF NOT EXISTS idx_po_items_product ON purchase_order_items(item_id);

-- ============================================================
-- PURCHASE RECEIPTS (采购收货单 — 联动仓库)
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_receipts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    po_id           UUID NOT NULL REFERENCES purchase_orders(id),
    item_id         UUID NOT NULL REFERENCES products(id),
    site_id         UUID NOT NULL REFERENCES sites(id),
    bin_id          UUID REFERENCES warehouse_bins(id),
    quantity        DECIMAL(18,4) NOT NULL,
    unit_cost       DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_cost      DECIMAL(18,4) NOT NULL DEFAULT 0,
    batch_no        VARCHAR(100),
    receipt_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    received_by     UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pr_po ON purchase_receipts(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_item ON purchase_receipts(item_id);
CREATE INDEX IF NOT EXISTS idx_pr_site ON purchase_receipts(site_id);
CREATE INDEX IF NOT EXISTS idx_pr_date ON purchase_receipts(receipt_date DESC);
CREATE INDEX IF NOT EXISTS idx_pr_org ON purchase_receipts(org_id);

-- ============================================================
-- PURCHASE INVOICES (采购发票 — 联动财务结算)
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_invoices (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    invoice_number  VARCHAR(50) NOT NULL,
    vendor_id       UUID NOT NULL REFERENCES vendors(id),
    po_id           UUID REFERENCES purchase_orders(id),
    invoice_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount    DECIMAL(18,4) NOT NULL DEFAULT 0,
    tax_amount      DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING, MATCHED, SETTLED, REJECTED
    match_status    VARCHAR(30),                               -- FULL_MATCH, PRICE_MISMATCH, QTY_MISMATCH
    ocr_data        JSONB,                                     -- AI OCR extracted data
    notes           TEXT,
    created_by      UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, invoice_number)
);
CREATE INDEX IF NOT EXISTS idx_pi_org ON purchase_invoices(org_id);
CREATE INDEX IF NOT EXISTS idx_pi_vendor ON purchase_invoices(vendor_id);
CREATE INDEX IF NOT EXISTS idx_pi_po ON purchase_invoices(po_id);
CREATE INDEX IF NOT EXISTS idx_pi_status ON purchase_invoices(status);

-- ============================================================
-- BUSINESS EVENTS (业务事件 → 异步触发财务过账)
-- ============================================================
CREATE TABLE IF NOT EXISTS business_events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    event_type      VARCHAR(50) NOT NULL,       -- PO_GOODS_RECEIVED, PO_INVOICE_MATCHED, PO_INVOICE_SETTLED
    source_id       UUID NOT NULL,              -- ID of the source document (receipt/invoice)
    source_type     VARCHAR(30) NOT NULL,        -- purchase_receipt, purchase_invoice
    event_data      JSONB,                       -- contextual payload for AI GL posting
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING, PROCESSED, FAILED
    error_message   TEXT,
    processed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_be_org ON business_events(org_id);
CREATE INDEX IF NOT EXISTS idx_be_type ON business_events(event_type);
CREATE INDEX IF NOT EXISTS idx_be_status ON business_events(status);
CREATE INDEX IF NOT EXISTS idx_be_source ON business_events(source_id, source_type);
CREATE INDEX IF NOT EXISTS idx_be_created ON business_events(created_at);

-- ============================================================
-- TRIGGERS: auto update updated_at
-- ============================================================
CREATE TRIGGER trg_vendors_updated
    BEFORE UPDATE ON vendors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_purchase_orders_updated
    BEFORE UPDATE ON purchase_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_purchase_invoices_updated
    BEFORE UPDATE ON purchase_invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
