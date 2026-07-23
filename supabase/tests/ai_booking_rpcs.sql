\set ON_ERROR_STOP on

begin;

do $$
declare
  v_branch uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  v_service uuid := '00000000-0000-4000-8000-000000000101'::uuid;
  v_staff_a uuid := '00000000-0000-4000-8000-000000000201'::uuid;
  v_staff_b uuid := '00000000-0000-4000-8000-000000000202'::uuid;
  v_client uuid := '00000000-0000-4000-8000-000000000301'::uuid;
  v_plan uuid := '00000000-0000-4000-8000-000000000401'::uuid;
  v_booking uuid;
  v_booking_distinct uuid;
  v_date date := (current_date + interval '7 days')::date;
  v_result jsonb;
  v_second jsonb;
  v_assertions integer := 0;
begin
  delete from public.bookings
  where ai_idempotency_key like 'sql-test:%'
     or client_record_id = v_client
     or id in (
       '00000000-0000-4000-8000-000000000501'::uuid,
       '00000000-0000-4000-8000-000000000502'::uuid
     );
  delete from public.gift_cards where code in ('SQL-TEST-AI-RPC-GC');
  delete from public.client_memberships where client_id = v_client;
  delete from public.membership_plans where id = v_plan;
  delete from public.staff_working_hours where staff_id in (v_staff_a, v_staff_b);
  delete from public.staff_services where staff_id in (v_staff_a, v_staff_b);
  delete from public.schedule_blocks where staff_id in (v_staff_a, v_staff_b) or title like 'SQL test%';
  delete from public.staff where id in (v_staff_a, v_staff_b);
  delete from public.clients where id = v_client;
  delete from public.services where id = v_service;

  insert into public.sucursales (id, nombre)
  values (v_branch, 'Sahara Club Spa')
  on conflict (id) do nothing;

  insert into public.services (
    id,
    name,
    category,
    duration_min,
    duration,
    price,
    is_active,
    active
  ) values (
    v_service,
    'SQL Test Massage',
    'test',
    60,
    60,
    1200,
    true,
    true
  );

  insert into public.staff (id, full_name, role, active, active_for_ai)
  values
    (v_staff_a, 'SQL Test Therapist A', 'therapist', true, true),
    (v_staff_b, 'SQL Test Therapist B', 'therapist', true, true);

  insert into public.staff_services (staff_id, service_id)
  values (v_staff_a, v_service), (v_staff_b, v_service);

  insert into public.staff_working_hours (staff_id, weekday, is_working, starts_at, ends_at)
  select staff_id, d.weekday, true, time '09:00', time '18:00'
  from (values (v_staff_a), (v_staff_b)) as s(staff_id)
  cross join (values (0),(1),(2),(3),(4),(5),(6)) as d(weekday);

  insert into public.business_hours (branch_id, weekday, opens_at, closes_at, is_closed)
  select v_branch, d.weekday, time '09:00', time '18:00', false
  from (values (0),(1),(2),(3),(4),(5),(6)) as d(weekday)
  on conflict (branch_id, weekday) do update
    set opens_at = excluded.opens_at,
        closes_at = excluded.closes_at,
        is_closed = excluded.is_closed;

  insert into public.business_settings (branch_id, room_capacity)
  values (v_branch, 2)
  on conflict (branch_id) do update set room_capacity = excluded.room_capacity;

  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    v_date,
    time '10:00',
    60,
    v_branch,
    null
  );
  if v_result->>'available' <> 'true' or v_result->>'selected_staff_id' is null then
    raise exception 'expected available slot with selected staff, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  update public.services set is_active = false, active = false where id = v_service;
  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    v_date,
    time '10:00',
    60,
    v_branch,
    null
  );
  if v_result->>'available' <> 'false' or v_result->>'reason' <> 'service_not_found' then
    raise exception 'expected inactive service rejection, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;
  update public.services set is_active = true, active = true where id = v_service;

  insert into public.clients (id, full_name, phone)
  values (v_client, 'SQL Test Client', '6460000000');

  insert into public.bookings (
    id,
    client_record_id,
    therapist_id,
    service_id,
    booking_date,
    booking_time,
    duration_min,
    status,
    sucursal_id,
    ai_idempotency_key
  ) values (
    '00000000-0000-4000-8000-000000000501'::uuid,
    v_client,
    v_staff_a,
    v_service,
    v_date,
    time '10:00',
    60,
    'pending_reception',
    v_branch,
    'sql-test:existing-staff-a'
  );

  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    v_date,
    time '10:00',
    60,
    v_branch,
    v_staff_a
  );
  if v_result->>'available' <> 'false' or v_result->>'reason' <> 'existing_booking' then
    raise exception 'expected staff conflict, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    v_date,
    time '11:00',
    60,
    v_branch,
    v_staff_a
  );
  if v_result->>'available' <> 'true' then
    raise exception 'expected consecutive [start,end) slot available, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  insert into public.bookings (
    id,
    client_record_id,
    therapist_id,
    service_id,
    booking_date,
    booking_time,
    duration_min,
    status,
    sucursal_id,
    ai_idempotency_key
  ) values (
    '00000000-0000-4000-8000-000000000502'::uuid,
    v_client,
    v_staff_b,
    v_service,
    v_date,
    time '14:00',
    60,
    'cancelled',
    v_branch,
    'sql-test:cancelled-staff-b'
  );

  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    v_date,
    time '14:00',
    60,
    v_branch,
    v_staff_b
  );
  if v_result->>'available' <> 'true' then
    raise exception 'expected cancelled booking not to block, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    v_date,
    time '10:00',
    60,
    v_branch,
    v_staff_b
  );
  if v_result->>'available' <> 'true' then
    raise exception 'expected second therapist available, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    date '2026-11-01',
    time '01:30',
    60,
    v_branch,
    v_staff_a
  );
  if v_result->>'available' <> 'false' or v_result->>'reason' <> 'outside_business_hours' then
    raise exception 'expected DST night outside business hours in America/Tijuana, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  insert into public.schedule_blocks (
    branch_id,
    staff_id,
    block_date,
    start_minute,
    end_minute,
    title
  ) values (
    v_branch,
    v_staff_b,
    v_date,
    600,
    660,
    'SQL test block'
  );

  v_result := public.check_availability_for_booking_from_ai(
    v_service,
    v_date,
    time '10:00',
    60,
    v_branch,
    null
  );
  if v_result->>'available' <> 'false' or v_result->>'reason' <> 'no_staff_available' then
    raise exception 'expected no staff available, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  delete from public.schedule_blocks where title = 'SQL test block';

  insert into public.ai_settings (id, appointment_deposit_amount, appointment_deposit_enabled)
  values (1, 150, true)
  on conflict (id) do update
    set appointment_deposit_amount = excluded.appointment_deposit_amount,
        appointment_deposit_enabled = excluded.appointment_deposit_enabled;

  v_result := public.check_booking_payment_requirement(
    '6469999999',
    v_service,
    v_date,
    time '10:00',
    'Cliente Nuevo'
  );
  if v_result->>'requires_deposit' <> 'true'
     or (v_result->>'deposit_required_cents')::int <> 15000
     or v_result->>'currency' <> 'MXN' then
    raise exception 'expected deposit for unknown client, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  insert into public.gift_cards (
    client_id,
    code,
    initial_balance,
    current_balance,
    status,
    valid_from,
    expires_on,
    service_id
  ) values (
    v_client,
    'SQL-TEST-AI-RPC-GC',
    150,
    150,
    'active',
    timezone('America/Tijuana', now())::date,
    timezone('America/Tijuana', now())::date + 30,
    v_service
  );

  v_result := public.check_booking_payment_requirement(
    '6460000000',
    v_service,
    v_date,
    time '10:00',
    'SQL Test Client'
  );
  if v_result->>'requires_deposit' <> 'false' or v_result->>'reason' <> 'gift_card' then
    raise exception 'expected gift card waiver, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  update public.gift_cards set status = 'redeemed' where code = 'SQL-TEST-AI-RPC-GC';
  v_result := public.check_booking_payment_requirement(
    '6460000000',
    v_service,
    v_date,
    time '10:00',
    'SQL Test Client'
  );
  if v_result->>'requires_deposit' <> 'true' or v_result->>'reason' <> 'deposit_required' then
    raise exception 'expected invalid gift card not to waive deposit, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  insert into public.membership_plans (id, name, price_monthly, sessions_per_month)
  values (v_plan, 'SQL Test Plan', 1500, 4);
  insert into public.client_memberships (client_id, plan_id, status, sessions_total, sessions_used)
  values (v_client, v_plan, 'active', 4, 1);

  v_result := public.check_booking_payment_requirement(
    '6460000000',
    v_service,
    v_date,
    time '10:00',
    'SQL Test Client'
  );
  if v_result->>'requires_deposit' <> 'false' or v_result->>'reason' <> 'membership' then
    raise exception 'expected membership waiver, got %', v_result;
  end if;
  v_assertions := v_assertions + 1;

  v_result := public.create_pending_booking_from_ai(
    p_phone => '6461234567',
    p_client_name => 'Maria Test Reserva',
    p_email => 'maria.test@example.com',
    p_service_id => v_service,
    p_booking_date => v_date,
    p_booking_time => time '12:00',
    p_duration_min => 30,
    p_notes => 'SQL test booking',
    p_ai_conversation_id => null,
    p_ai_confidence_score => 0.91,
    p_therapist_id => v_staff_a,
    p_request_id => 'sql-test:create-1',
    p_branch_id => v_branch
  );
  if v_result->>'ok' <> 'true'
     or v_result->>'created' <> 'true'
     or v_result->>'booking_id' is null
     or v_result->>'client_is_new' <> 'true' then
    raise exception 'expected booking creation, got %', v_result;
  end if;
  if v_result::text like '%maria.test@example.com%' or v_result::text like '%6461234567%' then
    raise exception 'booking creation response leaked PII: %', v_result;
  end if;
  v_assertions := v_assertions + 1;
  v_booking := (v_result->>'booking_id')::uuid;

  select to_jsonb(b.*) into v_second
  from public.bookings b
  where b.id = v_booking
    and b.status = 'pending_reception'
    and b.status <> 'confirmed'
    and b.payment_status is null
    and b.created_by_ai = true
    and b.ai_idempotency_key = 'sql-test:create-1'
    and b.therapist_id = v_staff_a;
  if v_second is null then
    raise exception 'created booking did not persist expected AI fields';
  end if;
  if (v_second->>'duration_min')::int <> 60 then
    raise exception 'expected server-side service duration 60, got %', v_second->>'duration_min';
  end if;
  v_assertions := v_assertions + 1;

  if not exists (
    select 1
    from public.clients
    where right(regexp_replace(phone, '\D', '', 'g'), 10) = '6461234567'
  ) then
    raise exception 'expected normalized phone stored for created booking client';
  end if;
  v_assertions := v_assertions + 1;

  v_second := public.create_pending_booking_from_ai(
    p_phone => '6461234567',
    p_client_name => 'Maria Test Reserva',
    p_email => 'maria.test@example.com',
    p_service_id => v_service,
    p_booking_date => v_date,
    p_booking_time => time '12:00',
    p_duration_min => 60,
    p_notes => 'SQL test booking retry',
    p_ai_conversation_id => null,
    p_ai_confidence_score => 0.91,
    p_therapist_id => v_staff_a,
    p_request_id => 'sql-test:create-1',
    p_branch_id => v_branch
  );
  if v_second->>'created' <> 'false'
     or v_second->>'duplicate_prevented' <> 'true'
     or (v_second->>'booking_id')::uuid <> v_booking then
    raise exception 'expected idempotent duplicate, got %', v_second;
  end if;
  v_assertions := v_assertions + 1;

  v_second := public.create_pending_booking_from_ai(
    p_phone => '6461234567',
    p_client_name => 'Maria Test Reserva',
    p_email => 'maria.test@example.com',
    p_service_id => v_service,
    p_booking_date => v_date,
    p_booking_time => time '13:00',
    p_duration_min => 30,
    p_notes => 'SQL test booking distinct request',
    p_ai_conversation_id => null,
    p_ai_confidence_score => 0.91,
    p_therapist_id => v_staff_a,
    p_request_id => 'sql-test:create-2',
    p_branch_id => v_branch
  );
  if v_second->>'created' <> 'true'
     or v_second->>'duplicate_prevented' <> 'false'
     or v_second->>'booking_id' is null then
    raise exception 'expected distinct request_id to create a separate slot, got %', v_second;
  end if;
  v_booking_distinct := (v_second->>'booking_id')::uuid;
  if v_booking_distinct = v_booking then
    raise exception 'distinct request_id reused original booking id';
  end if;
  v_assertions := v_assertions + 1;

  v_second := public.create_pending_booking_from_ai(
    p_phone => '6467654321',
    p_client_name => 'Laura Test Reserva',
    p_email => 'laura.test@example.com',
    p_service_id => v_service,
    p_booking_date => v_date,
    p_booking_time => time '12:00',
    p_duration_min => 60,
    p_notes => 'SQL test occupied slot',
    p_ai_conversation_id => null,
    p_ai_confidence_score => 0.91,
    p_therapist_id => v_staff_a,
    p_request_id => 'sql-test:create-occupied',
    p_branch_id => v_branch
  );
  if v_second->>'ok' <> 'false'
     or v_second->>'error' <> 'slot_not_available'
     or v_second->>'reason' <> 'existing_booking' then
    raise exception 'expected occupied staff rejection, got %', v_second;
  end if;
  v_assertions := v_assertions + 1;

  raise notice 'ai_booking_rpcs behavioral assertions: %', v_assertions;
