-- ZIMRA FDMS compliance fields + fiscal invoice numbering.

-- Tenant-level fiscal identity (issued by ZIMRA on registration).
ALTER TABLE tenants ADD COLUMN tin              TEXT;
ALTER TABLE tenants ADD COLUMN vat_number       TEXT;
ALTER TABLE tenants ADD COLUMN fiscal_device_id TEXT;   -- ZIMRA-issued FDMS device ID
ALTER TABLE tenants ADD COLUMN trade_name       TEXT;
ALTER TABLE tenants ADD COLUMN address          TEXT;

-- VAT-class per product so the POS can compute correctly.
ALTER TABLE products ADD COLUMN vat_class TEXT NOT NULL DEFAULT 'STANDARD'
        CHECK (vat_class IN ('STANDARD','ZERO','EXEMPT','LUXURY'));

-- Sale-level VAT totals (pre-computed on write, immutable).
ALTER TABLE sales ADD COLUMN subtotal_cents BIGINT NOT NULL DEFAULT 0;
ALTER TABLE sales ADD COLUMN vat_cents      BIGINT NOT NULL DEFAULT 0;
ALTER TABLE sales ADD COLUMN fiscal_receipt_no TEXT UNIQUE;
ALTER TABLE sales ADD COLUMN fiscal_status  TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (fiscal_status IN ('PENDING','SUBMITTED','ACCEPTED','REJECTED','OFFLINE'));
ALTER TABLE sales ADD COLUMN fiscal_reference TEXT;        -- ZIMRA verification code
ALTER TABLE sales ADD COLUMN fiscal_qr_payload TEXT;
ALTER TABLE sales ADD COLUMN customer_tin    TEXT;         -- required if >$1000 USD or B2B
ALTER TABLE sales ADD COLUMN customer_name   TEXT;

-- Line-level tax breakdown snapshot.
ALTER TABLE sale_items ADD COLUMN vat_class TEXT NOT NULL DEFAULT 'STANDARD';
ALTER TABLE sale_items ADD COLUMN net_cents BIGINT NOT NULL DEFAULT 0;
ALTER TABLE sale_items ADD COLUMN vat_cents BIGINT NOT NULL DEFAULT 0;

-- Monotonically-increasing per-tenant fiscal receipt counter.
-- FDMS requires a strictly sequential number; we scope to tenant.
CREATE TABLE fiscal_counters (
    tenant_id  UUID PRIMARY KEY REFERENCES tenants(id),
    next_value BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Outbox for FDMS submissions so a 24h ZIMRA outage never blocks a till.
CREATE TABLE fdms_submissions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      UUID NOT NULL REFERENCES tenants(id),
    sale_id        UUID NOT NULL REFERENCES sales(id),
    payload_json   JSONB NOT NULL,
    status         TEXT NOT NULL DEFAULT 'PENDING'
         CHECK (status IN ('PENDING','SUBMITTED','ACCEPTED','REJECTED','DEAD_LETTER')),
    attempts       INT NOT NULL DEFAULT 0,
    last_error     TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_fdms_due ON fdms_submissions (status, next_attempt_at);
CREATE INDEX ix_fdms_tenant ON fdms_submissions (tenant_id, created_at DESC);

-- Z-report summaries (end-of-day totals for audit).
CREATE TABLE z_reports (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      UUID NOT NULL REFERENCES tenants(id),
    business_date  DATE NOT NULL,
    sales_count    INT NOT NULL,
    gross_cents    BIGINT NOT NULL,
    net_cents      BIGINT NOT NULL,
    vat_cents      BIGINT NOT NULL,
    by_payment     JSONB NOT NULL,
    by_vat_class   JSONB NOT NULL,
    closed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, business_date)
);

-- Customer registry (for credit sales + repeat shoppers).
CREATE TABLE customers (
    id          UUID PRIMARY KEY,
    tenant_id   UUID NOT NULL REFERENCES tenants(id),
    name        TEXT NOT NULL,
    phone       TEXT,
    email       TEXT,
    tin         TEXT,
    balance_cents BIGINT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_customers_tenant ON customers (tenant_id);

ALTER TABLE sales ADD COLUMN customer_id UUID REFERENCES customers(id);
