-- Reconstructed baseline for the ecommerce and notification support surface.
-- Source of truth: verified remote public schema dump plus canonical loose SQL.
-- This is intentionally a subset, not a full dump replay.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'booking_status'
  ) then
    create type public.booking_status as enum (
      'scheduled',
      'pending',
      'confirmed',
      'checked_in',
      'in_progress',
      'completed',
      'awaiting_payment',
      'paid',
      'pending_reception',
      'pending_payment',
      'payment_received',
      'cancelled',
      'rescheduled',
      'no_show'
    );
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'membership_status'
  ) then
    create type public.membership_status as enum (
      'active',
      'inactive',
      'expired',
      'cancelled'
    );
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'payment_status'
  ) then
    create type public.payment_status as enum (
      'pending',
      'paid',
      'refunded',
      'failed'
    );
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'therapist_specialty'
  ) then
    create type public.therapist_specialty as enum (
      'massage',
      'facial',
      'body_treatment',
      'nail_care',
      'hair_removal',
      'hydrotherapy',
      'general'
    );
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'user_role'
  ) then
    create type public.user_role as enum (
      'client',
      'therapist',
      'receptionist',
      'admin'
    );
  end if;
end $$;

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key,
  full_name text,
  phone text,
  avatar_url text,
  role public.user_role default 'client'::public.user_role,
  specialty public.therapist_specialty,
  bio text,
  is_active boolean default true,
  fcm_token text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  permissions text[] default array[
    'ver_caja'::text,
    'ver_gastos'::text,
    'ver_clientes'::text,
    'cancelar_citas'::text
  ],
  commission_pct numeric(5,2) default 20.0,
  birth_date date,
  notes text not null default '',
  email text not null default '',
  active boolean not null default true
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique,
  full_name text not null,
  email text not null default '',
  phone text not null default '',
  birth_date date,
  notes text not null default '',
  created_at timestamp with time zone not null default now(),
  is_frequent boolean not null default false
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  category text not null,
  duration_min integer not null,
  price numeric(10,2) not null,
  image_url text,
  is_active boolean default true,
  display_order integer default 0,
  created_at timestamp with time zone default now(),
  duration integer not null default 60,
  active boolean not null default true,
  tagline text,
  price_on_quote boolean not null default false,
  benefits text[] not null default '{}'::text[],
  contraindications text[] not null default '{}'::text[],
  recommended_for text[] not null default '{}'::text[],
  internal_notes text not null default '',
  sessions_count integer,
  is_package boolean default false
);

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text,
  phone text,
  role text default 'therapist'::text,
  active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  specialties text[] not null default '{}'::text[],
  certifications text[] not null default '{}'::text[],
  bio text not null default '',
  recommended_services uuid[] not null default '{}'::uuid[],
  active_for_ai boolean not null default true,
  years_experience smallint,
  auth_user_id uuid,
  can_login boolean not null default false,
  can_access_web boolean not null default false,
  can_access_mobile boolean not null default false,
  whatsapp text,
  address text,
  city text,
  emergency_contact_name text,
  emergency_contact_phone text,
  work_days text[],
  work_start_time text,
  work_end_time text,
  break_time text,
  show_in_calendar boolean not null default false,
  fixed_salary numeric,
  commission_percentage numeric,
  payment_notes text,
  allow_off_hours_booking boolean not null default false,
  constraint staff_role_check
    check (role = any (array['admin','reception','therapist','cleaning','sales','other']::text[]))
);

create table if not exists public.sucursales (
  id uuid primary key default extensions.uuid_generate_v4(),
  nombre text not null,
  direccion_completa text,
  telefono_contacto text,
  link_maps text,
  created_at timestamp with time zone default now(),
  whatsapp text,
  email text
);

create table if not exists public.membership_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price_monthly numeric(10,2) not null,
  sessions_per_month integer not null,
  includes text[],
  discount_pct numeric(5,2) default 0,
  image_url text,
  icon text,
  is_active boolean default true,
  display_order integer default 0,
  created_at timestamp with time zone default now()
);

