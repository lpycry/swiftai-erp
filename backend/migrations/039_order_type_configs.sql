-- ============================================================
-- SwiftAI ERP - Order Type Configuration Matrix
-- SAP-like config-driven order type engine
-- ============================================================

CREATE TABLE IF NOT EXISTS order_type_configs (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_type          VARCHAR(4) NOT NULL,
    description         VARCHAR(100) NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    is_system           BOOLEAN NOT NULL DEFAULT false,  -- system types cannot be deleted

    -- 1. Logistics & Stock Control
    requires_shipping       BOOLEAN NOT NULL DEFAULT true,
    shipping_direction      VARCHAR(20) NOT NULL DEFAULT 'outbound',  -- outbound / inbound / none
    auto_create_delivery    BOOLEAN NOT NULL DEFAULT false,
    auto_pgi_pgr            BOOLEAN NOT NULL DEFAULT false,
    target_stock_type       VARCHAR(30) NOT NULL DEFAULT 'unrestricted',  -- unrestricted / quality_inspection / consignment / in_transit

    -- 2. Risk & Validation Control
    credit_check_required   BOOLEAN NOT NULL DEFAULT false,
    atp_check_logic         VARCHAR(20) NOT NULL DEFAULT 'hard',  -- hard / soft / none
    reference_required      BOOLEAN NOT NULL DEFAULT false,

    -- 3. Pricing & Finance Control
    pricing_procedure       VARCHAR(30) NOT NULL DEFAULT 'standard',  -- standard / zero_price / intercompany
    billing_trigger         VARCHAR(30) NOT NULL DEFAULT 'post_delivery',  -- order_save / post_delivery / none
    billing_type            VARCHAR(20) NOT NULL DEFAULT 'invoice',  -- invoice / credit_memo / none
    gl_account_strategy     VARCHAR(30) NOT NULL DEFAULT 'standard_sales',  -- standard_sales / sales_expense / intercompany_trade / none

    -- 4. Block Control
    billing_block_default   BOOLEAN NOT NULL DEFAULT false,

    -- Meta
    sort_order          INTEGER NOT NULL DEFAULT 0,
    created_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, order_type)
);

CREATE INDEX IF NOT EXISTS idx_otc_tenant ON order_type_configs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_otc_active ON order_type_configs(tenant_id, is_active);

CREATE TRIGGER trg_order_type_configs_updated
    BEFORE UPDATE ON order_type_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE  order_type_configs               IS 'Order type configuration matrix driving SD/MM/FI behavior';
COMMENT ON COLUMN order_type_configs.order_type    IS 'OR=Standard, EC=E-Commerce, CS=Cash Sale, RE=Return, CF=Consignment Fill-up, CI=Consignment Issue, ST=Stock Transfer, SD=Sample';

-- ============================================================
-- Seed Data — 8 default order types
-- ============================================================
INSERT INTO order_type_configs (id, tenant_id, order_type, description, is_system, sort_order,
    requires_shipping, shipping_direction, auto_create_delivery, auto_pgi_pgr, target_stock_type,
    credit_check_required, atp_check_logic, reference_required,
    pricing_procedure, billing_trigger, billing_type, gl_account_strategy,
    billing_block_default)
SELECT
    gen_random_uuid(), t.id, ot.*
FROM tenants t
CROSS JOIN (VALUES
    -- 1. Standard Order (SO)
    ('OR', 'Standard Order',       true, 1,  true,  'outbound',   false, false, 'unrestricted',       true,  'hard',  false, 'standard',          'post_delivery', 'invoice',       'standard_sales',       false),
    -- 2. E-Commerce Order (ECO)
    ('EC', 'E-Commerce Order',     true, 2,  true,  'outbound',   true,  false, 'unrestricted',       false, 'soft',  false, 'standard',          'order_save',    'invoice',       'standard_sales',       false),
    -- 3. Cash Sale (CS)
    ('CS', 'Cash Sale',            true, 3,  true,  'outbound',   true,  true,  'unrestricted',       false, 'hard',  false, 'standard',          'order_save',    'invoice',       'standard_sales',       false),
    -- 4. Return Order (RE)
    ('RE', 'Return Order',         true, 4,  true,  'inbound',    false, false, 'quality_inspection',  false, 'none',  true,  'standard',          'post_delivery', 'credit_memo',   'sales_expense',        false),
    -- 5. Consignment Fill-up (CF)
    ('CF', 'Consignment Fill-up',  true, 5,  true,  'outbound',   false, false, 'consignment',         true,  'hard',  false, 'standard',          'none',          'none',          'none',                 false),
    -- 6. Consignment Issue (CI)
    ('CI', 'Consignment Issue',    true, 6,  false, 'none',       false, false, 'consignment',         true,  'hard',  false, 'standard',          'order_save',    'invoice',       'standard_sales',       false),
    -- 7. Stock Transfer (STO)
    ('ST', 'Stock Transfer',       true, 7,  true,  'outbound',   false, false, 'in_transit',          false, 'hard',  false, 'intercompany',      'post_delivery', 'invoice',       'intercompany_trade',   false),
    -- 8. Sample Order (SD)
    ('SD', 'Sample Order',         true, 8,  true,  'outbound',   false, false, 'unrestricted',       false, 'hard',  false, 'zero_price',        'post_delivery', 'invoice',       'sales_expense',        true)
) AS ot(order_type, description, is_system, sort_order, requires_shipping, shipping_direction, auto_create_delivery, auto_pgi_pgr, target_stock_type, credit_check_required, atp_check_logic, reference_required, pricing_procedure, billing_trigger, billing_type, gl_account_strategy, billing_block_default)
ON CONFLICT (tenant_id, order_type) DO NOTHING;
