-- ============================================================================
-- reception_alert_booking_change_trigger.sql
-- Alerta de panel para CANCELACIONES y REAGENDAS hechas por el CLIENTE desde
-- canales que no son WhatsApp (landing/web, app móvil, externo).
--
-- Regla de negocio: el cliente puede crear/cambiar/cancelar su cita desde
-- cualquier canal, pero recepción SIEMPRE valida. WhatsApp ya genera estas
-- alertas con contexto desde su Edge Function; este trigger cubre el resto de
-- los canales de cliente — sin duplicar y sin autodisparar cuando el cambio
-- lo hace recepción/admin.
--
-- Distingue al autor del cambio con current_user_role() (lee profiles por
-- auth.uid()): recepción/admin desde el panel quedan excluidos; cliente
-- (anónimo o autenticado) y service_role disparan la alerta.
--
-- Cubre:
--   • Cancelación  → status pasa a 'cancelled'      → event 'booking_cancelled'
--   • Reagenda     → cambia booking_date/time/terapeuta → 'reschedule_requested'
--
-- 100% ADITIVO e idempotente. No toca WhatsApp ni el flujo de confirmación.
-- ============================================================================

create or replace function public.notify_reception_on_booking_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source  text := coalesce(new.booking_source, 'reception');
  v_role    text := public.current_user_role();
  v_service text;
  v_name    text;
  v_phone   text;
  v_channel text;
  v_event   text;
  v_msg     text;
begin
  -- Solo canales de cliente DISTINTOS de WhatsApp (WhatsApp ya alerta con
  -- contexto desde su Edge Function). Las citas de recepcion/admin no aplican.
  if v_source not in ('landing','mobile_app','external') then
    return new;
  end if;

  -- Si el cambio lo hizo recepcion/admin (panel), NO alertamos: ellos lo hicieron.
  if v_role in ('admin','reception','receptionist') then
    return new;
  end if;

  -- Clasificar el cambio
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_event := 'booking_cancelled';
    v_msg   := 'El cliente canceló su cita. Validar en agenda.';
  elsif new.status <> 'cancelled' and (
          old.booking_date  is distinct from new.booking_date
       or old.booking_time  is distinct from new.booking_time
       or old.therapist_id  is distinct from new.therapist_id) then
    v_event := 'reschedule_requested';
    v_msg   := 'El cliente cambió la fecha/hora de su cita. Revalidar en agenda.';
  else
    return new; -- cambio irrelevante (confirmación, notas, etc.)
  end if;

  v_channel := case v_source
                 when 'landing'    then 'web'
                 when 'mobile_app' then 'app'
                 else 'external'
               end;

  select s.name into v_service from public.services s where s.id = new.service_id;
  select c.full_name, c.phone into v_name, v_phone
  from public.clients c where c.id = new.client_record_id;

  insert into public.reception_alerts (
    event_type, booking_id, client_record_id, client_name, client_phone,
    service_name, booking_date, booking_time, channel, message
  ) values (
    v_event, new.id, new.client_record_id, v_name, v_phone,
    coalesce(v_service, 'Servicio'), new.booking_date, new.booking_time,
    v_channel, v_msg
  );

  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists trg_notify_reception_on_booking_change on public.bookings;
create trigger trg_notify_reception_on_booking_change
  after update on public.bookings
  for each row
  execute function public.notify_reception_on_booking_change();
