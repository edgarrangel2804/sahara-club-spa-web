-- Reconstructed producers for reception alerts.
-- Source: remote public schema plus reception_alert_* loose SQL files.

create or replace function public.notify_reception_on_booking_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source text := coalesce(new.booking_source, 'reception');
  v_role text := public.current_user_role();
  v_service text;
  v_name text;
  v_phone text;
  v_channel text;
  v_event text;
  v_msg text;
begin
  if v_source not in ('landing', 'mobile_app', 'external') then
    return new;
  end if;

  if v_role in ('admin', 'reception', 'receptionist') then
    return new;
  end if;

  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_event := 'booking_cancelled';
    v_msg := 'El cliente cancelo su cita. Validar en agenda.';
  elsif new.status <> 'cancelled' and (
       old.booking_date is distinct from new.booking_date
    or old.booking_time is distinct from new.booking_time
    or old.therapist_id is distinct from new.therapist_id
  ) then
    v_event := 'reschedule_requested';
    v_msg := 'El cliente cambio la fecha/hora de su cita. Revalidar en agenda.';
  else
    return new;
  end if;

  v_channel := case v_source
    when 'landing' then 'web'
    when 'mobile_app' then 'app'
    else 'external'
  end;

  select s.name into v_service
  from public.services s
  where s.id = new.service_id;

  select c.full_name, c.phone into v_name, v_phone
  from public.clients c
  where c.id = new.client_record_id;

  insert into public.reception_alerts (
    event_type,
    booking_id,
    client_record_id,
    client_name,
    client_phone,
    service_name,
    booking_date,
    booking_time,
    channel,
    message
  ) values (
    v_event,
    new.id,
    new.client_record_id,
    v_name,
    v_phone,
    coalesce(v_service, 'Servicio'),
    new.booking_date,
    new.booking_time,
    v_channel,
    v_msg
  );

  return new;
exception
  when others then
    return new;
end;
$$;

create or replace function public.notify_reception_on_new_booking()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source text := coalesce(new.booking_source, 'reception');
  v_service text;
  v_name text;
  v_phone text;
  v_channel text;
  v_msg text;
begin
  if v_source not in ('landing', 'mobile_app', 'whatsapp_ai', 'external') then
    return new;
  end if;

  if new.status = 'cancelled' then
    return new;
  end if;

  select s.name into v_service
  from public.services s
  where s.id = new.service_id;

  select c.full_name, c.phone into v_name, v_phone
  from public.clients c
  where c.id = new.client_record_id;

  if v_source = 'whatsapp_ai' then
    v_channel := 'whatsapp';
    v_msg := 'Nueva cita por WhatsApp. Validar en agenda y asignar terapeuta.';
  elsif v_source = 'landing' then
    v_channel := 'web';
    v_msg := 'Nueva cita desde la pagina web. Validar en agenda y asignar terapeuta.';
  elsif v_source = 'mobile_app' then
    v_channel := 'app';
    v_msg := 'Nueva cita desde la app. Validar en agenda y asignar terapeuta.';
  else
    v_channel := 'external';
    v_msg := 'Nueva cita de origen externo. Validar en agenda y asignar terapeuta.';
  end if;

  insert into public.reception_alerts (
    event_type,
    booking_id,
    client_record_id,
    client_name,
    client_phone,
    service_name,
    booking_date,
    booking_time,
    channel,
    message
  ) values (
    'booking_pending_reception',
    new.id,
    new.client_record_id,
    v_name,
    v_phone,
    coalesce(v_service, 'Servicio'),
    new.booking_date,
    new.booking_time,
    v_channel,
    v_msg
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
  for each row execute function public.notify_reception_on_booking_change();

drop trigger if exists trg_notify_reception_on_new_booking on public.bookings;
create trigger trg_notify_reception_on_new_booking
  after insert on public.bookings
  for each row execute function public.notify_reception_on_new_booking();

grant all on function public.notify_reception_on_booking_change() to anon, authenticated, service_role;
grant all on function public.notify_reception_on_new_booking() to anon, authenticated, service_role;
