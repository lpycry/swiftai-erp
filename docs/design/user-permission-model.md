# 用户与权限模型设计

## 参考体系：SAP 权限管理

| SAP 概念 | SwiftAI 对应 | 说明 |
|----------|-------------|------|
| SU01 (User Master) | User Management | 用户主数据维护 |
| PFCG (Role Maintenance) | Role Manager | 角色定义与权限分配 |
| Authorization Object | Permission + Conditions | 细粒度权限对象 |
| Authorization Profile | Role Bundle | 角色组合 |
| Organizational Levels | Org Context | 组织层级过滤 |
| Derived Roles | Inherited Roles | 角色继承体系 |
| Composite Roles | Composite Roles | 多角色组合 |
| CUA (Central User Admin) | Tenant-level Admin | 多公司统一管理 |
| GRC Access Control | Approval Workflow | 权限申请审批流 |

---

## 一、整体架构

```
┌─────────────────────────────────────────────────────────┐
│                   User Management                        │
│  ┌──────────────────────────────────────────────────┐   │
│  │  1. User Master (SU01-like)                     │   │
│  │  ├─ 基本属性 (姓名/邮箱/电话/语言/时区)            │   │
│  │  ├─ 认证配置 (密码/MFA/SSO)                       │   │
│  │  ├─ 地址信息                                      │   │
│  │  ├─ 参数配置 (默认值/显示格式)                      │   │
│  │  ├─ 角色分配                                       │   │
│  │  └─ 锁定/解锁/过期管理                             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  2. Role Management (PFCG-like)                  │   │
│  │  ├─ Single Role (单角色)                          │   │
│  │  ├─ Composite Role (复合角色)                     │   │
│  │  ├─ Derived Role (派生角色)                       │   │
│  │  └─ Role Inheritance (角色继承链)                   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  3. Authorization Objects                        │   │
│  │  ├─ Object Class (对象类)                         │   │
│  │  ├─ Authorization Field (权限字段)                 │   │
│  │  ├─ Value Range (值范围)                          │   │
│  │  └─ Condition-based (条件表达式)                   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  4. Org Structure (组织架构)                       │   │
│  │  ├─ Company -> Division -> Department -> Team     │   │
│  │  ├─ Org-based Permission Filter                    │   │
│  │  └─ Position/Job-based Role Auto-Assign            │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  5. Approval Workflow (GRC-like)                 │   │
│  │  ├─ Access Request (权限申请)                      │   │
│  │  ├─ Approval Chain (审批链)                        │   │
│  │  ├─ Emergency Access (紧急权限/Firefighter)         │   │
│  │  └─ Periodic Review (定期审阅)                     │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  6. Audit & Compliance                           │   │
│  │  ├─ Change Log (权限变更日志)                       │   │
│  │  ├─ SoD Analysis (职责分离分析)                     │   │
│  │  ├─ Access Certificate (权限认证报告)               │   │
│  │  └─ User Activity Log (用户行为审计)                │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 二、数据模型设计

### 2.1 User Master（用户主数据）

```sql
CREATE TABLE user_master (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    
    -- 基本属性
    user_id         VARCHAR(50) NOT NULL,  -- 登录ID (alias)
    email           VARCHAR(255) NOT NULL,
    display_name    VARCHAR(255) NOT NULL,
    last_name       VARCHAR(100),
    first_name      VARCHAR(100),
    phone           VARCHAR(50),
    mobile          VARCHAR(50),
    language        VARCHAR(10) DEFAULT 'en',
    timezone        VARCHAR(50) DEFAULT 'UTC',
    date_format     VARCHAR(20) DEFAULT 'YYYY-MM-DD',
    decimal_format  VARCHAR(10) DEFAULT '1,234.56',
    
    -- 认证配置
    password_hash       VARCHAR(255),
    mfa_type            VARCHAR(20),       -- totp, sms, email, none
    mfa_secret          TEXT,
    sso_provider        VARCHAR(50),
    sso_external_id     VARCHAR(255),
    password_changed_at TIMESTAMPTZ,
    password_expires_at TIMESTAMPTZ,
    require_pwd_change  BOOLEAN DEFAULT false,
    login_attempts      INT DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    
    -- 状态
    account_type     VARCHAR(20) DEFAULT 'user',  -- user, service, system
    is_active        BOOLEAN DEFAULT true,
    is_locked        BOOLEAN DEFAULT false,
    valid_from       TIMESTAMPTZ,
    valid_to         TIMESTAMPTZ,
    
    -- 组织分配
    org_unit_id      UUID,
    position_id      UUID,
    supervisor_id    UUID,
    
    -- 元数据
    last_login_at    TIMESTAMPTZ,
    last_ip          VARCHAR(45),
    created_by       UUID REFERENCES users(id),
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(tenant_id, user_id),
    UNIQUE(tenant_id, email)
);
```

### 2.2 Role Master（角色主数据）

```sql
-- 角色主表 (支持 Single / Composite / Derived)
CREATE TABLE role_master (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    
    role_id         VARCHAR(50) NOT NULL,  -- 角色编码 (Z_ADMIN, Z_ACCOUNTANT)
    description     TEXT,
    role_type       VARCHAR(20) NOT NULL,  -- single, composite, derived
    role_category   VARCHAR(50),           -- finance, logistics, admin, ...
    
    -- 角色继承
    parent_role_id  UUID REFERENCES role_master(id),
    inherit_level   INT DEFAULT 0,         -- 继承层级
    
    -- 状态
    is_system       BOOLEAN DEFAULT false,
    is_active       BOOLEAN DEFAULT true,
    valid_from      TIMESTAMPTZ,
    valid_to        TIMESTAMPTZ,
    
    -- 元数据
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    changed_at      TIMESTAMPTZ,
    changed_by      UUID REFERENCES users(id),
    
    UNIQUE(tenant_id, role_id)
);

