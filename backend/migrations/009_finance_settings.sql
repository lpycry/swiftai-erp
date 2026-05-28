-- ============================================================
-- SwiftAI ERP - Finance Settings: Payment Terms & Incoterms
-- Migration 009: Finance configuration tables
-- ============================================================

-- ============================================================
-- PAYMENT TERMS (付款条件)
-- ============================================================
CREATE TABLE IF NOT EXISTS payment_terms (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL,
    code            VARCHAR(30) NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    due_days        INTEGER NOT NULL DEFAULT 0,
    discount_days   INTEGER DEFAULT 0,
    discount_pct    DECIMAL(5,2) DEFAULT 0,
    is_standard     BOOLEAN NOT NULL DEFAULT false,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

-- ============================================================
-- INCOTERMS 2020 (国际贸易术语)
-- ============================================================
CREATE TABLE IF NOT EXISTS incoterms (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL,
    code            VARCHAR(10) NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    category        VARCHAR(20) NOT NULL DEFAULT 'OTHER',  -- E, F, C, D
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

-- ============================================================
-- SEED: Standard Payment Terms
-- ============================================================
-- These is_standard=true rows serve as tenant-independent defaults.
-- Tenant-specific copies will be created on first access.
INSERT INTO payment_terms (tenant_id, code, name, description, due_days, discount_days, discount_pct, is_standard)
SELECT t.id, 'NET30',    'Net 30',          'Full payment due within 30 days',                   30,  0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'NET30')
UNION ALL
SELECT t.id, 'NET15',    'Net 15',          'Full payment due within 15 days',                   15,  0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'NET15')
UNION ALL
SELECT t.id, 'NET60',    'Net 60',          'Full payment due within 60 days',                   60,  0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'NET60')
UNION ALL
SELECT t.id, 'NET90',    'Net 90',          'Full payment due within 90 days',                   90,  0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'NET90')
UNION ALL
SELECT t.id, 'DUEONREC', 'Due on Receipt',  'Payment due immediately upon receipt',              0,   0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'DUEONREC')
UNION ALL
SELECT t.id, '2NET30',   '2/10 Net 30',     '2% discount if paid within 10 days, otherwise 30',  30,  10,  2.00, true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = '2NET30')
UNION ALL
SELECT t.id, '1NET30',   '1/10 Net 30',     '1% discount if paid within 10 days, otherwise 30',  30,  10,  1.00, true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = '1NET30')
UNION ALL
SELECT t.id, 'COD',      'Cash on Delivery','Payment due upon delivery of goods',                0,   0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'COD')
UNION ALL
SELECT t.id, 'PREPAID',  'Prepaid',         'Full payment required before shipment',             0,   0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'PREPAID')
UNION ALL
SELECT t.id, 'EOM',      'End of Month',    'Full payment due by end of invoice month',          30,  0,   0,    true
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM payment_terms WHERE code = 'EOM');

-- ============================================================
-- SEED: Standard Incoterms 2020
-- ============================================================
INSERT INTO incoterms (tenant_id, code, name, description, category)
SELECT t.id, 'EXW', 'Ex Works',
       'The seller makes goods available at their premises. Buyer bears all risks and costs from pickup.',
       'E'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'EXW')
UNION ALL
SELECT t.id, 'FCA', 'Free Carrier',
       'Seller delivers goods to carrier or nominated place. Risk transfers when goods are handed over.',
       'F'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'FCA')
UNION ALL
SELECT t.id, 'FAS', 'Free Alongside Ship',
       'Seller places goods alongside vessel at nominated port. Risk transfers at that point.',
       'F'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'FAS')
UNION ALL
SELECT t.id, 'FOB', 'Free On Board',
       'Seller loads goods on board vessel. Risk transfers once on board. Most common maritime term.',
       'F'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'FOB')
UNION ALL
SELECT t.id, 'CFR', 'Cost and Freight',
       'Seller pays cost and freight to destination port. Risk transfers at origin port.',
       'C'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'CFR')
UNION ALL
SELECT t.id, 'CIF', 'Cost, Insurance & Freight',
       'Like CFR plus seller provides insurance. Risk transfers at origin port.',
       'C'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'CIF')
UNION ALL
SELECT t.id, 'CPT', 'Carriage Paid To',
       'Seller pays carriage to named destination. Risk transfers to first carrier.',
       'C'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'CPT')
UNION ALL
SELECT t.id, 'CIP', 'Carriage & Insurance Paid',
       'Like CPT plus seller provides insurance. Risk transfers to first carrier.',
       'C'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'CIP')
UNION ALL
SELECT t.id, 'DAP', 'Delivered at Place',
       'Seller delivers goods to named destination. Buyer handles import clearance.',
       'D'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'DAP')
UNION ALL
SELECT t.id, 'DPU', 'Delivered at Place Unloaded',
       'Seller delivers and unloads at destination. Risk transfers at destination.',
       'D'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'DPU')
UNION ALL
SELECT t.id, 'DDP', 'Delivered Duty Paid',
       'Seller bears all risks and costs including duties to final destination. Maximum seller obligation.',
       'D'
FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM incoterms WHERE code = 'DDP');
