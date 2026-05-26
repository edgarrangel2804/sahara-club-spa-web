-- Sahara Club Spa - Chequeo de disponibilidad antes de crear pending_reception
-- ----------------------------------------------------------------------------
-- RPC check_availability_for_booking_from_ai usado por la tool del router.
-- Devuelve si el horario solicitado está libre + slots sugeridos si no.
--
-- Considera:
--   - business_hours (weekday + opens/closes)
--   - business_closed_days (override)
--   - schedule_blocks (block_date + start_minute/end_minute)
--   - bookings (status no-cancelled, overlap por duration_min)
--   - duration del servicio
-- NO valida terapeuta individual aún (recepción asigna).

create or replace function public.check_availability_for_booking_from_ai(
  p_service_id uuid,
  p_requested_date date,
  p_requested_time time,
  p_duration_min int default null,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111'
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_service record;
  v_weekday int;
  v_opens time;
  v_closes time;
  v_is_closed boolean := false;
  v_closed_override record;
  v_dur int;
  v_start_min int;
  v_end_min int;
  v_conflict_id uuid;
  v_block_id uuid;
  v_suggestions jsonb := '[]'::jsonb;
  v_slot_time time;
  v_step int := 30;       -- pasos de 30 min para buscar slots
  v_check_min int;
  v_check_end_min int;
  v_overlap_count int;
  v_block_overlap int;
  v_slot_count int := 0;
  v_max_suggestions int := 3;
  v_search_date date;
  v_max_days_ahead int := 7;
  v_day_offset int;
begin
  -- 1) Servicio + duración
  select id, name, duration_min into v_service
  from public.services where id = p_service_id and is_active = true;
  if not found then
    return jsonb_build_object('available', false, 'reason', 'service_not_found');
  end if;
  v_dur := coalesce(p_duration_min, v_service.duration_min, 60);

  v_start_min := extract(hour from p_requested_time)::int * 60
               + extract(minute from p_requested_time)::int;
  v_end_min := v_start_min + v_dur;

  -- 2) ¿El día está cerrado?
  v_weekday := extract(dow from p_requested_date)::int; -- 0=domingo
  select opens_at, closes_at, is_closed
  into v_opens, v_closes, v_is_closed
  from public.business_hours
  where weekday = v_weekday
  limit 1;

  select * into v_closed_override
  from public.business_closed_days
  where date = p_requested_date and branch_id = p_branch_id
  limit 1;

  if found then
    if v_closed_override.custom_opens_at is not null and v_closed_override.custom_closes_at is not null then
      v_opens := v_closed_override.custom_opens_at;
      v_closes := v_closed_override.custom_closes_at;
      v_is_closed := false;
    else
      v_is_closed := true;
    end if;
  end if;

  if v_is_closed or v_opens is null or v_closes is null then
    -- buscar próximos slots en los siguientes días
    for v_day_offset in 1..v_max_days_ahead loop
      v_search_date := p_requested_date + (v_day_offset || ' day')::interval;
      v_suggestions := v_suggestions || public._first_free_slots_for_day(
        v_search_date::date, p_service_id, v_dur, p_branch_id, 3 - v_slot_count
      );
      v_slot_count := jsonb_array_length(v_suggestions);
      if v_slot_count >= v_max_suggestions then exit; end if;
    end loop;

    return jsonb_build_object(
      'available', false,
      'reason', 'closed_day',
      'business_open', false,
      'service_duration_min', v_dur,
      'suggested_slots', v_suggestions
    );
  end if;

  -- 3) ¿Dentro de horario de negocio?
  if p_requested_time < v_opens or (v_start_min + v_dur)::int > (
    extract(hour from v_closes)::int * 60 + extract(minute from v_closes)::int
  ) then
    v_suggestions := public._first_free_slots_for_day(
      p_requested_date, p_service_id, v_dur, p_branch_id, 3
    );
    return jsonb_build_object(
      'available', false,
      'reason', 'outside_business_hours',
      'business_open', false,
      'opens_at', v_opens::text,
      'closes_at', v_closes::text,
      'service_duration_min', v_dur,
      'suggested_slots', v_suggestions
    );
  end if;

  -- 4) ¿Bloqueado por schedule_blocks?
  select sb.id into v_block_id
  from public.schedule_blocks sb
  where sb.branch_id = p_branch_id
    and sb.block_date = p_requested_date
    and sb.start_minute < v_end_min
    and sb.end_minute   > v_start_min
  limit 1;

  if v_block_id is not null then
    v_suggestions := public._first_free_slots_for_day(
      p_requested_date, p_service_id, v_dur, p_branch_id, 3
    );
    return jsonb_build_object(
      'available', false,
      'reason', 'blocked_by_schedule',
      'business_open', true,
      'blocked_by_schedule', true,
      'service_duration_min', v_dur,
      'suggested_slots', v_suggestions
    );
  end if;

  -- 5) ¿Hay booking que se empalme?
  select b.id into v_conflict_id
  from public.bookings b
  where b.booking_date = p_requested_date
    and b.status in ('pending','pending_reception','scheduled','confirmed','rescheduled','checked_in','in_progress','awaiting_payment')
    and (
      -- overlap: existing_start < requested_end AND existing_end > requested_start
      (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int) < v_end_min
      and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int + coalesce(b.duration_min, 60)) > v_start_min
    )
  order by b.booking_time
  limit 1;

  if v_conflict_id is not null then
    v_suggestions := public._first_free_slots_for_day(
      p_requested_date, p_service_id, v_dur, p_branch_id, 3
    );
    return jsonb_build_object(
      'available', false,
      'reason', 'conflicting_booking',
      'business_open', true,
      'conflicting_booking_id', v_conflict_id,
      'service_duration_min', v_dur,
      'suggested_slots', v_suggestions
    );
  end if;

  -- ¡Libre!
  return jsonb_build_object(
    'available', true,
    'reason', 'ok',
    'business_open', true,
    'service_duration_min', v_dur
  );
