-- Políticas para configuracion_sistema
CREATE POLICY solo_admins_leen_config ON configuracion_sistema
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY solo_admins_editan_config ON configuracion_sistema
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- Proteger staff con RLS
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY staff_select_all ON staff
  FOR SELECT USING (true);

CREATE POLICY staff_manage_by_admin ON staff
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- Proteger sales con RLS
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY sales_select_staff ON sales
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'receptionist'))
  );

CREATE POLICY sales_manage_staff ON sales
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'receptionist'))
  );

-- Proteger sale_items con RLS
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY sale_items_select_staff ON sale_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'receptionist'))
  );

CREATE POLICY sale_items_manage_staff ON sale_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'receptionist'))
  );

-- Políticas para whatsapp_templates
CREATE POLICY wt_select_staff ON whatsapp_templates
  FOR SELECT USING (true);

CREATE POLICY wt_manage_admin ON whatsapp_templates
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- Políticas para membership_plans
CREATE POLICY plans_select_all ON membership_plans
  FOR SELECT USING (true);

CREATE POLICY plans_manage_admin ON membership_plans
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );
