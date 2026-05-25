-- Sahara Club Spa - Centro de Control IA
-- Extiende ai_settings, agrega audit trail y helper can_ai_respond(phone, conv_id)
-- Mantiene retro-compat con columnas existentes (pilot_phones, llm_model).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. ALTER ai_settings — campos nuevos del Control Center
-- ---------------------------------------------------------------------------
alter table public.ai_settings
  add column if not exists ai_mode text not null default 'pilot',
  add column if not exists allowed_test_numbers text[] not null default '{}',
  add column if not exists ai_pause_all_conversations boolean not null default false,
  add column if not exists handoff_human_priority boolean not null default true,
  add column if not exists allow_after_hours_responses boolean not null default false,
  add column if not exists max_messages_per_conversation integer not null default 30,
  add column if not exists max_daily_cost_usd numeric(10,4) not null default 25,
  add column if not exists active_model text not null default 'claude-haiku-4-5';

-- CHECK para ai_mode
alter table public.ai_settings drop constraint if exists ai_settings_mode_check;
alter table public.ai_settings add constraint ai_settings_mode_check
  check (ai_mode in ('disabled','pilot','read_only','assisted'));

-- Migrar valores actuales (una sola vez)
update public.ai_settings
set
  allowed_test_numbers = coalesce(nullif(allowed_test_numbers, '{}'), pilot_phones),
  active_model         = coalesce(nullif(active_model, ''), llm_model),
  ai_mode = case
    when ai_enabled = false then 'disabled'
    when pilot_mode = true  then 'pilot'
    else 'read_only'
  end
where id = 1
  and (allowed_test_numbers = '{}' or active_model is null);

-- ---------------------------------------------------------------------------
-- 2. Tabla de auditoría
-- ---------------------------------------------------------------------------
create table if not exists public.ai_settings_audit (
  id uuid primary key default gen_random_uuid(),
  changed_at timestamptz not null default now(),
  changed_by uuid,
  changed_by_email text,
  field text not null,
  old_value text,
  new_value text
);

create index if not exists idx_ai_settings_audit_at on public.ai_settings_audit (changed_at desc);

create or replace function public.log_ai_settings_changes()
returns trigger
language plpgsql
as $$
declare
  v_user uuid := auth.uid();
  v_email text;
begin
  select email into v_email from auth.users where id = v_user;

  if old.ai_enabled is distinct from new.ai_enabled then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'ai_enabled', old.ai_enabled::text, new.ai_enabled::text);
  end if;
  if old.ai_mode is distinct from new.ai_mode then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'ai_mode', old.ai_mode, new.ai_mode);
  end if;
  if old.ai_pause_all_conversations is distinct from new.ai_pause_all_conversations then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'ai_pause_all_conversations',
            old.ai_pause_all_conversations::text, new.ai_pause_all_conversations::text);
  end if;
  if old.allowed_test_numbers is distinct from new.allowed_test_numbers then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'allowed_test_numbers',
            array_to_string(old.allowed_test_numbers, ','),
            array_to_string(new.allowed_test_numbers, ','));
  end if;
  if old.handoff_human_priority is distinct from new.handoff_human_priority then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'handoff_human_priority',
            old.handoff_human_priority::text, new.handoff_human_priority::text);
  end if;
  if old.allow_after_hours_responses is distinct from new.allow_after_hours_responses then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'allow_after_hours_responses',
            old.allow_after_hours_responses::text, new.allow_after_hours_responses::text);
  end if;
  if old.active_model is distinct from new.active_model then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'active_model', old.active_model, new.active_model);
  end if;
  if old.max_daily_cost_usd is distinct from new.max_daily_cost_usd then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'max_daily_cost_usd',
            old.max_daily_cost_usd::text, new.max_daily_cost_usd::text);
  end if;
  return new;
end;
$$;

drop trigger if exists on_ai_settings_audit on public.ai_settings;
create trigger on_ai_settings_audit
after update on public.ai_settings
for each row execute function public.log_ai_settings_changes();

-- ---------------------------------------------------------------------------
-- 3. RPC central can_ai_respond — devuelve jsonb {allowed, reason}
-- ---------------------------------------------------------------------------
create or replace function public.can_ai_respond(
  p_phone text,
  p_conversation_id uuid default null
)
returns jsonb
language plpgsql
stable
as $$
declare
  s record;
  cost_today numeric;
  conv record;
  is_open boolean;
