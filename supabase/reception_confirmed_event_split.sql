-- Sahara Club Spa - Split del evento reservation_confirmed según booking_source
-- ----------------------------------------------------------------------------
-- Cuando recepción/admin crea cita en persona (booking_source IN reception, admin)
-- y status nace o pasa a 'confirmed', el trigger emite el nuevo event_type
-- 'reservation_confirmed_reception' → worker enruta a template cita_agendada_recepcion.
--
-- Para landing/app/IA/externo (no nace en mostrador): sigue emitiendo
-- 'reservation_confirmed' (template confirmacion_cita) cuando recepción
-- confirma manualmente.
--
-- NO toca otros eventos: rescheduled, cancelled, reminders.

create or replace function public.handle_booking_whatsapp_events()
returns trigger
language plpgsql
security definer
as $$
declare
  v_source text := coalesce(new.booking_source, 'reception');
  v_reception_event text := 'reservation_confirmed_reception';
  v_remote_event text := 'reservation_confirmed';
  v_confirm_event text;
begin
  -- Elegimos event_type según el origen de la cita.
  -- reception y admin → cita_agendada_recepcion
  -- landing/mobile_app/whatsapp_ai/external → confirmacion_cita (legacy)
  if v_source in ('reception','admin') then
    v_confirm_event := v_reception_event;
  else
    v_confirm_event := v_remote_event;
  end if;

  if tg_op = 'INSERT' then
    if new.status = 'confirmed' and v_source in ('reception','admin') then
      perform public.enqueue_whatsapp_event_safe(
        v_confirm_event, new.id, new.client_record_id);
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_cancelled', new.id, new.client_record_id);
    end if;
    -- pending desde landing/app/IA/externo: NO dispara WhatsApp; recepción
    -- decide después.
    return new;
  end if;

  -- UPDATE: transición de status
  if old.status is distinct from new.status then
    if new.status = 'confirmed' then
      -- pending→confirmed (recepción validó cita externa) o cualquier
      -- otra transición: dispara el evento correcto según origen.
      perform public.enqueue_whatsapp_event_safe(
        v_confirm_event, new.id, new.client_record_id);
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_cancelled', new.id, new.client_record_id);
    end if;
  end if;

  -- UPDATE: cambio de fecha/hora/terapeuta en cita confirmada → reagendado
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

-- Verificación: queue events recientes
select event_type, count(*) as count
from public.whatsapp_queue
where created_at > now() - interval '7 days'
group by 1
order by count desc;
