-- Sahara Club Spa - Gift Card digital fulfillment.
-- Incremental/idempotent: no remote application in this phase.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.add_calendar_months(p_date date, p_months integer)
returns date
language plpgsql
immutable
as $$
declare
  v_month_index integer;
  v_year integer;
  v_month integer;
  v_day integer;
  v_last_day integer;
begin
  if p_date is null then
    return null;
  end if;

  v_month_index := (extract(year from p_date)::integer * 12)
    + extract(month from p_date)::integer - 1 + coalesce(p_months, 0);
  v_year := floor(v_month_index / 12);
  v_month := (v_month_index % 12) + 1;
  v_last_day := extract(
    day from (make_date(v_year, v_month, 1) + interval '1 month - 1 day')
  )::integer;
  v_day := least(extract(day from p_date)::integer, v_last_day);

  return make_date(v_year, v_month, v_day);
end;
$$;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'gift_cards'
      and column_name = 'message'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'gift_cards'
      and column_name = 'dedication_message'
  ) then
    alter table public.gift_cards rename column message to dedication_message;
  end if;
end $$;

alter table public.gift_cards
  add column if not exists purchaser_name text not null default '',
  add column if not exists purchaser_phone text not null default '',
  add column if not exists recipient_phone text not null default '',
  add column if not exists dedication_message text not null default '',
  add column if not exists expires_on date,
  add column if not exists package_id uuid,
  add column if not exists package_name text not null default '',
  add column if not exists product_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists digital_asset_path text,
  add column if not exists digital_asset_status text not null default 'pending',
  add column if not exists digital_asset_generated_at timestamptz,
  add column if not exists digital_asset_sha256 text,
  add column if not exists delivery_status text not null default 'pending',
  add column if not exists delivered_at timestamptz,
  add column if not exists delivery_attempts integer not null default 0,
  add column if not exists last_delivery_error text,
  add column if not exists buyer_copy_requested boolean not null default false,
  add column if not exists buyer_copy_delivered_at timestamptz;

do $$
declare
  v_data_type text;
begin
  select data_type into v_data_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'gift_cards'
    and column_name = 'valid_from';

  if v_data_type is null then
    alter table public.gift_cards
      add column valid_from date not null default (timezone('America/Tijuana', now())::date);
  elsif v_data_type = 'timestamp with time zone' then
    alter table public.gift_cards alter column valid_from drop default;
    alter table public.gift_cards
      alter column valid_from type date
      using coalesce((valid_from at time zone 'America/Tijuana')::date,
        timezone('America/Tijuana', now())::date);
    alter table public.gift_cards
      alter column valid_from set default (timezone('America/Tijuana', now())::date);
  elsif v_data_type = 'timestamp without time zone' then
    alter table public.gift_cards alter column valid_from drop default;
    alter table public.gift_cards
      alter column valid_from type date
      using coalesce(valid_from::date, timezone('America/Tijuana', now())::date);
    alter table public.gift_cards
      alter column valid_from set default (timezone('America/Tijuana', now())::date);
  end if;
end $$;

update public.gift_cards
set valid_from = coalesce(valid_from, timezone('America/Tijuana', created_at)::date,
  timezone('America/Tijuana', now())::date);

update public.gift_cards
set expires_on = coalesce(
  expires_on,
  case
    when expires_at is not null then (expires_at at time zone 'America/Tijuana')::date
    else public.add_calendar_months(valid_from, 3)
  end
);

alter table public.gift_cards
  alter column valid_from set not null,
  alter column product_snapshot set default '{}'::jsonb,
  alter column digital_asset_status set default 'pending',
  alter column delivery_status set default 'pending',
  alter column delivery_attempts set default 0,
  alter column buyer_copy_requested set default false;

alter table public.gift_cards
  drop constraint if exists gift_cards_validity_dates_check,
  drop constraint if exists gift_cards_digital_asset_status_check,
  drop constraint if exists gift_cards_delivery_status_check;

alter table public.gift_cards
  add constraint gift_cards_validity_dates_check
    check (expires_on is null or expires_on >= valid_from),
  add constraint gift_cards_digital_asset_status_check
    check (digital_asset_status = any (array['pending','generated','failed']::text[])),
  add constraint gift_cards_delivery_status_check
    check (delivery_status = any (array['pending','processing','sent','partial','failed','skipped']::text[]));

