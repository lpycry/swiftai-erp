-- Credit Limits (SAP Credit Management)
CREATE TABLE IF NOT EXISTS credit_limits (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id       UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    credit_limit      DECIMAL(18,2) NOT NULL DEFAULT 0,
    used_credit       DECIMAL(18,2) NOT NULL DEFAULT 0,
    available_credit  DECIMAL(18,2) GENERATED ALWAYS AS (credit_limit - used_credit) STORED,
    currency          VARCHAR(3) NOT NULL DEFAULT 'USD',
    risk_category     VARCHAR(30) DEFAULT 'LOW',
    credit_status     VARCHAR(30) NOT NULL DEFAULT 'OK',
    last_reviewed     DATE DEFAULT NULL,
    reviewed_by       UUID DEFAULT NULL,
    notes             TEXT DEFAULT '',
    is_active         BOOLEAN NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_credit_limits_tenant ON credit_limits(tenant_id);
CREATE INDEX IF NOT EXISTS idx_credit_limits_customer ON credit_limits(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_credit_limits_status ON credit_limits(credit_status);

-- Customer Down Payments (AR Down Payments with auto GL posting)
CREATE TABLE IF NOT EXISTS customer_down_payments (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id       UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    org_id            UUID NOT NULL REFERENCES organizations(id),
    dp_type           VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    dp_number         VARCHAR(50) NOT NULL,
    amount            DECIMAL(18,2) NOT NULL,
    currency          VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_method    VARCHAR(30) DEFAULT 'BANK_TRANSFER',
    reference_no      VARCHAR(100) DEFAULT '',
    status            VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    dp_date           DATE NOT NULL,
    clearing_date     DATE DEFAULT NULL,
    description       TEXT DEFAULT '',
    gl_je_id          UUID DEFAULT NULL REFERENCES gl_journal_entries(id),
    gl_posting_status VARCHAR(30) DEFAULT 'PENDING',
    created_by        UUID DEFAULT NULL REFERENCES users(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cdp_tenant ON customer_down_payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_cdp_customer ON customer_down_payments(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_cdp_status ON customer_down_payments(status);

COMMENT ON TABLE credit_limits IS 'Customer credit limits (SAP credit management)';
COMMENT ON COLUMN credit_limits.risk_category IS 'LOW, MEDIUM, HIGH, CRITICAL';
COMMENT ON COLUMN credit_limits.credit_status IS 'OK, WARNING, EXCEEDED, BLOCKED';
COMMENT ON COLUMN customer_down_payments.dp_type IS 'STANDARD, PARTIAL, ADVANCE';
