-- Sahara Club Spa - F2b: Paquetes como excepción al anticipo de $200
-- ----------------------------------------------------------------------------
-- 100% aditivo. Extiende el mismo mecanismo que ya exime el anticipo por
-- gift card / membresía, ahora también para paquetes activos con sesiones.
-- Decisiones (Edgar):
--   - Se exime el anticipo mientras el paquete tenga sesiones pendientes,
--     aunque el cliente aún deba abonos (pagos independientes de sesiones).
--   - Al CONFIRMAR la cita cubierta por paquete se consume 1 sesión (auto),
--     con ajuste manual disponible en recepción (F2c).

-- 1) Columnas nuevas en bookings (idempotentes)
alter table public.bookings
  add column if not exists client_package_id uuid
    references public.client_packages(id) on delete set null,
  add column if not exists client_package_session_id uuid
    references public.client_package_sessions(id) on delete set null;

-- Permitir waiver_reason='package'
alter table public.bookings drop constraint if exists bookings_waiver_reason_check;
alter table public.bookings add constraint bookings_waiver_reason_check
  check (waiver_reason is null
         or waiver_reason in ('gift_card','membership','package','admin_override'));

-- 2) check_booking_payment_requirement: agrega paquetes a la regla del waiver
create or replace function public.check_booking_payment_requirement(
  p_phone text,
  p_service_id uuid default null,
  p_requested_date date default null,
  p_requested_time time default null,
  p_customer_name text default null
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_normalized_phone text := regexp_replace(coalesce(p_phone,''),'\D','','g');
  v_client_id uuid;
  v_gc record;
  v_cm record;
  v_pkg record;
  v_plan_name text;
  v_deposit_required_cents int := 20000;
  v_amount numeric;
begin
  -- Permite override del anticipo via ai_settings.appointment_deposit_amount
  select (coalesce(appointment_deposit_amount, 200) * 100)::int
    into v_amount
  from public.ai_settings where id = 1;
  if v_amount is not null then v_deposit_required_cents := v_amount; end if;

  if v_normalized_phone = '' then
    return jsonb_build_object(
      'requires_deposit', true,
      'reason', 'deposit_required',
      'message', 'Sin teléfono no podemos validar beneficios.'
    );
  end if;

  -- 1) cliente por phone (últimos 10)
  select id into v_client_id
  from public.clients
  where right(regexp_replace(phone,'\D','','g'),10) = right(v_normalized_phone,10)
  order by created_at asc
  limit 1;

  if v_client_id is null then
    return jsonb_build_object(
      'requires_deposit', true,
      'reason', 'deposit_required',
      'message', 'Cliente nuevo; requiere anticipo.'
    );
  end if;

  -- 2) PAQUETE activo con sesión pendiente del MISMO servicio solicitado.
  --    Tiene prioridad: el paquete se compró para esos servicios.
  if p_service_id is not null then
    select cps.id as session_id, cps.client_package_id
    into v_pkg
    from public.client_package_sessions cps
    join public.client_packages cp on cp.id = cps.client_package_id
    where cps.client_id = v_client_id
      and cps.status = 'pendiente'
      and cps.service_id = p_service_id
      and cp.status = 'activo'
      and (cp.expires_at is null or cp.expires_at > now())
    order by cp.purchased_at asc
    limit 1;
    if found then
      return jsonb_build_object(
        'requires_deposit', false,
        'reason', 'package',
        'gift_card_id', null,
        'membership_id', null,
        'client_package_id', v_pkg.client_package_id,
        'client_package_session_id', v_pkg.session_id,
        'deposit_required_cents', v_deposit_required_cents,
        'message', 'Anticipo cubierto por paquete activo (servicio incluido).'
      );
    end if;
  end if;

  -- 3) gift card activa con saldo SUFICIENTE para cubrir el anticipo
  select gc.id, gc.current_balance, gc.expires_at
  into v_gc
  from public.gift_cards gc
  where gc.client_id = v_client_id
    and gc.status = 'active'
    and (coalesce(gc.current_balance, 0) * 100)::int >= v_deposit_required_cents
    and (gc.expires_at is null or gc.expires_at > now())
  order by gc.expires_at nulls last, gc.created_at desc
  limit 1;

  if found then
    return jsonb_build_object(
      'requires_deposit', false,
      'reason', 'gift_card',
      'gift_card_id', v_gc.id,
      'membership_id', null,
      'deposit_required_cents', v_deposit_required_cents,
      'message', 'Anticipo cubierto por gift card activa.'
    );
  end if;

  -- 4) membresía activa con sesiones disponibles
  select cm.id, cm.plan_id, cm.sessions_total, cm.sessions_used,
         (coalesce(cm.sessions_total,0) - coalesce(cm.sessions_used,0)) as remaining
  into v_cm
  from public.client_memberships cm
  where cm.client_id = v_client_id
    and cm.status = 'active'
    and (cm.start_date is null or cm.start_date <= current_date)
    and (cm.end_date is null or cm.end_date >= current_date)
    and (coalesce(cm.sessions_total,0) - coalesce(cm.sessions_used,0)) > 0
  order by cm.end_date desc nulls last, cm.created_at desc
  limit 1;

  if found then
    select name into v_plan_name from public.membership_plans where id = v_cm.plan_id;
    return jsonb_build_object(
      'requires_deposit', false,
      'reason', 'membership',
      'gift_card_id', null,
      'membership_id', v_cm.id,
      'membership_plan', v_plan_name,
      'sessions_remaining', v_cm.remaining,
      'deposit_required_cents', v_deposit_required_cents,
      'message', 'Anticipo cubierto por membresía activa.'
    );
  end if;

  -- 5) PAQUETE activo con CUALQUIER sesión pendiente (fallback, sin match de servicio)
  select cps.id as session_id, cps.client_package_id
  into v_pkg
  from public.client_package_sessions cps
  join public.client_packages cp on cp.id = cps.client_package_id
  where cps.client_id = v_client_id
    and cps.status = 'pendiente'
    and cp.status = 'activo'
    and (cp.expires_at is null or cp.expires_at > now())
  order by cp.purchased_at asc
  limit 1;
  if found then
    return jsonb_build_object(
      'requires_deposit', false,
      'reason', 'package',
      'gift_card_id', null,
      'membership_id', null,
      'client_package_id', v_pkg.client_package_id,
      'client_package_session_id', v_pkg.session_id,
      'deposit_required_cents', v_deposit_required_cents,
      'message', 'Anticipo cubierto por paquete activo.'
    );
  end if;

  -- 6) sin beneficio aplicable
  return jsonb_build_object(
    'requires_deposit', true,
    'reason', 'deposit_required',
    'gift_card_id', null,
    'membership_id', null,
    'deposit_required_cents', v_deposit_required_cents,
    'message', 'Requiere anticipo de $200 MXN.'
  );
