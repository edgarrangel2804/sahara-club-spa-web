create extension if not exists pgcrypto;

create table if not exists public.role_permissions (
  id uuid primary key default gen_random_uuid(),
  role text not null,
  module_key text not null,
  can_view boolean not null default false,
  can_create boolean not null default false,
  can_edit boolean not null default false,
  can_delete boolean not null default false,
  can_export boolean not null default false,
  can_manage boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint role_permissions_role_module_unique unique (role, module_key)
);

create index if not exists idx_role_permissions_role
  on public.role_permissions(role);

create index if not exists idx_role_permissions_module_key
  on public.role_permissions(module_key);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists role_permissions_set_updated_at on public.role_permissions;
create trigger role_permissions_set_updated_at
before update on public.role_permissions
for each row
execute function public.set_updated_at();

create or replace function public.normalize_app_role(p_role text)
returns text
language sql
immutable
as $$
  select case
    when lower(coalesce(trim(p_role), '')) in ('reception', 'receptionist') then 'receptionist'
    else lower(coalesce(trim(p_role), ''))
  end;
$$;

create or replace function public.has_role_permission(
  p_role text,
  p_module_key text,
  p_capability text default 'view'
)
returns boolean
language plpgsql
stable
as $$
declare
  normalized_role text := public.normalize_app_role(p_role);
  permission_row public.role_permissions%rowtype;
begin
  if normalized_role in ('admin', 'super_admin') then
    return true;
  end if;

  select *
    into permission_row
  from public.role_permissions
  where role = normalized_role
    and module_key = p_module_key
  limit 1;

  if found then
    return case lower(coalesce(p_capability, 'view'))
      when 'view' then permission_row.can_view
      when 'create' then permission_row.can_create
      when 'edit' then permission_row.can_edit
      when 'delete' then permission_row.can_delete
      when 'export' then permission_row.can_export
      when 'manage' then permission_row.can_manage
      else false
    end;
  end if;

  if normalized_role = 'receptionist' then
    if p_module_key in ('agenda', 'clients', 'sales', 'messages') then
      return lower(coalesce(p_capability, 'view')) in ('view', 'create', 'edit');
    end if;
    return false;
  end if;

  if normalized_role = 'therapist' then
    return p_module_key = 'agenda' and lower(coalesce(p_capability, 'view')) in ('view', 'edit');
  end if;

  if normalized_role = 'client' then
    return p_module_key = 'agenda' and lower(coalesce(p_capability, 'view')) in ('view', 'create');
  end if;

  return false;
end;
$$;

create or replace function public.current_user_has_permission(
  p_module_key text,
  p_capability text default 'view'
)
returns boolean
language sql
stable
as $$
  select public.has_role_permission(public.current_user_role(), p_module_key, p_capability);
$$;

insert into public.role_permissions (
  role,
  module_key,
  can_view,
  can_create,
  can_edit,
  can_delete,
  can_export,
  can_manage
)
values
  ('receptionist', 'dashboard', false, false, false, false, false, false),
  ('receptionist', 'agenda', true, true, true, false, false, false),
  ('receptionist', 'clients', true, true, true, false, false, false),
  ('receptionist', 'sales', true, true, true, false, false, false),
  ('receptionist', 'messages', true, true, true, false, false, false),
  ('receptionist', 'products', false, false, false, false, false, false),
  ('receptionist', 'finances', false, false, false, false, false, false),
  ('receptionist', 'reports', false, false, false, false, false, false),
  ('receptionist', 'payroll', false, false, false, false, false, false),
  ('receptionist', 'fixed_expenses', false, false, false, false, false, false),
  ('receptionist', 'supplier_expenses', false, false, false, false, false, false),
  ('receptionist', 'services', false, false, false, false, false, false),
  ('receptionist', 'templates', false, false, false, false, false, false),
  ('receptionist', 'whatsapp', false, false, false, false, false, false),
  ('receptionist', 'settings', false, false, false, false, false, false),
  ('receptionist', 'staff', false, false, false, false, false, false),
  ('receptionist', 'memberships', false, false, false, false, false, false),
  ('receptionist', 'gift_cards', false, false, false, false, false, false),
  ('receptionist', 'web_content', false, false, false, false, false, false),
  ('receptionist', 'inventory', false, false, false, false, false, false),
  ('receptionist', 'analytics', false, false, false, false, false, false),
  ('receptionist', 'administration', false, false, false, false, false, false)
on conflict (role, module_key) do nothing;

alter table public.role_permissions enable row level security;