end;
$$;


-- Helper: devuelve hasta N slots libres de 30 min en un día, ordenados por hora.
create or replace function public._first_free_slots_for_day(
  p_date date,
  p_service_id uuid,
  p_duration_min int,
  p_branch_id uuid,
  p_max int default 3
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_weekday int;
  v_opens time;
  v_closes time;
  v_is_closed boolean := false;
  v_closed_override record;
  v_open_min int;
  v_close_min int;
  v_slot_min int;
  v_end_min int;
  v_count int := 0;
  v_out jsonb := '[]'::jsonb;
  v_conflict int;
  v_block int;
begin
  if p_max <= 0 then return '[]'::jsonb; end if;

  v_weekday := extract(dow from p_date)::int;
  select opens_at, closes_at, is_closed
  into v_opens, v_closes, v_is_closed
  from public.business_hours
  where weekday = v_weekday
  limit 1;

  select * into v_closed_override
  from public.business_closed_days
  where date = p_date and branch_id = p_branch_id
  limit 1;
  if found then
    if v_closed_override.custom_opens_at is not null then
      v_opens := v_closed_override.custom_opens_at;
      v_closes := v_closed_override.custom_closes_at;
      v_is_closed := false;
    else
      v_is_closed := true;
    end if;
  end if;

  if v_is_closed or v_opens is null or v_closes is null then
    return '[]'::jsonb;
  end if;

  v_open_min := extract(hour from v_opens)::int * 60 + extract(minute from v_opens)::int;
  v_close_min := extract(hour from v_closes)::int * 60 + extract(minute from v_closes)::int;

  v_slot_min := v_open_min;
  while v_slot_min + p_duration_min <= v_close_min and v_count < p_max loop
    v_end_min := v_slot_min + p_duration_min;

    select count(*) into v_conflict
    from public.bookings b
    where b.booking_date = p_date
      and b.status in ('pending','pending_reception','scheduled','confirmed','rescheduled','checked_in','in_progress','awaiting_payment')
      and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int) < v_end_min
      and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int + coalesce(b.duration_min, 60)) > v_slot_min;

    select count(*) into v_block
    from public.schedule_blocks sb
    where sb.branch_id = p_branch_id
      and sb.block_date = p_date
      and sb.start_minute < v_end_min
      and sb.end_minute   > v_slot_min;

    if v_conflict = 0 and v_block = 0 then
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'date', p_date::text,
        'time', lpad((v_slot_min / 60)::text, 2, '0') || ':' || lpad((v_slot_min % 60)::text, 2, '0'),
        'duration_min', p_duration_min
      ));
      v_count := v_count + 1;
    end if;

    v_slot_min := v_slot_min + 30;
  end loop;

  return v_out;
end;
$$;

revoke all on function public.check_availability_for_booking_from_ai(uuid,date,time,int,uuid) from public;
grant execute on function public.check_availability_for_booking_from_ai(uuid,date,time,int,uuid) to service_role;
revoke all on function public._first_free_slots_for_day(date,uuid,int,uuid,int) from public;
grant execute on function public._first_free_slots_for_day(date,uuid,int,uuid,int) to service_role;

-- Smoke
select public.check_availability_for_booking_from_ai(
  '5a3512a2-0f43-4fcf-9546-aa026f3b49c4',
  current_date + 2, '15:00:00', 60
);
