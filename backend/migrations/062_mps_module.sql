CREATE TABLE IF NOT EXISTS product_independent_requirements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    requirement_date DATE NOT NULL,
    quantity NUMERIC(18,4) NOT NULL DEFAULT 0,
    consumed_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pir_tenant_product_date
ON product_independent_requirements(tenant_id, product_id, requirement_date);

CREATE TABLE IF NOT EXISTS mps_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    planning_mode VARCHAR(10) NOT NULL DEFAULT 'NETCH',
    planning_time_fence_enabled BOOLEAN NOT NULL DEFAULT true,
    planning_time_fence_days INTEGER NOT NULL DEFAULT 5,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    progress_percent INTEGER NOT NULL DEFAULT 0,
    progress_message TEXT NOT NULL DEFAULT '',
    started_by UUID,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_mps_runs_tenant_started
ON mps_runs(tenant_id, started_at DESC);

CREATE TABLE IF NOT EXISTS mps_planned_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    run_id UUID REFERENCES mps_runs(id) ON DELETE SET NULL,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    planned_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    due_date DATE NOT NULL,
    source VARCHAR(30) NOT NULL DEFAULT 'MPS',
    is_firmed BOOLEAN NOT NULL DEFAULT false,
    firmed_by UUID,
    firmed_at TIMESTAMPTZ,
    exception_code VARCHAR(10) DEFAULT '',
    exception_message TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mps_planned_orders_tenant_product
ON mps_planned_orders(tenant_id, product_id, due_date);

CREATE TABLE IF NOT EXISTS mps_dependent_demands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    run_id UUID REFERENCES mps_runs(id) ON DELETE CASCADE,
    parent_product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    component_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    component_mrp_type VARCHAR(10) NOT NULL DEFAULT 'MRP',
    demand_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    requirement_date DATE NOT NULL,
    action VARCHAR(30) NOT NULL DEFAULT 'DEPENDENT_DEMAND_ONLY',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mps_dependent_demands_run
ON mps_dependent_demands(run_id);

CREATE TABLE IF NOT EXISTS mps_exception_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    run_id UUID REFERENCES mps_runs(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    code VARCHAR(10) NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'WARNING',
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mps_exception_messages_run
ON mps_exception_messages(run_id);
