-- ============================================================
-- Sahara Club Spa - Agenda -> Ventas -> Caja -> Reportes
-- Ejecutar despues de las migraciones base y antes del deploy
-- ============================================================

create extension if not exists pgcrypto;

alter type public.booking_status add value if not exists 'awaiting_payment' after 'completed';
alter type public.booking_status add value if not exists 'paid' after 'awaiting_payment';

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

alter table public.sales
  add column if not exists branch_id uuid references public.sucursales(id) on delete set null,
  add column if not exists appointment_id uuid references public.bookings(id) on delete set null,
  add column if not exists customer_id uuid references public.clients(id) on delete set null,
  add column if not exists professional_id uuid references public.staff(id) on delete set null,
  add column if not exists subtotal numeric(10,2) not null default 0,
  add column if not exists discount numeric(10,2) not null default 0,
  add column if not exists tax numeric(10,2) not null default 0,
  add column if not exists payment_status text not null default 'pending',
  add column if not exists sale_status text not null default 'open',
  add column if not exists created_by uuid references public.profiles(id) on delete set null,
  add column if not exists updated_at timestamptz not null default now();

update public.sales
set
  subtotal = case when subtotal = 0 then coalesce(total, 0) else subtotal end,
  payment_status = case
    when coalesce(payment_status, '') <> '' then payment_status
    when status = 'paid' then 'paid'
    when status = 'cancelled' then 'refunded'
    else 'pending'
  end,
  sale_status = case
    when coalesce(sale_status, '') <> '' then sale_status
    when status = 'cancelled' then 'cancelled'
    when status = 'paid' then 'completed'
    else 'open'
  end,
  updated_at = now()
where true;

create index if not exists idx_sales_appointment_id on public.sales(appointment_id);
create index if not exists idx_sales_customer_id on public.sales(customer_id);
create index if not exists idx_sales_professional_id on public.sales(professional_id);
create index if not exists idx_sales_payment_status on public.sales(payment_status);
create index if not exists idx_sales_sale_status on public.sales(sale_status);

alter table public.sale_items
  add column if not exists service_id uuid references public.services(id) on delete set null,
  add column if not exists product_id uuid references public.products(id) on delete set null,
  add column if not exists description text not null default '',
  add column if not exists unit_price numeric(10,2) not null default 0,
  add column if not exists total_price numeric(10,2) not null default 0,
  add column if not exists updated_at timestamptz not null default now();

update public.sale_items
set
  description = case when description = '' then coalesce(name, '') else description end,
  unit_price = case when unit_price = 0 then coalesce(price, 0) else unit_price end,
  total_price = case
    when total_price = 0 then round((coalesce(price, 0) * coalesce(quantity, 1) * (1 - (coalesce(discount_pct, 0) / 100.0)))::numeric, 2)
    else total_price
  end,
  updated_at = now()
where true;

create index if not exists idx_sale_items_service_id on public.sale_items(service_id);
create index if not exists idx_sale_items_product_id on public.sale_items(product_id);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid,
  sale_id uuid,
  provider text not null default 'internal',
  status text not null default 'pending',
  amount numeric(10,2) not null default 0,
  currency text not null default 'MXN',
  payment_intent_id text,
  checkout_session_id text,
  raw_response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payments
  add column if not exists order_id uuid;

alter table public.payments
  alter column order_id drop not null;

alter table public.payments
  add column if not exists sale_id uuid,
  add column if not exists provider text not null default 'internal',
  add column if not exists status text not null default 'pending',
  add column if not exists amount numeric(10,2) not null default 0,
  add column if not exists currency text not null default 'MXN',
  add column if not exists payment_intent_id text,
  add column if not exists checkout_session_id text,
  add column if not exists raw_response jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_payments_sale_id on public.payments(sale_id);
create index if not exists idx_payments_status on public.payments(status);

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'sales'
  ) and not exists (
    select 1
    from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'payments'
      and constraint_name = 'payments_sale_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_sale_id_fkey
      foreign key (sale_id) references public.sales(id) on delete cascade;
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'orders'
  ) and not exists (
    select 1
    from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'payments'
      and constraint_name = 'payments_order_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;
end $$;

create table if not exists public.cash_register_sessions (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete set null,
  opened_by uuid references public.profiles(id) on delete set null,
  closed_by uuid references public.profiles(id) on delete set null,
  opening_amount numeric(10,2) not null default 0,
  closing_amount numeric(10,2),
  expected_amount numeric(10,2) not null default 0,
  status text not null default 'open',
  notes text not null default '',
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_cash_register_sessions_branch on public.cash_register_sessions(branch_id, opened_at desc);
create index if not exists idx_cash_register_sessions_status on public.cash_register_sessions(status);

drop trigger if exists trg_sales_updated_at on public.sales;
create trigger trg_sales_updated_at
before update on public.sales
for each row execute function public.touch_updated_at();

drop trigger if exists trg_sale_items_updated_at on public.sale_items;
create trigger trg_sale_items_updated_at
before update on public.sale_items
for each row execute function public.touch_updated_at();

drop trigger if exists trg_payments_updated_at on public.payments;
create trigger trg_payments_updated_at
before update on public.payments
for each row execute function public.touch_updated_at();

drop trigger if exists trg_cash_register_sessions_updated_at on public.cash_register_sessions;
create trigger trg_cash_register_sessions_updated_at
before update on public.cash_register_sessions
for each row execute function public.touch_updated_at();

alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.payments enable row level security;
alter table public.cash_register_sessions enable row level security;

drop policy if exists auth_all_sales on public.sales;
create policy auth_all_sales
  on public.sales for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_sale_items on public.sale_items;
create policy auth_all_sale_items
  on public.sale_items for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_payments on public.payments;
create policy auth_all_payments
  on public.payments for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_cash_register_sessions on public.cash_register_sessions;
create policy auth_all_cash_register_sessions
  on public.cash_register_sessions for all to authenticated
  using (true) with check (true);
