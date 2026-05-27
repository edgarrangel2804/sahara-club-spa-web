-- Sahara Club Spa - Excepción al anticipo de $200 por gift card / membresía
-- ----------------------------------------------------------------------------
-- Conecta el módulo de Beneficios del cliente con el flujo de booking IA.
-- Si el cliente tiene gift card con saldo o membresía con sesiones disponibles,
-- la IA NO genera el link de Stripe y el booking nace como pending_reception.
-- Al confirmar recepción, se descuenta el saldo o se consume una sesión.

-- 1. Columnas nuevas en bookings (todas idempotentes)
alter table public.bookings
  add column if not exists payment_requirement text not null default 'deposit_required',
  add column if not exists waiver_reason text,
  add column if not exists gift_card_id uuid references public.gift_cards(id) on delete set null,
  add column if not exists membership_id uuid references public.client_memberships(id) on delete set null,
  add column if not exists deposit_required_cents int default 20000,
  add column if not exists deposit_paid_cents int default 0;

alter table public.bookings
  drop constraint if exists bookings_payment_requirement_check;
alter table public.bookings
  add constraint bookings_payment_requirement_check
  check (payment_requirement in ('deposit_required','waived','paid'));

alter table public.bookings
  drop constraint if exists bookings_waiver_reason_check;
alter table public.bookings
  add constraint bookings_waiver_reason_check
  check (waiver_reason is null or waiver_reason in ('gift_card','membership','admin_override'));

create index if not exists idx_bookings_payment_requirement
  on public.bookings(payment_requirement)
  where payment_requirement in ('waived','deposit_required');

-- 2. RPC check_booking_payment_requirement (callable desde Edge Function)
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

  -- 2) gift card activa con saldo SUFICIENTE para cubrir el anticipo
  --    (regla actual: la GC cubre al menos el anticipo de $200; el cobro real
  --    del servicio queda para recepción).
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

  -- 3) membresía activa con sesiones disponibles
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

  -- 4) sin beneficio aplicable
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

-- 3. Trigger: al confirmar un booking con payment_requirement='waived',
--    consume gift card / membresía automáticamente.
create or replace function public.apply_waiver_on_booking_confirm()
returns trigger
language plpgsql
security definer
as $$
declare
  v_amount numeric;
  v_gc record;
begin
  -- Solo dispara cuando pasa A 'confirmed' y aplica un waiver real
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
  end if;

  return new;
end;
$$;

drop trigger if exists trg_apply_waiver_on_booking_confirm on public.bookings;
create trigger trg_apply_waiver_on_booking_confirm
  after update of status on public.bookings
  for each row
  execute function public.apply_waiver_on_booking_confirm();

-- 4. Verificación
select column_name from information_schema.columns
where table_schema='public' and table_name='bookings'
  and column_name in ('payment_requirement','waiver_reason','gift_card_id',
                      'membership_id','deposit_required_cents','deposit_paid_cents')
order by column_name;
