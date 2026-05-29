-- ============================================================
-- SwiftAI ERP - Down Payment Module
-- Migration 013: Create down payment, clearing, and refund tables
-- ============================================================

-- 1. Down Payment Main Table
CREATE TABLE IF NOT EXISTS purchase_down_payments (
    id              UUID PRIMARY KEY,
    org_id          UUID NOT NULL,
    dp_number       VARCHAR(50) NOT NULL,
    vendor_id       UUID NOT NULL,
    vendor_code     VARCHAR(50) NOT NULL DEFAULT '',
    vendor_name     VARCHAR(255) NOT NULL DEFAULT '',
    po_id           UUID NOT NULL,
    po_number       VARCHAR(50) NOT NULL DEFAULT '',
    total_amount    DECIMAL(18,2) NOT NULL DEFAULT 0,
    paid_amount     DECIMAL(18,2) NOT NULL DEFAULT 0,
    refunded_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    cleared_amount  DECIMAL(18,2) NOT NULL DEFAULT 0,
    remaining_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    exchange_rate   DECIMAL(18,6) NOT NULL DEFAULT 1,
    ap_dp_account_id UUID NOT NULL,
    credit_account_id UUID NOT NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    -- DRAFT, POSTED, PARTIALLY_CLEARED, FULLY_CLEARED, PARTIALLY_REFUNDED, FULLY_REFUNDED
    payment_status  VARCHAR(30) NOT NULL DEFAULT 'UNPAID',
    -- UNPAID, PAID, REFUNDED
    gl_je_id        UUID,
    payment_gl_je_id UUID,
    description     TEXT,
    reference_no    VARCHAR(100),
    special_gl_indicator VARCHAR(10) NOT NULL DEFAULT 'A',
    created_by      UUID,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_by      UUID,
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    posted_by       UUID,
    posted_at       TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dp_org ON purchase_down_payments(org_id);
CREATE INDEX IF NOT EXISTS idx_dp_vendor ON purchase_down_payments(vendor_id);
CREATE INDEX IF NOT EXISTS idx_dp_po ON purchase_down_payments(po_id);
CREATE INDEX IF NOT EXISTS idx_dp_status ON purchase_down_payments(status);
CREATE INDEX IF NOT EXISTS idx_dp_number ON purchase_down_payments(dp_number);

-- 2. Down Payment Clearing Detail Table
CREATE TABLE IF NOT EXISTS purchase_dp_clearings (
    id              UUID PRIMARY KEY,
    dp_id           UUID NOT NULL REFERENCES purchase_down_payments(id),
    invoice_id      UUID NOT NULL,
    invoice_number  VARCHAR(50) NOT NULL DEFAULT '',
    clearing_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    gl_je_id        UUID,
    notes           TEXT,
    created_by      UUID,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dp_clear_dp ON purchase_dp_clearings(dp_id);
CREATE INDEX IF NOT EXISTS idx_dp_clear_inv ON purchase_dp_clearings(invoice_id);

-- 3. Down Payment Refund Table
CREATE TABLE IF NOT EXISTS purchase_dp_refunds (
    id              UUID PRIMARY KEY,
    dp_id           UUID NOT NULL REFERENCES purchase_down_payments(id),
    refund_amount   DECIMAL(18,2) NOT NULL DEFAULT 0,
    refund_date     DATE NOT NULL,
    refund_method   VARCHAR(30) NOT NULL DEFAULT 'BANK_TRANSFER',
    -- BANK_TRANSFER, CASH, CHECK, OTHER
    source_account_id UUID NOT NULL,
    gl_je_id        UUID,
    payment_gl_je_id UUID,
    reason          TEXT NOT NULL,
    created_by      UUID,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dp_refund_dp ON purchase_dp_refunds(dp_id);
