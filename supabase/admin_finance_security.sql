-- ============================================================
-- Sahara Club Spa - Administración y Finanzas
-- Reorganiza permisos y crea tablas financieras protegidas.
-- ============================================================

create extension if not exists pgcrypto;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.fixed_expenses (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid default '11111111-1111-1111-1111-111111111111'::uuid
    references public.sucursales(id) on delete set null,
  name text not null,
  category text not null default '',
  amount numeric(10,2) not null default 0,
  frequency text not null default 'mensual',
  due_day integer not null default 1,
  payment_method text not null default 'transferencia',
  status text not null default 'pendiente',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supplier_expenses (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid default '11111111-1111-1111-1111-111111111111'::uuid
    references public.sucursales(id) on delete set null,
  supplier_name text not null,
  category text not null default '',
  description text not null default '',
  amount numeric(10,2) not null default 0,
  invoice_number text not null default '',
  payment_method text not null default 'transferencia',
  expense_date date not null default current_date,
  status text not null default 'pendiente',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payroll_entries (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid default '11111111-1111-1111-1111-111111111111'::uuid
    references public.sucursales(id) on delete set null,
  employee_id uuid references public.staff(id) on delete set null,
  period_start date not null,
  period_end date not null,
  base_salary numeric(10,2) not null default 0,
  commissions numeric(10,2) not null default 0,
  bonuses numeric(10,2) not null default 0,
  tips numeric(10,2) not null default 0,
  deductions numeric(10,2) not null default 0,
  total_pay numeric(10,2) not null default 0,
  payment_status text not null default 'pendiente',
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_fixed_expenses_branch_status
  on public.fixed_expenses(branch_id, status, created_at desc);
create index if not exists idx_supplier_expenses_branch_status
  on public.supplier_expenses(branch_id, status, created_at desc);
create index if not exists idx_payroll_entries_branch_status
  on public.payroll_entries(branch_id, payment_status, created_at desc);

drop trigger if exists trg_fixed_expenses_updated_at on public.fixed_expenses;
create trigger trg_fixed_expenses_updated_at
before update on public.fixed_expenses
for each row execute function public.touch_updated_at();

drop trigger if exists trg_supplier_expenses_updated_at on public.supplier_expenses;
create trigger trg_supplier_expenses_updated_at
before update on public.supplier_expenses
for each row execute function public.touch_updated_at();

drop trigger if exists trg_payroll_entries_updated_at on public.payroll_entries;
create trigger trg_payroll_entries_updated_at
before update on public.payroll_entries
for each row execute function public.touch_updated_at();

alter table public.fixed_expenses enable row level security;
alter table public.supplier_expenses enable row level security;
alter table public.payroll_entries enable row level security;

drop policy if exists fixed_expenses_admin_all on public.fixed_expenses;
create policy fixed_expenses_admin_all
  on public.fixed_expenses for all to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'))
  with check (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists supplier_expenses_admin_all on public.supplier_expenses;
create policy supplier_expenses_admin_all
  on public.supplier_expenses for all to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'))
  with check (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists payroll_entries_admin_all on public.payroll_entries;
create policy payroll_entries_admin_all
  on public.payroll_entries for all to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'))
  with check (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists auth_all_products on public.products;
drop policy if exists products_select_authenticated on public.products;
drop policy if exists products_manage_admin on public.products;
create policy products_select_authenticated
  on public.products for select to authenticated
  using (true);
create policy products_manage_admin
  on public.products for all to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'))
  with check (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists services_manage_by_staff on public.services;
drop policy if exists services_manage_admin on public.services;
create policy services_manage_admin
  on public.services for all to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'))
  with check (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists business_whatsapp_settings_select_admin on public.business_whatsapp_settings;
create policy business_whatsapp_settings_select_admin
  on public.business_whatsapp_settings
  for select
  to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists business_whatsapp_settings_manage_admin on public.business_whatsapp_settings;
create policy business_whatsapp_settings_manage_admin
  on public.business_whatsapp_settings
  for all
  to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'))
  with check (public.current_user_role() in ('admin', 'super_admin'));
