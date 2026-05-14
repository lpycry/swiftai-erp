-- ============================================================
-- SwiftAI ERP - General Ledger Schema
-- Phase 2: Chart of Accounts, Journal Entries, Periods
-- ============================================================

-- ============================================================
-- 1. CHART OF ACCOUNTS (科目表)
-- ============================================================
CREATE TABLE IF NOT EXISTS gl_accounts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    account_code    VARCHAR(20) NOT NULL,        -- 1001, 1101, 2001...
    account_name    VARCHAR(255) NOT NULL,
    account_type    VARCHAR(20) NOT NULL,        -- asset, liability, equity, revenue, expense
    parent_id       UUID REFERENCES gl_accounts(id),
    level           INT NOT NULL DEFAULT 1,      -- 1=root, 2=group, 3=detail
    is_active       BOOLEAN NOT NULL DEFAULT true,
    is_leaf         BOOLEAN NOT NULL DEFAULT true,
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, account_code)
);

CREATE INDEX IF NOT EXISTS idx_gl_accounts_tenant ON gl_accounts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_gl_accounts_type ON gl_accounts(tenant_id, account_type);
CREATE INDEX IF NOT EXISTS idx_gl_accounts_parent ON gl_accounts(parent_id);
CREATE INDEX IF NOT EXISTS idx_gl_accounts_leaf ON gl_accounts(tenant_id, is_leaf) WHERE is_leaf = true;

-- ============================================================
-- 2. FISCAL PERIODS (会计期间)
-- ============================================================
CREATE TABLE IF NOT EXISTS gl_periods (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    fiscal_year     INT NOT NULL,
    period_no       INT NOT NULL CHECK (period_no >= 1 AND period_no <= 12),
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    is_open         BOOLEAN NOT NULL DEFAULT true,
    is_locked       BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, fiscal_year, period_no)
);

CREATE INDEX IF NOT EXISTS idx_gl_periods_tenant ON gl_periods(tenant_id);
CREATE INDEX IF NOT EXISTS idx_gl_periods_open ON gl_periods(tenant_id, is_open) WHERE is_open = true;

-- ============================================================
-- 3. JOURNAL ENTRIES (记账凭证头)
-- ============================================================
CREATE TABLE IF NOT EXISTS gl_journal_entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    document_no     VARCHAR(30) NOT NULL,
    posting_date    DATE NOT NULL,
    period_id       UUID NOT NULL REFERENCES gl_periods(id),
    description     VARCHAR(500) NOT NULL,
    reference       VARCHAR(100),                -- external reference number
    entry_type      VARCHAR(20) NOT NULL DEFAULT 'normal',  -- normal, adjusting, reversal, accrual
    status          VARCHAR(20) NOT NULL DEFAULT 'draft',   -- draft, posted, reversed
    source          VARCHAR(20) NOT NULL DEFAULT 'manual',  -- manual, ai, import, bank
    ai_confidence   REAL DEFAULT 0,              -- 0-1 for AI-generated
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    posted_at       TIMESTAMPTZ,
    posted_by       UUID REFERENCES users(id),
    UNIQUE(tenant_id, document_no)
);

CREATE INDEX IF NOT EXISTS idx_gl_entries_tenant ON gl_journal_entries(tenant_id);
CREATE INDEX IF NOT EXISTS idx_gl_entries_status ON gl_journal_entries(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_gl_entries_period ON gl_journal_entries(period_id);
CREATE INDEX IF NOT EXISTS idx_gl_entries_document ON gl_journal_entries(tenant_id, document_no);
CREATE INDEX IF NOT EXISTS idx_gl_entries_created ON gl_journal_entries(created_at);

-- ============================================================
-- 4. JOURNAL LINES (记账凭证行)
-- ============================================================
CREATE TABLE IF NOT EXISTS gl_journal_lines (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id        UUID NOT NULL REFERENCES gl_journal_entries(id) ON DELETE CASCADE,
    account_id      UUID NOT NULL REFERENCES gl_accounts(id),
    account_code    VARCHAR(20) NOT NULL,         -- denormalized
    account_name    VARCHAR(255) NOT NULL,        -- denormalized
    debit           NUMERIC(18,2) NOT NULL DEFAULT 0,
    credit          NUMERIC(18,2) NOT NULL DEFAULT 0,
    description     VARCHAR(500),
    cost_center_id  UUID,
    partner_id      UUID,
    partner_type    VARCHAR(20)                   -- customer, vendor
);

CREATE INDEX IF NOT EXISTS idx_gl_lines_entry ON gl_journal_lines(entry_id);
CREATE INDEX IF NOT EXISTS idx_gl_lines_account ON gl_journal_lines(account_id);

-- ============================================================
-- 5. DOCUMENT SEQUENCE (凭证编号序列)
-- ============================================================
CREATE TABLE IF NOT EXISTS gl_document_seq (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    prefix          VARCHAR(20) NOT NULL,         -- GL-YYYYMM-
    seq             INT NOT NULL DEFAULT 0,
    UNIQUE(tenant_id, prefix)
);

-- ============================================================
-- 6. ACCOUNT BALANCES (科目余额 - for performance)
-- ============================================================
CREATE TABLE IF NOT EXISTS gl_account_balances (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    account_id      UUID NOT NULL REFERENCES gl_accounts(id),
    period_id       UUID NOT NULL REFERENCES gl_periods(id),
    opening_balance NUMERIC(18,2) NOT NULL DEFAULT 0,
    period_debit    NUMERIC(18,2) NOT NULL DEFAULT 0,
    period_credit   NUMERIC(18,2) NOT NULL DEFAULT 0,
    closing_balance NUMERIC(18,2) NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, account_id, period_id)
);

CREATE INDEX IF NOT EXISTS idx_gl_balances_account ON gl_account_balances(account_id);
CREATE INDEX IF NOT EXISTS idx_gl_balances_period ON gl_account_balances(period_id);

-- ============================================================
-- 7. TRIGGERS
-- ============================================================
CREATE TRIGGER trg_gl_accounts_updated
    BEFORE UPDATE ON gl_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_gl_periods_updated
    BEFORE UPDATE ON gl_periods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 8. COMMENTS
-- ============================================================
COMMENT ON TABLE gl_accounts IS 'Chart of accounts with parent-child tree structure';
COMMENT ON TABLE gl_periods IS 'Fiscal periods controlling posting availability';
COMMENT ON TABLE gl_journal_entries IS 'Journal entry headers with document sequence';
COMMENT ON TABLE gl_journal_lines IS 'Individual line items with debit/credit amounts';
COMMENT ON TABLE gl_document_seq IS 'Sequential number generator for document numbering';
COMMENT ON TABLE gl_account_balances IS 'Materialized account balances by period for reporting';