end;
$$;

grant execute on function public.check_booking_payment_requirement(text, uuid, date, time, text)
  to authenticated, anon, service_role;

-- 3) get_customer_benefits_summary: refleja el paquete en el panel del cliente
create or replace function public.get_customer_benefits_summary(p_client_id uuid)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_now timestamptz := now();
  v_gc record;
  v_cm record;
  v_sessions_used int := 0;
  v_sessions_remaining int := 0;
  v_customer_type text := 'regular';
  v_has_gc boolean := false;
  v_gc_balance numeric := 0;
  v_gc_expires timestamptz;
  v_has_membership boolean := false;
  v_plan_name text;
  v_membership_start date;
  v_membership_end date;
  v_has_package boolean := false;
  v_pkg_sessions int := 0;
  v_requires_deposit boolean := true;
  v_waiver_reason text;
begin
  if p_client_id is null then
    return jsonb_build_object('ok', false, 'error', 'client_id required');
  end if;

  -- Gift card
  select gc.id, gc.current_balance, gc.expires_at, gc.status, gc.code
  into v_gc
  from public.gift_cards gc
  where gc.client_id = p_client_id
    and gc.status = 'active'
    and coalesce(gc.current_balance, 0) > 0
    and (gc.expires_at is null or gc.expires_at > v_now)
  order by gc.expires_at nulls last, gc.created_at desc
  limit 1;

  if found then
    v_has_gc := true;
    v_gc_balance := coalesce(v_gc.current_balance, 0);
    v_gc_expires := v_gc.expires_at;
  end if;

  -- Membresía activa
  select cm.id, cm.plan_id, cm.status, cm.start_date, cm.end_date,
         cm.sessions_used, cm.sessions_total
  into v_cm
  from public.client_memberships cm
  where cm.client_id = p_client_id
    and cm.status = 'active'
    and (cm.start_date is null or cm.start_date <= current_date)
    and (cm.end_date is null or cm.end_date >= current_date)
  order by cm.end_date desc nulls last, cm.created_at desc
  limit 1;

  if found then
    v_has_membership := true;
    v_membership_start := v_cm.start_date;
    v_membership_end := v_cm.end_date;
    v_sessions_used := coalesce(v_cm.sessions_used, 0);
    v_sessions_remaining := greatest(coalesce(v_cm.sessions_total, 0) - v_sessions_used, 0);
    select name into v_plan_name from public.membership_plans where id = v_cm.plan_id;
  end if;

  -- Paquete activo con sesiones pendientes
  select count(*)
  into v_pkg_sessions
  from public.client_package_sessions cps
  join public.client_packages cp on cp.id = cps.client_package_id
  where cps.client_id = p_client_id
    and cps.status = 'pendiente'
    and cp.status = 'activo'
    and (cp.expires_at is null or cp.expires_at > v_now);
  v_has_package := v_pkg_sessions > 0;

  -- Tipo del cliente (prioridad: membresía > gift card > paquete > regular)
  if v_has_membership then v_customer_type := 'membership';
  elsif v_has_gc then v_customer_type := 'gift_card';
  elsif v_has_package then v_customer_type := 'package';
  else v_customer_type := 'regular';
  end if;

  -- Regla de anticipo (waiver): membresía > gift card > paquete
  if v_has_membership and v_sessions_remaining > 0 then
    v_requires_deposit := false;
    v_waiver_reason := 'active_membership_with_sessions';
  elsif v_has_gc and v_gc_balance > 0 then
    v_requires_deposit := false;
    v_waiver_reason := 'active_gift_card_with_balance';
  elsif v_has_package then
    v_requires_deposit := false;
    v_waiver_reason := 'active_package_with_sessions';
  else
    v_requires_deposit := true;
    v_waiver_reason := null;
  end if;

  return jsonb_build_object(
    'ok', true,
    'client_id', p_client_id,
    'customer_type', v_customer_type,
    'has_active_gift_card', v_has_gc,
    'gift_card_balance', v_gc_balance,
    'gift_card_expires_at', v_gc_expires,
    'has_active_membership', v_has_membership,
    'membership_plan', v_plan_name,
    'membership_start_date', v_membership_start,
    'membership_end_date', v_membership_end,
    'sessions_used', v_sessions_used,
    'sessions_remaining', v_sessions_remaining,
    'has_active_package', v_has_package,
    'package_sessions_remaining', v_pkg_sessions,
    'requires_deposit', v_requires_deposit,
    'waiver_reason', v_waiver_reason
  );
