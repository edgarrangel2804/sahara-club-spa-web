-- Sahara Club Spa - Gestión de citas del cliente vía concierge IA (Fase 1)
-- ----------------------------------------------------------------------------
-- Tres RPCs read/write usadas SOLO por la Edge Function whatsapp-ai-router
-- (service_role). Permiten que el cliente, desde WhatsApp, consulte, reagende
-- o cancele SUS PROPIAS citas.
--
-- SEGURIDAD (no negociable):
--   - El cliente se resuelve SIEMPRE por su teléfono (últimos 10 dígitos).
--   - Reagendar/cancelar exige que el booking pertenezca a ESE cliente.
--     Si el booking_id no es suyo → error 'not_your_booking'.
--   - Solo se pueden reagendar/cancelar citas en estados NO confirmados
--     (pending, pending_reception, scheduled). Las confirmadas/reagendadas
--     las maneja recepción → error 'requires_reception'.
--   - Reagendar valida disponibilidad real y deja la cita en 'pending_reception'
--     para que recepción re-valide (invisible a los triggers de WhatsApp).

-- Estados que el cliente puede gestionar por sí mismo desde la IA.
-- (confirmed, rescheduled, checked_in, in_progress, completed, etc. → recepción)
-- Definido inline en cada función para mantenerlas autocontenidas.

-- ---------------------------------------------------------------------------
-- 1. Consultar mis citas (read-only)
-- ---------------------------------------------------------------------------
create or replace function public.consult_my_appointments_from_ai(
  p_phone text
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_client_id uuid;
  v_today date := (now() at time zone 'America/Tijuana')::date;
  v_normalized_phone text := regexp_replace(coalesce(p_phone,''),'\D','','g');
  v_appointments jsonb;
begin
  if v_normalized_phone = '' then
    return jsonb_build_object('ok', false, 'error', 'phone_required');
  end if;

  select id into v_client_id
  from public.clients
  where right(regexp_replace(phone,'\D','','g'),10) = right(v_normalized_phone,10)
  order by created_at asc
  limit 1;

  if v_client_id is null then
    return jsonb_build_object('ok', true, 'appointments', '[]'::jsonb, 'client_found', false);
  end if;

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by (t->>'date'), (t->>'time')), '[]'::jsonb)
  into v_appointments
  from (
    select
      b.id::text                                   as booking_id,
      coalesce(s.name, 'Servicio')                 as service_name,
      b.booking_date::text                         as date,
      to_char(b.booking_time, 'HH24:MI')           as time,
      coalesce(b.duration_min, 60)                 as duration_min,
      b.status::text                               as status,
      case b.status::text
        when 'pending'           then 'Pendiente de confirmación'
        when 'pending_reception' then 'En revisión por recepción'
        when 'scheduled'         then 'Agendada (por confirmar)'
        when 'confirmed'         then 'Confirmada'
        when 'rescheduled'       then 'Reagendada (confirmada)'
        when 'checked_in'        then 'En recepción'
        when 'in_progress'       then 'En curso'
        else b.status::text
      end                                          as status_label,
      (b.status::text in ('pending','pending_reception','scheduled')) as ai_manageable
    from public.bookings b
    left join public.services s on s.id = b.service_id
    where b.client_record_id = v_client_id
      and b.booking_date >= v_today
      and b.status not in ('cancelled','no_show','completed')
    order by b.booking_date, b.booking_time
  ) t;

  return jsonb_build_object(
    'ok', true,
    'client_found', true,
    'appointments', v_appointments
  );
end;
$$;

revoke all on function public.consult_my_appointments_from_ai(text) from public;
grant execute on function public.consult_my_appointments_from_ai(text) to service_role;

