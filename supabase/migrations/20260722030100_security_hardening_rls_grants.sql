-- Sahara Club Spa - harden RLS policies and table grants.

alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.gift_cards enable row level security;
alter table public.gift_card_transactions enable row level security;
alter table public.gift_card_deliveries enable row level security;
alter table public.reception_alerts enable row level security;

drop policy if exists "anon_select_own_orders" on public.orders;
drop policy if exists "anon_select_own_order_items" on public.order_items;
drop policy if exists "auth_all_orders" on public.orders;
drop policy if exists "auth_all_order_items" on public.order_items;
drop policy if exists "auth_all_payments" on public.payments;
drop policy if exists "auth_all_gift_cards" on public.gift_cards;
drop policy if exists "payments access" on public.payments;
drop policy if exists gift_card_tx_staff_read on public.gift_card_transactions;

drop policy if exists commerce_orders_staff_all on public.orders;
create policy commerce_orders_staff_all
  on public.orders
  for all
  to authenticated
  using (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]))
  with check (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]));

drop policy if exists commerce_orders_select_owner_or_staff on public.orders;
create policy commerce_orders_select_owner_or_staff
  on public.orders
  for select
  to authenticated
  using (
    customer_id = auth.uid()
    or public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[])
  );

drop policy if exists commerce_order_items_staff_all on public.order_items;
create policy commerce_order_items_staff_all
  on public.order_items
  for all
  to authenticated
  using (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]))
  with check (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]));

drop policy if exists commerce_order_items_select_owner_or_staff on public.order_items;
create policy commerce_order_items_select_owner_or_staff
  on public.order_items
  for select
  to authenticated
  using (
    public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[])
    or exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and o.customer_id = auth.uid()
    )
  );

drop policy if exists commerce_payments_staff_all on public.payments;
create policy commerce_payments_staff_all
  on public.payments
  for all
  to authenticated
  using (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]))
  with check (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]));

drop policy if exists commerce_payments_select_owner_or_staff on public.payments;
create policy commerce_payments_select_owner_or_staff
  on public.payments
  for select
  to authenticated
  using (
    client_id = auth.uid()
    or public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[])
    or exists (
      select 1
      from public.orders o
      where o.id = payments.order_id
        and o.customer_id = auth.uid()
    )
    or exists (
      select 1
      from public.bookings b
      where b.id = payments.booking_id
        and (
          b.client_id = auth.uid()
          or exists (
            select 1
            from public.clients c
            where c.id = b.client_record_id
              and c.profile_id = auth.uid()
          )
        )
    )
  );

drop policy if exists commerce_gift_cards_staff_all on public.gift_cards;
create policy commerce_gift_cards_staff_all
  on public.gift_cards
  for all
  to authenticated
  using (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]))
  with check (public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[]));

drop policy if exists commerce_gift_cards_select_owner_or_staff on public.gift_cards;
create policy commerce_gift_cards_select_owner_or_staff
  on public.gift_cards
  for select
  to authenticated
  using (
    public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[])
    or exists (
      select 1
      from public.clients c
      where c.id = gift_cards.client_id
        and c.profile_id = auth.uid()
    )
    or exists (
      select 1
      from public.orders o
      where o.id = gift_cards.order_id
        and o.customer_id = auth.uid()
    )
  );

drop policy if exists gift_card_transactions_staff_or_owner_read on public.gift_card_transactions;
create policy gift_card_transactions_staff_or_owner_read
  on public.gift_card_transactions
  for select
  to authenticated
  using (
    public.has_any_role(array['admin','super_admin','reception','receptionist','sales']::text[])
    or exists (
      select 1
      from public.gift_cards gc
      join public.clients c on c.id = gc.client_id
      where gc.id = gift_card_transactions.gift_card_id
        and c.profile_id = auth.uid()
    )
  );

drop policy if exists gift_card_transactions_service_role_all on public.gift_card_transactions;
create policy gift_card_transactions_service_role_all
  on public.gift_card_transactions
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists gift_card_deliveries_service_role_all on public.gift_card_deliveries;
create policy gift_card_deliveries_service_role_all
  on public.gift_card_deliveries
  for all
  to service_role
  using (true)
  with check (true);

revoke all privileges on table
  public.profiles,
  public.clients,
  public.client_memberships,
  public.bookings,
  public.sales,
  public.orders,
  public.order_items,
  public.payments,
  public.gift_cards,
  public.gift_card_transactions,
  public.gift_card_deliveries,
  public.reception_alerts,
  public.business_whatsapp_settings,
  public.ai_settings,
  public.whatsapp_logs
from anon;

revoke all privileges on table
  public.gift_card_deliveries
from authenticated;

revoke truncate, references, trigger on all tables in schema public from authenticated;

grant select, insert, update, delete on table
  public.orders,
  public.order_items,
  public.payments,
  public.gift_cards
to authenticated;

grant select on table public.gift_card_transactions to authenticated;
grant select, update on table public.reception_alerts to authenticated;
grant all privileges on table public.gift_card_deliveries to service_role;
grant all privileges on table public.gift_card_transactions to service_role;

