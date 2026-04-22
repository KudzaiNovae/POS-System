-- Flyway baseline migration for TillPro
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE tenants (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  country_code    CHAR(2) NOT NULL,
  currency        CHAR(3) NOT NULL,
  timezone        TEXT NOT NULL DEFAULT 'Africa/Harare',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  email           TEXT UNIQUE NOT NULL,
  phone           TEXT,
  password_hash   TEXT NOT NULL,
  role            TEXT NOT NULL CHECK (role IN ('OWNER','CASHIER','MANAGER')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_users_tenant ON users (tenant_id);

CREATE TABLE subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID UNIQUE NOT NULL REFERENCES tenants(id),
  tier            TEXT NOT NULL CHECK (tier IN ('FREE','STARTER','PRO','BUSINESS')),
  status          TEXT NOT NULL CHECK (status IN ('ACTIVE','PAST_DUE','CANCELED','TRIALING')),
  current_period_end TIMESTAMPTZ NOT NULL,
  provider        TEXT,
  external_ref    TEXT,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE products (
  id              UUID PRIMARY KEY,
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  sku             TEXT,
  name            TEXT NOT NULL,
  barcode         TEXT,
  price_cents     BIGINT NOT NULL CHECK (price_cents >= 0),
  cost_cents      BIGINT NOT NULL DEFAULT 0,
  stock_qty       NUMERIC(14,3) NOT NULL DEFAULT 0,
  reorder_level   NUMERIC(14,3) NOT NULL DEFAULT 0,
  unit            TEXT NOT NULL DEFAULT 'pc',
  deleted         BOOLEAN NOT NULL DEFAULT false,
  version         BIGINT NOT NULL DEFAULT 1,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, sku)
);
CREATE INDEX ix_products_tenant_updated ON products (tenant_id, updated_at);

CREATE TABLE sales (
  id                 UUID PRIMARY KEY,
  tenant_id          UUID NOT NULL REFERENCES tenants(id),
  cashier_id         UUID REFERENCES users(id),
  total_cents        BIGINT NOT NULL,
  tax_cents          BIGINT NOT NULL DEFAULT 0,
  payment_method     TEXT NOT NULL, -- CASH | ECOCASH | ONEMONEY | INNBUCKS | ZIPIT | CARD | CREDIT

  payment_ref        TEXT,
  status             TEXT NOT NULL DEFAULT 'COMPLETED',
  client_created_at  TIMESTAMPTZ NOT NULL,
  server_received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_sales_tenant_time ON sales (tenant_id, client_created_at DESC);

CREATE TABLE sale_items (
  id               UUID PRIMARY KEY,
  sale_id          UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id       UUID NOT NULL REFERENCES products(id),
  tenant_id        UUID NOT NULL REFERENCES tenants(id),
  name_snapshot    TEXT NOT NULL,
  qty              NUMERIC(14,3) NOT NULL,
  unit_price_cents BIGINT NOT NULL,
  line_total_cents BIGINT NOT NULL
);
CREATE INDEX ix_sale_items_tenant ON sale_items (tenant_id);
CREATE INDEX ix_sale_items_sale ON sale_items (sale_id);

CREATE TABLE stock_movements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id),
  product_id  UUID NOT NULL REFERENCES products(id),
  qty_delta   NUMERIC(14,3) NOT NULL,
  reason      TEXT NOT NULL,
  ref_id      UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_stock_movements_tenant ON stock_movements (tenant_id, created_at DESC);

CREATE TABLE sync_cursors (
  device_id    UUID PRIMARY KEY,
  tenant_id    UUID NOT NULL REFERENCES tenants(id),
  last_pull_at TIMESTAMPTZ NOT NULL DEFAULT '1970-01-01'
);
