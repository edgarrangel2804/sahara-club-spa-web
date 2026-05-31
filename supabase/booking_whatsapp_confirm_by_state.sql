-- Sahara Club Spa - Corrección del disparador de notificaciones WhatsApp
-- ----------------------------------------------------------------------------
-- Reemplaza el split por ORIGEN (reception_confirmed_event_split.sql) por un
-- ruteo atado al ESTADO real de la cita.
--
-- PROBLEMA: la plantilla se elegía por ORIGEN de la cita, no por su ESTADO.
--   reception/admin -> cita_agendada_recepcion ("ha sido AGENDADA")
--   landing/app/IA  -> confirmacion_cita       ("ha sido CONFIRMADA")
-- Resultado: al darle "Confirmar cita" a una cita de recepción, al cliente le
-- llegaba "tu cita ha sido AGENDADA" en lugar de "CONFIRMADA". Contradicción.
--
-- CORRECCIÓN: atar el mensaje al ESTADO, no al origen.
--   Pasa a 'confirmed' (cualquier canal) -> reservation_confirmed (confirmacion_cita)
--   Pasa a 'cancelled'                    -> reservation_cancelled  (cancelacion_cita)
--   Pasa a 'payment_received' (anticipo)  -> reservation_confirmed_reception
--                                            (cita_agendada_recepcion, #24)
--   Cambio de fecha/hora/especialista en cita YA confirmada -> reservation_rescheduled
--
-- ANTICIPO (#24): cuando el cliente paga su depósito (bot vía Stripe o landing),
-- stripe_webhook mueve pending_payment -> payment_received y el cliente recibe
-- "tu cita ha sido agendada" (NO confirmada). Recepción valida y luego marca
-- confirmed -> dispara "tu cita ha sido confirmada". Flujo de 2 pasos.
--
-- AUTO-AGENDADA (#21): cuando recepción/admin CREA la cita (nace 'scheduled'),
-- se dispara solo cita_agendada_recepcion ("tu cita ha sido agendada"). El mensaje
-- de anticipo lo manda recepción MANUAL después (botón WhatsApp). Landing/bot/app
-- NO entran aquí (tienen su propio flujo de anticipo) → filtro por booking_source.
--
-- EXTRA: se blinda el reagendado para que NO se dispare cuando una cita pasa de
-- pendiente -> confirmed y recepción asigna especialista en ese mismo momento
-- (antes eso disparaba un "reagendado" falso porque therapist_id cambiaba).

create or replace function public.handle_booking_whatsapp_events()
returns trigger
language plpgsql
security definer
as $$
declare
  v_source text := coalesce(new.booking_source, 'reception');
begin
  -- ── INSERT ────────────────────────────────────────────────────────────────
  if tg_op = 'INSERT' then
    if new.status = 'confirmed' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed', new.id, new.client_record_id);
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_cancelled', new.id, new.client_record_id);
    elsif new.status = 'scheduled' and v_source in ('reception','admin') then
      -- Cita presencial recién creada → aviso automático de "agendada".
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed_reception', new.id, new.client_record_id);
    end if;
    -- Citas de landing/bot/app que nacen pendientes: NO disparan nada aquí
    -- (mandan su propio mensaje de anticipo).
    return new;
  end if;

  -- ── UPDATE: transición de status ──────────────────────────────────────────
  if old.status is distinct from new.status then
    if new.status = 'confirmed' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed', new.id, new.client_record_id);
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_cancelled', new.id, new.client_record_id);
    elsif new.status = 'payment_received' then
      -- ANTICIPO RECIBIDO (#24): el cliente pagó su depósito (bot vía Stripe o
      -- landing). stripe_webhook mueve la cita pending_payment → payment_received
      -- y este disparador avisa al CLIENTE "tu cita ha sido agendada" con la
      -- MISMA plantilla de recepción (cita_agendada_recepcion). NO es "confirmada":
      -- recepción valida y luego marca confirmed → dispara confirmacion_cita.
      -- La plantilla aprobada por Meta NO sufre el límite de 24h de texto libre.
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed_reception', new.id, new.client_record_id);
    end if;
  end if;

  -- ── UPDATE: reagendado (solo en citas YA confirmadas) ─────────────────────
  -- old.status debe haber sido confirmed/rescheduled para evitar un "reagendado"
  -- espurio cuando apenas se confirma y se asigna especialista.
  if old.status in ('confirmed','rescheduled')
     and new.status in ('confirmed','rescheduled')
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

-- Verificación
select event_type, count(*) as count
from public.whatsapp_queue
where created_at > now() - interval '7 days'
group by 1
order by count desc;
