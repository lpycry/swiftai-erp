# Database Schema

## Entity Relationship Overview

```
tenants
  ├── users
  │     └── user_roles
  │           └── roles
  │                 └── role_permissions
  │                       └── permissions
  ├── audit_log
  └── sessions
```

## Core Tables

### tenants
| Column | Type | Description |
|--------|------|-------------|
| id | UUID PK | Tenant identifier |
| name | VARCHAR(255) | Company name |
| slug | VARCHAR(100) UNIQUE | URL-friendly identifier |
| domain | VARCHAR(255) | Custom domain |
| plan | VARCHAR(50) | Subscription plan |
| is_active | BOOLEAN | Tenant active status |
| settings | JSONB | Tenant configuration |
| created_at | TIMESTAMPTZ | Creation timestamp |
| updated_at | TIMESTAMPTZ | Last update timestamp |

### users
| Column | Type | Description |
|--------|------|-------------|
| id | UUID PK | User identifier |
| tenant_id | UUID FK | Belongs to tenant |
| email | VARCHAR(255) | Login email (unique per tenant) |
| password_hash | VARCHAR(255) | bcrypt password hash |
| display_name | VARCHAR(255) | User display name |
| phone | VARCHAR(50) | Phone number |
| avatar_url | VARCHAR(500) | Profile picture URL |
| is_active | BOOLEAN | Account active status |
| is_mfa_enabled | BOOLEAN | MFA toggle |
| last_login_at | TIMESTAMPTZ | Last login timestamp |

### roles (tenant-scoped)
| Column | Type | Description |
|--------|------|-------------|
| id | UUID PK | Role identifier |
| tenant_id | UUID FK | Tenant scope |
| name | VARCHAR(100) | Role name (admin, user, viewer...) |
| description | TEXT | Role description |
| is_system | BOOLEAN | System role (cannot delete) |

### permissions (global)
| Column | Type | Description |
|--------|------|-------------|
| id | UUID PK | Permission identifier |
| code | VARCHAR(100) UNIQUE | Permission code (e.g. finance:gl:read) |
| name | VARCHAR(255) | Display name |
| module | VARCHAR(50) | Module scope |
| action | VARCHAR(50) | Action type (read, write, manage) |

## Indexing Strategy
- All foreign keys indexed
- Unique constraints on (tenant_id, email), (tenant_id, name)
- Audit log indexed on tenant_id, entity_type+entity_id, created_at
- Sessions indexed on user_id and expires_at for cleanup
