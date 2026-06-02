-- Vendor Payment & Open Items Management
-- Adds paid_amount to invoices and creates payment tracking tables

ALTER TABLE purchase_invoices ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(18,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS vendor_payments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL,
    vendor_id       UUID NOT NULL,
    bank_account_id UUID,
    payment_amount  NUMERIC(18,2) NOT NULL,
    payment_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    status          VARCHAR(20) NOT NULL DEFAULT 'POSTED',
    gl_je_id        UUID,
    description     TEXT,
    created_by      UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vendor_payment_allocations (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id       UUID NOT NULL REFERENCES vendor_payments(id) ON DELETE CASCADE,
    source_type      VARCHAR(20) NOT NULL,  -- 'INVOICE' or 'DOWN_PAYMENT'
    source_id        UUID NOT NULL,
    allocated_amount NUMERIC(18,2) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vp_org ON vendor_payments(org_id);
CREATE INDEX IF NOT EXISTS idx_vp_vendor ON vendor_payments(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vpa_payment ON vendor_payment_allocations(payment_id);
CREATE INDEX IF NOT EXISTS idx_vpa_source ON vendor_payment_allocations(source_type, source_id);

CREATE OR REPLACE FUNCTION update_vendor_payments_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_vendor_payments_updated ON vendor_payments;
CREATE TRIGGER trg_vendor_payments_updated
    BEFORE UPDATE ON vendor_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
