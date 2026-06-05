-- ============================================================
-- SwiftAI ERP - Sales Orders (SAP VA01 style)
-- Supports: OR, EC, CS, RM, CN, ST, SP order types
-- ============================================================

CREATE TABLE IF NOT EXISTS sales_orders (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id         UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    order_no            VARCHAR(20) NOT NULL,
    order_type          VARCHAR(4) NOT NULL DEFAULT 'OR',  -- OR/EC/CS/RM/CN/ST/SP
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT', -- DRAFT/OPEN/CONFIRMED/SHIPPED/INVOICED/COMPLETED/REJECTED
    currency            VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_terms       VARCHAR(20) DEFAULT 'Net 30',
    incoterm            VARCHAR(20),
    order_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    delivery_date       DATE,
    requested_ship_date DATE,
    employee_id         UUID REFERENCES employee_base(id) ON DELETE SET NULL,
    total_amount        NUMERIC(18,2) NOT NULL DEFAULT 0,
    discount_pct        NUMERIC(5,2) NOT NULL DEFAULT 0,
    discount_amount     NUMERIC(18,2) NOT NULL DEFAULT 0,
    net_amount          NUMERIC(18,2) NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(18,2) NOT NULL DEFAULT 0,
    grand_total         NUMERIC(18,2) NOT NULL DEFAULT 0,
    notes               TEXT,
    internal_notes      TEXT,
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, order_no)
);

CREATE TABLE IF NOT EXISTS sales_order_items (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sales_order_id      UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
    line_no             INTEGER NOT NULL DEFAULT 10,
    product_id          UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    description         TEXT,
    quantity            NUMERIC(18,4) NOT NULL DEFAULT 1,
    unit_of_measure     VARCHAR(10) NOT NULL DEFAULT 'EA',
    unit_price          NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount_pct        NUMERIC(5,2) NOT NULL DEFAULT 0,
    line_total          NUMERIC(18,2) NOT NULL DEFAULT 0,
    delivery_date       DATE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_so_tenant ON sales_orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_so_customer ON sales_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_so_status ON sales_orders(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_so_type ON sales_orders(tenant_id, order_type);
CREATE INDEX IF NOT EXISTS idx_soi_order ON sales_order_items(sales_order_id);

CREATE TRIGGER trg_sales_orders_updated
    BEFORE UPDATE ON sales_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE  sales_orders               IS 'Sales orders (OR/EC/CS/RM/CN/ST/SP)';
COMMENT ON COLUMN sales_orders.order_type    IS 'OR=Standard, EC=Commerce, CS=Cash Sale, RM=Return, CN=Consignment, ST=Stock Transfer, SP=Sample';
COMMENT ON COLUMN sales_orders.status        IS 'DRAFT→OPEN→CONFIRMED→SHIPPED→INVOICED→COMPLETED';
