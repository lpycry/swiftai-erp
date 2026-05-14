-- ============================================================
-- SwiftAI ERP - GAAP Chart of Accounts Migration
-- Adds reconciliation_type column for AR/AP reconciliation
-- ============================================================

-- Add reconciliation_type to gl_accounts
ALTER TABLE gl_accounts ADD COLUMN IF NOT EXISTS reconciliation_type VARCHAR(20) DEFAULT 'none';
COMMENT ON COLUMN gl_accounts.reconciliation_type IS 'Reconciliation account type: none, customer, vendor, asset';
