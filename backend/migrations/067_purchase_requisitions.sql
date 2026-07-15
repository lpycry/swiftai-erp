CREATE TABLE IF NOT EXISTS purchase_requisitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    pr_number VARCHAR(30) NOT NULL,
    requester_id UUID,
    department VARCHAR(120) DEFAULT '',
    cost_center VARCHAR(80) DEFAULT '',
    requisition_type VARCHAR(40) NOT NULL DEFAULT 'INVENTORY',
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    total_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    source VARCHAR(30) NOT NULL DEFAULT 'MANUAL',
    current_level INTEGER NOT NULL DEFAULT 0,
    approval_level INTEGER NOT NULL DEFAULT 1,
    rejection_reason TEXT DEFAULT '',
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, pr_number)
);

CREATE INDEX IF NOT EXISTS idx_purchase_requisitions_org_status
ON purchase_requisitions(org_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS purchase_requisition_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_id UUID NOT NULL REFERENCES purchase_requisitions(id) ON DELETE CASCADE,
    item_no INTEGER NOT NULL,
    product_id UUID NOT NULL REFERENCES products(id),
    qty_requested NUMERIC(18,4) NOT NULL,
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'EA',
    estimated_price NUMERIC(18,4) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    required_date DATE NOT NULL,
    acct_assignment VARCHAR(80) DEFAULT '',
    suggested_vendor_id UUID REFERENCES vendors(id) ON DELETE SET NULL,
    source_mrp_pr_id UUID REFERENCES mrp_planned_purchase_requisitions(id) ON DELETE SET NULL,
    converted_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    po_id UUID REFERENCES purchase_orders(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(pr_id, item_no)
);

CREATE INDEX IF NOT EXISTS idx_purchase_requisition_items_product
ON purchase_requisition_items(product_id, required_date);

CREATE TABLE IF NOT EXISTS purchase_requisition_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_id UUID NOT NULL REFERENCES purchase_requisitions(id) ON DELETE CASCADE,
    user_id UUID,
    action VARCHAR(40) NOT NULL,
    old_status VARCHAR(30) DEFAULT '',
    new_status VARCHAR(30) DEFAULT '',
    message TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pr_audit_pr
ON purchase_requisition_audit_logs(pr_id, created_at DESC);