create or replace function public.sync_gift_card_validity()
returns trigger
language plpgsql
as $$
begin
  if new.valid_from is null then
    new.valid_from := timezone('America/Tijuana', now())::date;
  end if;
  if new.expires_on is null then
    if new.expires_at is not null then
      new.expires_on := (new.expires_at at time zone 'America/Tijuana')::date;
    else
      new.expires_on := public.add_calendar_months(new.valid_from, 3);
    end if;
  end if;
  if new.expires_at is null and new.expires_on is not null then
    new.expires_at :=
      ((new.expires_on + 1)::timestamp at time zone 'America/Tijuana')
      - interval '1 millisecond';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_gift_cards_validity on public.gift_cards;
create trigger trg_gift_cards_validity
  before insert or update of valid_from, expires_on, expires_at
  on public.gift_cards
  for each row execute function public.sync_gift_card_validity();

create index if not exists idx_gift_cards_order_item_id
  on public.gift_cards (order_item_id)
  where order_item_id is not null;
create index if not exists idx_gift_cards_validity
  on public.gift_cards (status, valid_from, expires_on)
  where status = 'active';
create index if not exists idx_gift_cards_asset_pending
  on public.gift_cards (digital_asset_status, created_at)
  where digital_asset_status <> 'generated';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gift-card-assets', 'gift-card-assets', false, 10485760, array['application/pdf'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.gift_card_transactions (
  id uuid primary key default gen_random_uuid(),
  gift_card_id uuid not null references public.gift_cards(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  branch_id uuid,
  type text not null check (type in ('load','redeem','refund','adjust','expire')),
  amount numeric not null,
  balance_before numeric,
  balance_after numeric,
  result text not null default 'ok',
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

alter table public.gift_card_transactions
  add column if not exists branch_id uuid,
  add column if not exists result text not null default 'ok';

create index if not exists idx_gift_card_tx_card
  on public.gift_card_transactions (gift_card_id, created_at desc);
create index if not exists idx_gift_card_tx_client
  on public.gift_card_transactions (client_id, created_at desc);
create unique index if not exists gift_card_redeem_once_per_booking
  on public.gift_card_transactions (gift_card_id, booking_id, type)
  where booking_id is not null and type = 'redeem';

create table if not exists public.gift_card_deliveries (
  id uuid primary key default gen_random_uuid(),
  gift_card_id uuid not null references public.gift_cards(id) on delete cascade,
  destination_hash text not null,
  delivery_type text not null,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  last_attempt_at timestamptz,
  delivered_at timestamptz,
  last_error text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gift_card_deliveries_type_check
    check (delivery_type = any (array[
      'recipient_whatsapp',
      'buyer_whatsapp_copy',
      'download',
      'reception_resend'
    ]::text[])),
  constraint gift_card_deliveries_status_check
    check (status = any (array['pending','processing','sent','failed','skipped']::text[])),
  constraint gift_card_deliveries_destination_nonempty
    check (length(trim(destination_hash)) >= 16),
  unique (gift_card_id, destination_hash, delivery_type)
);

create index if not exists idx_gift_card_deliveries_card
  on public.gift_card_deliveries (gift_card_id, created_at desc);
create index if not exists idx_gift_card_deliveries_retry
  on public.gift_card_deliveries (status, last_attempt_at)
  where status in ('pending','processing','failed');

drop trigger if exists trg_gift_card_deliveries_updated_at on public.gift_card_deliveries;
create trigger trg_gift_card_deliveries_updated_at
  before update on public.gift_card_deliveries
  for each row execute function public.touch_updated_at();

create or replace function public.claim_gift_card_delivery(
  p_gift_card_id uuid,
  p_destination_hash text,
  p_delivery_type text
)
returns table(delivery_id uuid, claimed boolean, status text, attempt_count integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.gift_card_deliveries%rowtype;
begin
  insert into public.gift_card_deliveries (
    gift_card_id, destination_hash, delivery_type, status, attempt_count, last_attempt_at
  ) values (
    p_gift_card_id, p_destination_hash, p_delivery_type, 'processing', 1, now()
  )
  on conflict (gift_card_id, destination_hash, delivery_type) do nothing
  returning * into v_row;

  if found then
    delivery_id := v_row.id;
    claimed := true;
    status := v_row.status;
    attempt_count := v_row.attempt_count;
    return next;
    return;
  end if;

  select * into v_row
  from public.gift_card_deliveries
  where gift_card_id = p_gift_card_id
    and destination_hash = p_destination_hash
    and delivery_type = p_delivery_type
  for update;

  if not found then
    delivery_id := null;
    claimed := false;
    status := 'failed';
    attempt_count := 0;
    return next;
    return;
  end if;

  if v_row.status = 'sent' then
    delivery_id := v_row.id;
    claimed := false;
    status := v_row.status;
    attempt_count := v_row.attempt_count;
    return next;
    return;
  end if;

  if v_row.status = 'processing'
     and v_row.last_attempt_at > now() - interval '5 minutes' then
    delivery_id := v_row.id;
    claimed := false;
    status := v_row.status;
    attempt_count := v_row.attempt_count;
    return next;
    return;
  end if;

  update public.gift_card_deliveries
  set status = 'processing',
      attempt_count = coalesce(attempt_count, 0) + 1,
      last_attempt_at = now(),
      updated_at = now()
  where id = v_row.id
  returning * into v_row;

  delivery_id := v_row.id;
  claimed := true;
  status := v_row.status;
  attempt_count := v_row.attempt_count;
  return next;
end;
$$;

create or replace function public.complete_gift_card_delivery(
  p_delivery_id uuid,
  p_status text,
  p_last_error text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.gift_card_deliveries
  set status = p_status,
      delivered_at = case when p_status = 'sent' then now() else delivered_at end,
      last_error = nullif(trim(coalesce(p_last_error, '')), ''),
      metadata = coalesce(metadata, '{}'::jsonb) || coalesce(p_metadata, '{}'::jsonb),
      updated_at = now()
  where id = p_delivery_id
    and p_status = any (array['sent','failed','skipped']::text[]);
end;
$$;

alter table public.reception_alerts
  add column if not exists order_id uuid,
  add column if not exists order_item_id uuid,
  add column if not exists gift_card_id uuid,
  add column if not exists payment_id uuid,
  add column if not exists buyer_name text,
  add column if not exists buyer_email text,
  add column if not exists buyer_phone text,
  add column if not exists product_name text,
  add column if not exists face_value numeric(10, 2),
  add column if not exists amount_paid numeric(10, 2),
  add column if not exists currency text,
  add column if not exists purchase_channel text,
  add column if not exists occurred_at timestamptz,
  add column if not exists metadata jsonb default '{}'::jsonb;

update public.reception_alerts
set metadata = '{}'::jsonb
where metadata is null;

alter table public.reception_alerts
  drop constraint if exists reception_alerts_event_type_check,
  drop constraint if exists reception_alerts_purchase_channel_check;

alter table public.reception_alerts
  add constraint reception_alerts_event_type_check
  check (
    event_type = any (array[
      'booking_pending_reception',
      'booking_cancelled',
      'reschedule_requested',
      'deposit_paid',
      'requires_reception',
      'gift_card_purchased'
    ]::text[])
  ),
  add constraint reception_alerts_purchase_channel_check
  check (
    purchase_channel is null
    or purchase_channel = any (array['web','whatsapp','reception','unknown']::text[])
  );

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass
      and conname = 'reception_alerts_order_id_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass
      and conname = 'reception_alerts_order_item_id_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_order_item_id_fkey
      foreign key (order_item_id) references public.order_items(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass
      and conname = 'reception_alerts_gift_card_id_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_gift_card_id_fkey
      foreign key (gift_card_id) references public.gift_cards(id) on delete set null;
  end if;
end $$;

create unique index if not exists reception_alerts_one_gift_card_purchase
  on public.reception_alerts (gift_card_id)
  where event_type = 'gift_card_purchased'
    and gift_card_id is not null;
create index if not exists idx_reception_alerts_order
  on public.reception_alerts (order_id)
  where order_id is not null;
create index if not exists idx_reception_alerts_occurred_at
  on public.reception_alerts (occurred_at desc)
  where occurred_at is not null;

create or replace function public.redeem_service_gift_card(
  p_client_id uuid,
  p_service_id uuid,
  p_booking_id uuid default null,
  p_amount numeric default 0,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gc public.gift_cards%rowtype;
  v_today date := timezone('America/Tijuana', now())::date;
  v_amount numeric := greatest(coalesce(p_amount, 0), 0);
  v_after numeric;
begin
  if p_client_id is null then
    return jsonb_build_object('ok', false, 'error', 'client_id_required');
  end if;

  select * into v_gc
  from public.gift_cards
  where client_id = p_client_id
    and (p_service_id is null or service_id is null or service_id = p_service_id)
    and coalesce(current_balance, 0) > 0
  order by expires_on nulls last, created_at desc
  limit 1
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'gift_card_not_found');
  end if;

  if v_gc.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'gift_card_not_active');
  end if;
  if v_gc.valid_from is not null and v_today < v_gc.valid_from then
    return jsonb_build_object('ok', false, 'error', 'gift_card_not_yet_valid');
  end if;
  if v_gc.expires_on is not null and v_today > v_gc.expires_on then
    return jsonb_build_object('ok', false, 'error', 'gift_card_expired');
  end if;
  if v_amount > 0 and coalesce(v_gc.current_balance, 0) < v_amount then
    return jsonb_build_object('ok', false, 'error', 'gift_card_insufficient_balance');
  end if;
  if p_booking_id is not null and exists (
    select 1 from public.gift_card_transactions
    where gift_card_id = v_gc.id
      and booking_id = p_booking_id
      and type = 'redeem'
  ) then
    return jsonb_build_object('ok', false, 'error', 'gift_card_already_redeemed_for_booking');
  end if;

  v_after := coalesce(v_gc.current_balance, 0) - v_amount;
  update public.gift_cards
  set current_balance = v_after,
      status = case when v_after <= 0 then 'redeemed' else 'active' end,
      updated_at = now()
  where id = v_gc.id;

  insert into public.gift_card_transactions (
    gift_card_id,
    client_id,
    booking_id,
    branch_id,
    type,
    amount,
    balance_before,
    balance_after,
    result,
    notes,
    created_by
  ) values (
    v_gc.id,
    p_client_id,
    p_booking_id,
    p_branch_id,
    'redeem',
    v_amount,
    coalesce(v_gc.current_balance, 0),
    v_after,
    'ok',
    'Gift card redeemed by backend RPC',
    auth.uid()
  );

  return jsonb_build_object(
    'ok', true,
    'gift_card_id', v_gc.id,
    'balance_before', coalesce(v_gc.current_balance, 0),
    'balance_after', v_after,
    'status', case when v_after <= 0 then 'redeemed' else 'active' end
  );
end;
$$;

revoke all on function public.claim_gift_card_delivery(uuid, text, text) from public;
revoke all on function public.complete_gift_card_delivery(uuid, text, text, jsonb) from public;
grant execute on function public.claim_gift_card_delivery(uuid, text, text)
  to service_role;
grant execute on function public.complete_gift_card_delivery(uuid, text, text, jsonb)
  to service_role;
grant execute on function public.redeem_service_gift_card(uuid, uuid, uuid, numeric, uuid)
  to authenticated, service_role;

alter table public.gift_card_deliveries enable row level security;
alter table public.gift_card_transactions enable row level security;

drop policy if exists gift_card_deliveries_service_role_all on public.gift_card_deliveries;
create policy gift_card_deliveries_service_role_all
  on public.gift_card_deliveries
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists gift_card_tx_staff_read on public.gift_card_transactions;
create policy gift_card_tx_staff_read
  on public.gift_card_transactions
  for select
  to authenticated
  using (public.current_user_role() = any (array['admin','reception','receptionist','sales']::text[]));

do $$
begin
  if to_regprocedure('public.get_gift_card_public(text,text)') is not null then
    execute 'revoke all on function public.get_gift_card_public(text,text) from anon';
    execute 'revoke all on function public.get_gift_card_public(text,text) from authenticated';
    execute 'grant execute on function public.get_gift_card_public(text,text) to service_role';
  end if;
end $$;
