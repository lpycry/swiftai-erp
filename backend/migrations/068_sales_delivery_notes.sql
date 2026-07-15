CREATE TABLE IF NOT EXISTS sales_delivery_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    delivery_no VARCHAR(30) NOT NULL,
    sales_order_id UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    selection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ship_to_name VARCHAR(200) DEFAULT '',
    ship_to_phone VARCHAR(80) DEFAULT '',
    ship_to_address TEXT DEFAULT '',
    shipping_method VARCHAR(80) DEFAULT '',
    route VARCHAR(120) DEFAULT '',
    status VARCHAR(30) NOT NULL DEFAULT 'CREATED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    pgi_at TIMESTAMPTZ,
    UNIQUE(tenant_id, delivery_no)
);

CREATE TABLE IF NOT EXISTS sales_delivery_note_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES sales_delivery_notes(id) ON DELETE CASCADE,
    so_item_id UUID NOT NULL REFERENCES sales_order_items(id),
    item_no INT NOT NULL,
    product_id UUID NOT NULL REFERENCES products(id),
    order_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    delivery_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    picked_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    unit_of_measure VARCHAR(20) DEFAULT 'EA',
    stock_loc VARCHAR(120) DEFAULT '',
    pgi_status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sales_billing_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    delivery_id UUID NOT NULL REFERENCES sales_delivery_notes(id) ON DELETE CASCADE,
    sales_order_id UUID NOT NULL REFERENCES sales_orders(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    status VARCHAR(30) NOT NULL DEFAULT 'READY',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sales_delivery_notes_tenant_status
ON sales_delivery_notes(tenant_id, status);

CREATE INDEX IF NOT EXISTS idx_sales_delivery_items_delivery
ON sales_delivery_note_items(delivery_id);