create table if not exists public.client_memberships (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  plan_id uuid not null,
  status public.membership_status default 'active'::public.membership_status,
  start_date date not null default current_date,
  end_date date,
  sessions_used integer default 0,
  sessions_total integer not null,
  auto_renew boolean default true,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid,
  therapist_id uuid,
  service_id uuid,
  membership_id uuid,
  booking_date date not null,
  booking_time time without time zone not null,
  duration_min integer not null,
  status public.booking_status default 'scheduled'::public.booking_status,
  cabin text,
  price numeric(10,2),
  session_notes text,
  client_notes text,
  created_by uuid,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  service_name text,
  client_record_id uuid,
  sucursal_id uuid default '11111111-1111-1111-1111-111111111111'::uuid,
  source_platform text not null default 'web',
  updated_by uuid,
  booking_source text not null default 'reception',
  created_by_ai boolean not null default false,
  ai_conversation_id uuid,
  ai_confidence_score numeric,
  deposit_amount numeric,
  stripe_session_id text,
  stripe_payment_intent_id text,
  checkout_url text,
  deposit_paid_at timestamp with time zone,
  payment_status text,
  deposit_alerted_at timestamp with time zone,
  payment_requirement text not null default 'deposit_required',
  waiver_reason text,
  gift_card_id uuid,
  deposit_required_cents integer default 20000,
  deposit_paid_cents integer default 0,
  availability_override boolean not null default false,
  override_reason text,
  override_by uuid,
  client_package_id uuid,
  client_package_session_id uuid,
  constraint bookings_payment_requirement_check
    check (payment_requirement = any (array['deposit_required','waived','paid']::text[])),
  constraint bookings_source_check
    check (booking_source = any (array[
      'reception',
      'admin',
      'landing',
      'mobile_app',
      'whatsapp_ai',
      'external',
      'web',
      'web_concierge'
    ]::text[])),
  constraint bookings_waiver_reason_check
    check (
      waiver_reason is null
      or waiver_reason = any (array['gift_card','membership','package','admin_override']::text[])
    )
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  client_id uuid,
  total numeric not null default 0,
  payment_method text,
  status text default 'paid'::text,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  branch_id uuid,
  appointment_id uuid,
  customer_id uuid,
  professional_id uuid,
  subtotal numeric(10,2) not null default 0,
  discount numeric(10,2) not null default 0,
  tax numeric(10,2) not null default 0,
  payment_status text not null default 'pending',
  sale_status text not null default 'open',
  created_by uuid,
  updated_at timestamp with time zone not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid,
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
  paid_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null,
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
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  redeemed_at timestamp with time zone,
  redeemed_by uuid
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid,
  booking_id uuid,
  membership_id uuid,
  amount numeric(10,2) not null,
  status public.payment_status default 'pending'::public.payment_status,
  payment_method text,
  reference text,
  notes text,
  created_by uuid,
  created_at timestamp with time zone default now(),
  order_id uuid,
  sale_id uuid,
  provider text not null default 'internal',
  currency text not null default 'MXN',
  payment_intent_id text,
  checkout_session_id text,
  raw_response jsonb not null default '{}'::jsonb,
  updated_at timestamp with time zone not null default now()
);

create table if not exists public.gift_cards (
  id uuid primary key default gen_random_uuid(),
  order_id uuid,
  order_item_id uuid unique,
  code text not null unique,
  initial_balance numeric(10,2) not null default 0,
  current_balance numeric(10,2) not null default 0,
  currency text not null default 'MXN',
  recipient_name text not null default '',
  sender_name text not null default '',
  message text not null default '',
  delivery_method text not null default 'digital',
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  client_id uuid,
  valid_from timestamp with time zone default now(),
  expires_at timestamp with time zone,
  notes text,
  service_id uuid,
  service_name text
);

