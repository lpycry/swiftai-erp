-- Sales Orders (SAP VA01/VA02/VA03 style)
CREATE TABLE IF NOT EXISTS sales_orders (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id       UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    quotation_id      UUID DEFAULT NULL REFERENCES quotations(id) ON DELETE SET NULL,
    so_number         VARCHAR(50) NOT NULL,
    so_type           VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    status            VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    customer_po_no    VARCHAR(100) DEFAULT '',
    po_date           DATE DEFAULT NULL,
    currency          VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_terms     VARCHAR(50) DEFAULT 'Net 30',
    incoterm          VARCHAR(30) DEFAULT '',
    valid_from        DATE NOT NULL DEFAULT CURRENT_DATE,
    delivery_date     DATE DEFAULT NULL,
    requested_date    DATE DEFAULT NULL,
    total_amount      DECIMAL(18,2) NOT NULL DEFAULT 0,
    discount_pct      DECIMAL(5,2) DEFAULT 0,
    discount_amount   DECIMAL(18,2) DEFAULT 0,
    net_amount        DECIMAL(18,2) NOT NULL DEFAULT 0,
    tax_amount        DECIMAL(18,2) DEFAULT 0,
    grand_total       DECIMAL(18,2) NOT NULL DEFAULT 0,
    notes             TEXT DEFAULT '',
    internal_notes    TEXT DEFAULT '',
    -- Shipping Info
    carrier           VARCHAR(100) DEFAULT '',
    shipping_method   VARCHAR(100) DEFAULT '',
    shipper_account   VARCHAR(100) DEFAULT '',
    signature_required BOOLEAN NOT NULL DEFAULT false,
    saturday_delivery BOOLEAN NOT NULL DEFAULT false,
    insurance_amt     DECIMAL(18,2) DEFAULT 0,
    -- Bill-to / Transport Info
    transportation_to VARCHAR(255) DEFAULT '',
    transport_payer_account VARCHAR(100) DEFAULT '',
    bill_to_address   TEXT DEFAULT '',
    -- Sales Order Status Tracking
    credit_check_status VARCHAR(30) DEFAULT 'PENDING',
    inventory_check_status VARCHAR(30) DEFAULT 'PENDING',
    tax_calc_status     VARCHAR(30) DEFAULT 'PENDING',
    allocation_status   VARCHAR(30) DEFAULT 'PENDING',
    created_by        UUID DEFAULT NULL REFERENCES users(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_so_tenant ON sales_orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_so_customer ON sales_orders(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_so_status ON sales_orders(status);
CREATE INDEX IF NOT EXISTS idx_so_quotation ON sales_orders(quotation_id);

CREATE TABLE IF NOT EXISTS sales_order_items (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    so_id             UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
    line_no           INTEGER NOT NULL DEFAULT 0,
    product_id        UUID NOT NULL REFERENCES products(id),
    quotation_item_id UUID DEFAULT NULL,
    description       TEXT DEFAULT '',
    quantity          DECIMAL(18,4) NOT NULL DEFAULT 1,
    allocated_qty     DECIMAL(18,4) NOT NULL DEFAULT 0,
    unit_of_measure   VARCHAR(20) DEFAULT 'EA',
    unit_price        DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_pct      DECIMAL(5,2) DEFAULT 0,
    line_total        DECIMAL(18,2) NOT NULL DEFAULT 0,
    delivery_date     DATE DEFAULT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_so_items_so ON sales_order_items(so_id);

COMMENT ON TABLE sales_orders IS 'Sales orders with shipping/billing & automated checks';
COMMENT ON COLUMN sales_orders.status IS 'DRAFT, CONFIRMED, SHIPPED, INVOICED, CANCELLED';
COMMENT ON COLUMN sales_orders.credit_check_status IS 'PENDING, PASSED, FAILED, SKIPPED';
COMMENT ON COLUMN sales_orders.inventory_check_status IS 'PENDING, AVAILABLE, PARTIAL, UNAVAILABLE';
COMMENT ON COLUMN sales_orders.tax_calc_status IS 'PENDING, CALCULATED, SKIPPED';
COMMENT ON COLUMN sales_orders.allocation_status IS 'PENDING, ALLOCATED, PARTIAL, NOT_ALLOCATED';