drop policy if exists role_permissions_select_admin on public.role_permissions;
create policy role_permissions_select_admin
  on public.role_permissions
  for select
  using (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists role_permissions_select_own_role on public.role_permissions;
create policy role_permissions_select_own_role
  on public.role_permissions
  for select
  using (
    role = public.normalize_app_role(public.current_user_role())
  );

drop policy if exists role_permissions_manage_admin on public.role_permissions;
create policy role_permissions_manage_admin
  on public.role_permissions
  for all
  using (public.current_user_role() in ('admin', 'super_admin'))
  with check (public.current_user_role() in ('admin', 'super_admin'));

do $$
begin
  if to_regclass('public.bookings') is not null then
    execute 'drop policy if exists bookings_dynamic_reception_select on public.bookings';
    execute '
      create policy bookings_dynamic_reception_select
      on public.bookings
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''agenda'', ''view'')
      )';

    execute 'drop policy if exists bookings_dynamic_reception_insert on public.bookings';
    execute '
      create policy bookings_dynamic_reception_insert
      on public.bookings
      as restrictive
      for insert
      with check (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''agenda'', ''create'')
      )';

    execute 'drop policy if exists bookings_dynamic_reception_update on public.bookings';
    execute '
      create policy bookings_dynamic_reception_update
      on public.bookings
      as restrictive
      for update
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''agenda'', ''edit'')
      )
      with check (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''agenda'', ''edit'')
      )';
  end if;

  if to_regclass('public.clients') is not null then
    execute 'drop policy if exists clients_dynamic_reception_select on public.clients';
    execute '
      create policy clients_dynamic_reception_select
      on public.clients
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''clients'', ''view'')
      )';

    execute 'drop policy if exists clients_dynamic_reception_insert on public.clients';
    execute '
      create policy clients_dynamic_reception_insert
      on public.clients
      as restrictive
      for insert
      with check (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''clients'', ''create'')
      )';

    execute 'drop policy if exists clients_dynamic_reception_update on public.clients';
    execute '
      create policy clients_dynamic_reception_update
      on public.clients
      as restrictive
      for update
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''clients'', ''edit'')
      )
      with check (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''clients'', ''edit'')
      )';
  end if;

  if to_regclass('public.sales') is not null then
    execute 'drop policy if exists sales_dynamic_reception_select on public.sales';
    execute '
      create policy sales_dynamic_reception_select
      on public.sales
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''sales'', ''view'')
      )';

    execute 'drop policy if exists sales_dynamic_reception_insert on public.sales';
    execute '
      create policy sales_dynamic_reception_insert
      on public.sales
      as restrictive
      for insert
      with check (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''sales'', ''create'')
      )';

    execute 'drop policy if exists sales_dynamic_reception_update on public.sales';
    execute '
      create policy sales_dynamic_reception_update
      on public.sales
      as restrictive
      for update
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''sales'', ''edit'')
      )
      with check (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''sales'', ''edit'')
      )';
  end if;

  if to_regclass('public.products') is not null then
    execute 'drop policy if exists products_dynamic_reception_select on public.products';
    execute '
      create policy products_dynamic_reception_select
      on public.products
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''products'', ''view'')
      )';
  end if;

  if to_regclass('public.services') is not null then
    execute 'drop policy if exists services_dynamic_reception_select on public.services';
    execute '
      create policy services_dynamic_reception_select
      on public.services
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''services'', ''view'')
      )';
  end if;

  if to_regclass('public.fixed_expenses') is not null then
    execute 'drop policy if exists fixed_expenses_dynamic_reception_select on public.fixed_expenses';
    execute '
      create policy fixed_expenses_dynamic_reception_select
      on public.fixed_expenses
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''fixed_expenses'', ''view'')
      )';
  end if;

  if to_regclass('public.supplier_expenses') is not null then
    execute 'drop policy if exists supplier_expenses_dynamic_reception_select on public.supplier_expenses';
    execute '
      create policy supplier_expenses_dynamic_reception_select
      on public.supplier_expenses
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''supplier_expenses'', ''view'')
      )';
  end if;

  if to_regclass('public.payroll_entries') is not null then
    execute 'drop policy if exists payroll_entries_dynamic_reception_select on public.payroll_entries';
    execute '
      create policy payroll_entries_dynamic_reception_select
      on public.payroll_entries
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''payroll'', ''view'')
      )';
  end if;

  if to_regclass('public.business_whatsapp_settings') is not null then
    execute 'drop policy if exists business_whatsapp_settings_dynamic_reception_select on public.business_whatsapp_settings';
    execute '
      create policy business_whatsapp_settings_dynamic_reception_select
      on public.business_whatsapp_settings
      as restrictive
      for select
      using (
        public.current_user_role() not in (''reception'', ''receptionist'')
        or public.current_user_has_permission(''whatsapp'', ''view'')
      )';
  end if;
end $$;
