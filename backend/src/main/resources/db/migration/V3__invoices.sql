-- Invoices / Quotations / Credit Notes --------------------------------------
--
-- TillPro targets every SME, not just over-the-counter retailers. A plumber,
-- graphic designer, consultant, tradesman, salon, mechanic, or event caterer
-- thinks in terms of *invoices* — issue now, get paid later — rather than
-- receipts handed over at the till.
--
-- This migration adds a full invoice lifecycle:
--   DRAFT → SENT → (PARTIAL | PAID) → closed
--                → OVERDUE auto-transition by a scheduler
--                → VOIDED at any time
--   Credit notes reference a parent invoice via parent_invoice_id.
--   Quotations live in the same table with kind='QUOTE' and convert to
--     kind='INVOICE' on acceptance (same id, new number).
--
-- Offline-first: client-generated UUID, same as sales/products.
-- Multi-tenant: every row carries tenant_id; queries MUST filter by it.

CREATE TABLE IF NOT EXISTS invoices (
    id                  UUID PRIMARY KEY,
    tenant_id           UUID NOT NULL,
    number              VARCHAR(32) UNIQUE,               -- INV-2026-000123
    kind                VARCHAR(16) NOT NULL DEFAULT 'INVOICE', -- INVOICE | QUOTE | PROFORMA | CREDIT_NOTE
    parent_invoice_id   UUID,                              -- for CREDIT_NOTE
    customer_id         UUID,
    customer_name       VARCHAR(200),
    customer_tin        VARCHAR(40),
    customer_email      VARCHAR(200),
    customer_address    TEXT,
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT',  -- DRAFT|SENT|PARTIAL|PAID|OVERDUE|VOIDED
    issue_date          DATE NOT NULL,
    due_date            DATE,
    currency            VARCHAR(4) NOT NULL DEFAULT 'USD',
    subtotal_cents      BIGINT NOT NULL DEFAULT 0,
    vat_cents           BIGINT NOT NULL DEFAULT 0,
    discount_cents      BIGINT NOT NULL DEFAULT 0,
    total_cents         BIGINT NOT NULL DEFAULT 0,
    paid_cents          BIGINT NOT NULL DEFAULT 0,
    balance_cents       BIGINT NOT NULL DEFAULT 0,
    notes               TEXT,
    terms               TEXT,
    fiscal_receipt_no   VARCHAR(64),       -- populated on PAID if converted to a fiscalised sale
    fiscal_status       VARCHAR(16),
    client_created_at   TIMESTAMPTZ NOT NULL,
    server_received_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_invoices_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant ON invoices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_status ON invoices(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_due ON invoices(tenant_id, due_date);

CREATE TABLE IF NOT EXISTS invoice_items (
    id                  UUID PRIMARY KEY,
    invoice_id          UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    tenant_id           UUID NOT NULL,
    product_id          UUID,                              -- nullable: invoices can be for services/custom work
    description         VARCHAR(400) NOT NULL,
    qty                 NUMERIC(14,3) NOT NULL,
    unit                VARCHAR(16) NOT NULL DEFAULT 'pc',
    unit_price_cents    BIGINT NOT NULL,
    discount_cents      BIGINT NOT NULL DEFAULT 0,
    line_total_cents    BIGINT NOT NULL,
    vat_class           VARCHAR(16) NOT NULL DEFAULT 'STANDARD',
    net_cents           BIGINT NOT NULL DEFAULT 0,
    vat_cents           BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);

CREATE TABLE IF NOT EXISTS invoice_payments (
    id                  UUID PRIMARY KEY,
    invoice_id          UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    tenant_id           UUID NOT NULL,
    paid_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    amount_cents        BIGINT NOT NULL,
    method              VARCHAR(20) NOT NULL,              -- CASH | ECOCASH | ONEMONEY | INNBUCKS | ZIPIT | CARD | BANK_TRANSFER
    reference           VARCHAR(80),
    recorded_by         UUID
);
CREATE INDEX IF NOT EXISTS idx_invoice_payments_invoice ON invoice_payments(invoice_id);

-- Per-tenant counter for sequential invoice numbering: INV-YYYY-NNNNNN
CREATE TABLE IF NOT EXISTS invoice_counters (
    tenant_id   UUID NOT NULL,
    year        INT  NOT NULL,
    kind        VARCHAR(16) NOT NULL,          -- INVOICE | QUOTE | PROFORMA | CREDIT_NOTE
    next_value  BIGINT NOT NULL DEFAULT 1,
    PRIMARY KEY (tenant_id, year, kind)
);
