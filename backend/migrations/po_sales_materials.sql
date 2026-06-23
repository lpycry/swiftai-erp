-- production_orders: add sales order link
ALTER TABLE production_orders
  ADD COLUMN IF NOT EXISTS sales_order_id UUID NULL,
  ADD COLUMN IF NOT EXISTS so_item_id UUID NULL;

ALTER TABLE production_orders
  DROP CONSTRAINT IF EXISTS fk_po_sales_order;
ALTER TABLE production_orders
  DROP CONSTRAINT IF EXISTS fk_po_so_item;

ALTER TABLE production_orders
  ADD CONSTRAINT fk_po_sales_order FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id) ON DELETE SET NULL;
ALTER TABLE production_orders
  ADD CONSTRAINT fk_po_so_item FOREIGN KEY (so_item_id) REFERENCES sales_order_items(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_po_sales_order ON production_orders(sales_order_id);

-- production_order_materials: BOM-exploded material lines with issue_qty
CREATE TABLE IF NOT EXISTS production_order_materials (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  production_order_id UUID NOT NULL REFERENCES production_orders(id) ON DELETE CASCADE,
  component_id        UUID NOT NULL REFERENCES products(id),
  bom_item_id         UUID NULL REFERENCES bom_items(item_id) ON DELETE SET NULL,
  required_qty        NUMERIC(18,4) NOT NULL DEFAULT 0,
  issue_qty           NUMERIC(18,4) NOT NULL DEFAULT 0,
  unit_of_measure     VARCHAR(20)   NOT NULL DEFAULT 'EA',
  item_position       INT           NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pom_order     ON production_order_materials(production_order_id);
CREATE INDEX IF NOT EXISTS idx_pom_component ON production_order_materials(component_id);

SELECT 'Migration OK';
