-- Migration 050: Add routing_template_id to bom_headers
ALTER TABLE bom_headers ADD COLUMN IF NOT EXISTS routing_template_id UUID;
ALTER TABLE bom_headers ADD CONSTRAINT fk_bom_routing_template 
  FOREIGN KEY (routing_template_id) REFERENCES routing_templates(id) ON DELETE SET NULL;
