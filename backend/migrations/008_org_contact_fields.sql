-- ============================================================
-- SwiftAI ERP - Add contact fields to organizations
-- ============================================================

ALTER TABLE organizations
    ADD COLUMN IF NOT EXISTS email   VARCHAR(255),
    ADD COLUMN IF NOT EXISTS phone   VARCHAR(50),
    ADD COLUMN IF NOT EXISTS website VARCHAR(500);

COMMENT ON COLUMN organizations.email   IS 'Contact email address';
COMMENT ON COLUMN organizations.phone   IS 'Contact phone number';
COMMENT ON COLUMN organizations.website IS 'Website URL';
