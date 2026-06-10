-- ============================================================================
-- list_giftable_services.sql
-- Catálogo de servicios "regalables" para la compra de gift cards en línea.
-- La tabla services NO es legible por anon (RLS), así que la landing/app públicas
-- obtienen el catálogo vía este RPC security-definer (solo activos, precio fijo,
-- no paquetes, precio > 0).
-- ============================================================================
create or replace function public.list_giftable_services()
returns table(id uuid, name text, price numeric)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.name, s.price
  from public.services s
  where s.is_active = true
    and coalesce(s.price_on_quote, false) = false
    and coalesce(s.is_package, false) = false
    and coalesce(s.price, 0) > 0
  order by s.name;
$$;

revoke all on function public.list_giftable_services() from public;
grant execute on function public.list_giftable_services() to anon, authenticated, service_role;
