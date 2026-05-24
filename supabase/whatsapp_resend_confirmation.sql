-- Sahara Club Spa - Reenvío manual de confirmación WhatsApp por cita
-- Validaciones explícitas + encola job reservation_confirmed con prioridad alta.

create or replace function public.whatsapp_resend_booking_confirmation(
  p_booking_id uuid
) returns jsonb
language plpgsql
security definer
as $$
declare
  v_role text;
  v_booking record;
  v_client record;
  v_service record;
  v_therapist record;
  v_phone text;
  v_template record;
  v_queue_id uuid;
begin
  -- 1. Permisos: solo admin o recepción
  v_role := public.current_user_role();
  if v_role not in ('admin','reception','receptionist') then
    return jsonb_build_object('ok', false, 'error',
      'Sin permisos. Se requiere rol admin o recepción.');
  end if;

  -- 2. Carga del booking
  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Cita no encontrada.');
  end if;
  if v_booking.status not in ('confirmed','rescheduled') then
    return jsonb_build_object('ok', false, 'error',
      format('La cita está en estado "%s". Solo se puede reenviar confirmación a citas confirmadas o reagendadas.', v_booking.status));
  end if;

  -- 3. Validaciones de datos requeridos por el template
  if v_booking.client_record_id is null then
    return jsonb_build_object('ok', false, 'error', 'La cita no tiene cliente vinculado.');
  end if;
  select * into v_client from public.clients where id = v_booking.client_record_id;
  v_phone := regexp_replace(coalesce(v_client.phone,''), '\D', '', 'g');
  if v_phone = '' then
    return jsonb_build_object('ok', false, 'error',
      'El cliente no tiene teléfono registrado. Captura el teléfono antes de reenviar.');
  end if;
  if length(v_phone) < 10 then
    return jsonb_build_object('ok', false, 'error',
      format('El teléfono "%s" no tiene formato válido (mínimo 10 dígitos).', v_client.phone));
  end if;

  if v_booking.booking_date is null or v_booking.booking_time is null then
    return jsonb_build_object('ok', false, 'error', 'La cita no tiene fecha u hora.');
  end if;

  if v_booking.service_id is null and coalesce(v_booking.service_name,'') = '' then
    return jsonb_build_object('ok', false, 'error', 'La cita no tiene servicio asignado.');
  end if;

  if v_booking.therapist_id is null then
    return jsonb_build_object('ok', false, 'error', 'La cita no tiene terapeuta asignado.');
  end if;
  select * into v_therapist from public.staff where id = v_booking.therapist_id;
  if coalesce(v_therapist.full_name,'') = '' then
    return jsonb_build_object('ok', false, 'error', 'El terapeuta asignado no tiene nombre registrado.');
  end if;

  -- 4. Verificar template
  select * into v_template
  from public.whatsapp_templates
  where template_key = 'reservation_confirmed' and is_active = true
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error',
      'No existe plantilla activa "reservation_confirmed".');
  end if;

  -- 5. Si el template no está aprobado y NO hay ventana 24h, avisar SIN encolar
  if v_template.meta_template_status <> 'approved' then
    if not public.is_within_customer_service_window('+'||v_phone) then
      return jsonb_build_object(
        'ok', false,
        'pending_template', true,
        'error', 'Plantilla "confirmacion_cita" pendiente de aprobación en Meta. El mensaje se enviará automáticamente una vez aprobada.'
      );
    end if;
  end if;

  -- 6. Encolar con prioridad alta (10 < default 100)
  insert into public.whatsapp_queue (
    branch_id, event_type, reservation_id, customer_id,
    template_id, payload, status, scheduled_at, priority
  ) values (
    coalesce(v_booking.sucursal_id, public.get_default_branch_id()),
    'reservation_confirmed', v_booking.id, v_booking.client_record_id,
    v_template.id, '{}'::jsonb, 'queued', now(), 10
  )
  returning id into v_queue_id;

  return jsonb_build_object(
    'ok', true,
    'queue_id', v_queue_id,
    'message', 'Confirmación encolada. El worker la enviará en menos de 1 minuto.'
  );
end;
$$;

grant execute on function public.whatsapp_resend_booking_confirmation(uuid) to authenticated;

-- Vista cómoda: último estado WhatsApp por booking
create or replace view public.whatsapp_status_per_booking as
with last_log as (
  select distinct on (reservation_id)
    reservation_id, status, meta_template_name, meta_error_message,
    meta_error_code, created_at as last_log_at, sent_at, delivered_at, read_at,
    window_type, error_message
  from public.whatsapp_logs
  where reservation_id is not null
  order by reservation_id, created_at desc
),
last_queue as (
  select distinct on (reservation_id)
    reservation_id, status as queue_status, dead_letter_reason, scheduled_at,
    retry_count, last_error_code
  from public.whatsapp_queue
  where reservation_id is not null
  order by reservation_id, updated_at desc
)
select
  b.id as booking_id,
  l.status as log_status,
  l.meta_template_name,
  l.last_log_at,
  l.sent_at,
  l.delivered_at,
  l.read_at,
  l.meta_error_message,
  l.error_message as log_error,
  q.queue_status,
  q.dead_letter_reason,
  q.scheduled_at,
  q.retry_count,
  case
    when l.status = 'sent' and l.read_at is not null then 'read'
    when l.status = 'sent' and l.delivered_at is not null then 'delivered'
    when l.status = 'sent' then 'sent'
    when q.queue_status in ('queued','pending','retrying','processing') then 'queued'
    when q.queue_status = 'dead_letter' and q.dead_letter_reason like '%no aprobado%' then 'pending_template'
    when q.queue_status = 'dead_letter' then 'failed'
    when l.status = 'failed' then 'failed'
    else 'unknown'
  end as overall_status
from public.bookings b
left join last_log l on l.reservation_id = b.id
left join last_queue q on q.reservation_id = b.id;
