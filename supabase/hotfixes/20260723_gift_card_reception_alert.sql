-- SAHARA CLUB SPA - PRODUCTIVE HOTFIX
-- Gift Card paid purchase -> Reception alert.
--
-- Scope:
-- - Does not touch supabase_migrations.
-- - Does not call external services.
-- - Does not use Stripe identifiers, signed URLs, gift card codes, or secrets.
-- - Creates one reception_alerts row per paid Gift Card.
--
-- Remote contract evidence:
-- - orders.status is set to 'paid' and paid_at before fulfillOrder inserts gift_cards.
-- - gift_cards has order_id/order_item_id FKs and order_item_id is unique.
-- - reception_alerts has no metadata/source_id/gift_card_id column, so the
--   idempotency key is the internal Gift Card UUID embedded in the operational
--   message and protected by a partial unique expression index.

begin;

-- Required compatibility change: production currently rejects unknown event_type
-- values. This adds only the new hotfix event and preserves existing values.
alter table public.reception_alerts
  drop constraint if exists reception_alerts_event_type_check;

alter table public.reception_alerts
  add constraint reception_alerts_event_type_check
  check (
    event_type = any (
      array[
        'booking_pending_reception'::text,
        'booking_cancelled'::text,
        'reschedule_requested'::text,
        'deposit_paid'::text,
        'requires_reception'::text,
        'gift_card_purchased'::text
      ]
    )
  );

create unique index if not exists idx_reception_alerts_gift_card_purchased_once
  on public.reception_alerts (
    (
      substring(
        message from 'Gift Card ID: ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
      )
    )
  )
  where event_type = 'gift_card_purchased';

create or replace function public.notify_reception_on_gift_card_created()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
  v_digits text;
  v_masked_phone text;
  v_message text;
begin
  if new.order_id is null then
    return new;
  end if;

  select *
    into v_order
    from public.orders
   where id = new.order_id;

  if not found then
    return new;
  end if;

  -- The alert is for a paid purchase only. Manual/unpaid gift cards do not fire it.
  if coalesce(v_order.status, '') not in ('paid', 'completed')
     and v_order.paid_at is null then
    return new;
  end if;

  if new.order_item_id is not null then
    select product_type, product_name, metadata
      into v_item
      from public.order_items
     where id = new.order_item_id;

    if found
       and lower(coalesce(v_item.product_type::text, '')) not in ('gift_card', 'giftcard') then
      return new;
    end if;
  end if;

  v_digits := regexp_replace(coalesce(v_order.customer_phone, ''), '\D', '', 'g');
  if length(v_digits) >= 4 then
    v_masked_phone := repeat('*', greatest(length(v_digits) - 4, 0)) || right(v_digits, 4);
  else
    v_masked_phone := nullif(v_digits, '');
  end if;

  v_message := concat_ws(
    E'\n',
    'Gift card pagada.',
    'Gift Card ID: ' || new.id::text,
    'Comprador: ' || nullif(coalesce(new.sender_name, v_order.customer_name, ''), ''),
    'Telefono comprador: ' || v_masked_phone,
    'Destinatario: ' || nullif(coalesce(new.recipient_name, ''), ''),
    'Servicio: ' || nullif(coalesce(new.service_name, ''), ''),
    'Importe: ' || coalesce(to_char(new.initial_balance, 'FM999999990.00'), '0.00') || ' ' || coalesce(new.currency, 'MXN'),
    'Vigencia: ' ||
      coalesce(to_char(new.valid_from at time zone 'America/Tijuana', 'YYYY-MM-DD'), 'sin inicio') ||
      ' a ' ||
      coalesce(to_char(new.expires_at at time zone 'America/Tijuana', 'YYYY-MM-DD'), 'sin vencimiento'),
    'Compra: ' || coalesce(to_char(new.created_at at time zone 'America/Tijuana', 'YYYY-MM-DD HH24:MI'), 'sin fecha') || ' America/Tijuana',
    'Estado inicial: ' || coalesce(new.status, 'active')
  );

  begin
    insert into public.reception_alerts (
      event_type,
      client_record_id,
      client_name,
      client_phone,
      service_name,
      channel,
      message,
      amount_mxn,
      status,
      created_at
    )
    select
      'gift_card_purchased',
      new.client_id,
      coalesce(nullif(new.sender_name, ''), nullif(v_order.customer_name, ''), 'Comprador Gift Card'),
      v_masked_phone,
      nullif(new.service_name, ''),
      'system',
      v_message,
      new.initial_balance,
      'unseen',
      now()
    where not exists (
      select 1
        from public.reception_alerts ra
       where ra.event_type = 'gift_card_purchased'
         and substring(
               ra.message from 'Gift Card ID: ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
             ) = new.id::text
    );
  exception
    when unique_violation then
      -- Idempotency guard for concurrent/replayed fulfillment.
      null;
  end;

  return new;
end;
$$;

revoke all on function public.notify_reception_on_gift_card_created() from public;
revoke all on function public.notify_reception_on_gift_card_created() from anon;
revoke all on function public.notify_reception_on_gift_card_created() from authenticated;

comment on function public.notify_reception_on_gift_card_created()
  is 'Hotfix 20260723: create one non-sensitive reception alert when a paid Gift Card is created.';

drop trigger if exists trg_gift_card_reception_alert on public.gift_cards;

create trigger trg_gift_card_reception_alert
after insert on public.gift_cards
for each row
execute function public.notify_reception_on_gift_card_created();

comment on trigger trg_gift_card_reception_alert on public.gift_cards
  is 'Hotfix 20260723: AFTER INSERT paid Gift Card -> reception_alerts gift_card_purchased.';

commit;
