-- Sahara Club Spa - Agente recepcionista F2 (piloto read-only)
-- Tablas para conversaciones IA + flag de activación restringido a números piloto.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. ai_conversations
-- ---------------------------------------------------------------------------
create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete set null,
  customer_phone text not null,
  client_id uuid references public.clients(id) on delete set null,
  status text not null default 'active'
    check (status in ('active','escalated_to_human','closed','expired')),
  channel text not null default 'whatsapp',
  last_message_at timestamptz default now(),
  escalation_reason text,
  total_tokens_in integer not null default 0,
  total_tokens_out integer not null default 0,
  total_cost_usd numeric(10,6) not null default 0,
  llm_model text,
  message_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_ai_conv_phone_status
  on public.ai_conversations (customer_phone, status, last_message_at desc);
create index if not exists idx_ai_conv_last_message
  on public.ai_conversations (last_message_at desc);

drop trigger if exists on_ai_conv_updated on public.ai_conversations;
create trigger on_ai_conv_updated
before update on public.ai_conversations
for each row execute function public.handle_updated_at();

-- ---------------------------------------------------------------------------
-- 2. ai_messages
-- ---------------------------------------------------------------------------
create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant','tool','system')),
  content text,
  tool_name text,
  tool_input jsonb,
  tool_output jsonb,
  wamid text,
  meta_message_id text,
  tokens_in integer,
  tokens_out integer,
  latency_ms integer,
  llm_model text,
  stop_reason text,
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_messages_conversation
  on public.ai_messages (conversation_id, created_at);
create index if not exists idx_ai_messages_wamid
  on public.ai_messages (wamid) where wamid is not null;

-- ---------------------------------------------------------------------------
-- 3. ai_intents
-- ---------------------------------------------------------------------------
create table if not exists public.ai_intents (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  message_id uuid references public.ai_messages(id) on delete set null,
  intent_code text not null,
  confidence numeric(3,2),
  detected_at timestamptz not null default now()
);

create index if not exists idx_ai_intents_conv on public.ai_intents (conversation_id);
create index if not exists idx_ai_intents_code on public.ai_intents (intent_code);

-- ---------------------------------------------------------------------------
-- 4. ai_settings (single row, controla activación piloto)
-- ---------------------------------------------------------------------------
create table if not exists public.ai_settings (
  id smallint primary key default 1 check (id = 1),
  ai_enabled boolean not null default false,            -- master switch
  pilot_mode boolean not null default true,             -- si true, solo responde a pilot_phones
  pilot_phones text[] not null default '{}',            -- ej ['6462882480']
  llm_model text not null default 'claude-haiku-4-5',
  temperature numeric(3,2) not null default 0.20,
  max_output_tokens integer not null default 400,
  cost_per_million_input_usd numeric(10,4) not null default 0.80,
  cost_per_million_output_usd numeric(10,4) not null default 4.00,
  max_msgs_per_phone_24h integer not null default 30,   -- rate limit por número
  max_tokens_per_conversation integer not null default 50000,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.ai_settings (id, ai_enabled, pilot_mode, pilot_phones, llm_model)
values (1, true, true, ARRAY['6462882480'], 'claude-haiku-4-5')
on conflict (id) do update
set ai_enabled = excluded.ai_enabled,
    pilot_mode = excluded.pilot_mode,
    pilot_phones = excluded.pilot_phones,
    llm_model = excluded.llm_model;

drop trigger if exists on_ai_settings_updated on public.ai_settings;
create trigger on_ai_settings_updated
before update on public.ai_settings
for each row execute function public.handle_updated_at();

-- ---------------------------------------------------------------------------
-- 5. RPC helper: chequea si un teléfono está en pilot whitelist
-- ---------------------------------------------------------------------------
create or replace function public.ai_should_respond(p_phone text)
returns boolean
language sql
stable
as $$
  select coalesce(
    (
      select
        s.ai_enabled
        and (
          s.pilot_mode = false
          or right(regexp_replace(p_phone, '\D', '', 'g'), 10) = any (
            select right(regexp_replace(p, '\D', '', 'g'), 10)
            from unnest(s.pilot_phones) as p
          )
        )
      from public.ai_settings s
      where s.id = 1
    ),
    false
  );
$$;

-- ---------------------------------------------------------------------------
-- 6. RLS — admin/reception leen, solo admin escribe; service_role bypass
-- ---------------------------------------------------------------------------
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_intents enable row level security;
alter table public.ai_settings enable row level security;

drop policy if exists ai_conv_read on public.ai_conversations;
create policy ai_conv_read on public.ai_conversations for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));
drop policy if exists ai_conv_admin on public.ai_conversations;
create policy ai_conv_admin on public.ai_conversations for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists ai_msg_read on public.ai_messages;
create policy ai_msg_read on public.ai_messages for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));
drop policy if exists ai_msg_admin on public.ai_messages;
create policy ai_msg_admin on public.ai_messages for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists ai_int_read on public.ai_intents;
create policy ai_int_read on public.ai_intents for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));

drop policy if exists ai_set_read on public.ai_settings;
create policy ai_set_read on public.ai_settings for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));
drop policy if exists ai_set_admin on public.ai_settings;
create policy ai_set_admin on public.ai_settings for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');