end;
$$;

grant execute on function public.get_customer_benefits_summary(uuid)
  to authenticated, service_role;

-- 4) Trigger: consume gift card / membresía / paquete al confirmar el booking
create or replace function public.apply_waiver_on_booking_confirm()
returns trigger
language plpgsql
security definer
as $$
declare
  v_amount numeric;
  v_gc record;
  v_session_id uuid;
  v_remaining int;
begin
  if new.status = 'confirmed'
     and (old.status is null or old.status <> 'confirmed')
     and new.payment_requirement = 'waived' then

    if new.waiver_reason = 'gift_card' and new.gift_card_id is not null then
      v_amount := coalesce(new.deposit_required_cents, 20000)::numeric / 100.0;
      select id, current_balance into v_gc
      from public.gift_cards
      where id = new.gift_card_id and status = 'active'
      for update;

      if found and coalesce(v_gc.current_balance, 0) >= v_amount then
        update public.gift_cards
          set current_balance = current_balance - v_amount,
              status = case when current_balance - v_amount <= 0 then 'redeemed' else 'active' end
          where id = new.gift_card_id;

        insert into public.gift_card_transactions(
          gift_card_id, client_id, booking_id, type, amount,
          balance_before, balance_after, notes
        ) values (
          new.gift_card_id, new.client_record_id, new.id, 'redeem', v_amount,
          v_gc.current_balance, v_gc.current_balance - v_amount,
          'Anticipo de cita cubierto por gift card'
        );
      end if;
    end if;

    if new.waiver_reason = 'membership' and new.membership_id is not null then
      update public.client_memberships
        set sessions_used = coalesce(sessions_used, 0) + 1
        where id = new.membership_id;

      insert into public.membership_usage(
        client_membership_id, client_id, booking_id, service_id, notes
      ) values (
        new.membership_id, new.client_record_id, new.id, new.service_id,
        'Sesión consumida al confirmar cita'
      );
    end if;

    -- PAQUETE: consume una sesión pendiente del paquete
    if new.waiver_reason = 'package' and new.client_package_id is not null then
      -- elige la sesión indicada (si sigue pendiente); si no, una pendiente
      -- del mismo servicio; si no, cualquier pendiente del paquete.
      select id into v_session_id
      from public.client_package_sessions
      where id = new.client_package_session_id
        and client_package_id = new.client_package_id
        and status = 'pendiente'
      for update
      limit 1;

      if v_session_id is null then
        select id into v_session_id
        from public.client_package_sessions
        where client_package_id = new.client_package_id
          and status = 'pendiente'
          and (new.service_id is null or service_id = new.service_id)
        order by created_at asc
        for update
        limit 1;
      end if;

      if v_session_id is null then
        select id into v_session_id
        from public.client_package_sessions
        where client_package_id = new.client_package_id
          and status = 'pendiente'
        order by created_at asc
        for update
        limit 1;
      end if;

      if v_session_id is not null then
        update public.client_package_sessions
          set status = 'usada', used_at = now(), appointment_id = new.id
          where id = v_session_id;

        -- si ya no quedan sesiones pendientes, marca el paquete como completado
        select count(*) into v_remaining
        from public.client_package_sessions
        where client_package_id = new.client_package_id
          and status = 'pendiente';

        if v_remaining = 0 then
          update public.client_packages
            set status = 'completado'
            where id = new.client_package_id and status = 'activo';
        end if;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_apply_waiver_on_booking_confirm on public.bookings;
create trigger trg_apply_waiver_on_booking_confirm
  after update of status on public.bookings
  for each row
  execute function public.apply_waiver_on_booking_confirm();
