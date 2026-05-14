-- ============================================================
-- Sahara Club Spa - Fase 4 ecommerce + Stripe
-- Ejecutar en Supabase SQL editor
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists product_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table products
  add column if not exists category_id uuid references product_categories(id) on delete set null,
  add column if not exists slug text,
  add column if not exists short_description text not null default '',
  add column if not exists currency text not null default 'MXN',
  add column if not exists product_type text not null default 'physical',
  add column if not exists image_url text not null default '',
  add column if not exists duration_minutes integer,
  add column if not exists is_active boolean not null default true,
  add column if not exists is_featured boolean not null default false,
  add column if not exists stock_quantity integer not null default 0,
  add column if not exists digital_file_url text not null default '',
  add column if not exists updated_at timestamptz not null default now();

update products
set
  slug = coalesce(nullif(slug, ''), lower(regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'))),
  short_description = case
    when short_description = '' then left(description, 160)
    else short_description
  end,
  is_active = coalesce(is_active, active, true),
  stock_quantity = case
    when stock_quantity = 0 then coalesce(stock, 0)
    else stock_quantity
  end,
  product_type = case
    when product_type in ('service', 'digital', 'physical', 'membership', 'gift_card') then product_type
    when lower(category) like '%masaje%' then 'service'
    when lower(category) like '%facial%' then 'service'
    when lower(category) like '%ritual%' then 'service'
    when lower(category) like '%digital%' then 'digital'
    when lower(category) like '%membres%' then 'membership'
    when lower(category) like '%gift%' then 'gift_card'
    else 'physical'
  end
where true;

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references profiles(id) on delete set null,
  customer_name text not null default '',
  customer_email text not null default '',
  customer_phone text not null default '',
  notes text not null default '',
  status text not null default 'pending',
  subtotal numeric(10,2) not null default 0,
  member_credit numeric(10,2) not null default 0,
  service_charge numeric(10,2) not null default 0,
  total numeric(10,2) not null default 0,
  currency text not null default 'MXN',
  stripe_session_id text,
  stripe_payment_intent_id text,
  checkout_url text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_orders_stripe_session_id
  on orders(stripe_session_id)
  where stripe_session_id is not null;

create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id text not null,
  product_name text not null,
  product_description text not null default '',
  image_url text not null default '',
  quantity integer not null default 1,
  unit_price numeric(10,2) not null default 0,
  total_price numeric(10,2) not null default 0,
  currency text not null default 'MXN',
  product_type text not null default 'physical',
  category_key text not null default '',
  duration_minutes integer,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_order_items_order_id on order_items(order_id);
create index if not exists idx_order_items_product_type on order_items(product_type);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  provider text not null default 'stripe',
  status text not null default 'pending',
  amount numeric(10,2) not null default 0,
  currency text not null default 'MXN',
  payment_intent_id text,
  checkout_session_id text,
  raw_response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_payments_order_id on payments(order_id);
create unique index if not exists idx_payments_payment_intent_id
  on payments(payment_intent_id)
  where payment_intent_id is not null;

create table if not exists digital_access (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  order_item_id uuid not null unique references order_items(id) on delete cascade,
  product_id text not null,
  access_status text not null default 'granted',
  access_url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists memberships (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  order_item_id uuid not null unique references order_items(id) on delete cascade,
  customer_id uuid references profiles(id) on delete set null,
  membership_name text not null,
  status text not null default 'active',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists gift_cards (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  order_item_id uuid not null unique references order_items(id) on delete cascade,
  code text not null unique,
  initial_balance numeric(10,2) not null default 0,
  current_balance numeric(10,2) not null default 0,
  currency text not null default 'MXN',
  recipient_name text not null default '',
  sender_name text not null default '',
  message text not null default '',
  delivery_method text not null default 'digital',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_product_categories_updated_at on product_categories;
create trigger trg_product_categories_updated_at
before update on product_categories
for each row execute function public.touch_updated_at();

drop trigger if exists trg_products_updated_at on products;
create trigger trg_products_updated_at
before update on products
for each row execute function public.touch_updated_at();

drop trigger if exists trg_orders_updated_at on orders;
create trigger trg_orders_updated_at
before update on orders
for each row execute function public.touch_updated_at();

drop trigger if exists trg_order_items_updated_at on order_items;
create trigger trg_order_items_updated_at
before update on order_items
for each row execute function public.touch_updated_at();

drop trigger if exists trg_payments_updated_at on payments;
create trigger trg_payments_updated_at
before update on payments
for each row execute function public.touch_updated_at();

drop trigger if exists trg_digital_access_updated_at on digital_access;
create trigger trg_digital_access_updated_at
before update on digital_access
for each row execute function public.touch_updated_at();

drop trigger if exists trg_memberships_updated_at on memberships;
create trigger trg_memberships_updated_at
before update on memberships
for each row execute function public.touch_updated_at();

drop trigger if exists trg_gift_cards_updated_at on gift_cards;
create trigger trg_gift_cards_updated_at
before update on gift_cards
for each row execute function public.touch_updated_at();

alter table product_categories enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table payments enable row level security;
alter table digital_access enable row level security;
alter table memberships enable row level security;
alter table gift_cards enable row level security;

drop policy if exists auth_all_product_categories on product_categories;
create policy auth_all_product_categories
  on product_categories for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_orders on orders;
create policy auth_all_orders
  on orders for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_order_items on order_items;
create policy auth_all_order_items
  on order_items for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_payments on payments;
create policy auth_all_payments
  on payments for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_digital_access on digital_access;
create policy auth_all_digital_access
  on digital_access for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_memberships on memberships;
create policy auth_all_memberships
  on memberships for all to authenticated
  using (true) with check (true);

drop policy if exists auth_all_gift_cards on gift_cards;
create policy auth_all_gift_cards
  on gift_cards for all to authenticated
  using (true) with check (true);
