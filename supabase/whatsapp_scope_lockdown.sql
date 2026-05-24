-- Sahara Club Spa - Lockdown de alcance WhatsApp operativo
--
-- Templates activos finales:
--   reservation_confirmed   → confirmacion_cita     (manual recepción)
--   reservation_rescheduled → reagendado_cita       (cambio fecha/hora/terapeuta)
--   reservation_cancelled   → cancelacion_cita      (cambio status → cancelled)
--   reminder_24h            → recordatorio_24h      (20:00 Tijuana, citas mañana)
--   reminder_3h             → recordatorio_3h       (3h antes de la cita, ±30 min)
--   first_visit             → bienvenida_cliente    (opcional)
--
-- Desactivados:
--   reminder_1h     → recordatorio_1h
--   payment_pending → pago_pendiente

-- 1. Desactivar templates fuera de alcance --------------------------------
update public.whatsapp_templates
set is_active = false
where template_key in ('reminder_1h','payment_pending');

-- 2. Cancelar jobs ya encolados con event_type desactivado ----------------
update public.whatsapp_queue
set status = 'cancelled',
    locked_at = null, locked_by = null,
    error_message = 'Evento fuera del alcance vigente (deshabilitado por scope_lockdown)'
where event_type in ('reminder_1h','payment_pending')
  and status in ('queued','pending','retrying','processing');

-- 3. Trigger idempotente: evita duplicados al re-confirmar ----------------
create or replace function public.enqueue_whatsapp_event_safe(
  p_event_type text,
  p_reservation_id uuid,
  p_customer_id uuid default null,
  p_payload jsonb default '{}'::jsonb,
  p_scheduled_at timestamptz default now(),
  p_dedup_window interval default interval '10 minutes'
) returns uuid
language plpgsql
security definer
as $$
declare
  v_id uuid;
  v_branch uuid;
  v_customer uuid := p_customer_id;
