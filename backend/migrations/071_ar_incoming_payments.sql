ALTER TABLE sales_invoices
    ADD COLUMN IF NOT EXISTS remaining_amount NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS clearing_status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
    ADD COLUMN IF NOT EXISTS clearing_voucher_id UUID;

UPDATE sales_invoices
SET remaining_amount = COALESCE(remaining_amount, total_amount),
    clearing_status = CASE
        WHEN COALESCE(remaining_amount, total_amount) <= 0 THEN 'CLEARED'
        WHEN status = 'PARTIALLY_CLEARED' THEN 'PARTIAL'
        ELSE 'OPEN'
    END
WHERE status <> 'CANCELLED';

CREATE TABLE IF NOT EXISTS ar_receipt_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    voucher_no VARCHAR(30) NOT NULL,
    customer_id UUID NOT NULL REFERENCES customers(id),
    bank_account_id UUID NOT NULL REFERENCES gl_accounts(id),
    receipt_date DATE NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    exchange_rate NUMERIC(18,6) NOT NULL DEFAULT 1,
    net_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    diff_type VARCHAR(40) NOT NULL DEFAULT '',
    diff_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    applied_total NUMERIC(18,2) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'POSTED',
    journal_entry_id UUID REFERENCES gl_journal_entries(id),
    description TEXT DEFAULT '',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, voucher_no)
);

CREATE TABLE IF NOT EXISTS ar_receipt_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id UUID NOT NULL REFERENCES ar_receipt_vouchers(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES sales_invoices(id),
    apply_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ar_receipts_customer ON ar_receipt_vouchers(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_ar_receipt_apps_invoice ON ar_receipt_applications(invoice_id);
