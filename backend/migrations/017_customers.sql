-- Customer Master (SAP-style with structured addresses, tax exemption & certificates)

CREATE TABLE IF NOT EXISTS customers (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id                   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_code               VARCHAR(50) NOT NULL,
    name                        VARCHAR(255) NOT NULL,
    tax_number                  VARCHAR(100) DEFAULT '',
    customer_type               VARCHAR(30) NOT NULL DEFAULT 'Corporate',
    currency                    VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_terms               VARCHAR(50) DEFAULT 'Net 30',

    contact_person              VARCHAR(255) DEFAULT '',
    contact_email               VARCHAR(255) DEFAULT '',
    contact_phone               VARCHAR(50) DEFAULT '',

    billing_street              TEXT NOT NULL DEFAULT '',
    billing_city                VARCHAR(100) NOT NULL DEFAULT '',
    billing_state               VARCHAR(50) NOT NULL DEFAULT '',
    billing_zip                 VARCHAR(20) NOT NULL DEFAULT '',
    billing_country             VARCHAR(100) NOT NULL DEFAULT 'US',

    shipping_street             TEXT NOT NULL DEFAULT '',
    shipping_city               VARCHAR(100) NOT NULL DEFAULT '',
    shipping_state              VARCHAR(50) NOT NULL DEFAULT '',
    shipping_zip                VARCHAR(20) NOT NULL DEFAULT '',
    shipping_country            VARCHAR(100) NOT NULL DEFAULT 'US',

    status                      VARCHAR(20) NOT NULL DEFAULT 'Active',

    is_tax_exempt               BOOLEAN NOT NULL DEFAULT false,
    tax_exemption_cert          VARCHAR(100) DEFAULT '',
    tax_exempt_start_date       DATE DEFAULT NULL,
    tax_exempt_end_date         DATE DEFAULT NULL,
    tax_exempt_reason           VARCHAR(255) DEFAULT '',
    default_tax_jurisdiction_id UUID DEFAULT NULL,

    is_active                   BOOLEAN NOT NULL DEFAULT true,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_code_tenant ON customers(tenant_id, customer_code);
CREATE INDEX IF NOT EXISTS idx_customers_tenant ON customers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customers_status ON customers(tenant_id, status);

-- Customer Certificates (tax exemption certificate uploads)
CREATE TABLE IF NOT EXISTS customer_certificates (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    cert_type   VARCHAR(30) NOT NULL DEFAULT 'TAX_EXEMPT',
    file_name   VARCHAR(255) NOT NULL,
    file_path   TEXT NOT NULL,
    file_size   INTEGER NOT NULL DEFAULT 0,
    mime_type   VARCHAR(100) DEFAULT '',
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cust_certs_customer ON customer_certificates(customer_id);

COMMENT ON TABLE customers IS 'Customer master data with structured addresses and tax exemption';
COMMENT ON TABLE customer_certificates IS 'Tax exemption certificates uploaded for customers';
COMMENT ON COLUMN customers.customer_type IS 'Individual, Corporate, Government, Non-Profit';
COMMENT ON COLUMN customers.status IS 'Active, Inactive, Blocked';
COMMENT ON COLUMN customers.tax_exempt_reason IS 'RESALE, GOVERNMENT, NON_PROFIT, CHARITABLE, OTHER';