end $$;

do $$
declare
  v_assertions integer := 0;
begin
  if has_function_privilege(
    'anon',
    'public.check_booking_payment_requirement(text, uuid, date, time, text)',
    'EXECUTE'
  ) then
    raise exception 'anon unexpectedly has EXECUTE on check_booking_payment_requirement';
  end if;
  v_assertions := v_assertions + 1;

  if has_function_privilege(
    'authenticated',
    'public.create_pending_booking_from_ai(text, text, uuid, date, time, integer, text, uuid, numeric, text, uuid, text, uuid)',
    'EXECUTE'
  ) then
    raise exception 'authenticated unexpectedly has EXECUTE on create_pending_booking_from_ai';
  end if;
  v_assertions := v_assertions + 1;

  if has_function_privilege(
    'anon',
    'public.check_availability_for_booking_from_ai(uuid, date, time, integer, uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception 'anon unexpectedly has EXECUTE on check_availability_for_booking_from_ai';
  end if;
  v_assertions := v_assertions + 1;

  if not has_function_privilege(
    'service_role',
    'public.check_availability_for_booking_from_ai(uuid, date, time, integer, uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception 'service_role missing EXECUTE on check_availability_for_booking_from_ai';
  end if;
  v_assertions := v_assertions + 1;

  if not has_function_privilege(
    'service_role',
    'public.create_pending_booking_from_ai(text, text, uuid, date, time, integer, text, uuid, numeric, text, uuid, text, uuid)',
    'EXECUTE'
  ) then
    raise exception 'service_role missing EXECUTE on create_pending_booking_from_ai';
  end if;
  v_assertions := v_assertions + 1;

  if not has_function_privilege(
    'service_role',
    'public.check_booking_payment_requirement(text, uuid, date, time, text)',
    'EXECUTE'
  ) then
    raise exception 'service_role missing EXECUTE on check_booking_payment_requirement';
  end if;
  v_assertions := v_assertions + 1;

  raise notice 'ai_booking_rpcs grant assertions: %', v_assertions;
end $$;

rollback;