create table if not exists public.business_whatsapp_settings (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null unique,
  business_name text not null default '',
  meta_business_id text not null default '',
  whatsapp_business_account_id text not null default '',
  phone_number_id text not null default '',
  whatsapp_phone_number text not null default '',
  access_token_encrypted text not null default '',
  access_token_masked text not null default '',
  app_id text not null default '',
  app_secret_encrypted text not null default '',
  app_secret_masked text not null default '',
  webhook_verify_token text not null default '',
  connection_status text not null default 'not_configured',
  last_validated_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  environment text not null default 'sandbox',
  is_sandbox boolean not null default true,
  webhook_status text not null default 'not_verified',
  webhook_last_event_at timestamp with time zone,
  webhook_last_verified_at timestamp with time zone,
  webhook_last_error text,
  constraint business_whatsapp_settings_environment_check
    check (environment = any (array['sandbox','production']::text[])),
  constraint business_whatsapp_settings_status_check
    check (connection_status = any (array['not_configured','pending','connected','error']::text[])),
  constraint business_whatsapp_settings_webhook_status_check
    check (webhook_status = any (array['not_verified','verified','error']::text[]))
);

create table if not exists public.ai_settings (
  id smallint primary key default 1,
  ai_enabled boolean not null default false,
  pilot_mode boolean not null default true,
  pilot_phones text[] not null default '{}'::text[],
  llm_model text not null default 'claude-haiku-4-5',
  temperature numeric(3,2) not null default 0.20,
  max_output_tokens integer not null default 400,
  cost_per_million_input_usd numeric(10,4) not null default 0.80,
  cost_per_million_output_usd numeric(10,4) not null default 4.00,
  max_msgs_per_phone_24h integer not null default 30,
  max_tokens_per_conversation integer not null default 50000,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  ai_mode text not null default 'pilot',
  allowed_test_numbers text[] not null default '{}'::text[],
  ai_pause_all_conversations boolean not null default false,
  handoff_human_priority boolean not null default true,
  allow_after_hours_responses boolean not null default false,
  max_messages_per_conversation integer not null default 30,
  max_daily_cost_usd numeric(10,4) not null default 25,
  active_model text not null default 'claude-haiku-4-5',
  ai_admin_numbers text[] not null default '{}'::text[],
  max_admin_daily_cost_usd numeric(10,4) not null default 5,
  admin_daily_report_enabled boolean not null default false,
  admin_daily_report_time time without time zone not null default '20:30:00'::time without time zone,
  admin_daily_report_timezone text not null default 'America/Tijuana',
  admin_daily_report_last_sent_date date,
  human_backup_enabled boolean not null default false,
  human_backup_numbers text[] not null default '{}'::text[],
  human_backup_dedup_minutes integer not null default 15,
  customer_support_start time without time zone not null default '07:00:00'::time without time zone,
  customer_support_end time without time zone not null default '23:59:59'::time without time zone,
  after_hours_message text not null default 'Hola. Nuestro horario de atencion es de 7:00 a.m. a 12:00 a.m. Te responderemos en cuanto abramos. Gracias por escribir a Sahara Club Spa.',
  appointment_deposit_amount numeric not null default 200,
  appointment_deposit_currency text not null default 'mxn',
  appointment_deposit_enabled boolean not null default true,
  appointment_deposit_product_id text,
  appointment_deposit_price_id text,
  constraint ai_settings_id_check check (id = 1),
  constraint ai_settings_mode_check
    check (ai_mode = any (array['disabled','pilot','read_only','assisted']::text[]))
);

create table if not exists public.whatsapp_logs (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid,
  type text,
  sent_at timestamp with time zone default now(),
  reservation_id uuid,
  customer_id uuid,
  template_id uuid,
  queue_id uuid,
  phone text not null default '',
  message_rendered text not null default '',
  status text not null default 'sent',
  provider text not null default 'meta_cloud_api',
  provider_response jsonb not null default '{}'::jsonb,
  delivered_at timestamp with time zone,
  read_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  error_message text,
  event_type text,
  meta_template_name text,
  meta_template_status text,
  meta_language text,
  payload_sent jsonb,
  meta_error_code integer,
  meta_error_message text,
  meta_error_subcode integer,
  window_type text,
  constraint whatsapp_logs_booking_id_type_key unique (booking_id, type)
);

