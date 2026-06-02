-- Sahara Club Spa - Modulo Paquetes (Fase 1). 100% aditivo.
-- Aplicado como migracion `create_packages_schema` el 2026-06-01.
-- No altera columnas/datos existentes; solo agrega columnas con default y
-- crea 4 tablas nuevas con RLS espejando el patron de client_memberships.
--
-- Decisiones de diseno (acordadas con Edgar):
--  - Pagos diferidos: recepcion los registra a mano (sin Stripe en esta etapa).
--  - Consumo de sesiones: recepcion marca la sesion como usada a mano.
--  - Vigencia: sin vencimiento por defecto (expires_at nulo).
--  - El paquete base (products) es una PLANTILLA editable.
--  - Al asignar a un cliente se guarda una COPIA CONGELADA (client_packages +
--    items_snapshot + client_package_sessions) que no cambia si luego se edita
--    el paquete base.

-- 1) Extender products (aditivo)
alter table public.products
  add column if not exists is_package boolean not null default false,
  add column if not exists package_type text,
  add column if not exists payment_plan_enabled boolean not null default false,
  add column if not exists installments_allowed int[],
  add column if not exists sessions_total int;

-- 2) package_items: servicios de la plantilla del paquete (base, editable)
create table if not exists public.package_items (
  id uuid primary key default gen_random_uuid(),
  package_id uuid not null references public.products(id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  service_name text,
  quantity int not null default 1,
  unit_price numeric not null default 0,
  total_price numeric generated always as (quantity * unit_price) stored,
  created_at timestamptz not null default now()
);
create index if not exists package_items_package_id_idx on public.package_items(package_id);

-- 3) client_packages: copia CONGELADA asignada a un cliente
create table if not exists public.client_packages (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  package_id uuid references public.products(id) on delete set null,
  name text,
  description text,
  status text not null default 'activo'
    check (status in ('activo','completado','pendiente_pago','vencido','cancelado')),
  total_amount numeric not null default 0,
  paid_amount numeric not null default 0,
  pending_amount numeric generated always as (total_amount - paid_amount) stored,
  payment_plan_type text
    check (payment_plan_type in ('single','two_payments','three_payments')),
  installments_count int not null default 1,
  items_snapshot jsonb,
  purchased_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists client_packages_client_id_idx on public.client_packages(client_id);
create index if not exists client_packages_status_idx on public.client_packages(status);

-- 4) client_package_sessions: sesiones disponibles del cliente
create table if not exists public.client_package_sessions (
  id uuid primary key default gen_random_uuid(),
  client_package_id uuid not null references public.client_packages(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  service_name text,
  status text not null default 'pendiente'
    check (status in ('pendiente','usada','cancelada','vencida')),
  used_at timestamptz,
  appointment_id uuid references public.bookings(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists cps_client_package_id_idx on public.client_package_sessions(client_package_id);
create index if not exists cps_client_id_idx on public.client_package_sessions(client_id);

-- 5) client_package_payments: abonos del plan de pago
create table if not exists public.client_package_payments (
  id uuid primary key default gen_random_uuid(),
  client_package_id uuid not null references public.client_packages(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  installment_number int not null,
  amount numeric not null,
  status text not null default 'pendiente'
    check (status in ('pendiente','pagado','vencido','cancelado')),
  due_date date,
  paid_at timestamptz,
  payment_method text,
  created_at timestamptz not null default now()
);
create index if not exists cpp_client_package_id_idx on public.client_package_payments(client_package_id);

-- 6) RLS: admin + receptionist gestionan todo; cliente lee lo suyo.
alter table public.package_items enable row level security;
alter table public.client_packages enable row level security;
alter table public.client_package_sessions enable row level security;
alter table public.client_package_payments enable row level security;

drop policy if exists package_items_staff_manage on public.package_items;
create policy package_items_staff_manage on public.package_items
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])));
drop policy if exists package_items_read on public.package_items;
create policy package_items_read on public.package_items
  for select to authenticated using (true);

drop policy if exists client_packages_staff_manage on public.client_packages;
create policy client_packages_staff_manage on public.client_packages
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])));
drop policy if exists client_packages_client_read on public.client_packages;
create policy client_packages_client_read on public.client_packages
  for select to authenticated
  using (exists (select 1 from public.clients cl where cl.id = client_packages.client_id
                 and cl.profile_id = auth.uid()));

drop policy if exists cps_staff_manage on public.client_package_sessions;
create policy cps_staff_manage on public.client_package_sessions
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])));
drop policy if exists cps_client_read on public.client_package_sessions;
create policy cps_client_read on public.client_package_sessions
  for select to authenticated
  using (exists (select 1 from public.clients cl where cl.id = client_package_sessions.client_id
                 and cl.profile_id = auth.uid()));

drop policy if exists cpp_staff_manage on public.client_package_payments;
create policy cpp_staff_manage on public.client_package_payments
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid()
                 and p.role = any (array['admin'::user_role,'receptionist'::user_role])));
drop policy if exists cpp_client_read on public.client_package_payments;
create policy cpp_client_read on public.client_package_payments
  for select to authenticated
  using (exists (select 1 from public.clients cl where cl.id = client_package_payments.client_id
                 and cl.profile_id = auth.uid()));
