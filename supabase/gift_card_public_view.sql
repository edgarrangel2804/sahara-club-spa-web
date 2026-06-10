-- ============================================================================
-- gift_card_public_view.sql
-- RPC público para mostrar la TARJETA DIGITAL (QR) de una gift card al comprador.
-- gift_cards no es legible por anon (RLS), así que esta función security-definer
-- expone SOLO campos de presentación, buscando por código o por session_id de Stripe.
-- El código es el secreto (quien lo tiene puede ver/regalar la tarjeta).
-- ============================================================================
create or replace function public.get_gift_card_public(
  p_code       text default null,
  p_session_id text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v public.gift_cards%rowtype;
begin
  if p_code is not null and length(trim(p_code)) > 0 then
    select * into v
    from public.gift_cards
    where code = trim(p_code)
    limit 1;
  elsif p_session_id is not null and length(trim(p_session_id)) > 0 then
    select gc.* into v
    from public.gift_cards gc
    join public.orders o on o.id = gc.order_id
    where o.stripe_session_id = trim(p_session_id)
    order by gc.created_at desc
    limit 1;
  else
    return jsonb_build_object('found', false, 'error', 'missing_params');
  end if;

  if v.id is null then
    return jsonb_build_object('found', false);
  end if;

  return jsonb_build_object(
    'found',          true,
    'code',           v.code,
    'service_name',   v.service_name,
    'recipient_name', v.recipient_name,
    'sender_name',    v.sender_name,
    'message',        v.message,
    'expires_at',     v.expires_at,
    'status',         v.status,
    'currency',       v.currency,
    'amount',         v.initial_balance
  );
end;
$$;

revoke all on function public.get_gift_card_public(text, text) from public;
grant execute on function public.get_gift_card_public(text, text) to anon, authenticated, service_role;
