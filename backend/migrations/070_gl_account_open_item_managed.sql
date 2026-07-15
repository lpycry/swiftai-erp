-- Add open item management flag to Chart of Accounts.
-- Only accounts with this flag enabled create uncleared line items for clearing/reconciliation.

ALTER TABLE gl_accounts
  ADD COLUMN IF NOT EXISTS open_item_managed BOOLEAN NOT NULL DEFAULT false;

UPDATE gl_accounts
SET open_item_managed = true
WHERE open_item_managed = false
  AND (
    COALESCE(reconciliation_type, 'none') IN ('customer', 'vendor')
    OR account_code IN ('1125', '2190')
    OR lower(account_name) LIKE '%clearing%'
    OR lower(account_name) LIKE '%gr/ir%'
  );

ALTER TABLE gl_journal_lines
  ADD COLUMN IF NOT EXISTS open_item_status VARCHAR(20) NOT NULL DEFAULT 'open';

UPDATE gl_journal_lines l
SET open_item_status = 'not_managed'
FROM gl_accounts a
WHERE l.account_id = a.id
  AND a.open_item_managed = false
  AND COALESCE(l.open_item_status, 'open') = 'open';

COMMENT ON COLUMN gl_accounts.open_item_managed IS
  'When true, posted journal lines remain open until cleared through open item clearing.';