-- 复合角色 → 子角色关联
CREATE TABLE composite_role_members (
    composite_role_id    UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    child_role_id        UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    PRIMARY KEY (composite_role_id, child_role_id)
);

-- 派生角色：基础角色 + 限制条件
CREATE TABLE derived_role_rules (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    derived_role_id     UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    base_role_id        UUID NOT NULL REFERENCES role_master(id),
    restriction_type    VARCHAR(50),  -- org_unit, company_code, plant, ...
    restriction_value   TEXT,         -- JSON condition
    created_at          TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.3 Authorization Objects（权限对象）

```sql
-- 权限对象定义 (类比 SAP Authorization Object)
CREATE TABLE auth_objects (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    object_class    VARCHAR(50) NOT NULL,  -- 对象类: finance, logistics, admin
    object_code     VARCHAR(50) NOT NULL UNIQUE,  -- F_GL_POST, M_MATE_STOCK
    description     TEXT,
    
    -- 活动类型模板 (SAP: 01=创建, 02=修改, 03=显示, 06=删除)
    activities      TEXT[] DEFAULT '{}',   -- create, read, update, delete, approve, print
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(object_code)
);

-- 权限字段定义 (每个对象有多个字段)
CREATE TABLE auth_object_fields (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_object_id  UUID NOT NULL REFERENCES auth_objects(id) ON DELETE CASCADE,
    field_name      VARCHAR(100) NOT NULL,  -- company_code, plant, gl_account, cost_center
    field_label     VARCHAR(255),
    field_type      VARCHAR(30),  -- org, account, value, general
    is_required     BOOLEAN DEFAULT false,
    display_order   INT DEFAULT 0,
    UNIQUE(auth_object_id, field_name)
);

-- 角色 → 权限对象值 (核心: 角色赋予哪些对象哪些字段值)
CREATE TABLE role_auth_values (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id         UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    auth_object_id  UUID NOT NULL REFERENCES auth_objects(id),
    
    -- 活动值
    activity_create BOOLEAN DEFAULT false,
    activity_read   BOOLEAN DEFAULT false,
    activity_update BOOLEAN DEFAULT false,
    activity_delete BOOLEAN DEFAULT false,
    activity_approve BOOLEAN DEFAULT false,
    activity_print   BOOLEAN DEFAULT false,
    
    -- 字段值 (JSON: {"company_code": "1000", "plant": "PL01"})
    field_values    JSONB DEFAULT '{}',
    
    -- 值范围 (高级)
    field_ranges    JSONB DEFAULT '{}',  -- {"gl_account": {"from": "400000", "to": "499999"}}
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role_id, auth_object_id)
);

-- 用户 → 角色分配
CREATE TABLE user_role_assignments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES user_master(id) ON DELETE CASCADE,
    role_id         UUID NOT NULL REFERENCES role_master(id) ON DELETE CASCADE,
    
    assignment_type VARCHAR(20) DEFAULT 'direct',  -- direct, derived, composite
    valid_from      TIMESTAMPTZ DEFAULT NOW(),
    valid_to        TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT true,
    
    assigned_by     UUID REFERENCES users(id),
    assigned_at     TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, role_id, valid_from)
);
```

### 2.4 Org Structure（组织结构）

```sql
CREATE TABLE org_units (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    parent_id       UUID REFERENCES org_units(id),
    org_code        VARCHAR(50) NOT NULL,
    org_name        VARCHAR(255) NOT NULL,
    org_type        VARCHAR(30) NOT NULL,  -- company, division, department, team, position
    is_active       BOOLEAN DEFAULT true,
    level           INT DEFAULT 0,         -- 层级深度
    path            LTREE,                 -- 快速祖先查询
    manager_id      UUID REFERENCES user_master(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, org_code)
);

-- 用户 → 组织分配
CREATE TABLE user_org_assignments (
    user_id     UUID NOT NULL REFERENCES user_master(id),
    org_unit_id UUID NOT NULL REFERENCES org_units(id),
    is_primary  BOOLEAN DEFAULT true,
    valid_from  TIMESTAMPTZ DEFAULT NOW(),
    valid_to    TIMESTAMPTZ,
    PRIMARY KEY (user_id, org_unit_id)
);
```

### 2.5 SoD (职责分离)

```sql
CREATE TABLE sod_rules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    rule_code       VARCHAR(50) NOT NULL,
    description     TEXT,
    severity        VARCHAR(20) DEFAULT 'medium',  -- low, medium, high, critical
    risk_category   VARCHAR(100),
    object_a_id     UUID NOT NULL REFERENCES auth_objects(id),
    object_activity_a VARCHAR(10),  -- 冲突活动: create, approve...
    object_b_id     UUID NOT NULL REFERENCES auth_objects(id),
    object_activity_b VARCHAR(10),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, rule_code)
);

CREATE TABLE sod_violations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    user_id         UUID NOT NULL REFERENCES user_master(id),
    role_a_id       UUID NOT NULL REFERENCES role_master(id),
    role_b_id       UUID NOT NULL REFERENCES role_master(id),
    sod_rule_id     UUID NOT NULL REFERENCES sod_rules(id),
    status          VARCHAR(20) DEFAULT 'open',  -- open, waived, mitigated
    detected_at     TIMESTAMPTZ DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ,
    waived_by       UUID REFERENCES users(id),
    waiver_reason   TEXT
);
```

### 2.6 Access Request（权限申请工单）

```sql
CREATE TABLE access_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    requester_id    UUID NOT NULL REFERENCES user_master(id),
    target_user_id  UUID NOT NULL REFERENCES user_master(id),  -- 被授权人
    request_type    VARCHAR(20) NOT NULL,  -- role_assignment, role_removal, privilege_escalation
    
    -- 请求内容
    request_data    JSONB NOT NULL,  -- {role_ids: [...], valid_from, valid_to, reason}
    justification   TEXT,
    urgency         VARCHAR(20) DEFAULT 'normal',  -- normal, urgent, emergency
    
    -- 审批
    approver_id     UUID REFERENCES user_master(id),
    approval_status VARCHAR(20) DEFAULT 'pending',  -- pending, approved, rejected, revoked
    approval_at     TIMESTAMPTZ,
    approval_comment TEXT,
    
    -- 执行
    executed        BOOLEAN DEFAULT false,
    executed_at     TIMESTAMPTZ,
    execution_result JSONB,
    
    -- 紧急权限 (Firefighter)
    firefighter_id  UUID REFERENCES user_master(id),
    ff_session_id   VARCHAR(100),  -- 紧急会话ID
    ff_start_at     TIMESTAMPTZ,
    ff_end_at       TIMESTAMPTZ,
    ff_activity_log JSONB,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 三、API 设计

### 3.1 User Management

| Method | Path | Description | SAP Equivalent |
|--------|------|-------------|---------------|
| POST | `/users` | Create user | SU01 Create |
| GET | `/users` | List users (search/filter) | SU01 List |
| GET | `/users/:id` | Get user detail | SU01 Display |
| PUT | `/users/:id` | Update user | SU01 Change |
| DELETE | `/users/:id` | Lock/Deactivate user | SU01 Lock |
| POST | `/users/:id/lock` | Lock user | SU01 Lock |
| POST | `/users/:id/unlock` | Unlock user | SU01 Unlock |
| POST | `/users/:id/password/reset` | Password reset | SU01 Password |
| POST | `/users/:id/password/force-change` | Force change on next login | -- |
| GET | `/users/:id/roles` | Get user roles | SU01 Roles tab |
| POST | `/users/:id/roles/assign` | Assign role to user | SU01 Roles assign |
| POST | `/users/:id/roles/remove` | Remove role from user | SU01 Roles remove |
| GET | `/users/:id/permissions` | Get effective permissions | SUUM Permissions |
| GET | `/users/:id/activity-log` | User activity history | SUIM Audit |

### 3.2 Role Management

| Method | Path | Description | SAP Equivalent |
|--------|------|-------------|---------------|
| POST | `/roles` | Create role | PFCG Create |
| GET | `/roles` | List roles | PFCG List |
| GET | `/roles/:id` | Get role detail (with auth values) | PFCG Display |
| PUT | `/roles/:id` | Update role | PFCG Change |
| DELETE | `/roles/:id` | Delete role | PFCG Delete |
| POST | `/roles/:id/generate-profile` | Generate authorization profile | PFCG Generate |
| POST | `/roles/:id/copy` | Copy role | PFCG Copy |
| GET | `/roles/:id/users` | Get users assigned to role | PFCG User List |
| GET | `/roles/:id/auth-values` | Get authorization values | PFCG Auth tab |
| PUT | `/roles/:id/auth-values` | Update authorization values | PFCG Auth |

### 3.3 Authorization Objects

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth-objects` | Create auth object |
| GET | `/auth-objects` | List auth objects (by class) |
| GET | `/auth-objects/:id` | Get auth object detail |
| PUT | `/auth-objects/:id` | Update auth object |
| DELETE | `/auth-objects/:id` | Delete auth object |
| GET | `/auth-objects/classes` | List object classes |

### 3.4 Organization Management

| Method | Path | Description |
|--------|------|-------------|
| POST | `/org-units` | Create org unit |
| GET | `/org-units` | List org tree |
| GET | `/org-units/:id` | Get org unit detail |
| PUT | `/org-units/:id` | Update org unit |
| DELETE | `/org-units/:id` | Delete org unit |
| GET | `/org-units/:id/users` | Users in org unit |
| GET | `/org-units/:id/children` | Sub org units |

### 3.5 SoD & Compliance

| Method | Path | Description |
|--------|------|-------------|
| POST | `/sod-rules` | Create SoD rule |
| GET | `/sod-rules` | List SoD rules |
| GET | `/sod-rules/check/user/:id` | Check user SoD conflicts |
| GET | `/sod-rules/check/role/:id` | Check role SoD conflicts |
| GET | `/sod-violations` | List SoD violations |
| PUT | `/sod-violations/:id/waive` | Waive a violation |
| GET | `/compliance/access-certificate/user/:id` | User access certificate |
| GET | `/compliance/access-certificate/role/:id` | Role access certificate |

### 3.6 Access Request

| Method | Path | Description |
|--------|------|-------------|
| POST | `/access-requests` | Submit access request |
| GET | `/access-requests` | List requests (my/filter) |
| GET | `/access-requests/:id` | Get request detail |
| POST | `/access-requests/:id/approve` | Approve request |
| POST | `/access-requests/:id/reject` | Reject request |
| POST | `/access-requests/:id/emergency` | Emergency access (Firefighter) |
| POST | `/access-requests/:id/revoke` | Revoke access |

---

## 四、权限校验引擎

### 4.1 Permission Check 核心流程

```
User Request → Service Endpoint
                     │
                     ▼
        ┌─────────────────────────┐
        │  1. Extract User Context │  JWT → user_id + tenant_id
        └────────┬────────────────┘
                 ▼
        ┌─────────────────────────┐
        │  2. Check User          │  is_active? is_locked? valid period?
        │     Account Status       │
        └────────┬────────────────┘
                 ▼
        ┌─────────────────────────┐
        │  3. Load Effective      │  直接角色 + 复合角色展开 + 派生角色
        │     Roles (Recursive)    │  缓存 Redis (TTL: 5min)
        └────────┬────────────────┘
                 ▼
        ┌─────────────────────────┐
        │  4. Check Auth Object   │  对象代码匹配 (e.g. F_GL_POST)
        └────────┬────────────────┘
                 ▼
        ┌─────────────────────────┐
        │  5. Check Activity      │  create/read/update/delete/approve
        └────────┬────────────────┘
                 ▼
        ┌─────────────────────────┐
        │  6. Check Field Values  │  org字段过滤 (company=1000, plant=PL01)
        │     + Range Check       │  gl_account 400000-499999
        └────────┬────────────────┘
                 ▼
        ┌─────────────────────────┐
        │  7. SoD Check (可选)     │  如果操作有SoD风险，标记/阻断
        └────────┬────────────────┘
                 ▼
            GRANT / DENY
```

### 4.2 Auth Middleware 设计

```go
// 请求中的权限校验
type PermissionCheck struct {
    ObjectCode string            // F_GL_POST
    Activity   string            // create
    Fields     map[string]string // {"company_code": "1000", "gl_account": "410000"}
}

// 中间件使用方式
r.POST("/finance/journal-entries",
    middleware.AuthRequired(cfg.JWT),
    middleware.RequirePermission("F_GL_POST", "create"),
    financeHandler.CreateJournalEntry,
)

// 或者路徑级权限
r.POST("/finance/journal-entries",
    middleware.AuthRequired(cfg.JWT),
    middleware.RequirePermissionWithOrg("F_GL_POST", "create",
        func(c *gin.Context) map[string]string {
            return map[string]string{
                "company_code": c.Param("company"),
                "gl_account":   c.PostForm("account"),
            }
        },
    ),
    financeHandler.CreateJournalEntry,
)
```

### 4.3 权限缓存策略

```
┌─────────┐     ┌──────────┐     ┌──────────┐
│ 请求进入  │ ──► │  Redis   │ ──► │  Return   │
└─────────┘     │  Cache   │     │  Cached   │
                │  (5min)  │     │  Result   │
                └────┬─────┘     └──────────┘
                     │ Miss
                     ▼
                ┌──────────┐
                │   DB     │
                │  Query   │
                └────┬─────┘
                     │
                ┌────▼─────┐
                │  Update  │
                │  Cache   │
                └──────────┘
```

User's effective permissions cached key:
```
swiftai:perm:{tenant_id}:{user_id}:{object_code}:{activity}
```

Cache invalidated when:
- Role assigned/removed from user
- Role authorization values changed
- User status changed (lock/expire)
- Derived role conditions changed

---

## 五、审批工作流

### 5.1 权限申请流程

```
User Request
     │
     ▼
┌─────────────────────┐
│  SoD Pre-check       │ ← 自动检测是否违反职责分离
└────────┬────────────┘
    OK   │   Violation
         ▼         ▼
┌──────────────┐ ┌──────────────────┐
│ Normal Flow  │ │ Mitigation Flow  │
└──────┬───────┘ └────────┬─────────┘
       │                  │
       ▼                  ▼
┌──────────────────────────────┐
│  Approval Routing             │
│  ├─ Direct Manager (Level 1)  │
│  ├─ Security Officer (Level 2)│
│  └─ Compliance (Level 3)      │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────┐
│  Execute Assignment   │
│  + Audit Log Entry    │
└──────────────────────┘
```

### 5.2 Emergency Access (Firefighter)

类似 SAP Firefighter (GRC)，允许运维在紧急情况下越权访问，但有：

1. 时间窗口（默认 4 小时，不可续期）
2. 所有操作被完整记录日志
3. 自动通知安全主管
4. 事后必须提交事故报告（Post-Event Review）

---

## 六、种子数据

### 6.1 默认权限对象

```sql
-- Finance
INSERT INTO auth_objects (object_class, object_code, description, activities)
VALUES
('finance', 'F_GL_POST',       'Post Journal Entries',           ARRAY['create','read','update','delete','approve']),
('finance', 'F_GL_DISPLAY',    'Display General Ledger',         ARRAY['read','print']),
('finance', 'F_AP_POST',       'Post AP Documents',              ARRAY['create','read','update','delete','approve','print']),
('finance', 'F_AR_POST',       'Post AR Documents',              ARRAY['create','read','update','delete','approve','print']),
('finance', 'F_BANK_POST',     'Post Bank Statements',           ARRAY['create','read','update','approve']),
('finance', 'F_COST_POST',     'Post Cost Allocations',          ARRAY['create','read','update','approve']),
('finance', 'F_REPORT_RUN',    'Run Financial Reports',          ARRAY['read','print','schedule']),
('finance', 'F_TAX_CONFIG',    'Configure Tax Settings',         ARRAY['read','update']),
('finance', 'F_PERIOD_MGMT',   'Period Close/Open Management',   ARRAY['read','update','close','open']);

-- Logistics
INSERT INTO auth_objects (object_class, object_code, description, activities)
VALUES
('logistics', 'M_MATE_STOCK',  'Manage Stock Movements',         ARRAY['create','read','update','delete','transfer']),
('logistics', 'M_WAREHOUSE',   'Manage Warehouses',              ARRAY['create','read','update','delete','transfer']),
('logistics', 'M_INV_COUNT',   'Physical Inventory Count',       ARRAY['create','read','update','approve']);

-- Procurement
INSERT INTO auth_objects (object_class, object_code, description, activities)
VALUES
('procurement', 'P_PO_CREATE', 'Create Purchase Orders',         ARRAY['create','read','update','delete','approve','print']),
('procurement', 'P_RFQ_MGMT',  'Manage RFQs',                    ARRAY['create','read','update','close']),
('procurement', 'P_GR_POST',   'Post Goods Receipts',            ARRAY['create','read','update','delete']),
('procurement', 'P_VENDOR_MGMT','Manage Vendor Master',          ARRAY['create','read','update','delete']);

-- Sales
INSERT INTO auth_objects (object_class, object_code, description, activities)
VALUES
('sales', 'S_SO_CREATE',       'Create Sales Orders',            ARRAY['create','read','update','delete','approve']),
('sales', 'S_QUOTE_MGMT',      'Manage Quotations',              ARRAY['create','read','update','delete']),
('sales', 'S_CUSTOMER_MGMT',   'Manage Customer Master',         ARRAY['create','read','update','delete']);
```

### 6.2 默认标准角色

```go
// 角色定义 (映射到 SAP 标准角色)
var DefaultRoles = []RoleDefinition{
    {
        RoleID: "SAP_SYSTEM_ADMIN",
        Name:   "Global Administrator",
        Type:   "composite",
        AuthObjects: []string{
            "F_GL_POST", "F_AP_POST", "F_AR_POST", "F_PERIOD_MGMT",
            "M_MATE_STOCK", "M_WAREHOUSE",
            "P_PO_CREATE", "P_VENDOR_MGMT",
            "S_SO_CREATE", "S_CUSTOMER_MGMT",
            "F_REPORT_RUN", "F_TAX_CONFIG",
        },
    },
    {
        RoleID: "SAP_ACCOUNTANT",
        Name:   "Accountant",
        Type:   "single",
        AuthObjects: []string{
            "F_GL_POST", "F_AP_POST", "F_AR_POST", "F_BANK_POST",
            "F_COST_POST", "F_REPORT_RUN",
        },
    },
    {
        RoleID: "SAP_AR_SPECIALIST",
        Name:   "AR Specialist",
        Type:   "single",
        AuthObjects: []string{"F_AR_POST"},
    },
    {
        RoleID: "SAP_AP_SPECIALIST",
        Name:   "AP Specialist",
        Type:   "single",
        AuthObjects: []string{"F_AP_POST"},
    },
    {
        RoleID: "SAP_WAREHOUSE_CLERK",
        Name:   "Warehouse Clerk",
        Type:   "single",
        AuthObjects: []string{"M_MATE_STOCK", "M_INV_COUNT"},
    },
    {
        RoleID: "SAP_PURCHASER",
        Name:   "Purchaser",
        Type:   "single",
        AuthObjects: []string{"P_PO_CREATE", "P_RFQ_MGMT", "P_GR_POST"},
    },
    {
        RoleID: "SAP_SALES_REP",
        Name:   "Sales Representative",
        Type:   "single",
        AuthObjects: []string{"S_SO_CREATE", "S_QUOTE_MGMT"},
    },
    {
        RoleID: "SAP_VIEWER",
        Name:   "Read-Only Viewer",
        Type:   "single",
        AuthObjects: []string{"F_GL_DISPLAY", "F_REPORT_RUN"},
    },
}
```

---

## 七、开发计划

### Sprint 1: User Master (3天)

| 天数 | 内容 | 交付物 |
|------|------|--------|
| Day 1 | user_master 表 + Repository CRUD | Repository 接口 |
| Day 2 | User Service + Handler (SU01-like UI) | API 端点 |
| Day 3 | 用户锁定/解锁/密码策略 + MFA | 安全功能 |

### Sprint 2: Role Management (3天)

| 天数 | 内容 | 交付物 |
|------|------|--------|
| Day 1 | role_master 表 + 角色 CRUD | Role API |
| Day 2 | 复合角色/派生角色 + 继承链 | 高级角色功能 |
| Day 3 | 角色分配管理 (用户 ↔ 角色) | 分配 API |

### Sprint 3: Authorization Engine (4天)

| 天数 | 内容 | 交付物 |
|------|------|--------|
| Day 1 | auth_objects + auth_object_fields 表 | 权限对象 CRUD |
| Day 2 | role_auth_values 表 + 赋值 UI | 权限值维护 |
| Day 3 | 权限校验引擎 (递归角色展开 + 缓存) | Check() 函数 |
| Day 4 | Auth middleware + 集成测试 | 中间件 + 测试 |

### Sprint 4: Org Structure + SoD (3天)

| 天数 | 内容 | 交付物 |
|------|------|--------|
| Day 1 | org_units 表 + 树管理 | Org API |
| Day 2 | SoD 规则 + 冲突检测 | SoD 引擎 |
| Day 3 | 权限认证报告 + 角色展开视图 | 报表 |

### Sprint 5: Access Request + Workflow (3天)

| 天数 | 内容 | 交付物 |
|------|------|--------|
| Day 1 | access_requests 表 + 提交接口 | Request API |
| Day 2 | 审批链 + Firefighter 紧急访问 | 审批流 |
| Day 3 | 审计日志 + Flutter 管理界面 | 完整 UI |

---

## 八、风险尾注

- **权限膨胀风险** — 复合角色 + 派生角色的递归展开可能产生性能热点，必须使用 Redis 缓存 + TTL 过期机制。建议为每个权限查询设置 50ms 超时兜底
- **SoD 冲突阻塞** — 职责分离检查若过严可能导致管理员无法分配必要权限，需提供豁免（Waive）机制并记入审计
- **角色维护负担** — 相比 SAP 需要专门的 Basis 团队，SMB 场景需使用"角色模板 + 向导式创建"降低门槛
- **树结构查询性能** — 组织架构的祖先查询（LTREE）在 PostgreSQL 中需要安装扩展，如果不支持可使用嵌套集（Nested Set）或物化路径替代
