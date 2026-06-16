-- Production Module: BOM, Work Center & Routing
-- BOM (Bill of Materials), Work Center, Routing / Operations

-- ════════════════════════════════════════════════════════════
-- WORK CENTER
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS work_centers (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code                VARCHAR(50) NOT NULL,
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    work_center_type    VARCHAR(30) NOT NULL DEFAULT 'machine',
    -- work_center_type: machine, assembly, labor, inspection
    available_capacity  DECIMAL(12,2) NOT NULL DEFAULT 8.00,  -- daily standard hours
    efficiency_rate     DECIMAL(5,2) NOT NULL DEFAULT 1.00,   -- factor
    cost_per_hour       DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_center_id      UUID,  -- optional FK to cost centers
    plant_location      VARCHAR(100),
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_wc_tenant ON work_centers(tenant_id);

-- ════════════════════════════════════════════════════════════
-- BOM HEADER (supports versioning & validity)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bom_headers (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id          UUID NOT NULL REFERENCES products(id),
    bom_version         VARCHAR(30) NOT NULL DEFAULT 'V1',
    description         TEXT,
    valid_from          DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to            DATE,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    is_default          BOOLEAN NOT NULL DEFAULT false,
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, product_id, bom_version)
);

CREATE INDEX IF NOT EXISTS idx_bomh_tenant ON bom_headers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_bomh_product ON bom_headers(product_id);

-- ════════════════════════════════════════════════════════════
-- BOM LINE ITEMS (parent-child tree via parent_bom_item_id)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bom_items (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    bom_header_id       UUID NOT NULL REFERENCES bom_headers(id) ON DELETE CASCADE,
    parent_item_id      UUID REFERENCES bom_items(id) ON DELETE CASCADE,  -- for sub-assemblies
    sort_order          INTEGER NOT NULL DEFAULT 0,
    -- Component product
    component_id        UUID NOT NULL REFERENCES products(id),
    component_sku       VARCHAR(100),
    component_name      VARCHAR(255),
    quantity            DECIMAL(18,4) NOT NULL DEFAULT 1.0000,
    uom                 VARCHAR(20) NOT NULL DEFAULT 'EA',
    scrap_factor        DECIMAL(5,4) NOT NULL DEFAULT 0.0000,  -- e.g. 0.02 = 2%
    -- BOM type
    item_type           VARCHAR(20) NOT NULL DEFAULT 'material',
    -- item_type: material, phantom, tool, service
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bomi_header ON bom_items(bom_header_id);
CREATE INDEX IF NOT EXISTS idx_bomi_parent ON bom_items(parent_item_id);
CREATE INDEX IF NOT EXISTS idx_bomi_component ON bom_items(component_id);

-- ════════════════════════════════════════════════════════════
-- ROUTING HEADER (one per product + version)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS routings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id          UUID NOT NULL REFERENCES products(id),
    routing_version     VARCHAR(30) NOT NULL DEFAULT 'V1',
    description         TEXT,
    valid_from          DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to            DATE,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    is_default          BOOLEAN NOT NULL DEFAULT false,
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, product_id, routing_version)
);

CREATE INDEX IF NOT EXISTS idx_rout_tenant ON routings(tenant_id);
CREATE INDEX IF NOT EXISTS idx_rout_product ON routings(product_id);

-- ════════════════════════════════════════════════════════════
-- ROUTING OPERATIONS (sequenced steps)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS routing_operations (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    routing_id          UUID NOT NULL REFERENCES routings(id) ON DELETE CASCADE,
    operation_no        INTEGER NOT NULL,
    operation_name      VARCHAR(255) NOT NULL,
    description         TEXT,
    work_center_id      UUID NOT NULL REFERENCES work_centers(id),
    setup_time_minutes  DECIMAL(10,2) NOT NULL DEFAULT 0,   -- setup/preparation hours
    machine_time_minutes DECIMAL(10,2) NOT NULL DEFAULT 0,   -- machine run hours
    labor_time_minutes  DECIMAL(10,2) NOT NULL DEFAULT 0,    -- labor hours
    queue_time_minutes  DECIMAL(10,2) NOT NULL DEFAULT 0,    -- queue/wait hours
    overlap_percent     DECIMAL(5,2) DEFAULT 0,             -- overlap % with prev op
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routop_routing ON routing_operations(routing_id);
CREATE INDEX IF NOT EXISTS idx_routop_wc ON routing_operations(work_center_id);

-- ════════════════════════════════════════════════════════════
-- TRIGGERS
-- ════════════════════════════════════════════════════════════
CREATE TRIGGER trg_work_centers_updated
    BEFORE UPDATE ON work_centers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_bom_headers_updated
    BEFORE UPDATE ON bom_headers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_bom_items_updated
    BEFORE UPDATE ON bom_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_routings_updated
    BEFORE UPDATE ON routings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_routing_operations_updated
    BEFORE UPDATE ON routing_operations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
