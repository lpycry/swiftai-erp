-- Customer Inquiries & Quotations (SAP-style: inquiry → quotation → sales order)
CREATE TABLE IF NOT EXISTS quotations (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id       UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    quotation_no      VARCHAR(50) NOT NULL,
    quotation_type    VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    status            VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    valid_from        DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to          DATE DEFAULT NULL,
    currency          VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_terms     VARCHAR(50) DEFAULT 'Net 30',
    incoterm          VARCHAR(30) DEFAULT '',
    delivery_date     DATE DEFAULT NULL,
    total_amount      DECIMAL(18,2) NOT NULL DEFAULT 0,
    discount_pct      DECIMAL(5,2) DEFAULT 0,
    discount_amount   DECIMAL(18,2) DEFAULT 0,
    net_amount        DECIMAL(18,2) NOT NULL DEFAULT 0,
    tax_amount        DECIMAL(18,2) DEFAULT 0,
    grand_total       DECIMAL(18,2) NOT NULL DEFAULT 0,
    notes             TEXT DEFAULT '',
    internal_notes    TEXT DEFAULT '',
    reference_inquiry TEXT DEFAULT '',
    created_by        UUID DEFAULT NULL REFERENCES users(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotations_tenant ON quotations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_quotations_customer ON quotations(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_quotations_status ON quotations(status);

CREATE TABLE IF NOT EXISTS quotation_items (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quotation_id      UUID NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    line_no           INTEGER NOT NULL DEFAULT 0,
    product_id        UUID NOT NULL REFERENCES products(id),
    description       TEXT DEFAULT '',
    quantity          DECIMAL(18,4) NOT NULL DEFAULT 1,
    unit_of_measure   VARCHAR(20) DEFAULT 'EA',
    unit_price        DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_pct      DECIMAL(5,2) DEFAULT 0,
    line_total        DECIMAL(18,2) NOT NULL DEFAULT 0,
    delivery_date     DATE DEFAULT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotation_items_q ON quotation_items(quotation_id);

COMMENT ON TABLE quotations IS 'Customer quotations (SAP VA21/VA22/VA23)';
COMMENT ON TABLE quotation_items IS 'Quotation line items';
COMMENT ON COLUMN quotations.quotation_type IS 'STANDARD, INQUIRY, SERVICE, PROPOSAL';
COMMENT ON COLUMN quotations.status IS 'DRAFT, OPEN, ACCEPTED, REJECTED, EXPIRED, CONVERTED';
