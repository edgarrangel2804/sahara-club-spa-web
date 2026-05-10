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

CREATE TABLE IF NOT EXISTS clients (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  UUID UNIQUE REFERENCES profiles(id) ON DELETE SET NULL,
  full_name   TEXT NOT NULL,
  email       TEXT NOT NULL DEFAULT '',
  phone       TEXT NOT NULL DEFAULT '',
  birth_date  DATE,
  notes       TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS client_record_id UUID REFERENCES clients(id) ON DELETE SET NULL;

ALTER TABLE bookings
  ALTER COLUMN client_id DROP NOT NULL;

INSERT INTO clients (profile_id, full_name, email, phone, birth_date, notes)
SELECT
  p.id,
  COALESCE(p.full_name, ''),
  COALESCE(p.email, ''),
  COALESCE(p.phone, ''),
  p.birth_date,
  COALESCE(p.notes, '')
FROM profiles p
WHERE p.role = 'client'
  AND NOT EXISTS (
    SELECT 1 FROM clients c WHERE c.profile_id = p.id
  );

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
ALTER TABLE profiles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE services   ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings   ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients    ENABLE ROW LEVEL SECURITY;

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

DROP POLICY IF EXISTS profiles_insert_by_staff ON profiles;
DROP POLICY IF EXISTS profiles_select_by_role ON profiles;
DROP POLICY IF EXISTS profiles_update_by_role ON profiles;
DROP POLICY IF EXISTS profiles_delete_by_admin ON profiles;
DROP POLICY IF EXISTS services_manage_by_staff ON services;
DROP POLICY IF EXISTS services_select_authenticated ON services;
DROP POLICY IF EXISTS bookings_insert_by_staff ON bookings;
DROP POLICY IF EXISTS bookings_select_by_role ON bookings;
DROP POLICY IF EXISTS bookings_update_by_role ON bookings;
DROP POLICY IF EXISTS bookings_delete_by_staff ON bookings;
DROP POLICY IF EXISTS clients_select_by_role ON clients;
DROP POLICY IF EXISTS clients_insert_by_staff ON clients;
DROP POLICY IF EXISTS clients_update_by_role ON clients;
DROP POLICY IF EXISTS clients_delete_by_staff ON clients;

CREATE POLICY profiles_select_by_role
  ON profiles FOR SELECT TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist', 'therapist')
    OR id = auth.uid()
  );

CREATE POLICY profiles_insert_by_staff
  ON profiles FOR INSERT TO authenticated
  WITH CHECK (
    current_user_role() IN ('admin', 'reception', 'receptionist')
  );

CREATE POLICY profiles_update_by_role
  ON profiles FOR UPDATE TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist')
    OR id = auth.uid()
  )
  WITH CHECK (
    current_user_role() IN ('admin', 'reception', 'receptionist')
    OR id = auth.uid()
  );

CREATE POLICY profiles_delete_by_admin
  ON profiles FOR DELETE TO authenticated
  USING (current_user_role() = 'admin');

CREATE POLICY services_select_authenticated
  ON services FOR SELECT TO authenticated
  USING (true);

CREATE POLICY services_manage_by_staff
  ON services FOR ALL TO authenticated
  USING (current_user_role() IN ('admin', 'reception', 'receptionist'))
  WITH CHECK (current_user_role() IN ('admin', 'reception', 'receptionist'));

CREATE POLICY bookings_select_by_role
  ON bookings FOR SELECT TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist')
    OR therapist_id = auth.uid()
    OR client_id = auth.uid()
  );

CREATE POLICY bookings_insert_by_staff
  ON bookings FOR INSERT TO authenticated
  WITH CHECK (
    current_user_role() IN ('admin', 'reception', 'receptionist')
  );

CREATE POLICY bookings_update_by_role
  ON bookings FOR UPDATE TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist')
    OR therapist_id = auth.uid()
  )
  WITH CHECK (
    current_user_role() IN ('admin', 'reception', 'receptionist')
    OR therapist_id = auth.uid()
  );

CREATE POLICY bookings_delete_by_staff
  ON bookings FOR DELETE TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist')
  );

-- ── Indexes ───────────────────────────────────────────────────
CREATE POLICY clients_select_by_role
  ON clients FOR SELECT TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist', 'therapist')
    OR profile_id = auth.uid()
  );

CREATE POLICY clients_insert_by_staff
  ON clients FOR INSERT TO authenticated
  WITH CHECK (
    current_user_role() IN ('admin', 'reception', 'receptionist')
  );

CREATE POLICY clients_update_by_role
  ON clients FOR UPDATE TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist')
    OR profile_id = auth.uid()
  )
  WITH CHECK (
    current_user_role() IN ('admin', 'reception', 'receptionist')
    OR profile_id = auth.uid()
  );

CREATE POLICY clients_delete_by_staff
  ON clients FOR DELETE TO authenticated
  USING (
    current_user_role() IN ('admin', 'reception', 'receptionist')
  );

CREATE INDEX IF NOT EXISTS idx_sales_created_at   ON sales(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_products_active    ON products(active);
CREATE INDEX IF NOT EXISTS idx_clients_profile_id  ON clients(profile_id);
CREATE INDEX IF NOT EXISTS idx_clients_full_name   ON clients(full_name);
CREATE INDEX IF NOT EXISTS idx_bookings_client_record_id ON bookings(client_record_id);
