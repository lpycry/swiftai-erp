-- ============================================================
-- SwiftAI ERP - Permission Engine Schema
-- Sprint 3: Authorization Objects, Role Enhancement, SoD
-- ============================================================

-- ============================================================
-- 1. AUTHORIZATION OBJECTS (权限对象定义)
-- ============================================================
CREATE TABLE IF NOT EXISTS auth_objects (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    object_class    VARCHAR(50) NOT NULL,       -- finance, logistics, admin
    object_code     VARCHAR(50) NOT NULL UNIQUE, -- F_GL_POST, M_MATE_STOCK
    description     TEXT,
    activities      TEXT[] NOT NULL DEFAULT '{}', -- create,read,update,delete,approve,print
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_objects_class ON auth_objects(object_class);

-- Authorization object fields (each object can have multiple fields)
CREATE TABLE IF NOT EXISTS auth_object_fields (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_object_id  UUID NOT NULL REFERENCES auth_objects(id) ON DELETE CASCADE,
    field_name      VARCHAR(100) NOT NULL,       -- company_code, plant, gl_account
    field_label     VARCHAR(255),
    field_type      VARCHAR(30) DEFAULT 'value',  -- org, account, value, general
    is_required     BOOLEAN DEFAULT false,
    display_order   INT DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(auth_object_id, field_name)
);

-- ============================================================
-- 2. ENHANCED ROLE MASTER (角色主数据增强)
-- ============================================================
CREATE TABLE IF NOT EXISTS role_master (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    role_id         VARCHAR(50) NOT NULL,         -- 角色编码 e.g. Z_ADMIN
    description     TEXT,
    role_type       VARCHAR(20) NOT NULL DEFAULT 'single',  -- single, composite, derived
    role_category   VARCHAR(50),                   -- finance, logistics, admin
    parent_role_id  UUID REFERENCES role_master(id),
    inherit_level   INT DEFAULT 0,
    is_system       BOOLEAN DEFAULT false,
    is_active       BOOLEAN DEFAULT true,
    valid_from      TIMESTAMPTZ,
    valid_to        TIMESTAMPTZ,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_role_master_tenant ON role_master(tenant_id);
CREATE INDEX IF NOT EXISTS idx_role_master_parent ON role_master(parent_role_id);

-- Data migration: copy existing roles to role_master
INSERT INTO role_master (id, tenant_id, role_id, description, role_type, is_system, is_active, created_at, updated_at)
SELECT id, tenant_id, name, description, 'single', is_system, true, created_at, updated_at
FROM roles
ON CONFLICT (tenant_id, role_id) DO NOTHING;

-- Composite role members (复合角色包含的子角色)
CREATE TABLE IF NOT EXISTS composite_role_members (
    composite_role_id UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    child_role_id     UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    PRIMARY KEY (composite_role_id, child_role_id)
);

-- Derived role rules (派生角色的限制条件)
CREATE TABLE IF NOT EXISTS derived_role_rules (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    derived_role_id   UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    base_role_id      UUID NOT NULL REFERENCES role_master(id),
    restriction_type  VARCHAR(50),     -- org_unit, company_code, plant
    restriction_value TEXT,            -- JSON condition
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User to Role assignments (with validity period)
CREATE TABLE IF NOT EXISTS user_role_assignments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id         UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    assignment_type VARCHAR(20) DEFAULT 'direct',  -- direct, derived, composite
    valid_from      TIMESTAMPTZ DEFAULT NOW(),
    valid_to        TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT true,
    assigned_by     UUID REFERENCES users(id),
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_user_role_assignments_user ON user_role_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_user_role_assignments_role ON user_role_assignments(role_id);

-- ============================================================
-- 3. ROLE AUTHORIZATION VALUES (角色权限值 - 核心)
-- ============================================================
CREATE TABLE IF NOT EXISTS role_auth_values (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id         UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    auth_object_id  UUID NOT NULL REFERENCES auth_objects(id),
    activity_create BOOLEAN DEFAULT false,
    activity_read   BOOLEAN DEFAULT false,
    activity_update BOOLEAN DEFAULT false,
    activity_delete BOOLEAN DEFAULT false,
    activity_approve BOOLEAN DEFAULT false,
    activity_print   BOOLEAN DEFAULT false,
    activity_transfer BOOLEAN DEFAULT false,
    activity_close   BOOLEAN DEFAULT false,
    field_values    JSONB DEFAULT '{}',     -- {"company_code": "1000", "plant": "PL01"}
    field_ranges    JSONB DEFAULT '{}',     -- {"gl_account": {"from": "400000", "to": "499999"}}
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(role_id, auth_object_id)
);

CREATE INDEX IF NOT EXISTS idx_role_auth_values_role ON role_auth_values(role_id);
CREATE INDEX IF NOT EXISTS idx_role_auth_values_object ON role_auth_values(auth_object_id);

-- ============================================================
-- 4. ORGANIZATION STRUCTURE (组织结构)
-- ============================================================
CREATE TABLE IF NOT EXISTS org_units (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    parent_id       UUID REFERENCES org_units(id),
    org_code        VARCHAR(50) NOT NULL,
    org_name        VARCHAR(255) NOT NULL,
    org_type        VARCHAR(30) NOT NULL,     -- company, division, dept, team, position
    is_active       BOOLEAN DEFAULT true,
    level           INT DEFAULT 0,
    path            TEXT,                     -- materialized path: /root/dept/team
    manager_id      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, org_code)
);

CREATE INDEX IF NOT EXISTS idx_org_units_tenant ON org_units(tenant_id);
CREATE INDEX IF NOT EXISTS idx_org_units_parent ON org_units(parent_id);

-- User org assignments
CREATE TABLE IF NOT EXISTS user_org_assignments (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    org_unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
    is_primary  BOOLEAN DEFAULT true,
    valid_from  TIMESTAMPTZ DEFAULT NOW(),
    valid_to    TIMESTAMPTZ,
    PRIMARY KEY (user_id, org_unit_id)
);

-- ============================================================
-- 5. SoD (Segregation of Duties) 职责分离
-- ============================================================
CREATE TABLE IF NOT EXISTS sod_rules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    rule_code       VARCHAR(50) NOT NULL,
    description     TEXT,
    severity        VARCHAR(20) DEFAULT 'medium',  -- low, medium, high, critical
    risk_category   VARCHAR(100),
    object_a_id     UUID NOT NULL REFERENCES auth_objects(id),
    activity_a      VARCHAR(20),
    object_b_id     UUID NOT NULL REFERENCES auth_objects(id),
    activity_b      VARCHAR(20),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, rule_code)
);

