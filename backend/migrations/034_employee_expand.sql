-- ============================================================
-- SwiftAI ERP - Employee Master Data Expansion
-- Split legal_name → first/middle/last; add position, dept, contact, etc.
-- ============================================================

ALTER TABLE employee_base
    ADD COLUMN IF NOT EXISTS first_name          VARCHAR(100) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS middle_name         VARCHAR(100) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS last_name           VARCHAR(100) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS position_id         UUID REFERENCES positions(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS department_id       UUID REFERENCES organization_units(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS hire_date           DATE,
    ADD COLUMN IF NOT EXISTS email               VARCHAR(255),
    ADD COLUMN IF NOT EXISTS phone               VARCHAR(50),
    ADD COLUMN IF NOT EXISTS legal_address       TEXT,
    ADD COLUMN IF NOT EXISTS emergency_contacts  JSONB NOT NULL DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS worker_type         VARCHAR(20) NOT NULL DEFAULT 'Regular',
    ADD COLUMN IF NOT EXISTS manager_id          UUID REFERENCES employee_base(id) ON DELETE SET NULL;

-- Migrate existing legal_name → first_name
UPDATE employee_base SET first_name = legal_name WHERE first_name = '';

-- Drop legal_name after migration
-- We'll keep legal_name as a computed/convenience column or drop it
-- For compatibility, keep it but update the app to use first/middle/last

COMMENT ON COLUMN employee_base.first_name          IS 'Given name';
COMMENT ON COLUMN employee_base.middle_name         IS 'Middle name / initial';
COMMENT ON COLUMN employee_base.last_name           IS 'Family name';
COMMENT ON COLUMN employee_base.position_id         IS 'FK to positions table';
COMMENT ON COLUMN employee_base.department_id       IS 'FK to organization_units table';
COMMENT ON COLUMN employee_base.hire_date           IS 'Date of employment start';
COMMENT ON COLUMN employee_base.email               IS 'Work email address';
COMMENT ON COLUMN employee_base.phone               IS 'Contact phone number';
COMMENT ON COLUMN employee_base.legal_address       IS 'Legal residence address';
COMMENT ON COLUMN employee_base.emergency_contacts  IS 'JSON array of {name, phone, relation}';
COMMENT ON COLUMN employee_base.worker_type         IS 'Regular, Part Time, Contractor, Intern';
COMMENT ON COLUMN employee_base.manager_id          IS 'FK to employee_base (self-referencing)';
