-- ============================================================================
-- reception_alert_new_booking_trigger.sql
-- Genera la alerta de panel 'booking_pending_reception' para TODA cita nueva
-- originada por el cliente, sin importar el canal:
--   landing (página web), mobile_app, whatsapp_ai, external.
-- Excluye reception/admin (esas las crea el propio personal).
--
-- Antes esto vivía disperso en las Edge Functions y solo cubría WhatsApp en
-- ciertos caminos. Centralizarlo en un trigger AFTER INSERT garantiza que
-- recepción reciba la alerta venga de donde venga la cita.
--
-- 100% ADITIVO e idempotente. Un INSERT por booking ⇒ una alerta.
-- ============================================================================

create or replace function public.notify_reception_on_new_booking()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source  text := coalesce(new.booking_source, 'reception');
  v_service text;
  v_name    text;
  v_phone   text;
  v_channel text;
  v_msg     text;
begin
  -- Solo citas originadas por el cliente. Las de recepción/admin no alertan.
  if v_source not in ('landing','mobile_app','whatsapp_ai','external') then
    return new;
  end if;

  -- No alertar por citas que nacen canceladas (caso raro / importaciones).
  if new.status = 'cancelled' then
    return new;
  end if;

  -- Snapshot estable de servicio y cliente.
  select s.name into v_service
  from public.services s where s.id = new.service_id;

  select c.full_name, c.phone into v_name, v_phone
  from public.clients c where c.id = new.client_record_id;

  -- Mensaje y canal según origen.
  if v_source = 'whatsapp_ai' then
    v_channel := 'whatsapp';
    v_msg := 'Nueva cita por WhatsApp. Validar en agenda y asignar terapeuta.';
  elsif v_source = 'landing' then
    v_channel := 'web';
    v_msg := 'Nueva cita desde la página web. Validar en agenda y asignar terapeuta.';
  elsif v_source = 'mobile_app' then
    v_channel := 'app';
    v_msg := 'Nueva cita desde la app. Validar en agenda y asignar terapeuta.';
  else
    v_channel := 'external';
    v_msg := 'Nueva cita (origen externo). Validar en agenda y asignar terapeuta.';
  end if;

  insert into public.reception_alerts (
    event_type, booking_id, client_record_id, client_name, client_phone,
    service_name, booking_date, booking_time, channel, message
  ) values (
    'booking_pending_reception', new.id, new.client_record_id,
    v_name, v_phone, coalesce(v_service, 'Servicio'),
    new.booking_date, new.booking_time, v_channel, v_msg
  );

  return new;
exception
  when others then
    -- Nunca romper la creación de la cita por una falla en la alerta.
    return new;
end;
$$;

drop trigger if exists trg_notify_reception_on_new_booking on public.bookings;
create trigger trg_notify_reception_on_new_booking
  after insert on public.bookings
  for each row
  execute function public.notify_reception_on_new_booking();