CREATE TABLE IF NOT EXISTS sod_violations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    role_a_id       UUID NOT NULL REFERENCES role_master(id),
    role_b_id       UUID NOT NULL REFERENCES role_master(id),
    sod_rule_id     UUID NOT NULL REFERENCES sod_rules(id),
    status          VARCHAR(20) DEFAULT 'open',   -- open, waived, mitigated
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ,
    waived_by       UUID REFERENCES users(id),
    waiver_reason   TEXT
);

-- ============================================================
-- 6. ACCESS REQUESTS (权限申请工单)
-- ============================================================
CREATE TABLE IF NOT EXISTS access_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    requester_id    UUID NOT NULL REFERENCES users(id),
    target_user_id  UUID NOT NULL REFERENCES users(id),
    request_type    VARCHAR(20) NOT NULL,        -- role_assign, role_remove, emergency
    request_data    JSONB NOT NULL,
    justification   TEXT,
    urgency         VARCHAR(20) DEFAULT 'normal',
    approver_id     UUID REFERENCES users(id),
    approval_status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    approval_at     TIMESTAMPTZ,
    approval_comment TEXT,
    executed        BOOLEAN DEFAULT false,
    executed_at     TIMESTAMPTZ,
    firefighter_id  UUID REFERENCES users(id),
    ff_session_id   VARCHAR(100),
    ff_start_at     TIMESTAMPTZ,
    ff_end_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_access_requests_requester ON access_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_access_requests_target ON access_requests(target_user_id);
CREATE INDEX IF NOT EXISTS idx_access_requests_status ON access_requests(approval_status);

COMMENT ON TABLE auth_objects IS 'Authorization objects (SAP-style permission definitions)';
COMMENT ON TABLE role_auth_values IS 'Core permission assignments: role -> auth object -> field values';
COMMENT ON TABLE sod_rules IS 'Segregation of Duties rules for conflict detection';
COMMENT ON TABLE access_requests IS 'Access request tickets with approval workflow';
