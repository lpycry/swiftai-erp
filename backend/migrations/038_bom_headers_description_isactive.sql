-- Migration 038: Add description and is_active to bom_headers
ALTER TABLE bom_headers ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE bom_headers ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
