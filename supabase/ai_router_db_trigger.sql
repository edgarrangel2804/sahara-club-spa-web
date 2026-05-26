-- Sahara Club Spa - Trigger DB que invoca whatsapp-ai-router
-- cuando llega un message inbound al webhook.
-- Reemplaza el patrón "webhook→fetch(router)" que falla silenciosamente
-- en Supabase Edge Functions con auth interna service_role.

create or replace function public.invoke_ai_router_for_message()
returns trigger
language plpgsql
security definer
as $$
declare
  v_text text;
  v_phone text;
  v_wamid text;
begin
  -- Solo procesar messages de texto inbound con firma válida
  if new.event_kind <> 'message' then return new; end if;
  if new.event_subtype <> 'text' then return new; end if;
  if new.signature_valid <> true then return new; end if;

  v_text := new.raw_payload->'text'->>'body';
  v_phone := new.from_phone;
  v_wamid := new.message_id;

  if v_text is null or v_text = '' or v_phone is null then
    return new;
  end if;

  -- pg_net es asíncrono: encola el POST y devuelve request_id
  perform public.invoke_edge_function(
    'whatsapp-ai-router',
    jsonb_build_object(
      'phone', v_phone,
      'message_text', v_text,
      'wamid', v_wamid
    )
  );

  return new;
end;
$$;

drop trigger if exists on_whatsapp_inbound_invoke_ai on public.whatsapp_webhook_events;
create trigger on_whatsapp_inbound_invoke_ai
after insert on public.whatsapp_webhook_events
for each row execute function public.invoke_ai_router_for_message();
