-- ============================================================
-- Sahara Club Spa — Supabase migrations
-- Run this in the Supabase SQL editor (Dashboard → SQL editor)
-- ============================================================

-- ── sales ────────────────────────────────────────────────────
-- profiles client fields
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS email TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS birth_date DATE,
  ADD COLUMN IF NOT EXISTS notes TEXT NOT NULL DEFAULT '';

-- services fields used by agenda/admin modules
ALTER TABLE services
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS duration INTEGER NOT NULL DEFAULT 60,
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS sales (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  client_name     TEXT NOT NULL DEFAULT '',
  total           NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method  TEXT NOT NULL DEFAULT 'efectivo',
  status          TEXT NOT NULL DEFAULT 'paid',
  notes           TEXT NOT NULL DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── sale_items ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sale_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id      UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  price        NUMERIC(10,2) NOT NULL DEFAULT 0,
  quantity     INTEGER NOT NULL DEFAULT 1,
  discount_pct NUMERIC(5,2) NOT NULL DEFAULT 0
);

-- ── products ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price       NUMERIC(10,2) NOT NULL DEFAULT 0,
  stock       INTEGER NOT NULL DEFAULT 0,
  category    TEXT NOT NULL DEFAULT 'general',
  active      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Row-level security ────────────────────────────────────────
ALTER TABLE sales      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE products   ENABLE ROW LEVEL SECURITY;

-- Authenticated staff have full access
CREATE POLICY "auth_all_sales"
  ON sales FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

CREATE POLICY "auth_all_sale_items"
  ON sale_items FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

CREATE POLICY "auth_all_products"
  ON products FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sales_created_at   ON sales(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_products_active    ON products(active);
