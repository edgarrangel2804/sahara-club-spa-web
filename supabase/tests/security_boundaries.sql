\set ON_ERROR_STOP on

begin;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from information_schema.role_table_grants
  where table_schema = 'public'
    and grantee = 'anon'
    and table_name in (
      'orders',
      'order_items',
      'payments',
      'gift_cards',
      'gift_card_transactions',
      'gift_card_deliveries',
      'reception_alerts',
      'whatsapp_logs',
      'ai_settings',
      'business_whatsapp_settings'
    );
  if v_count <> 0 then
    raise exception 'expected zero anon private grants, got %', v_count;
  end if;

  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and policyname in (
      'anon_select_own_orders',
      'anon_select_own_order_items',
      'auth_all_orders',
      'auth_all_order_items',
      'auth_all_payments',
      'auth_all_gift_cards',
      'payments access'
    );
  if v_count <> 0 then
    raise exception 'risky baseline policies still exist: %', v_count;
  end if;

  select count(*) into v_count
  from storage.buckets
  where id in ('gift-card-assets', 'receipts')
    and public = false
    and allowed_mime_types = array['application/pdf'];
  if v_count <> 2 then
    raise exception 'expected private pdf buckets for gift cards and receipts, got %', v_count;
  end if;

  begin
    set local role anon;
    perform count(*) from public.orders;
    raise exception 'anon unexpectedly selected public.orders';
  exception
    when insufficient_privilege then
      reset role;
  end;
end $$;

rollback;
