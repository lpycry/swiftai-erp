ALTER TABLE gl_journal_lines
    ADD COLUMN IF NOT EXISTS open_item_status VARCHAR(20) NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS clearing_doc_id UUID REFERENCES gl_journal_entries(id),
    ADD COLUMN IF NOT EXISTS clearing_date DATE,
    ADD COLUMN IF NOT EXISTS cleared_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_gl_lines_open_items
    ON gl_journal_lines(account_id, open_item_status);

CREATE INDEX IF NOT EXISTS idx_gl_lines_clearing_doc
    ON gl_journal_lines(clearing_doc_id);
