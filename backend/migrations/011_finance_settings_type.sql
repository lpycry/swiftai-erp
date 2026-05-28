-- ============================================================
-- SwiftAI ERP - Finance Settings: Account Type
-- Migration 011: Add account_type to org_reconciliation_accounts
-- ============================================================

ALTER TABLE org_reconciliation_accounts
  ADD COLUMN IF NOT EXISTS account_type VARCHAR(50) NOT NULL DEFAULT '';

-- Migrate existing data: set account_type from reconciliation_type
UPDATE org_reconciliation_accounts
  SET account_type = reconciliation_type
  WHERE account_type = '';

-- Drop old unique constraint on (org_id, reconciliation_type) if it exists,
-- then create unique constraint on (org_id, account_type).
-- Postgres auto-names the constraint; drop with a safe approach.

DO $$
BEGIN
  -- Drop the unique constraint if it exists (from the old ON CONFLICT design)
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'org_reconciliation_accounts'::regclass
      AND conname LIKE '%org_id_reconciliation_type%'
  ) THEN
    EXECUTE (
      SELECT 'ALTER TABLE org_reconciliation_accounts DROP CONSTRAINT ' || conname
      FROM pg_constraint
      WHERE conrelid = 'org_reconciliation_accounts'::regclass
        AND conname LIKE '%org_id_reconciliation_type%'
      LIMIT 1
    );
  END IF;
END $$;

-- Add unique constraint on (org_id, account_type) — one account per type per company
ALTER TABLE org_reconciliation_accounts
  ADD CONSTRAINT uq_org_account_type UNIQUE (org_id, account_type);

-- Set account_type NOT NULL now that data is migrated
ALTER TABLE org_reconciliation_accounts
  ALTER COLUMN account_type SET NOT NULL;
