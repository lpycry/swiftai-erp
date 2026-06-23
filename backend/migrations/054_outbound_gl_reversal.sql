ALTER TABLE outbound_orders
    ADD COLUMN IF NOT EXISTS gl_je_id UUID REFERENCES gl_journal_entries(id),
    ADD COLUMN IF NOT EXISTS is_reversed BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS reversed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_outbound_orders_gl_je ON outbound_orders(gl_je_id);
CREATE INDEX IF NOT EXISTS idx_outbound_orders_reversed ON outbound_orders(tenant_id, is_reversed);