create unique index if not exists bookings_client_date_time_unique
  on public.bookings (client_id, booking_date, booking_time)
  where status is distinct from 'cancelled'::public.booking_status
    and status is distinct from 'no_show'::public.booking_status;
create unique index if not exists bookings_stripe_session_idx
  on public.bookings (stripe_session_id)
  where stripe_session_id is not null;
create unique index if not exists bookings_therapist_date_time_unique
  on public.bookings (therapist_id, booking_date, booking_time)
  where therapist_id is not null
    and status is distinct from 'cancelled'::public.booking_status
    and status is distinct from 'no_show'::public.booking_status;
create index if not exists idx_bookings_client_record_id
  on public.bookings (client_record_id);
create index if not exists idx_bookings_dedup_phone_date
  on public.bookings (client_record_id, booking_date, booking_time, service_id, created_at desc);
create index if not exists idx_bookings_payment_requirement
  on public.bookings (payment_requirement)
  where payment_requirement = any (array['waived','deposit_required']::text[]);
create index if not exists idx_bookings_pending_payment_age
  on public.bookings (created_at)
  where status = 'pending_payment'::public.booking_status;
create index if not exists idx_bookings_pending_reception
  on public.bookings (status, created_at desc)
  where status = 'pending_reception'::public.booking_status;
create index if not exists idx_bookings_source
  on public.bookings (booking_source);
create index if not exists idx_bookings_sucursal_id
  on public.bookings (sucursal_id);

create index if not exists idx_clients_full_name
  on public.clients (full_name);
create index if not exists idx_clients_profile_id
  on public.clients (profile_id);

create index if not exists idx_services_benefits
  on public.services using gin (benefits);
create index if not exists idx_services_recommended_for
  on public.services using gin (recommended_for);

create unique index if not exists idx_orders_stripe_session_id
  on public.orders (stripe_session_id)
  where stripe_session_id is not null;
create index if not exists idx_order_items_order_id
  on public.order_items (order_id);
create index if not exists idx_order_items_product_type
  on public.order_items (product_type);
create index if not exists idx_payments_order_id
  on public.payments (order_id);
create unique index if not exists idx_payments_payment_intent_id
  on public.payments (payment_intent_id)
  where payment_intent_id is not null;
create index if not exists idx_payments_sale_id
  on public.payments (sale_id);
create index if not exists idx_payments_status
  on public.payments (status);
create index if not exists idx_gift_cards_client
  on public.gift_cards (client_id)
  where client_id is not null;
create index if not exists idx_gift_cards_status_active
  on public.gift_cards (client_id, status, expires_at)
  where status = 'active';

create index if not exists idx_business_whatsapp_settings_branch
  on public.business_whatsapp_settings (branch_id);

create index if not exists idx_whatsapp_logs_booking
  on public.whatsapp_logs (booking_id)
  where booking_id is not null;
create index if not exists idx_whatsapp_logs_created_status
  on public.whatsapp_logs (created_at desc, status);
create index if not exists idx_whatsapp_logs_phone
  on public.whatsapp_logs (phone)
  where phone is not null and phone <> '';
create index if not exists idx_whatsapp_logs_reservation_event
  on public.whatsapp_logs (reservation_id, event_type, sent_at desc);
create index if not exists idx_whatsapp_logs_wamid
  on public.whatsapp_logs (((provider_response -> 'messages'::text) -> 0 ->> 'id'::text))
  where provider_response is not null;

create or replace function public.current_user_role()
returns text
language sql
security definer
set search_path = public
as $$
  select role
  from profiles
  where id = auth.uid()
  limit 1
$$;

create or replace function public.get_user_role()
returns text
language sql
stable
as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function public.sync_whatsapp_environment_flags()
returns trigger
language plpgsql
as $$
begin
  if new.environment is null then
    new.environment := case when coalesce(new.is_sandbox, true) then 'sandbox' else 'production' end;
  end if;
  new.is_sandbox := (new.environment = 'sandbox');
  return new;
