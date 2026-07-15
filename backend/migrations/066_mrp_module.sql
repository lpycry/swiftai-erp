CREATE TABLE IF NOT EXISTS mrp_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    mps_run_id UUID REFERENCES mps_runs(id) ON DELETE SET NULL,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    planned_purchase_requisitions INTEGER NOT NULL DEFAULT 0,
    exceptions INTEGER NOT NULL DEFAULT 0,
    started_by UUID,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_mrp_runs_tenant_started
ON mrp_runs(tenant_id, started_at DESC);

CREATE TABLE IF NOT EXISTS mrp_planned_purchase_requisitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    run_id UUID REFERENCES mrp_runs(id) ON DELETE CASCADE,
    mps_run_id UUID REFERENCES mps_runs(id) ON DELETE SET NULL,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES vendors(id) ON DELETE SET NULL,
    info_record_id UUID REFERENCES purchasing_info_records(id) ON DELETE SET NULL,
    demand_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    net_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    order_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    due_date DATE NOT NULL,
    release_date DATE NOT NULL,
    purchase_uom VARCHAR(20) NOT NULL DEFAULT 'EA',
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'PLANNED',
    source VARCHAR(30) NOT NULL DEFAULT 'MRP',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mrp_planned_pr_tenant_product
ON mrp_planned_purchase_requisitions(tenant_id, product_id, due_date);

CREATE TABLE IF NOT EXISTS mrp_exception_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    run_id UUID REFERENCES mrp_runs(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'WARNING',
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mrp_exception_messages_run
ON mrp_exception_messages(run_id);