begin
  select * into s from public.ai_settings where id = 1;
  if not found then
    return jsonb_build_object('allowed', false, 'reason', 'no_settings_row');
  end if;

  -- Modo deshabilitado o switch global off
  if s.ai_enabled = false or s.ai_mode = 'disabled' then
    return jsonb_build_object('allowed', false, 'reason', 'ai_disabled');
  end if;

  -- Pausa total
  if s.ai_pause_all_conversations = true then
    return jsonb_build_object('allowed', false, 'reason', 'paused_all');
  end if;

  -- Modo piloto: phone debe estar en whitelist (comparando últimos 10 dígitos)
  if s.ai_mode = 'pilot' then
    if not exists (
      select 1 from unnest(s.allowed_test_numbers) as n
      where right(regexp_replace(n,'\D','','g'),10)
          = right(regexp_replace(p_phone,'\D','','g'),10)
    ) then
      return jsonb_build_object('allowed', false, 'reason', 'phone_not_in_pilot');
    end if;
  end if;

  -- Modo assisted aún no implementado
  if s.ai_mode = 'assisted' then
    return jsonb_build_object('allowed', false, 'reason', 'assisted_mode_not_implemented_yet');
  end if;

  -- Horario: si no se permite fuera de horario y el spa está cerrado → bloquear
  if s.allow_after_hours_responses = false then
    select (r.is_open) into is_open
    from public.is_business_open(now(), null) r;
    if coalesce(is_open, false) = false then
      return jsonb_build_object('allowed', false, 'reason', 'after_hours_blocked');
    end if;
  end if;

  -- Conversación escalada / cerrada → recepción tiene control
  if p_conversation_id is not null then
    select * into conv from public.ai_conversations where id = p_conversation_id;
    if found and s.handoff_human_priority = true
       and conv.status in ('escalated_to_human','closed') then
      return jsonb_build_object(
        'allowed', false,
        'reason', 'reception_in_control',
        'conversation_status', conv.status
      );
    end if;
    -- Cap de mensajes por conversación
    if found and conv.message_count >= s.max_messages_per_conversation then
      return jsonb_build_object('allowed', false, 'reason', 'msg_cap_reached');
    end if;
  end if;

  -- Cap de costo diario
  select coalesce(sum(total_cost_usd), 0) into cost_today
  from public.ai_conversations
  where last_message_at::date = (now() at time zone 'America/Tijuana')::date;
  if cost_today >= s.max_daily_cost_usd then
    return jsonb_build_object('allowed', false, 'reason', 'daily_cost_cap_reached',
                              'cost_today_usd', cost_today,
                              'cap', s.max_daily_cost_usd);
  end if;

  return jsonb_build_object('allowed', true, 'reason', 'ok',
                            'mode', s.ai_mode,
                            'model', s.active_model);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Vista de métricas para el dashboard
-- ---------------------------------------------------------------------------
create or replace view public.ai_metrics_dashboard as
select
  s.ai_enabled,
  s.ai_mode,
  s.active_model,
  s.allowed_test_numbers,
  s.ai_pause_all_conversations,
  s.handoff_human_priority,
  s.allow_after_hours_responses,
  s.max_daily_cost_usd,
  (select coalesce(sum(total_cost_usd), 0) from public.ai_conversations
    where last_message_at::date = (now() at time zone 'America/Tijuana')::date) as cost_today_usd,
  (select count(*) from public.ai_conversations where status='active'
    and last_message_at > now() - interval '24 hours') as active_conversations_24h,
  (select count(*) from public.ai_messages where role='user'
    and created_at::date = (now() at time zone 'America/Tijuana')::date) as user_messages_today,
  (select count(*) from public.ai_messages where role='assistant'
    and created_at::date = (now() at time zone 'America/Tijuana')::date) as assistant_messages_today,
  (select avg(latency_ms)::int from public.ai_messages
    where role='assistant' and created_at > now() - interval '24 hours') as avg_latency_ms_24h,
  (select count(*) from public.ai_conversations where status='escalated_to_human') as escalated_total
from public.ai_settings s where s.id=1;

-- ---------------------------------------------------------------------------
-- 5. RLS de la tabla audit
-- ---------------------------------------------------------------------------
alter table public.ai_settings_audit enable row level security;
drop policy if exists ai_audit_read on public.ai_settings_audit;
create policy ai_audit_read on public.ai_settings_audit for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));
