-- Add employee_code to quotations for employee assignment
ALTER TABLE quotations ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES employee_base(id) ON DELETE SET NULL;

COMMENT ON COLUMN quotations.employee_id IS 'FK to employee_base - assigned salesperson/employee';