-- ---------------------------------------------------------------------------
-- 2. Reagendar mi cita
-- ---------------------------------------------------------------------------
create or replace function public.reschedule_my_booking_from_ai(
  p_phone text,
  p_booking_id uuid,
  p_new_date date,
  p_new_time time,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111'
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_client_id uuid;
  v_booking record;
  v_normalized_phone text := regexp_replace(coalesce(p_phone,''),'\D','','g');
  v_avail jsonb;
begin
  if v_normalized_phone = '' then
    return jsonb_build_object('ok', false, 'error', 'phone_required');
  end if;
  if p_booking_id is null or p_new_date is null or p_new_time is null then
    return jsonb_build_object('ok', false, 'error', 'missing_params');
  end if;

  -- 1) Resolver cliente por teléfono
  select id into v_client_id
  from public.clients
  where right(regexp_replace(phone,'\D','','g'),10) = right(v_normalized_phone,10)
  order by created_at asc
  limit 1;

  if v_client_id is null then
    return jsonb_build_object('ok', false, 'error', 'client_not_found');
  end if;

  -- 2) Cargar booking y verificar PROPIEDAD (seguridad)
  select b.id, b.client_record_id, b.service_id, b.duration_min, b.status::text as status
  into v_booking
  from public.bookings b
  where b.id = p_booking_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'booking_not_found');
  end if;
  if v_booking.client_record_id is distinct from v_client_id then
    return jsonb_build_object('ok', false, 'error', 'not_your_booking');
  end if;

  -- 3) Solo estados no confirmados los maneja la IA
  if v_booking.status not in ('pending','pending_reception','scheduled') then
    return jsonb_build_object('ok', false, 'error', 'requires_reception', 'status', v_booking.status);
  end if;

  -- 4) Validar disponibilidad del nuevo horario.
  --    Args nombrados → usa la versión staff-aware (6 params) que usa el router;
  --    p_staff_id queda null (recepción reasigna terapeuta).
  v_avail := public.check_availability_for_booking_from_ai(
    p_service_id   := v_booking.service_id,
    p_requested_date := p_new_date,
    p_requested_time := p_new_time,
    p_duration_min := v_booking.duration_min,
    p_branch_id    := p_branch_id,
    p_staff_id     := null
  );
  if coalesce((v_avail->>'available')::boolean, false) = false then
    return jsonb_build_object(
      'ok', true,
      'rescheduled', false,
      'available', false,
      'reason', v_avail->>'reason',
      'suggested_slots', coalesce(v_avail->'suggested_slots', '[]'::jsonb)
    );
  end if;

  -- 5) Reagendar → vuelve a pending_reception para que recepción re-valide.
  update public.bookings
  set booking_date = p_new_date,
      booking_time = p_new_time,
      status = 'pending_reception',
      client_notes = trim(both E'\n' from
        coalesce(client_notes,'') || E'\n[IA] Reagendada por el cliente vía WhatsApp el ' ||
        to_char(now() at time zone 'America/Tijuana', 'YYYY-MM-DD HH24:MI'))
  where id = p_booking_id;

  return jsonb_build_object(
    'ok', true,
    'rescheduled', true,
    'available', true,
    'booking_id', p_booking_id::text,
    'new_date', p_new_date::text,
    'new_time', to_char(p_new_time, 'HH24:MI'),
    'status', 'pending_reception'
  );
end;
$$;

revoke all on function public.reschedule_my_booking_from_ai(text,uuid,date,time,uuid) from public;
grant execute on function public.reschedule_my_booking_from_ai(text,uuid,date,time,uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Cancelar mi cita
-- ---------------------------------------------------------------------------
create or replace function public.cancel_my_booking_from_ai(
  p_phone text,
  p_booking_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_client_id uuid;
  v_booking record;
  v_normalized_phone text := regexp_replace(coalesce(p_phone,''),'\D','','g');
begin
  if v_normalized_phone = '' then
    return jsonb_build_object('ok', false, 'error', 'phone_required');
  end if;
  if p_booking_id is null then
    return jsonb_build_object('ok', false, 'error', 'missing_booking_id');
  end if;

  select id into v_client_id
  from public.clients
  where right(regexp_replace(phone,'\D','','g'),10) = right(v_normalized_phone,10)
  order by created_at asc
  limit 1;

  if v_client_id is null then
    return jsonb_build_object('ok', false, 'error', 'client_not_found');
  end if;

  select b.id, b.client_record_id, b.status::text as status
  into v_booking
  from public.bookings b
  where b.id = p_booking_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'booking_not_found');
  end if;
  if v_booking.client_record_id is distinct from v_client_id then
    return jsonb_build_object('ok', false, 'error', 'not_your_booking');
  end if;

  if v_booking.status in ('cancelled','no_show','completed') then
    return jsonb_build_object('ok', false, 'error', 'already_closed', 'status', v_booking.status);
  end if;

  -- Citas confirmadas/reagendadas → recepción (puede haber anticipo/política 24h)
  if v_booking.status not in ('pending','pending_reception','scheduled') then
    return jsonb_build_object('ok', false, 'error', 'requires_reception', 'status', v_booking.status);
  end if;

  update public.bookings
  set status = 'cancelled',
      client_notes = trim(both E'\n' from
        coalesce(client_notes,'') || E'\n[IA] Cancelada por el cliente vía WhatsApp el ' ||
        to_char(now() at time zone 'America/Tijuana', 'YYYY-MM-DD HH24:MI') ||
        case when nullif(trim(coalesce(p_reason,'')),'') is not null
             then ' · Motivo: ' || trim(p_reason) else '' end)
  where id = p_booking_id;

  return jsonb_build_object(
    'ok', true,
    'cancelled', true,
    'booking_id', p_booking_id::text,
    'status', 'cancelled'
  );
end;
$$;

revoke all on function public.cancel_my_booking_from_ai(text,uuid,text) from public;
grant execute on function public.cancel_my_booking_from_ai(text,uuid,text) to service_role;
