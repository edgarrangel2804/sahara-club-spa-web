-- Sahara Club Spa - disponibilidad real de terapeutas
-- Ejecutar despues de ai_foundation.sql, staff_access_columns.sql y schedule_blocks.sql.

create extension if not exists pgcrypto;

alter table public.schedule_blocks
  add column if not exists staff_id uuid references public.staff(id) on delete cascade;

create index if not exists schedule_blocks_staff_date_idx
  on public.schedule_blocks (staff_id, block_date, start_minute);

alter table public.bookings
  add column if not exists availability_override boolean not null default false,
  add column if not exists override_reason text,
  add column if not exists override_by uuid references auth.users(id) on delete set null;

create table if not exists public.business_settings (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete cascade,
  calendar_start_hour text not null default '08:00',
  calendar_end_hour text not null default '22:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_settings_branch_unique unique (branch_id)
);

alter table public.business_settings
  add column if not exists room_capacity integer not null default 3
  check (room_capacity > 0);

create table if not exists public.staff_services (
  staff_id uuid not null references public.staff(id) on delete cascade,
  service_id uuid not null references public.services(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (staff_id, service_id)
);

create index if not exists staff_services_service_idx
  on public.staff_services (service_id);

create table if not exists public.staff_working_hours (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  is_working boolean not null default true,
  starts_at time,
  ends_at time,
  break_starts_at time,
  break_ends_at time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (staff_id, weekday),
  constraint staff_working_hours_required_hours check (
    is_working = false or (starts_at is not null and ends_at is not null)
  ),
  constraint staff_working_hours_start_end check (
    starts_at is null or ends_at is null or starts_at < ends_at
  ),
  constraint staff_working_hours_break_pair check (
    (break_starts_at is null and break_ends_at is null)
    or (break_starts_at is not null and break_ends_at is not null)
  ),
  constraint staff_working_hours_break_inside check (
    break_starts_at is null
    or (
      is_working = true
      and starts_at is not null
      and ends_at is not null
      and starts_at < break_starts_at
      and break_starts_at < break_ends_at
      and break_ends_at < ends_at
    )
  )
);

create index if not exists staff_working_hours_staff_weekday_idx
  on public.staff_working_hours (staff_id, weekday);

drop trigger if exists on_staff_working_hours_updated on public.staff_working_hours;
create trigger on_staff_working_hours_updated
before update on public.staff_working_hours
for each row execute function public.handle_updated_at();

create table if not exists public.staff_time_off (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  type text not null default 'blocked'
    check (type in ('vacation','sick','personal','training','blocked','other')),
  created_at timestamptz not null default now(),
  constraint staff_time_off_start_end check (starts_at < ends_at)
);

create index if not exists staff_time_off_staff_range_idx
  on public.staff_time_off (staff_id, starts_at, ends_at);

create or replace function public._staff_availability_parse_time(
  p_value text,
  p_fallback time
)
returns time
language plpgsql
immutable
as $$
declare
  v text := trim(coalesce(p_value, ''));
begin
  if v ~ '^\d{1,2}$' then
    return make_time(least(v::int, 23), 0, 0);
  end if;
  if v ~ '^\d{1,2}:\d{2}(:\d{2})?$' then
    return v::time;
  end if;
  return p_fallback;
end;
$$;

grant select, insert, update, delete on public.staff_working_hours to authenticated;
grant select, insert, update, delete on public.staff_time_off to authenticated;

alter table public.staff_working_hours enable row level security;
alter table public.staff_time_off enable row level security;

drop policy if exists staff_working_hours_select_authenticated on public.staff_working_hours;
create policy staff_working_hours_select_authenticated
on public.staff_working_hours for select to authenticated using (true);

drop policy if exists staff_working_hours_manage_staff on public.staff_working_hours;
create policy staff_working_hours_manage_staff
on public.staff_working_hours for all to authenticated
using (public.current_user_role() in ('admin','reception','receptionist'))
with check (public.current_user_role() in ('admin','reception','receptionist'));

drop policy if exists staff_time_off_select_authenticated on public.staff_time_off;
create policy staff_time_off_select_authenticated
on public.staff_time_off for select to authenticated using (true);

drop policy if exists staff_time_off_manage_staff on public.staff_time_off;
create policy staff_time_off_manage_staff
on public.staff_time_off for all to authenticated
using (public.current_user_role() in ('admin','reception','receptionist'))
with check (public.current_user_role() in ('admin','reception','receptionist'));

insert into public.staff_working_hours
  (staff_id, weekday, is_working, starts_at, ends_at)
select
  s.id,
  d.weekday,
  case
    when s.work_days is null or array_length(s.work_days, 1) is null then d.weekday between 1 and 6
    else exists (
      select 1
      from unnest(s.work_days) as wd(day_name)
      where lower(trim(wd.day_name)) in (
        case d.weekday
          when 0 then 'domingo'
          when 1 then 'lunes'
          when 2 then 'martes'
          when 3 then 'miercoles'
          when 4 then 'jueves'
          when 5 then 'viernes'
          when 6 then 'sabado'
        end,
        case d.weekday
          when 0 then 'sunday'
          when 1 then 'monday'
          when 2 then 'tuesday'
          when 3 then 'wednesday'
          when 4 then 'thursday'
          when 5 then 'friday'
          when 6 then 'saturday'
        end
      )
    )
  end,
  case when d.weekday = 0 then null else public._staff_availability_parse_time(s.work_start_time, time '10:00') end,
  case when d.weekday = 0 then null else public._staff_availability_parse_time(s.work_end_time, time '19:00') end
from public.staff s
cross join (values (0),(1),(2),(3),(4),(5),(6)) as d(weekday)
where s.role = 'therapist'
  and not exists (
    select 1 from public.staff_working_hours wh where wh.staff_id = s.id
  );

create or replace function public.check_staff_availability(
  p_staff_id uuid,
  p_service_id uuid,
  p_starts_at timestamptz,
  p_duration_minutes int,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111',
  p_exclude_booking_id uuid default null,
  p_include_suggestions boolean default true
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_local timestamp := p_starts_at at time zone 'America/Tijuana';
  v_date date := v_local::date;
  v_time time := v_local::time;
  v_weekday int := extract(dow from v_local)::int;
  v_duration int;
  v_end_at timestamptz;
  v_start_min int;
  v_end_min int;
  v_staff record;
  v_business record;
  v_closed record;
  v_work record;
  v_conflict uuid;
  v_room_capacity int := 3;
  v_room_count int := 0;
  v_suggested_slots jsonb := '[]'::jsonb;
begin
  v_duration := coalesce(nullif(p_duration_minutes, 0), 60);
  v_end_at := p_starts_at + make_interval(mins => v_duration);
  v_start_min := extract(hour from v_time)::int * 60 + extract(minute from v_time)::int;
  v_end_min := v_start_min + v_duration;
  if p_include_suggestions then
    v_suggested_slots := public._first_free_staff_slots_for_day(
      v_date, p_service_id, v_duration, p_branch_id, p_staff_id, 3
    );
  end if;

  select id, full_name, active, role into v_staff
  from public.staff
  where id = p_staff_id
  limit 1;

  if not found or coalesce(v_staff.active, false) = false or v_staff.role <> 'therapist' then
    return jsonb_build_object('available', false, 'reason', 'staff_not_active', 'details', 'El terapeuta no existe o no esta activo.', 'suggested_slots', v_suggested_slots);
  end if;

  select opens_at, closes_at, is_closed into v_business
  from public.business_hours
  where branch_id = p_branch_id and weekday = v_weekday
  limit 1;

  select * into v_closed
  from public.business_closed_days
  where branch_id = p_branch_id and date = v_date
  limit 1;

  if found and v_closed.custom_opens_at is null then
    return jsonb_build_object('available', false, 'reason', 'business_closed', 'details', coalesce(v_closed.reason, 'Negocio cerrado.'), 'suggested_slots', v_suggested_slots);
  elsif found then
    v_business.opens_at := v_closed.custom_opens_at;
    v_business.closes_at := v_closed.custom_closes_at;
    v_business.is_closed := false;
  end if;

  if v_business.opens_at is null or v_business.closes_at is null or coalesce(v_business.is_closed, true) then
    return jsonb_build_object('available', false, 'reason', 'business_closed', 'details', 'El negocio esta cerrado ese dia.', 'suggested_slots', v_suggested_slots);
  end if;

  if v_time < v_business.opens_at or (v_time + make_interval(mins => v_duration))::time > v_business.closes_at or v_end_min > 1440 then
    return jsonb_build_object('available', false, 'reason', 'outside_business_hours', 'details', 'El horario queda fuera del horario del negocio.', 'opens_at', v_business.opens_at::text, 'closes_at', v_business.closes_at::text, 'suggested_slots', v_suggested_slots);
  end if;

  select * into v_work
  from public.staff_working_hours
  where staff_id = p_staff_id and weekday = v_weekday
  limit 1;

  if not found then
    return jsonb_build_object('available', false, 'reason', 'staff_not_working_day', 'details', 'No hay horario semanal configurado para este terapeuta.', 'suggested_slots', v_suggested_slots);
  end if;

  if not coalesce(v_work.is_working, false) then
    return jsonb_build_object('available', false, 'reason', 'staff_not_working_day', 'details', 'El terapeuta no trabaja ese dia.', 'suggested_slots', v_suggested_slots);
  end if;

  if v_time < v_work.starts_at or (v_time + make_interval(mins => v_duration))::time > v_work.ends_at or v_end_min > 1440 then
    return jsonb_build_object('available', false, 'reason', 'outside_staff_hours', 'details', 'El horario queda fuera de la jornada del terapeuta.', 'starts_at', v_work.starts_at::text, 'ends_at', v_work.ends_at::text, 'suggested_slots', v_suggested_slots);
  end if;

  if v_work.break_starts_at is not null
     and v_time < v_work.break_ends_at
     and (v_time + make_interval(mins => v_duration))::time > v_work.break_starts_at then
    return jsonb_build_object('available', false, 'reason', 'staff_break', 'details', 'El horario empalma con comida o receso.', 'break_starts_at', v_work.break_starts_at::text, 'break_ends_at', v_work.break_ends_at::text, 'suggested_slots', v_suggested_slots);
  end if;

  select id into v_conflict
  from public.staff_time_off
  where staff_id = p_staff_id
    and starts_at < v_end_at
    and ends_at > p_starts_at
  limit 1;

  if v_conflict is not null then
    return jsonb_build_object('available', false, 'reason', 'staff_time_off', 'details', 'El terapeuta tiene una excepcion o ausencia.', 'staff_time_off_id', v_conflict, 'suggested_slots', v_suggested_slots);
  end if;

  select id into v_conflict
  from public.schedule_blocks sb
  where coalesce(sb.branch_id, p_branch_id) = p_branch_id
    and (sb.staff_id is null or sb.staff_id = p_staff_id)
    and sb.block_date = v_date
    and sb.start_minute < v_end_min
    and sb.end_minute > v_start_min
  limit 1;

  if v_conflict is not null then
    return jsonb_build_object('available', false, 'reason', 'schedule_block', 'details', 'El horario esta bloqueado en agenda.', 'schedule_block_id', v_conflict, 'suggested_slots', v_suggested_slots);
  end if;

  select id into v_conflict
  from public.bookings b
  where b.therapist_id = p_staff_id
    and b.booking_date = v_date
    and (p_exclude_booking_id is null or b.id <> p_exclude_booking_id)
    and b.status in ('pending','pending_reception','scheduled','confirmed','rescheduled','checked_in','in_progress','awaiting_payment','pending_payment','payment_received')
    and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int) < v_end_min
    and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int + coalesce(b.duration_min, 60)) > v_start_min
  limit 1;

  if v_conflict is not null then
    return jsonb_build_object('available', false, 'reason', 'existing_booking', 'details', 'Ya existe una cita para este terapeuta en ese horario.', 'conflicting_booking_id', v_conflict, 'suggested_slots', v_suggested_slots);
  end if;

  select coalesce(room_capacity, 3) into v_room_capacity
  from public.business_settings
  where branch_id = p_branch_id
  limit 1;

  select count(*) into v_room_count
  from public.bookings b
  where coalesce(b.sucursal_id, p_branch_id) = p_branch_id
    and b.booking_date = v_date
    and (p_exclude_booking_id is null or b.id <> p_exclude_booking_id)
    and b.status in ('pending','pending_reception','scheduled','confirmed','rescheduled','checked_in','in_progress','awaiting_payment','pending_payment','payment_received')
    and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int) < v_end_min
    and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int + coalesce(b.duration_min, 60)) > v_start_min;

  if v_room_count >= v_room_capacity then
    return jsonb_build_object('available', false, 'reason', 'room_capacity_full', 'details', 'No hay cuartos disponibles para ese horario.', 'room_capacity', v_room_capacity, 'overlapping_bookings', v_room_count, 'suggested_slots', v_suggested_slots);
  end if;

  return jsonb_build_object('available', true, 'reason', 'ok', 'details', 'Disponible.', 'staff_id', p_staff_id, 'service_duration_min', v_duration, 'suggested_slots', '[]'::jsonb);
