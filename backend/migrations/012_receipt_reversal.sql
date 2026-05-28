-- ============================================================
-- SwiftAI ERP - Purchase Receipt Reversal
-- Migration 012: Add reversal tracking columns
-- ============================================================

ALTER TABLE purchase_receipts
  ADD COLUMN IF NOT EXISTS reversed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reversal_receipt_id UUID REFERENCES purchase_receipts(id),
  ADD COLUMN IF NOT EXISTS is_reversed BOOLEAN NOT NULL DEFAULT false;