end;
$$;

drop trigger if exists on_profiles_updated on public.profiles;
create trigger on_profiles_updated
  before update on public.profiles
  for each row execute function public.handle_updated_at();

drop trigger if exists on_bookings_updated on public.bookings;
create trigger on_bookings_updated
  before update on public.bookings
  for each row execute function public.handle_updated_at();

drop trigger if exists on_business_whatsapp_settings_updated on public.business_whatsapp_settings;
create trigger on_business_whatsapp_settings_updated
  before update on public.business_whatsapp_settings
  for each row execute function public.handle_updated_at();

drop trigger if exists on_business_whatsapp_settings_env on public.business_whatsapp_settings;
create trigger on_business_whatsapp_settings_env
  before insert or update on public.business_whatsapp_settings
  for each row execute function public.sync_whatsapp_environment_flags();

drop trigger if exists on_ai_settings_updated on public.ai_settings;
create trigger on_ai_settings_updated
  before update on public.ai_settings
  for each row execute function public.handle_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
  before update on public.orders
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_order_items_updated_at on public.order_items;
create trigger trg_order_items_updated_at
  before update on public.order_items
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_payments_updated_at on public.payments;
create trigger trg_payments_updated_at
  before update on public.payments
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_gift_cards_updated_at on public.gift_cards;
create trigger trg_gift_cards_updated_at
  before update on public.gift_cards
  for each row execute function public.touch_updated_at();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass and conname = 'profiles_id_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_id_fkey
      foreign key (id) references auth.users(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.clients'::regclass and conname = 'clients_profile_id_fkey'
  ) then
    alter table public.clients
      add constraint clients_profile_id_fkey
      foreign key (profile_id) references public.profiles(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.client_memberships'::regclass and conname = 'client_memberships_client_id_fkey'
  ) then
    alter table public.client_memberships
      add constraint client_memberships_client_id_fkey
      foreign key (client_id) references public.clients(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.client_memberships'::regclass and conname = 'client_memberships_plan_id_fkey'
  ) then
    alter table public.client_memberships
      add constraint client_memberships_plan_id_fkey
      foreign key (plan_id) references public.membership_plans(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_client_id_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_client_id_fkey
      foreign key (client_id) references public.profiles(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_client_record_id_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_client_record_id_fkey
      foreign key (client_record_id) references public.clients(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_created_by_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_created_by_fkey
      foreign key (created_by) references public.profiles(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_membership_id_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_membership_id_fkey
      foreign key (membership_id) references public.client_memberships(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_override_by_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_override_by_fkey
      foreign key (override_by) references auth.users(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_service_id_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_service_id_fkey
      foreign key (service_id) references public.services(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_sucursal_id_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_sucursal_id_fkey
      foreign key (sucursal_id) references public.sucursales(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_therapist_id_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_therapist_id_fkey
      foreign key (therapist_id) references public.staff(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_updated_by_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_updated_by_fkey
      foreign key (updated_by) references public.profiles(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.business_whatsapp_settings'::regclass and conname = 'business_whatsapp_settings_branch_id_fkey'
  ) then
    alter table public.business_whatsapp_settings
      add constraint business_whatsapp_settings_branch_id_fkey
      foreign key (branch_id) references public.sucursales(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sales'::regclass and conname = 'sales_appointment_id_fkey'
  ) then
    alter table public.sales
      add constraint sales_appointment_id_fkey
      foreign key (appointment_id) references public.bookings(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sales'::regclass and conname = 'sales_branch_id_fkey'
  ) then
    alter table public.sales
      add constraint sales_branch_id_fkey
      foreign key (branch_id) references public.sucursales(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sales'::regclass and conname = 'sales_client_id_fkey'
  ) then
    alter table public.sales
      add constraint sales_client_id_fkey
      foreign key (client_id) references public.profiles(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sales'::regclass and conname = 'sales_created_by_fkey'
  ) then
    alter table public.sales
      add constraint sales_created_by_fkey
      foreign key (created_by) references public.profiles(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sales'::regclass and conname = 'sales_customer_id_fkey'
  ) then
    alter table public.sales
      add constraint sales_customer_id_fkey
      foreign key (customer_id) references public.clients(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sales'::regclass and conname = 'sales_professional_id_fkey'
  ) then
    alter table public.sales
      add constraint sales_professional_id_fkey
      foreign key (professional_id) references public.staff(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.orders'::regclass and conname = 'orders_customer_id_fkey'
  ) then
    alter table public.orders
      add constraint orders_customer_id_fkey
      foreign key (customer_id) references public.profiles(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.order_items'::regclass and conname = 'order_items_order_id_fkey'
  ) then
    alter table public.order_items
      add constraint order_items_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.payments'::regclass and conname = 'payments_order_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.payments'::regclass and conname = 'payments_booking_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_booking_id_fkey
      foreign key (booking_id) references public.bookings(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.payments'::regclass and conname = 'payments_client_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_client_id_fkey
      foreign key (client_id) references public.profiles(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.payments'::regclass and conname = 'payments_created_by_fkey'
  ) then
    alter table public.payments
      add constraint payments_created_by_fkey
      foreign key (created_by) references public.profiles(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.payments'::regclass and conname = 'payments_membership_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_membership_id_fkey
      foreign key (membership_id) references public.client_memberships(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.payments'::regclass and conname = 'payments_sale_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_sale_id_fkey
      foreign key (sale_id) references public.sales(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.gift_cards'::regclass and conname = 'gift_cards_client_id_fkey'
  ) then
    alter table public.gift_cards
      add constraint gift_cards_client_id_fkey
      foreign key (client_id) references public.clients(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.gift_cards'::regclass and conname = 'gift_cards_order_id_fkey'
  ) then
    alter table public.gift_cards
      add constraint gift_cards_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.gift_cards'::regclass and conname = 'gift_cards_order_item_id_fkey'
  ) then
    alter table public.gift_cards
      add constraint gift_cards_order_item_id_fkey
      foreign key (order_item_id) references public.order_items(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.gift_cards'::regclass and conname = 'gift_cards_service_id_fkey'
  ) then
    alter table public.gift_cards
      add constraint gift_cards_service_id_fkey
      foreign key (service_id) references public.services(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass and conname = 'bookings_gift_card_id_fkey'
  ) then
    alter table public.bookings
      add constraint bookings_gift_card_id_fkey
      foreign key (gift_card_id) references public.gift_cards(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.whatsapp_logs'::regclass and conname = 'whatsapp_logs_booking_id_fkey'
  ) then
    alter table public.whatsapp_logs
      add constraint whatsapp_logs_booking_id_fkey
      foreign key (booking_id) references public.bookings(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.whatsapp_logs'::regclass and conname = 'whatsapp_logs_customer_id_fkey'
  ) then
    alter table public.whatsapp_logs
      add constraint whatsapp_logs_customer_id_fkey
      foreign key (customer_id) references public.clients(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.whatsapp_logs'::regclass and conname = 'whatsapp_logs_reservation_id_fkey'
  ) then
    alter table public.whatsapp_logs
      add constraint whatsapp_logs_reservation_id_fkey
      foreign key (reservation_id) references public.bookings(id) on delete set null;
  end if;
end $$;

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.services enable row level security;
alter table public.staff enable row level security;
alter table public.sucursales enable row level security;
alter table public.membership_plans enable row level security;
alter table public.client_memberships enable row level security;
alter table public.bookings enable row level security;
alter table public.sales enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.gift_cards enable row level security;
alter table public.business_whatsapp_settings enable row level security;
alter table public.ai_settings enable row level security;
alter table public.whatsapp_logs enable row level security;

drop policy if exists "profiles_select_by_role" on public.profiles;
create policy "profiles_select_by_role"
  on public.profiles
  for select
  to authenticated
  using (
    public.current_user_role() = any (array['admin','reception','receptionist','therapist']::text[])
    or id = auth.uid()
  );

drop policy if exists "profiles_insert_by_staff" on public.profiles;
create policy "profiles_insert_by_staff"
  on public.profiles
  for insert
  to authenticated
  with check (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "profiles_update_by_role" on public.profiles;
create policy "profiles_update_by_role"
  on public.profiles
  for update
  to authenticated
  using (
    public.current_user_role() = any (array['admin','reception','receptionist']::text[])
    or id = auth.uid()
  )
  with check (
    public.current_user_role() = any (array['admin','reception','receptionist']::text[])
    or id = auth.uid()
  );

drop policy if exists "profiles_delete_by_admin" on public.profiles;
create policy "profiles_delete_by_admin"
  on public.profiles
  for delete
  to authenticated
  using (public.current_user_role() = 'admin');

drop policy if exists "clients_select_by_role" on public.clients;
create policy "clients_select_by_role"
  on public.clients
  for select
  to authenticated
  using (
    public.current_user_role() = any (array['admin','reception','receptionist','therapist']::text[])
    or profile_id = auth.uid()
  );

drop policy if exists "clients_insert_by_staff" on public.clients;
create policy "clients_insert_by_staff"
  on public.clients
  for insert
  to authenticated
  with check (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "clients_update_by_role" on public.clients;
create policy "clients_update_by_role"
  on public.clients
  for update
  to authenticated
  using (
    public.current_user_role() = any (array['admin','reception','receptionist']::text[])
    or profile_id = auth.uid()
  )
  with check (
    public.current_user_role() = any (array['admin','reception','receptionist']::text[])
    or profile_id = auth.uid()
  );

drop policy if exists "clients_delete_by_staff" on public.clients;
create policy "clients_delete_by_staff"
  on public.clients
  for delete
  to authenticated
  using (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "services_select_authenticated" on public.services;
create policy "services_select_authenticated"
  on public.services
  for select
  to authenticated
  using (true);

drop policy if exists "services_manage_admin" on public.services;
create policy "services_manage_admin"
  on public.services
  to authenticated
  using (public.current_user_role() = any (array['admin','super_admin']::text[]))
  with check (public.current_user_role() = any (array['admin','super_admin']::text[]));

drop policy if exists "bookings_insert_by_staff" on public.bookings;
create policy "bookings_insert_by_staff"
  on public.bookings
  for insert
  to authenticated
  with check (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "bookings_insert_by_client_pending" on public.bookings;
create policy "bookings_insert_by_client_pending"
  on public.bookings
  for insert
  to authenticated
  with check (
    public.current_user_role() = 'client'
    and client_id = auth.uid()
    and coalesce(status::text, 'pending') = 'pending'
  );

drop policy if exists "bookings_select_by_role" on public.bookings;
create policy "bookings_select_by_role"
  on public.bookings
  for select
  to authenticated
  using (
    public.current_user_role() = any (array['admin','reception','receptionist']::text[])
    or therapist_id = auth.uid()
    or client_id = auth.uid()
  );

drop policy if exists "bookings_client_via_client_record" on public.bookings;
create policy "bookings_client_via_client_record"
  on public.bookings
  for select
  to authenticated
  using (
    client_record_id is not null
    and client_record_id in (
      select c.id
      from public.clients c
      where c.profile_id = auth.uid()
    )
  );

drop policy if exists "bookings_select_therapist_all" on public.bookings;
create policy "bookings_select_therapist_all"
  on public.bookings
  for select
  using (public.current_user_role() = 'therapist');

drop policy if exists "bookings_update_by_role" on public.bookings;
create policy "bookings_update_by_role"
  on public.bookings
  for update
  to authenticated
  using (
    public.current_user_role() = any (array['admin','reception','receptionist']::text[])
    or therapist_id = auth.uid()
  )
  with check (
    public.current_user_role() = any (array['admin','reception','receptionist']::text[])
    or therapist_id = auth.uid()
  );

drop policy if exists "bookings_update_therapist_all" on public.bookings;
create policy "bookings_update_therapist_all"
  on public.bookings
  for update
  using (public.current_user_role() = 'therapist')
  with check (public.current_user_role() = 'therapist');

drop policy if exists "bookings_delete_by_staff" on public.bookings;
create policy "bookings_delete_by_staff"
  on public.bookings
  for delete
  to authenticated
  using (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "anon_select_own_orders" on public.orders;
create policy "anon_select_own_orders"
  on public.orders
  for select
  to anon
  using (true);

drop policy if exists "anon_select_own_order_items" on public.order_items;
create policy "anon_select_own_order_items"
  on public.order_items
  for select
  to anon
  using (true);

drop policy if exists "auth_all_orders" on public.orders;
create policy "auth_all_orders"
  on public.orders
  to authenticated
  using (true)
  with check (true);

drop policy if exists "auth_all_order_items" on public.order_items;
create policy "auth_all_order_items"
  on public.order_items
  to authenticated
  using (true)
  with check (true);

drop policy if exists "auth_all_payments" on public.payments;
create policy "auth_all_payments"
  on public.payments
  to authenticated
  using (true)
  with check (true);

drop policy if exists "auth_all_gift_cards" on public.gift_cards;
create policy "auth_all_gift_cards"
  on public.gift_cards
  to authenticated
  using (true)
  with check (true);

drop policy if exists "payments access" on public.payments;
create policy "payments access"
  on public.payments
  using (public.get_user_role() = any (array['admin','reception']::text[]));

drop policy if exists "business_whatsapp_settings_select_admin" on public.business_whatsapp_settings;
create policy "business_whatsapp_settings_select_admin"
  on public.business_whatsapp_settings
  for select
  to authenticated
  using (public.current_user_role() = any (array['admin','super_admin']::text[]));

drop policy if exists "business_whatsapp_settings_manage_admin" on public.business_whatsapp_settings;
create policy "business_whatsapp_settings_manage_admin"
  on public.business_whatsapp_settings
  to authenticated
  using (public.current_user_role() = any (array['admin','super_admin']::text[]))
  with check (public.current_user_role() = any (array['admin','super_admin']::text[]));

drop policy if exists "ai_set_read" on public.ai_settings;
create policy "ai_set_read"
  on public.ai_settings
  for select
  to authenticated
  using (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "ai_set_admin" on public.ai_settings;
create policy "ai_set_admin"
  on public.ai_settings
  to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists "whatsapp_logs_select_staff" on public.whatsapp_logs;
create policy "whatsapp_logs_select_staff"
  on public.whatsapp_logs
  for select
  to authenticated
  using (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "whatsapp_logs_admin_full" on public.whatsapp_logs;
create policy "whatsapp_logs_admin_full"
  on public.whatsapp_logs
  to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

grant usage on schema public to anon, authenticated, service_role;
grant all on function public.handle_updated_at() to anon, authenticated, service_role;
grant all on function public.touch_updated_at() to anon, authenticated, service_role;
grant all on function public.current_user_role() to anon, authenticated, service_role;
grant all on function public.get_user_role() to anon, authenticated, service_role;
grant all on function public.sync_whatsapp_environment_flags() to anon, authenticated, service_role;

grant all on table public.profiles to anon, authenticated, service_role;
grant all on table public.clients to anon, authenticated, service_role;
grant all on table public.services to anon, authenticated, service_role;
grant all on table public.staff to anon, authenticated, service_role;
grant all on table public.sucursales to anon, authenticated, service_role;
grant all on table public.membership_plans to anon, authenticated, service_role;
grant all on table public.client_memberships to anon, authenticated, service_role;
grant all on table public.bookings to anon, authenticated, service_role;
grant all on table public.sales to anon, authenticated, service_role;
grant all on table public.orders to anon, authenticated, service_role;
grant all on table public.order_items to anon, authenticated, service_role;
grant all on table public.payments to anon, authenticated, service_role;
grant all on table public.gift_cards to anon, authenticated, service_role;
grant all on table public.business_whatsapp_settings to anon, authenticated, service_role;
grant all on table public.ai_settings to anon, authenticated, service_role;
grant all on table public.whatsapp_logs to anon, authenticated, service_role;
