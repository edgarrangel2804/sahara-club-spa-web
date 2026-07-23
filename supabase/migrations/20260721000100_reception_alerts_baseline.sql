-- Reconstructed reception alert baseline.
-- Source: remote public schema and supabase/reception_alerts.sql.
-- Gift Card-specific columns are intentionally left to the later Gift Card Alerts migrations.

create table if not exists public.reception_alerts (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  booking_id uuid,
  client_record_id uuid,
  client_name text,
  client_phone text,
  service_name text,
  booking_date date,
  booking_time time without time zone,
  channel text not null default 'whatsapp',
  message text,
  amount_mxn numeric,
  status text not null default 'unseen',
  created_at timestamp with time zone not null default now(),
  seen_at timestamp with time zone,
  seen_by uuid,
  resolved_at timestamp with time zone,
  resolved_by uuid,
  constraint reception_alerts_event_type_check
    check (event_type = any (array[
      'booking_pending_reception',
      'booking_cancelled',
      'reschedule_requested',
      'deposit_paid',
      'requires_reception'
    ]::text[])),
  constraint reception_alerts_status_check
    check (status = any (array['unseen','seen','resolved']::text[]))
);

alter table public.reception_alerts
  add column if not exists event_type text,
  add column if not exists booking_id uuid,
  add column if not exists client_record_id uuid,
  add column if not exists client_name text,
  add column if not exists client_phone text,
  add column if not exists service_name text,
  add column if not exists booking_date date,
  add column if not exists booking_time time without time zone,
  add column if not exists channel text not null default 'whatsapp',
  add column if not exists message text,
  add column if not exists amount_mxn numeric,
  add column if not exists status text not null default 'unseen',
  add column if not exists created_at timestamp with time zone not null default now(),
  add column if not exists seen_at timestamp with time zone,
  add column if not exists seen_by uuid,
  add column if not exists resolved_at timestamp with time zone,
  add column if not exists resolved_by uuid;

alter table public.reception_alerts
  drop constraint if exists reception_alerts_event_type_check;

alter table public.reception_alerts
  add constraint reception_alerts_event_type_check
  check (event_type = any (array[
    'booking_pending_reception',
    'booking_cancelled',
    'reschedule_requested',
    'deposit_paid',
    'requires_reception'
  ]::text[]));

alter table public.reception_alerts
  drop constraint if exists reception_alerts_status_check;

alter table public.reception_alerts
  add constraint reception_alerts_status_check
  check (status = any (array['unseen','seen','resolved']::text[]));

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass and conname = 'reception_alerts_booking_id_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_booking_id_fkey
      foreign key (booking_id) references public.bookings(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass and conname = 'reception_alerts_client_record_id_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_client_record_id_fkey
      foreign key (client_record_id) references public.clients(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass and conname = 'reception_alerts_seen_by_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_seen_by_fkey
      foreign key (seen_by) references public.profiles(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass and conname = 'reception_alerts_resolved_by_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_resolved_by_fkey
      foreign key (resolved_by) references public.profiles(id) on delete set null;
  end if;
end $$;

create index if not exists idx_reception_alerts_status_created
  on public.reception_alerts (status, created_at desc);
create index if not exists idx_reception_alerts_booking
  on public.reception_alerts (booking_id);

create or replace function public.log_reception_alert(
  p_event_type text,
  p_booking_id uuid default null,
  p_phone text default null,
  p_client_name text default null,
  p_message text default null,
  p_channel text default 'whatsapp',
  p_amount_mxn numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alert_id uuid;
  v_service_name text;
  v_booking_date date;
  v_booking_time time;
  v_client_record_id uuid;
  v_client_name text := nullif(trim(coalesce(p_client_name, '')), '');
  v_client_phone text := nullif(trim(coalesce(p_phone, '')), '');
begin
  if p_event_type is null then
    raise exception 'event_type required';
  end if;

  if p_booking_id is not null then
    select
      coalesce(s.name, 'Servicio'),
      b.booking_date,
      b.booking_time,
      b.client_record_id,
      coalesce(v_client_name, c.full_name),
      coalesce(v_client_phone, c.phone)
    into
      v_service_name,
      v_booking_date,
      v_booking_time,
      v_client_record_id,
      v_client_name,
      v_client_phone
    from public.bookings b
    left join public.services s on s.id = b.service_id
    left join public.clients c on c.id = b.client_record_id
    where b.id = p_booking_id;
  end if;

  insert into public.reception_alerts (
    event_type,
    booking_id,
    client_record_id,
    client_name,
    client_phone,
    service_name,
    booking_date,
    booking_time,
    channel,
    message,
    amount_mxn
  ) values (
    p_event_type,
    p_booking_id,
    v_client_record_id,
    v_client_name,
    v_client_phone,
    v_service_name,
    v_booking_date,
    v_booking_time,
    coalesce(nullif(trim(coalesce(p_channel, '')), ''), 'whatsapp'),
    nullif(trim(coalesce(p_message, '')), ''),
    p_amount_mxn
  )
  returning id into v_alert_id;

  return v_alert_id;
end;
$$;

revoke all on function public.log_reception_alert(text, uuid, text, text, text, text, numeric) from public;
grant all on function public.log_reception_alert(text, uuid, text, text, text, text, numeric) to anon;
grant all on function public.log_reception_alert(text, uuid, text, text, text, text, numeric) to authenticated;
grant all on function public.log_reception_alert(text, uuid, text, text, text, text, numeric) to service_role;

alter table public.reception_alerts enable row level security;

drop policy if exists "reception_alerts_select_by_role" on public.reception_alerts;
create policy "reception_alerts_select_by_role"
  on public.reception_alerts
  for select
  to authenticated
  using (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

drop policy if exists "reception_alerts_update_by_role" on public.reception_alerts;
create policy "reception_alerts_update_by_role"
  on public.reception_alerts
  for update
  to authenticated
  using (public.current_user_role() = any (array['admin','reception','receptionist']::text[]))
  with check (public.current_user_role() = any (array['admin','reception','receptionist']::text[]));

grant all on table public.reception_alerts to anon, authenticated, service_role;

do $$
begin
  alter publication supabase_realtime add table public.reception_alerts;
exception
  when duplicate_object then null;
  when undefined_object then null;
  when others then null;
end $$;
