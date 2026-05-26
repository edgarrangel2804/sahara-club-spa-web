-- Sahara Club Spa - Flujo de status según origen de la cita
-- ----------------------------------------------------------
-- recepción/admin → status=confirmed → WhatsApp inmediato
-- landing/app/IA/externo → status=pending → recepción confirma manualmente
--                                            (al confirmar, dispara WhatsApp)

-- 1. Columna booking_source ---------------------------------
alter table public.bookings
  add column if not exists booking_source text not null default 'reception';

alter table public.bookings
  drop constraint if exists bookings_source_check;
alter table public.bookings
  add constraint bookings_source_check
  check (booking_source in (
    'reception','admin',
    'landing','mobile_app','whatsapp_ai','external'
  ));

create index if not exists idx_bookings_source on public.bookings(booking_source);

-- 2. Refactor trigger handle_booking_whatsapp_events --------
--    Solo encola reservation_confirmed cuando:
--      a) INSERT con status=confirmed Y source IN (reception, admin)
--      b) UPDATE status: cualquier transición → confirmed
--    NUNCA encola si nace pending desde landing/app/IA/externo.
create or replace function public.handle_booking_whatsapp_events()
returns trigger
language plpgsql
security definer
as $$
declare
  v_source text := coalesce(new.booking_source, 'reception');
begin
  if tg_op = 'INSERT' then
    if new.status = 'confirmed' and v_source in ('reception','admin') then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed', new.id, new.client_record_id);
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event_safe(
        'reservation_cancelled', new.id, new.client_record_id);
    end if;
    -- Si nace pending desde landing/app/IA/externo: NO dispara WhatsApp.
    -- Recepción debe revisar y cambiar el status a confirmed para enviarlo.
    return new;
  end if;

  -- UPDATE: transición de status
  if old.status is distinct from new.status then
    if new.status = 'confirmed' then
      -- Transición a confirmed (incluye pending→confirmed): SIEMPRE dispara.
      -- La fuente original no importa aquí; lo que importa es que recepción
      -- (o el sistema) lo confirmó.
      perform public.enqueue_whatsapp_event_safe(
        'reservation_confirmed', new.id, new.client_record_id);
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

-- 3. enqueue_whatsapp_event_safe ya hace dedup por (reservation_id, event_type)
--    en una ventana de 10 min. Ningún cambio adicional necesario.

-- 4. (Opcional) marcar bookings históricos sin source con 'reception' por default.
--    El default ya cubre INSERTS nuevos.
update public.bookings
set booking_source = 'reception'
where booking_source is null;
