-- Sahara Club Spa - estado del dia por terapeuta para el agente IA WhatsApp.
-- Devuelve, para una fecha dada, el estado actual de cada terapeuta activo:
--   working / off / time_off / lunch / busy / available
-- Usado por la tool get_staff_day_status del whatsapp-ai-router para
-- responder preguntas tipo "quien atiende hoy", "Victoria trabaja hoy?",
-- "Anita esta en comida?" sin tener que sondear slots.

create or replace function public.get_staff_day_status(
  p_date date default (now() at time zone 'America/Tijuana')::date,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111'
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_now timestamptz := now();
  v_local_now timestamp := v_now at time zone 'America/Tijuana';
  v_today date := (v_now at time zone 'America/Tijuana')::date;
  v_now_min int := extract(hour from v_local_now)::int * 60 + extract(minute from v_local_now)::int;
  v_weekday int := extract(dow from p_date)::int;
  v_is_today boolean := p_date = v_today;
  v_out jsonb := '[]'::jsonb;
  v_row record;
begin
  for v_row in
    select
      s.id,
      s.full_name,
      s.role,
      wh.is_working,
      wh.starts_at,
      wh.ends_at,
      wh.break_starts_at,
      wh.break_ends_at,
      (
        select to_jsonb(t)
        from public.staff_time_off t
        where t.staff_id = s.id
          and t.starts_at < (p_date + interval '1 day')
          and t.ends_at   > p_date
        order by t.starts_at
        limit 1
      ) as time_off,
      (
        select b.booking_time
        from public.bookings b
        where b.therapist_id = s.id
          and b.booking_date = p_date
          and b.status in ('confirmed','checked_in','in_progress','rescheduled')
          and v_is_today
          and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int) <= v_now_min
          and (extract(hour from b.booking_time)::int * 60 + extract(minute from b.booking_time)::int + coalesce(b.duration_min, 60)) > v_now_min
        order by b.booking_time
        limit 1
      ) as current_booking_time,
      (
        select count(*)::int
        from public.bookings b
        where b.therapist_id = s.id
          and b.booking_date = p_date
          and b.status not in ('cancelled','no_show')
      ) as bookings_count
    from public.staff s
    left join public.staff_working_hours wh
      on wh.staff_id = s.id and wh.weekday = v_weekday
    where coalesce(s.active, false) = true
      and s.role = 'therapist'
    order by s.full_name
  loop
    declare
      v_status text;
      v_reason text;
    begin
      if v_row.time_off is not null then
        v_status := 'time_off';
        v_reason := coalesce(v_row.time_off->>'reason', 'Ausencia / permiso');
      elsif v_row.is_working is null or coalesce(v_row.is_working, false) = false then
        v_status := 'off';
        v_reason := 'Dia de descanso';
      elsif v_is_today
        and v_row.break_starts_at is not null
        and v_now_min >= extract(hour from v_row.break_starts_at)::int * 60 + extract(minute from v_row.break_starts_at)::int
        and v_now_min <  extract(hour from v_row.break_ends_at)::int   * 60 + extract(minute from v_row.break_ends_at)::int
      then
        v_status := 'lunch';
        v_reason := 'En comida / descanso';
      elsif v_is_today and v_row.current_booking_time is not null then
        v_status := 'busy';
        v_reason := 'Atendiendo una cita ahora';
      elsif v_is_today
        and v_row.starts_at is not null
        and v_now_min >= extract(hour from v_row.starts_at)::int * 60 + extract(minute from v_row.starts_at)::int
        and v_now_min <  extract(hour from v_row.ends_at)::int   * 60 + extract(minute from v_row.ends_at)::int
      then
        v_status := 'available';
        v_reason := 'Disponible ahora';
      else
        v_status := 'working';
        v_reason := 'Trabaja ese dia';
      end if;

      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'staff_id', v_row.id,
        'name', v_row.full_name,
        'role', v_row.role,
        'status', v_status,
        'reason', v_reason,
        'works_today', coalesce(v_row.is_working, false),
        'start_time', v_row.starts_at::text,
        'end_time', v_row.ends_at::text,
        'lunch_start', v_row.break_starts_at::text,
        'lunch_end', v_row.break_ends_at::text,
        'bookings_count', v_row.bookings_count
      ));
    end;
  end loop;

  return jsonb_build_object(
    'date', p_date::text,
    'is_today', v_is_today,
    'branch_id', p_branch_id,
    'staff', v_out
  );
end;
$$;

revoke all on function public.get_staff_day_status(date, uuid) from public;
grant execute on function public.get_staff_day_status(date, uuid) to authenticated, service_role;

-- Smoke
select public.get_staff_day_status();