begin
  -- Anti-duplicado: si ya hay un evento igual reciente NO terminal, omitir
  if exists (
    select 1
    from public.whatsapp_queue
    where reservation_id = p_reservation_id
      and event_type = p_event_type
      and status in ('queued','pending','processing','retrying','processed','sent','delivered','read')
      and created_at > now() - p_dedup_window
  ) then
    return null;
  end if;

  -- Resuelve branch/customer desde la reserva si vienen null
  select coalesce(sucursal_id, public.get_default_branch_id()),
         coalesce(v_customer, client_record_id)
  into v_branch, v_customer
  from public.bookings
  where id = p_reservation_id;

  insert into public.whatsapp_queue (
    branch_id, event_type, reservation_id, customer_id, payload, status, scheduled_at
  ) values (
    coalesce(v_branch, public.get_default_branch_id()),
    p_event_type, p_reservation_id, v_customer,
    coalesce(p_payload, '{}'::jsonb), 'queued', coalesce(p_scheduled_at, now())
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.handle_booking_whatsapp_events()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'INSERT' then
    -- Solo si entra directamente como confirmed
    if new.status = 'confirmed' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed', new.id, new.client_record_id);
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_cancelled', new.id, new.client_record_id);
    end if;
    return new;
  end if;

  -- UPDATE: detecta transición de estado
  if old.status is distinct from new.status then
    if new.status = 'confirmed' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed', new.id, new.client_record_id);
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_cancelled', new.id, new.client_record_id);
    end if;
  end if;

  -- UPDATE: detecta cambio de fecha/hora/terapeuta (reagendado)
  if new.status in ('confirmed','rescheduled')
     and (old.booking_date is distinct from new.booking_date
          or old.booking_time is distinct from new.booking_time
          or old.therapist_id is distinct from new.therapist_id)
  then
    perform public.enqueue_whatsapp_event_safe(
      'reservation_rescheduled', new.id, new.client_record_id);
  end if;

  return new;
end;
$$;

-- 4. enqueue_due_whatsapp_reminders v3 -----------------------------------
--    - reminder_24h: SOLO a las 20:00-20:29 Tijuana, citas de mañana Tijuana
--    - reminder_3h:  ventana móvil ±30 min sobre la hora exacta
--    - reminder_1h:  ELIMINADO
--    - Fix TZ: trata booking_date+booking_time como hora local Tijuana
create or replace function public.enqueue_due_whatsapp_reminders(
  p_now timestamptz default now()
) returns integer
language plpgsql
security definer
as $$
declare
  total_inserted integer := 0;
  batch_inserted integer;
  tj_now timestamp := (p_now at time zone 'America/Tijuana');
  tj_hour int := extract(hour from tj_now)::int;
  tj_min  int := extract(minute from tj_now)::int;
  tomorrow_tj date := (tj_now::date) + 1;
begin
  -- ----------------- reminder_24h: 20:00-20:29 Tijuana ------------------
  if tj_hour = 20 and tj_min < 30 then
    with candidates as (
      select b.id as booking_id, b.client_record_id,
             coalesce(b.sucursal_id, public.get_default_branch_id()) as branch_id
      from public.bookings b
      where b.status = 'confirmed'
        and b.booking_date = tomorrow_tj
    ),
    filtered as (
      select c.*
      from candidates c
      where not exists (
        select 1 from public.whatsapp_logs l
        where l.reservation_id = c.booking_id
          and l.event_type = 'reminder_24h'
      )
      and not exists (
        select 1 from public.whatsapp_queue q
        where q.reservation_id = c.booking_id
          and q.event_type = 'reminder_24h'
          and q.status not in ('failed','dead_letter','cancelled','skipped')
      )
    )
    insert into public.whatsapp_queue (
      branch_id, event_type, reservation_id, customer_id, payload, status, scheduled_at
    )
    select branch_id, 'reminder_24h', booking_id, client_record_id,
           '{}'::jsonb, 'queued', p_now
    from filtered;
    get diagnostics batch_inserted = ROW_COUNT;
    total_inserted := total_inserted + coalesce(batch_inserted, 0);
  end if;

  -- ----------------- reminder_3h: 3h antes ± 30 min ---------------------
  -- Fix TZ: interpreta booking_date+booking_time como hora Tijuana local
  with candidates as (
    select b.id as booking_id, b.client_record_id,
           coalesce(b.sucursal_id, public.get_default_branch_id()) as branch_id,
           ((b.booking_date::text || ' ' || b.booking_time::text)::timestamp
              at time zone 'America/Tijuana') as booking_ts
    from public.bookings b
    where b.status = 'confirmed'
      and b.booking_date between (p_now at time zone 'America/Tijuana')::date
                             and (p_now at time zone 'America/Tijuana')::date + 1
  ),
  in_window as (
    select c.* from candidates c
    where c.booking_ts between (p_now + interval '3 hours' - interval '30 minutes')
                           and (p_now + interval '3 hours')
  ),
  filtered as (
    select w.*
    from in_window w
    where not exists (
      select 1 from public.whatsapp_logs l
      where l.reservation_id = w.booking_id
        and l.event_type = 'reminder_3h'
    )
    and not exists (
      select 1 from public.whatsapp_queue q
      where q.reservation_id = w.booking_id
        and q.event_type = 'reminder_3h'
        and q.status not in ('failed','dead_letter','cancelled','skipped')
    )
  )
  insert into public.whatsapp_queue (
    branch_id, event_type, reservation_id, customer_id, payload, status, scheduled_at
  )
  select branch_id, 'reminder_3h', booking_id, client_record_id,
         '{}'::jsonb, 'queued', p_now
  from filtered;
  get diagnostics batch_inserted = ROW_COUNT;
  total_inserted := total_inserted + coalesce(batch_inserted, 0);

  return total_inserted;
end;
$$;

-- 5. RPC reenvío: alinear lista de estados permitidos --------------------
-- (sin cambios funcionales, ya solo aplica a reservation_confirmed)
-- 6. Verificación rápida en runtime: log de configuración
do $$ begin
  raise notice 'WhatsApp scope lockdown aplicado. Templates activos: confirmacion_cita, reagendado_cita, cancelacion_cita, recordatorio_24h, recordatorio_3h, bienvenida_cliente. Desactivados: recordatorio_1h, pago_pendiente.';
end $$;
