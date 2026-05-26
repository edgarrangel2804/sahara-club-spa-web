-- Sahara Club Spa - Flujo de reservas IA → recepción
-- ----------------------------------------------------------------------------
-- Cuando el concierge IA detecta intención clara de reservar (servicio, fecha,
-- hora), crea automáticamente un booking con status='pending_reception'.
-- Recepción valida disponibilidad real, luego confirma/reagenda/cancela.
--
-- IMPORTANTE: el trigger handle_booking_whatsapp_events SIGUE disparando
-- WhatsApp solo cuando status='confirmed'. pending_reception es invisible
-- para el flujo de notificaciones.

-- 1. Columnas IA en bookings
alter table public.bookings
  add column if not exists created_by_ai boolean not null default false,
  add column if not exists ai_conversation_id uuid,
  add column if not exists ai_confidence_score numeric;

create index if not exists idx_bookings_pending_reception
  on public.bookings(status, created_at desc)
  where status = 'pending_reception';

create index if not exists idx_bookings_dedup_phone_date
  on public.bookings(client_record_id, booking_date, booking_time, service_id, created_at desc);

-- 2. Garantizar que el trigger NO encole WhatsApp en pending_reception.
--    El trigger actual ya filtra por status='confirmed', así que pending_reception
--    no dispara. Esta función queda como verificación + comentario. Sin cambios.

-- 3. RPC helper: dedup check + crear booking pending_reception en un solo paso.
--    Usada SOLO por la Edge Function whatsapp-ai-router (vía service_role).
create or replace function public.create_pending_booking_from_ai(
  p_phone text,
  p_client_name text,
  p_service_id uuid,
  p_booking_date date,
  p_booking_time time,
  p_duration_min int,
  p_notes text,
  p_ai_conversation_id uuid,
  p_ai_confidence_score numeric default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_client_id uuid;
  v_existing_id uuid;
  v_new_id uuid;
  v_normalized_phone text := regexp_replace(coalesce(p_phone,''),'\D','','g');
begin
  -- Validaciones mínimas
  if v_normalized_phone = '' then
    return jsonb_build_object('ok', false, 'error', 'phone_required');
  end if;
  if p_service_id is null or p_booking_date is null or p_booking_time is null then
    return jsonb_build_object('ok', false, 'error', 'missing_service_or_datetime');
  end if;

  -- 1) Resolver client_record_id por teléfono (últimos 10 dígitos)
  select id into v_client_id
  from public.clients
  where right(regexp_replace(phone,'\D','','g'),10) = right(v_normalized_phone,10)
  order by created_at asc
  limit 1;

  -- Si no existe el cliente, créalo mínimo (recepción puede completarlo después)
  if v_client_id is null then
    insert into public.clients(full_name, phone)
    values (coalesce(nullif(trim(p_client_name),''),'Cliente WhatsApp'), v_normalized_phone)
    returning id into v_client_id;
  end if;

  -- 2) Dedup: ¿hay un booking del mismo cliente, mismo servicio, misma fecha+hora,
  --    creado en los últimos 10 min, en cualquier status no-cancelado?
  select id into v_existing_id
  from public.bookings
  where client_record_id = v_client_id
    and service_id = p_service_id
    and booking_date = p_booking_date
    and booking_time = p_booking_time
    and status not in ('cancelled','no_show')
    and created_at > now() - interval '10 minutes'
  order by created_at desc
  limit 1;

  if v_existing_id is not null then
    return jsonb_build_object(
      'ok', true,
      'created', false,
      'duplicate_prevented', true,
      'booking_id', v_existing_id,
      'status', 'pending_reception',
      'client_id', v_client_id
    );
  end if;

  -- 3) Crear nuevo booking pending_reception
  insert into public.bookings (
    client_record_id,
    service_id,
    booking_date,
    booking_time,
    duration_min,
    status,
    client_notes,
    booking_source,
    source_platform,
    created_by_ai,
    ai_conversation_id,
    ai_confidence_score
  ) values (
    v_client_id,
    p_service_id,
    p_booking_date,
    p_booking_time,
    coalesce(p_duration_min, 60),
    'pending_reception',
    coalesce(nullif(trim(p_notes),''), 'Solicitud creada por IA WhatsApp'),
    'whatsapp_ai',
    'whatsapp',
    true,
    p_ai_conversation_id,
    p_ai_confidence_score
  )
  returning id into v_new_id;

  return jsonb_build_object(
    'ok', true,
    'created', true,
    'duplicate_prevented', false,
    'booking_id', v_new_id,
    'status', 'pending_reception',
    'client_id', v_client_id
  );
end;
$$;

revoke all on function public.create_pending_booking_from_ai(text,text,uuid,date,time,int,text,uuid,numeric) from public;
grant execute on function public.create_pending_booking_from_ai(text,text,uuid,date,time,int,text,uuid,numeric) to service_role;

-- 4. Verificación
select column_name from information_schema.columns
where table_schema='public' and table_name='bookings'
  and column_name in ('created_by_ai','ai_conversation_id','ai_confidence_score')
order by column_name;
