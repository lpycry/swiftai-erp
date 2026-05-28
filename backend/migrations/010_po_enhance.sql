-- ============================================================
-- SwiftAI ERP - PO Enhancement: Delivery dates, addresses,
-- payment terms, attachments
-- Migration 010: Purchase Order Enhancements
-- ============================================================

-- ============================================================
-- Add columns to purchase_orders
-- ============================================================
ALTER TABLE purchase_orders
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id),
    ADD COLUMN IF NOT EXISTS po_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS payment_term_code VARCHAR(30),
    ADD COLUMN IF NOT EXISTS delivery_address TEXT,
    ADD COLUMN IF NOT EXISTS incoterm_code VARCHAR(10);

-- ============================================================
-- Add columns to purchase_order_items
-- ============================================================
ALTER TABLE purchase_order_items
    ADD COLUMN IF NOT EXISTS expected_delivery_date DATE,
    ADD COLUMN IF NOT EXISTS delivery_address TEXT;

-- ============================================================
-- Purchase Order Attachments (采购订单附件)
-- ============================================================
CREATE TABLE IF NOT EXISTS po_attachments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_id           UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    file_name       VARCHAR(255) NOT NULL,
    file_type       VARCHAR(50) NOT NULL,
    file_size       BIGINT NOT NULL DEFAULT 0,
    file_path       TEXT NOT NULL,
    description     TEXT,
    uploaded_by     UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_po_attachments_po ON po_attachments(po_id);
CREATE INDEX IF NOT EXISTS idx_po_attachments_org ON po_attachments(org_id);
