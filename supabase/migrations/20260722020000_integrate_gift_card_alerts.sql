-- Manual integration of Gift Card reception alerts and admin WhatsApp delivery.
-- Additive, idempotent, and local-first. Does not create a second admin ledger.

alter table public.gift_card_deliveries
  drop constraint if exists gift_card_deliveries_type_check;

alter table public.gift_card_deliveries
  add constraint gift_card_deliveries_type_check
  check (delivery_type = any (array[
    'recipient_whatsapp',
    'buyer_whatsapp_copy',
    'download',
    'reception_resend',
    'admin_whatsapp_purchase_alert'
  ]::text[]));

alter table public.reception_alerts
  drop constraint if exists reception_alerts_purchase_channel_check;

alter table public.reception_alerts
  add constraint reception_alerts_purchase_channel_check
  check (
    purchase_channel is null
    or purchase_channel = any (array[
      'web',
      'whatsapp',
      'reception',
      'manual',
      'admin',
      'unknown'
    ]::text[])
  );

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.reception_alerts'::regclass
      and conname = 'reception_alerts_payment_id_fkey'
  ) then
    alter table public.reception_alerts
      add constraint reception_alerts_payment_id_fkey
      foreign key (payment_id) references public.payments(id) on delete set null;
  end if;
end $$;

create index if not exists idx_reception_alerts_order_item
  on public.reception_alerts (order_item_id)
  where order_item_id is not null;

create unique index if not exists idx_reception_alerts_gift_card_purchase
  on public.reception_alerts (gift_card_id)
  where event_type = 'gift_card_purchased';

create or replace function public.log_gift_card_purchase_alert(
  p_order_id uuid,
  p_order_item_id uuid,
  p_gift_card_id uuid,
  p_client_name text,
  p_client_phone text,
  p_service_name text,
  p_channel text,
  p_message text,
  p_amount_mxn numeric,
  p_buyer_name text,
  p_buyer_email text,
  p_buyer_phone text,
  p_product_name text,
  p_face_value numeric,
  p_amount_paid numeric,
  p_currency text,
  p_purchase_channel text,
  p_occurred_at timestamptz,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alert_id uuid;
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_operational_metadata jsonb;
begin
  if p_gift_card_id is null then
    raise exception 'gift_card_id_required';
  end if;

  v_operational_metadata := jsonb_strip_nulls(jsonb_build_object(
    'delivery_status', v_metadata ->> 'delivery_status',
    'digital_asset_status', v_metadata ->> 'digital_asset_status',
    'delivered_at', v_metadata ->> 'delivered_at',
    'buyer_copy_delivery_status', v_metadata ->> 'buyer_copy_delivery_status',
    'admin_notification_status', v_metadata ->> 'admin_notification_status',
    'last_status_refresh_at', now()
  ));

  insert into public.reception_alerts (
    event_type,
    booking_id,
    client_record_id,
    client_name,
    client_phone,
    service_name,
    channel,
    message,
    amount_mxn,
    status,
    order_id,
    order_item_id,
    gift_card_id,
    buyer_name,
    buyer_email,
    buyer_phone,
    product_name,
    face_value,
    amount_paid,
    currency,
    purchase_channel,
    occurred_at,
    metadata
  )
  values (
    'gift_card_purchased',
    null,
    null,
    nullif(trim(coalesce(p_client_name, '')), ''),
    nullif(trim(coalesce(p_client_phone, '')), ''),
    nullif(trim(coalesce(p_service_name, '')), ''),
    coalesce(nullif(trim(p_channel), ''), 'unknown'),
    nullif(trim(coalesce(p_message, '')), ''),
    p_amount_mxn,
    'unseen',
    p_order_id,
    p_order_item_id,
    p_gift_card_id,
    nullif(trim(coalesce(p_buyer_name, '')), ''),
    nullif(trim(coalesce(p_buyer_email, '')), ''),
    nullif(trim(coalesce(p_buyer_phone, '')), ''),
    nullif(trim(coalesce(p_product_name, '')), ''),
    p_face_value,
    p_amount_paid,
    coalesce(nullif(trim(p_currency), ''), 'MXN'),
    coalesce(nullif(trim(p_purchase_channel), ''), 'unknown'),
    coalesce(p_occurred_at, now()),
    v_metadata
  )
  on conflict (gift_card_id) where event_type = 'gift_card_purchased'
  do update set
    metadata = coalesce(public.reception_alerts.metadata, '{}'::jsonb)
      || v_operational_metadata
  returning id into v_alert_id;

  return v_alert_id;
end;
$$;

revoke all on function public.log_gift_card_purchase_alert(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  numeric,
  text,
  text,
  text,
  text,
  numeric,
  numeric,
  text,
  text,
  timestamptz,
  jsonb
) from public;

revoke execute on function public.log_gift_card_purchase_alert(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  numeric,
  text,
  text,
  text,
  text,
  numeric,
  numeric,
  text,
  text,
  timestamptz,
  jsonb
) from anon, authenticated;

grant execute on function public.log_gift_card_purchase_alert(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  numeric,
  text,
  text,
  text,
  text,
  numeric,
  numeric,
  text,
  text,
  timestamptz,
  jsonb
) to service_role;
