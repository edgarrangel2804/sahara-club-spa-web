-- Sahara Club Spa - Modo Administrador IA por WhatsApp
-- Tools admin read-only, helper is_ai_admin, excepción horario en can_ai_respond.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Extender ai_settings
-- ---------------------------------------------------------------------------
alter table public.ai_settings
  add column if not exists ai_admin_numbers text[] not null default '{}',
  add column if not exists max_admin_daily_cost_usd numeric(10,4) not null default 5,
  add column if not exists admin_daily_report_enabled boolean not null default false,
  add column if not exists admin_daily_report_time time not null default '20:30',
  add column if not exists admin_daily_report_timezone text not null default 'America/Tijuana',
  add column if not exists admin_daily_report_last_sent_date date;

-- Inicializar con los 3 admins
update public.ai_settings
set ai_admin_numbers = ARRAY['6462882480','6462108473','6461942940']
where id = 1;

-- ---------------------------------------------------------------------------
-- 2. ai_messages: marcar consultas admin
-- ---------------------------------------------------------------------------
alter table public.ai_messages
  add column if not exists is_admin_query boolean not null default false;

create index if not exists idx_ai_messages_admin
  on public.ai_messages (is_admin_query, created_at desc)
  where is_admin_query = true;

-- ---------------------------------------------------------------------------
-- 3. is_ai_admin(phone) - compara últimos 10 dígitos
-- ---------------------------------------------------------------------------
create or replace function public.is_ai_admin(p_phone text)
returns boolean
language sql
stable
as $$
  select coalesce(
    (select
      right(regexp_replace(p_phone,'\D','','g'),10) = any (
        select right(regexp_replace(n,'\D','','g'),10)
        from unnest(s.ai_admin_numbers) as n
      )
     from public.ai_settings s where s.id=1),
    false
  );
$$;

-- ---------------------------------------------------------------------------
-- 4. can_ai_respond v2 - excepción admin para horario, cap admin separado
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

  -- Admin: bypassa pilot whitelist y after-hours
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

    if s.allow_after_hours_responses = false then
      select (r.is_open) into is_open from public.is_business_open(now(), null) r;
      if coalesce(is_open, false) = false then
        return jsonb_build_object('allowed', false, 'reason', 'after_hours_blocked');
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

  -- Caps de costo: admin tiene su propio cap, cliente usa el general
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

-- ---------------------------------------------------------------------------
-- 5. Audit trigger: incluir cambios en ai_admin_numbers
-- ---------------------------------------------------------------------------
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
  if old.ai_admin_numbers is distinct from new.ai_admin_numbers then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'ai_admin_numbers',
            array_to_string(old.ai_admin_numbers, ','),
            array_to_string(new.ai_admin_numbers, ','));
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
  if old.admin_daily_report_enabled is distinct from new.admin_daily_report_enabled then
    insert into public.ai_settings_audit(changed_by, changed_by_email, field, old_value, new_value)
    values (v_user, v_email, 'admin_daily_report_enabled',
            old.admin_daily_report_enabled::text, new.admin_daily_report_enabled::text);
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Vistas helper para reportes admin
-- ---------------------------------------------------------------------------
create or replace view public.admin_today_summary as
with today as (
  select (now() at time zone 'America/Tijuana')::date as d
)
select
  today.d as date,
  (select count(*) from public.bookings b, today
    where b.booking_date = today.d) as total,
  (select count(*) from public.bookings b, today
    where b.booking_date = today.d and b.status='confirmed') as confirmed,
  (select count(*) from public.bookings b, today
    where b.booking_date = today.d and b.status='cancelled') as cancelled,
  (select count(*) from public.bookings b, today
    where b.booking_date = today.d and b.status in ('pending','scheduled')) as pending,
  (select count(*) from public.bookings b, today
    where b.booking_date = today.d and b.status='completed') as completed,
  (select count(*) from public.bookings b, today
    where b.booking_date = today.d and b.status in ('paid','awaiting_payment')) as paid_or_to_charge,
  (select coalesce(sum(s.total), 0) from public.sales s, today
    where s.created_at::date = today.d
      and s.payment_status = 'paid') as revenue_today
from today;

create or replace view public.admin_tomorrow_appointments as
with tj as (select (now() at time zone 'America/Tijuana')::date + 1 as d)
select
  b.booking_time,
  coalesce(sv.name, b.service_name, 'Servicio') as service,
  coalesce(st.full_name, 'Sin asignar') as therapist,
  b.status,
  -- privacidad: solo iniciales del cliente
  left(coalesce(c.full_name,''), 1) as client_initial
from public.bookings b
join tj on b.booking_date = tj.d
left join public.services sv on sv.id = b.service_id
left join public.staff st on st.id = b.therapist_id
left join public.clients c on c.id = b.client_record_id
order by b.booking_time;
