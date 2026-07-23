-- Sahara Club Spa - harden role helpers and SECURITY DEFINER functions.

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (
      select p.role::text
      from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.active, p.is_active, true)
      limit 1
    ),
    (
      select s.role
      from public.staff s
      where s.auth_user_id = auth.uid()
        and coalesce(s.active, true)
      limit 1
    )
  )
$$;

create or replace function public.get_user_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.current_user_role()
$$;

create or replace function public.has_any_role(p_allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_user_role() = any (p_allowed_roles), false)
$$;

revoke all on function public.current_user_role() from public, anon;
revoke all on function public.get_user_role() from public, anon;
revoke all on function public.has_any_role(text[]) from public, anon;
grant execute on function public.current_user_role() to authenticated, service_role;
grant execute on function public.get_user_role() to authenticated, service_role;
grant execute on function public.has_any_role(text[]) to authenticated, service_role;

alter function public.handle_updated_at() set search_path = public, pg_temp;
alter function public.touch_updated_at() set search_path = public, pg_temp;
alter function public.sync_whatsapp_environment_flags() set search_path = public, pg_temp;
revoke all on function public.handle_updated_at() from public, anon, authenticated;
revoke all on function public.touch_updated_at() from public, anon, authenticated;
revoke all on function public.sync_whatsapp_environment_flags() from public, anon, authenticated;
grant execute on function public.handle_updated_at() to service_role;
grant execute on function public.touch_updated_at() to service_role;
grant execute on function public.sync_whatsapp_environment_flags() to service_role;

revoke all on function public.log_reception_alert(text, uuid, text, text, text, text, numeric)
  from public, anon, authenticated;
alter function public.log_reception_alert(text, uuid, text, text, text, text, numeric)
  set search_path = public, pg_temp;
grant execute on function public.log_reception_alert(text, uuid, text, text, text, text, numeric)
  to service_role;

revoke all on function public.notify_reception_on_booking_change()
  from public, anon, authenticated;
revoke all on function public.notify_reception_on_new_booking()
  from public, anon, authenticated;
grant execute on function public.notify_reception_on_booking_change() to service_role;
grant execute on function public.notify_reception_on_new_booking() to service_role;

alter function public.claim_gift_card_delivery(uuid, text, text)
  set search_path = public, pg_temp;
alter function public.complete_gift_card_delivery(uuid, text, text, jsonb)
  set search_path = public, pg_temp;
revoke all on function public.claim_gift_card_delivery(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.complete_gift_card_delivery(uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.claim_gift_card_delivery(uuid, text, text)
  to service_role;
grant execute on function public.complete_gift_card_delivery(uuid, text, text, jsonb)
  to service_role;

create or replace function public.redeem_service_gift_card(
  p_client_id uuid,
  p_service_id uuid,
  p_booking_id uuid default null,
  p_amount numeric default 0,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_gc public.gift_cards%rowtype;
  v_today date := timezone('America/Tijuana', now())::date;
  v_amount numeric := greatest(coalesce(p_amount, 0), 0);
  v_after numeric;
begin
  if not public.has_any_role(array[
    'admin',
    'super_admin',
    'owner',
    'manager',
    'reception',
    'receptionist',
    'staff',
    'sales'
  ]::text[]) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;

  if p_client_id is null then
    return jsonb_build_object('ok', false, 'error', 'client_id_required');
  end if;

  if p_booking_id is not null and not exists (
    select 1
    from public.bookings b
    where b.id = p_booking_id
      and b.client_record_id = p_client_id
      and (p_service_id is null or b.service_id = p_service_id)
  ) then
    return jsonb_build_object('ok', false, 'error', 'booking_client_mismatch');
  end if;

  select * into v_gc
  from public.gift_cards
  where client_id = p_client_id
    and (p_service_id is null or service_id is null or service_id = p_service_id)
    and coalesce(current_balance, 0) > 0
  order by expires_on nulls last, created_at desc
  limit 1
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'gift_card_not_found');
  end if;

  if v_gc.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'gift_card_not_active');
  end if;
  if v_gc.valid_from is not null and v_today < v_gc.valid_from then
    return jsonb_build_object('ok', false, 'error', 'gift_card_not_yet_valid');
  end if;
  if v_gc.expires_on is not null and v_today > v_gc.expires_on then
    return jsonb_build_object('ok', false, 'error', 'gift_card_expired');
  end if;
  if v_amount > 0 and coalesce(v_gc.current_balance, 0) < v_amount then
    return jsonb_build_object('ok', false, 'error', 'gift_card_insufficient_balance');
  end if;
  if p_booking_id is not null and exists (
    select 1
    from public.gift_card_transactions
    where gift_card_id = v_gc.id
      and booking_id = p_booking_id
      and type = 'redeem'
  ) then
    return jsonb_build_object('ok', false, 'error', 'gift_card_already_redeemed_for_booking');
  end if;

  v_after := coalesce(v_gc.current_balance, 0) - v_amount;
  update public.gift_cards
  set current_balance = v_after,
      status = case when v_after <= 0 then 'redeemed' else 'active' end,
      updated_at = now()
  where id = v_gc.id;

  insert into public.gift_card_transactions (
    gift_card_id,
    client_id,
    booking_id,
    branch_id,
    type,
    amount,
    balance_before,
    balance_after,
    result,
    notes,
    created_by
  ) values (
    v_gc.id,
    p_client_id,
    p_booking_id,
    p_branch_id,
    'redeem',
    v_amount,
    coalesce(v_gc.current_balance, 0),
    v_after,
    'ok',
    'Gift card redeemed by authorized backend RPC',
    auth.uid()
  );

  return jsonb_build_object(
    'ok', true,
    'gift_card_id', v_gc.id,
    'balance_before', coalesce(v_gc.current_balance, 0),
    'balance_after', v_after,
    'status', case when v_after <= 0 then 'redeemed' else 'active' end
  );
end;
$$;

revoke all on function public.redeem_service_gift_card(uuid, uuid, uuid, numeric, uuid)
  from public, anon;
grant execute on function public.redeem_service_gift_card(uuid, uuid, uuid, numeric, uuid)
  to authenticated, service_role;

