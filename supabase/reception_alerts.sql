-- ============================================================================
-- reception_alerts.sql
-- Capa de alertas internas para RECEPCIÓN.
-- Eventos importantes originados por el cliente (principalmente WhatsApp IA)
-- que recepción debe ver de inmediato dentro del panel, sin revisar el chat.
--
-- 100% ADITIVO: no toca bookings ni la lógica de cancelación/reagenda.
-- La escritura ocurre vía RPC log_reception_alert (security definer) desde las
-- Edge Functions (service_role). Recepción lee y marca como vista/atendida.
-- ============================================================================

-- ── Tabla ───────────────────────────────────────────────────────────────────
create table if not exists public.reception_alerts (
  id                uuid primary key default gen_random_uuid(),
  event_type        text not null
                      check (event_type in (
                        'booking_cancelled',     -- cliente canceló su cita
                        'reschedule_requested',  -- cliente reagendó (revalidar)
                        'deposit_paid',          -- anticipo pagado
                        'requires_reception'     -- cliente atorado: cita confirmada que la IA no puede mover/cancelar
                      )),
  booking_id        uuid references public.bookings(id) on delete set null,
  client_record_id  uuid references public.clients(id) on delete set null,
  client_name       text,
  client_phone      text,
  service_name      text,
  booking_date      date,
  booking_time      time without time zone,
  channel           text not null default 'whatsapp',
  message           text,                          -- motivo / mensaje del cliente
  amount_mxn        numeric,                        -- monto si aplica (anticipo)
  status            text not null default 'unseen'
                      check (status in ('unseen','seen','resolved')),
  created_at        timestamptz not null default now(),
  seen_at           timestamptz,
  seen_by           uuid references public.profiles(id) on delete set null,
  resolved_at       timestamptz,
  resolved_by       uuid references public.profiles(id) on delete set null
);

create index if not exists idx_reception_alerts_status_created
  on public.reception_alerts(status, created_at desc);
create index if not exists idx_reception_alerts_booking
  on public.reception_alerts(booking_id);

-- ── RPC de escritura (la usan las Edge Functions con service_role) ──────────
-- Resuelve servicio/fecha/hora/cliente desde el booking para guardar un
-- snapshot estable (si luego cambia la cita, la alerta conserva el contexto).
create or replace function public.log_reception_alert(
  p_event_type text,
  p_booking_id uuid default null,
  p_phone      text default null,
  p_client_name text default null,
  p_message    text default null,
  p_channel    text default 'whatsapp',
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
  v_client_name text := nullif(trim(coalesce(p_client_name,'')), '');
  v_client_phone text := nullif(trim(coalesce(p_phone,'')), '');
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
      v_service_name, v_booking_date, v_booking_time,
      v_client_record_id, v_client_name, v_client_phone
    from public.bookings b
    left join public.services s on s.id = b.service_id
    left join public.clients  c on c.id = b.client_record_id
    where b.id = p_booking_id;
  end if;

  insert into public.reception_alerts (
    event_type, booking_id, client_record_id, client_name, client_phone,
    service_name, booking_date, booking_time, channel, message, amount_mxn
  ) values (
    p_event_type, p_booking_id, v_client_record_id, v_client_name, v_client_phone,
    v_service_name, v_booking_date, v_booking_time,
    coalesce(nullif(trim(coalesce(p_channel,'')),''), 'whatsapp'),
    nullif(trim(coalesce(p_message,'')), ''),
    p_amount_mxn
  )
  returning id into v_alert_id;

  return v_alert_id;
end;
$$;

revoke all on function public.log_reception_alert(text,uuid,text,text,text,text,numeric) from public;
grant execute on function public.log_reception_alert(text,uuid,text,text,text,text,numeric) to service_role;

-- ── RLS ─────────────────────────────────────────────────────────────────────
-- Mismo criterio que appointment_status_history: solo staff de recepción/admin.
alter table public.reception_alerts enable row level security;

drop policy if exists reception_alerts_select_by_role on public.reception_alerts;
create policy reception_alerts_select_by_role
  on public.reception_alerts
  for select
  to authenticated
  using (current_user_role() = any (array['admin','reception','receptionist']));

-- Recepción solo actualiza el estado (marcar vista/atendida). El insert lo hace
-- el RPC security definer; no se permite insert directo desde el cliente.
drop policy if exists reception_alerts_update_by_role on public.reception_alerts;
create policy reception_alerts_update_by_role
  on public.reception_alerts
  for update
  to authenticated
  using (current_user_role() = any (array['admin','reception','receptionist']))
  with check (current_user_role() = any (array['admin','reception','receptionist']));

-- ── Realtime ────────────────────────────────────────────────────────────────
-- Alta en la publicación para que el panel reciba INSERT/UPDATE en vivo.
do $$
begin
  alter publication supabase_realtime add table public.reception_alerts;
exception
  when duplicate_object then null;
  when others then null;
end $$;