end;
$$;

create or replace function public._first_free_staff_slots_for_day(
  p_date date,
  p_service_id uuid,
  p_duration_min int,
  p_branch_id uuid,
  p_staff_id uuid default null,
  p_max int default 3
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_out jsonb := '[]'::jsonb;
  v_count int := 0;
  v_staff record;
  v_work record;
  v_slot_min int;
  v_end_min int;
  v_result jsonb;
  v_start_at timestamptz;
begin
  if p_max <= 0 then return '[]'::jsonb; end if;

  for v_staff in
    select s.id, s.full_name
    from public.staff s
    where s.role = 'therapist'
      and coalesce(s.active, true) = true
      and (p_staff_id is null or s.id = p_staff_id)
      and (
        not exists (select 1 from public.staff_services ss where ss.staff_id = s.id)
        or exists (select 1 from public.staff_services ss where ss.staff_id = s.id and ss.service_id = p_service_id)
      )
    order by s.full_name
  loop
    select * into v_work
    from public.staff_working_hours
    where staff_id = v_staff.id and weekday = extract(dow from p_date)::int
    limit 1;

    if found and coalesce(v_work.is_working, false) then
      v_slot_min := extract(hour from v_work.starts_at)::int * 60 + extract(minute from v_work.starts_at)::int;
      while v_slot_min + p_duration_min <= (extract(hour from v_work.ends_at)::int * 60 + extract(minute from v_work.ends_at)::int)
        and v_count < p_max loop
        v_end_min := v_slot_min + p_duration_min;
        v_start_at := (p_date::text || ' ' || lpad((v_slot_min / 60)::text, 2, '0') || ':' || lpad((v_slot_min % 60)::text, 2, '0') || ':00 America/Tijuana')::timestamptz;
        v_result := public.check_staff_availability(v_staff.id, p_service_id, v_start_at, p_duration_min, p_branch_id, null, false);
        if (v_result->>'available')::boolean then
          v_out := v_out || jsonb_build_array(jsonb_build_object(
            'date', p_date::text,
            'time', lpad((v_slot_min / 60)::text, 2, '0') || ':' || lpad((v_slot_min % 60)::text, 2, '0'),
            'duration_min', p_duration_min,
            'staff_id', v_staff.id,
            'staff_name', v_staff.full_name
          ));
          v_count := v_count + 1;
        end if;
        v_slot_min := v_slot_min + 30;
      end loop;
    end if;
    if v_count >= p_max then exit; end if;
  end loop;

  return v_out;
end;
$$;

drop function if exists public.check_availability_for_booking_from_ai(uuid,date,time,int,uuid);

create or replace function public.check_availability_for_booking_from_ai(
  p_service_id uuid,
  p_requested_date date,
  p_requested_time time,
  p_duration_min int default null,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111',
  p_staff_id uuid default null
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_service record;
  v_dur int;
  v_start_at timestamptz;
  v_staff record;
  v_result jsonb;
  v_suggestions jsonb := '[]'::jsonb;
  v_day_offset int;
begin
  select id, name, duration_min into v_service
  from public.services
  where id = p_service_id and coalesce(is_active, true) = true
  limit 1;

  if not found then
    return jsonb_build_object('available', false, 'reason', 'service_not_found', 'suggested_slots', '[]'::jsonb);
  end if;

  v_dur := coalesce(nullif(p_duration_min, 0), v_service.duration_min, 60);
  v_start_at := (p_requested_date::text || ' ' || p_requested_time::text || ' America/Tijuana')::timestamptz;

  if p_staff_id is not null then
    return public.check_staff_availability(p_staff_id, p_service_id, v_start_at, v_dur, p_branch_id);
  end if;

  for v_staff in
    select s.id, s.full_name
    from public.staff s
    where s.role = 'therapist'
      and coalesce(s.active, true) = true
      and (
        not exists (select 1 from public.staff_services ss where ss.staff_id = s.id)
        or exists (select 1 from public.staff_services ss where ss.staff_id = s.id and ss.service_id = p_service_id)
      )
    order by s.full_name
  loop
    v_result := public.check_staff_availability(v_staff.id, p_service_id, v_start_at, v_dur, p_branch_id);
    if (v_result->>'available')::boolean then
      return v_result || jsonb_build_object('selected_staff_id', v_staff.id, 'selected_staff_name', v_staff.full_name);
    end if;
  end loop;

  for v_day_offset in 0..7 loop
    v_suggestions := v_suggestions || public._first_free_staff_slots_for_day(
      (p_requested_date + (v_day_offset || ' day')::interval)::date,
      p_service_id,
      v_dur,
      p_branch_id,
      null,
      3 - jsonb_array_length(v_suggestions)
    );
    exit when jsonb_array_length(v_suggestions) >= 3;
  end loop;

  return jsonb_build_object(
    'available', false,
    'reason', 'no_staff_available',
    'details', 'No hay terapeuta disponible para ese servicio y horario.',
    'service_duration_min', v_dur,
    'suggested_slots', v_suggestions
  );
end;
$$;

grant execute on function public.check_staff_availability(uuid,uuid,timestamptz,int,uuid,uuid,boolean) to authenticated, service_role;
grant execute on function public.check_availability_for_booking_from_ai(uuid,date,time,int,uuid,uuid) to service_role;
grant execute on function public._first_free_staff_slots_for_day(date,uuid,int,uuid,uuid,int) to authenticated, service_role;

create or replace function public.create_pending_booking_from_ai(
  p_phone text,
  p_client_name text,
  p_service_id uuid,
  p_booking_date date,
  p_booking_time time,
  p_duration_min int,
  p_notes text,
  p_ai_conversation_id uuid,
  p_ai_confidence_score numeric default null,
  p_therapist_id uuid default null
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
  if v_normalized_phone = '' then
    return jsonb_build_object('ok', false, 'error', 'phone_required');
  end if;
  if p_service_id is null or p_booking_date is null or p_booking_time is null then
    return jsonb_build_object('ok', false, 'error', 'missing_service_or_datetime');
  end if;

  select id into v_client_id
  from public.clients
  where right(regexp_replace(phone,'\D','','g'),10) = right(v_normalized_phone,10)
  order by created_at asc
  limit 1;

  if v_client_id is null then
    insert into public.clients(full_name, phone)
    values (coalesce(nullif(trim(p_client_name),''),'Cliente WhatsApp'), v_normalized_phone)
    returning id into v_client_id;
  end if;

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

  insert into public.bookings (
    client_record_id,
    therapist_id,
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
    p_therapist_id,
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
    'client_id', v_client_id,
    'therapist_id', p_therapist_id
  );
end;
$$;

revoke all on function public.create_pending_booking_from_ai(text,text,uuid,date,time,int,text,uuid,numeric,uuid) from public;
grant execute on function public.create_pending_booking_from_ai(text,text,uuid,date,time,int,text,uuid,numeric,uuid) to service_role;
