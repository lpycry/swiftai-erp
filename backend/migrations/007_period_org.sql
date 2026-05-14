-- ============================================================
-- SwiftAI ERP - Period Management per Organization
-- Add organization_id to periods for per-company accounting periods
-- ============================================================

ALTER TABLE gl_periods ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);
CREATE INDEX IF NOT EXISTS idx_gl_periods_org ON gl_periods(organization_id);

COMMENT ON COLUMN gl_periods.organization_id IS 'Company code (legal entity) for per-org period control';
