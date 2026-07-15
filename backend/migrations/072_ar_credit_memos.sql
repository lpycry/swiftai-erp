CREATE TABLE IF NOT EXISTS ar_credit_memos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    memo_no VARCHAR(30) NOT NULL,
    customer_id UUID NOT NULL REFERENCES customers(id),
    memo_date DATE NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    reason_code VARCHAR(60) NOT NULL DEFAULT '',
    amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    remaining_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
    journal_entry_id UUID REFERENCES gl_journal_entries(id),
    clearing_id UUID,
    description TEXT DEFAULT '',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, memo_no)
);

CREATE TABLE IF NOT EXISTS ar_credit_memo_clearings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    clearing_no VARCHAR(30) NOT NULL,
    customer_id UUID NOT NULL REFERENCES customers(id),
    posting_date DATE NOT NULL,
    document_date DATE NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    control_type VARCHAR(30) NOT NULL DEFAULT 'offset',
    credit_total NUMERIC(18,2) NOT NULL DEFAULT 0,
    invoice_applied_total NUMERIC(18,2) NOT NULL DEFAULT 0,
    net_balance NUMERIC(18,2) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'POSTED',
    journal_entry_id UUID REFERENCES gl_journal_entries(id),
    description TEXT DEFAULT '',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, clearing_no)
);

CREATE TABLE IF NOT EXISTS ar_credit_memo_clearing_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clearing_id UUID NOT NULL REFERENCES ar_credit_memo_clearings(id) ON DELETE CASCADE,
    credit_memo_id UUID REFERENCES ar_credit_memos(id),
    reason_code VARCHAR(60) NOT NULL DEFAULT '',
    amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ar_credit_memo_clearing_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clearing_id UUID NOT NULL REFERENCES ar_credit_memo_clearings(id) ON DELETE CASCADE,
    credit_memo_id UUID REFERENCES ar_credit_memos(id),
    invoice_id UUID NOT NULL REFERENCES sales_invoices(id),
    apply_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ar_credit_memos_customer ON ar_credit_memos(tenant_id, customer_id, status);
CREATE INDEX IF NOT EXISTS idx_ar_credit_clearings_customer ON ar_credit_memo_clearings(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_ar_credit_clear_inv ON ar_credit_memo_clearing_invoices(invoice_id);
