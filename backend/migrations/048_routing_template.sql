-- Routing Template + Work Center (PRD: 工艺模板)
-- Rebuilds work_centers and creates routing_templates (not bound to products)

-- ════════════════════════════════════════════════════════════
-- WORK CENTERS (daily capacity, efficiency, cost)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS work_centers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code                VARCHAR(50) NOT NULL,
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    work_center_type    VARCHAR(30) NOT NULL DEFAULT 'machine',
    available_capacity  DECIMAL(12,2) NOT NULL DEFAULT 8.00,
    efficiency_rate     DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    cost_per_hour       DECIMAL(18,4) NOT NULL DEFAULT 0,
    plant_location      VARCHAR(100),
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_wc_tenant ON work_centers(tenant_id);

-- ════════════════════════════════════════════════════════════
-- ROUTING TEMPLATES (NOT bound to products — reusable)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS routing_templates (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    template_code       VARCHAR(50) NOT NULL,
    template_name       VARCHAR(255) NOT NULL,
    description         TEXT,
    version             VARCHAR(10) NOT NULL DEFAULT 'V1',
    status              VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',
    total_setup_min     DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_run_min       DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, template_code)
);

CREATE INDEX IF NOT EXISTS idx_rt_tenant ON routing_templates(tenant_id);

COMMENT ON COLUMN routing_templates.template_code IS 'Template code (e.g. RT-LAMP-ASSY)';
COMMENT ON COLUMN routing_templates.status IS 'ACTIVE, INACTIVE';
COMMENT ON COLUMN routing_templates.total_setup_min IS 'Total setup time across all operations (auto-calculated)';
COMMENT ON COLUMN routing_templates.total_run_min IS 'Total run time across all operations (auto-calculated)';

-- ════════════════════════════════════════════════════════════
-- TEMPLATE OPERATIONS (sequenced steps within a template)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS template_operations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    template_id         UUID NOT NULL REFERENCES routing_templates(id) ON DELETE CASCADE,
    operation_no        INTEGER NOT NULL,
    operation_name      VARCHAR(255) NOT NULL,
    description         TEXT,
    work_center_id      UUID NOT NULL REFERENCES work_centers(id),
    setup_time_min      DECIMAL(10,2) NOT NULL DEFAULT 0,
    run_time_min        DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_to_template ON template_operations(template_id);
CREATE INDEX IF NOT EXISTS idx_to_wc ON template_operations(work_center_id);

COMMENT ON COLUMN template_operations.operation_no IS 'Sequence number (10, 20, 30...)';
COMMENT ON COLUMN template_operations.setup_time_min IS 'Standard setup/preparation time in minutes';
COMMENT ON COLUMN template_operations.run_time_min IS 'Standard machine/run time per unit in minutes';

-- ════════════════════════════════════════════════════════════
-- TRIGGERS
-- ════════════════════════════════════════════════════════════
CREATE TRIGGER trg_work_centers_updated
    BEFORE UPDATE ON work_centers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_routing_templates_updated
    BEFORE UPDATE ON routing_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_template_operations_updated
    BEFORE UPDATE ON template_operations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
