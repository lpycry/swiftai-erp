-- ============================================================
-- SwiftAI ERP - Journal Entry Enhancements
-- Org integration, attachments, enhanced validation
-- ============================================================

-- 1. Add organization_id to journal entries
ALTER TABLE gl_journal_entries ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);
CREATE INDEX IF NOT EXISTS idx_gl_entries_org ON gl_journal_entries(organization_id);

-- 2. Add document date (separate from posting date)
ALTER TABLE gl_journal_entries ADD COLUMN IF NOT EXISTS document_date DATE;

-- 3. Attachments for journal entries
CREATE TABLE IF NOT EXISTS gl_entry_attachments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id        UUID NOT NULL REFERENCES gl_journal_entries(id) ON DELETE CASCADE,
    file_name       VARCHAR(255) NOT NULL,
    file_type       VARCHAR(50) NOT NULL,        -- image/png, application/pdf, etc
    file_size       BIGINT NOT NULL DEFAULT 0,
    file_path       VARCHAR(500) NOT NULL,       -- storage path
    description     VARCHAR(255),
    uploaded_by     UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gl_attachments_entry ON gl_entry_attachments(entry_id);

COMMENT ON COLUMN gl_journal_entries.organization_id IS 'Company code (legal entity) for the entry';
COMMENT ON COLUMN gl_journal_entries.document_date IS 'Document date (can differ from posting date)';
COMMENT ON TABLE gl_entry_attachments IS 'Supporting documents attached to journal entries';
