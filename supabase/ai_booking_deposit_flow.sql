-- Sahara Club Spa - Flujo de anticipo Stripe para citas IA
-- ----------------------------------------------------------------------------
-- Cliente IA → booking(pending_payment) → Stripe checkout 200 MXN →
-- booking(payment_received) → recepción confirma → booking(confirmed) →
-- template cita_agendada_recepcion (o legacy mientras Meta no aprueba).
--
-- NO rompe flujo de la tienda virtual existente (orders + create_checkout_session).
-- Solo agrega nuevos estados al enum booking_status y nuevas columnas Stripe
-- en la tabla bookings.

-- 1. Enum booking_status: valores pending_payment + payment_received
--    se aplican APARTE en tx separadas (PG no permite usar el valor en el
--    mismo tx que se crea). Si ya están, idempotente.

-- 2. Columnas Stripe en bookings (deposit flow)
alter table public.bookings
  add column if not exists deposit_amount numeric,
  add column if not exists stripe_session_id text,
  add column if not exists stripe_payment_intent_id text,
  add column if not exists checkout_url text,
  add column if not exists deposit_paid_at timestamptz,
  add column if not exists payment_status text,
  add column if not exists deposit_alerted_at timestamptz;

create index if not exists idx_bookings_pending_payment_age
  on public.bookings(created_at)
  where status = 'pending_payment';

create unique index if not exists bookings_stripe_session_idx
  on public.bookings(stripe_session_id)
  where stripe_session_id is not null;

-- 3. Alerta automática a recepción si pasan 30 min sin pago
--    (cron job correrá cada 5 min y notificará uno por uno).
create or replace function public.alert_unpaid_deposits()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_unpaid record;
  v_alerts_sent int := 0;
begin
  for v_unpaid in
    select id, client_record_id, booking_date, booking_time, service_id, created_at
    from public.bookings
    where status = 'pending_payment'
      and created_at < now() - interval '30 minutes'
      and deposit_alerted_at is null
    limit 10
  loop
    update public.bookings
      set deposit_alerted_at = now()
      where id = v_unpaid.id;
    -- La invocación de Edge Function se hace via cron + invoke_edge_function
    -- desde el job programado abajo (no aquí porque pg_net no funciona bien
    -- desde dentro de funciones SECURITY DEFINER que se llaman en bucle).
    v_alerts_sent := v_alerts_sent + 1;
  end loop;
  return jsonb_build_object('alerts_marked', v_alerts_sent);
end;
$$;

-- 4. RPC que devuelve la lista de bookings que necesitan alerta
--    El cron llamará a un edge function que mande el WhatsApp por cada uno.
create or replace function public.list_unpaid_deposit_bookings_for_alert()
returns table(
  booking_id uuid,
  client_phone text,
  client_name text,
  service_name text,
  booking_date date,
  booking_time time,
  minutes_since_created int
)
language sql
security definer
as $$
  select
    b.id as booking_id,
    c.phone as client_phone,
    c.full_name as client_name,
    s.name as service_name,
    b.booking_date,
    b.booking_time,
    extract(epoch from (now() - b.created_at))::int / 60 as minutes_since_created
  from public.bookings b
  left join public.clients c on c.id = b.client_record_id
  left join public.services s on s.id = b.service_id
  where b.status = 'pending_payment'
    and b.created_at < now() - interval '30 minutes'
    and b.deposit_alerted_at is null
  order by b.created_at
  limit 10;
$$;

revoke all on function public.alert_unpaid_deposits() from public;
grant execute on function public.alert_unpaid_deposits() to service_role;
revoke all on function public.list_unpaid_deposit_bookings_for_alert() from public;
grant execute on function public.list_unpaid_deposit_bookings_for_alert() to service_role;

-- 5. Verificación
select unnest(enum_range(null::public.booking_status))::text as status
order by 1;
