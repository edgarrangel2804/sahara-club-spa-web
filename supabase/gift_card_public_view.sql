-- ============================================================================
-- gift_card_public_view.sql
-- Legacy compatibility shim.
--
-- La tarjeta digital ya no se autoriza por code ni session_id. El flujo vigente
-- usa la Edge Function `gift_card_download` con token firmado de proposito
-- `gift_card_download`, ligado a gift_card_id/order_item_id y sin PII en URL.
-- ============================================================================

create or replace function public.get_gift_card_public(
  p_code text default null,
  p_session_id text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return jsonb_build_object(
    'found', false,
    'error', 'signed_gift_card_token_required'
  );
end;
$$;

revoke all on function public.get_gift_card_public(text, text) from public;
revoke all on function public.get_gift_card_public(text, text) from anon;
revoke all on function public.get_gift_card_public(text, text) from authenticated;
grant execute on function public.get_gift_card_public(text, text) to service_role;
