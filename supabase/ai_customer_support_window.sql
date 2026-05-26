-- Sahara Club Spa - Ventana de atención al público IA
-- ----------------------------------------------------------------------------
-- Define el horario en que el concierge IA responde a clientes (no admins).
-- Fuera de la ventana, se manda un auto-reply con el horario.
-- Admins siguen respondiendo 24/7 (bypass total como ya estaba).

-- 1. Columnas en ai_settings -----------------------------------------------
alter table public.ai_settings
  add column if not exists customer_support_start time
    not null default '07:00:00',
  add column if not exists customer_support_end time
    not null default '23:59:59',
  add column if not exists after_hours_message text
    not null default 'Hola ✨ Nuestro horario de atención es de 7:00 a.m. a 12:00 a.m. (medianoche). Te responderemos en cuanto abramos. ¡Gracias por escribir a Sahara Club Spa! 🌿';

-- 2. Función helper: ¿estamos dentro de la ventana de atención al cliente?
--    Maneja correctamente ventanas que cruzan medianoche (ej. 22:00 → 02:00).
create or replace function public.is_within_customer_support_window()
returns boolean
language sql
stable
as $$
  with s as (select customer_support_start as start_t, customer_support_end as end_t from public.ai_settings where id=1),
  now_tj as (
    select (now() at time zone 'America/Tijuana')::time as t
  )
  select case
    -- Ventana misma día: start ≤ now < end
    when (select start_t from s) <= (select end_t from s)
      then (select t from now_tj) >= (select start_t from s)
       and (select t from now_tj) <  (select end_t from s)
    -- Ventana cruza medianoche: start > end → válido si now ≥ start O now < end
    else (select t from now_tj) >= (select start_t from s)
      or (select t from now_tj) <  (select end_t from s)
  end;
$$;

-- 3. Modificar can_ai_respond para usar la ventana de atención al cliente
--    en lugar de business_hours. Admins siguen bypassando.
create or replace function public.can_ai_respond(p_phone text, p_conversation_id uuid default null)
returns jsonb
language plpgsql
stable
as $$
declare
  s record;
  cost_today numeric;
  conv record;
  within_window boolean;
  admin_flag boolean := public.is_ai_admin(p_phone);
begin
  select * into s from public.ai_settings where id = 1;
  if not found then
    return jsonb_build_object('allowed', false, 'reason', 'no_settings_row');
  end if;

  if s.ai_enabled = false or s.ai_mode = 'disabled' then
    return jsonb_build_object('allowed', false, 'reason', 'ai_disabled');
  end if;

  if s.ai_pause_all_conversations = true then
    return jsonb_build_object('allowed', false, 'reason', 'paused_all');
  end if;

  -- Admin: bypassa pilot whitelist y ventana de atención
  if not admin_flag then
    if s.ai_mode = 'pilot' then
      if not exists (
        select 1 from unnest(s.allowed_test_numbers) as n
        where right(regexp_replace(n,'\D','','g'),10)
            = right(regexp_replace(p_phone,'\D','','g'),10)
      ) then
        return jsonb_build_object('allowed', false, 'reason', 'phone_not_in_pilot');
      end if;
    end if;

    if s.ai_mode = 'assisted' then
      return jsonb_build_object('allowed', false, 'reason', 'assisted_mode_not_implemented_yet');
    end if;

    -- Ventana de atención al cliente (default 07:00 → 23:59:59 Tijuana)
    if s.allow_after_hours_responses = false then
      select public.is_within_customer_support_window() into within_window;
      if coalesce(within_window, false) = false then
        return jsonb_build_object(
          'allowed', false,
          'reason', 'after_hours_blocked',
          'auto_reply', s.after_hours_message,
          'window_start', s.customer_support_start::text,
          'window_end', s.customer_support_end::text
        );
      end if;
    end if;
  end if;

  -- Conversación escalada / cerrada
  if p_conversation_id is not null then
    select * into conv from public.ai_conversations where id = p_conversation_id;
    if found and s.handoff_human_priority = true
       and conv.status in ('escalated_to_human','closed') then
      return jsonb_build_object(
        'allowed', false, 'reason', 'reception_in_control',
        'conversation_status', conv.status
      );
    end if;
    if found and conv.message_count >= s.max_messages_per_conversation then
      return jsonb_build_object('allowed', false, 'reason', 'msg_cap_reached');
    end if;
  end if;

  -- Caps de costo
  if admin_flag then
    select coalesce(sum(c.total_cost_usd), 0) into cost_today
    from public.ai_conversations c, public.ai_messages m
    where m.conversation_id = c.id
      and m.is_admin_query = true
      and m.created_at::date = (now() at time zone 'America/Tijuana')::date;
    if cost_today >= s.max_admin_daily_cost_usd then
      return jsonb_build_object('allowed', false, 'reason', 'admin_daily_cost_cap_reached',
                                'cost_today_usd', cost_today,
                                'cap', s.max_admin_daily_cost_usd);
    end if;
  else
    select coalesce(sum(total_cost_usd), 0) into cost_today
    from public.ai_conversations
    where last_message_at::date = (now() at time zone 'America/Tijuana')::date;
    if cost_today >= s.max_daily_cost_usd then
      return jsonb_build_object('allowed', false, 'reason', 'daily_cost_cap_reached',
                                'cost_today_usd', cost_today,
                                'cap', s.max_daily_cost_usd);
    end if;
  end if;

  return jsonb_build_object('allowed', true, 'reason', 'ok',
                            'mode', s.ai_mode,
                            'admin', admin_flag,
                            'model', s.active_model);
end;
$$;

-- 4. Verificación
select customer_support_start, customer_support_end,
       after_hours_message,
       public.is_within_customer_support_window() as within_now,
       (now() at time zone 'America/Tijuana')::time as now_tj
from public.ai_settings where id = 1;
