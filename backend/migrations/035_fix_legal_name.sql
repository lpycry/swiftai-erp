-- Make legal_name optional (use first/middle/last instead)
ALTER TABLE employee_base ALTER COLUMN legal_name DROP NOT NULL;
ALTER TABLE employee_base ALTER COLUMN legal_name SET DEFAULT '';
