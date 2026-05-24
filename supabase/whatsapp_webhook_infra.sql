-- Sahara Club Spa - WhatsApp Webhook Infrastructure (base)
-- Extiende business_whatsapp_settings con environment / webhook status
-- y crea tabla whatsapp_webhook_events para auditar entradas Meta.

create extension if not exists pgcrypto;

-- 1. Extender business_whatsapp_settings -------------------------------------
alter table public.business_whatsapp_settings
  add column if not exists environment text not null default 'sandbox',
  add column if not exists is_sandbox boolean not null default true,
  add column if not exists webhook_status text not null default 'not_verified',
  add column if not exists webhook_last_event_at timestamptz,
  add column if not exists webhook_last_verified_at timestamptz,
  add column if not exists webhook_last_error text;

alter table public.business_whatsapp_settings
  drop constraint if exists business_whatsapp_settings_environment_check;
alter table public.business_whatsapp_settings
  add constraint business_whatsapp_settings_environment_check
  check (environment in ('sandbox', 'production'));

alter table public.business_whatsapp_settings
  drop constraint if exists business_whatsapp_settings_webhook_status_check;
alter table public.business_whatsapp_settings
  add constraint business_whatsapp_settings_webhook_status_check
  check (webhook_status in ('not_verified', 'verified', 'error'));

-- Mantener is_sandbox y environment coherentes
create or replace function public.sync_whatsapp_environment_flags()
returns trigger
language plpgsql
as $$
begin
  if new.environment is null then
    new.environment := case when coalesce(new.is_sandbox, true) then 'sandbox' else 'production' end;
  end if;
  new.is_sandbox := (new.environment = 'sandbox');
  return new;
end;
$$;

drop trigger if exists on_business_whatsapp_settings_env on public.business_whatsapp_settings;
create trigger on_business_whatsapp_settings_env
before insert or update on public.business_whatsapp_settings
for each row execute function public.sync_whatsapp_environment_flags();

-- 2. Tabla de eventos entrantes del webhook ----------------------------------
create table if not exists public.whatsapp_webhook_events (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete set null,
  environment text not null default 'sandbox',
  event_kind text not null,                  -- 'message' | 'status' | 'unknown'
  event_subtype text,                        -- 'sent' | 'delivered' | 'read' | 'failed' | text | image | ...
  message_id text,                           -- wamid de Meta (cuando aplica)
  phone_number_id text,
  waba_id text,
  from_phone text,
  to_phone text,
  signature_valid boolean not null default false,
  http_status integer not null default 200,
  raw_payload jsonb not null default '{}'::jsonb,
  error_message text,
  received_at timestamptz not null default now()
);

create index if not exists idx_whatsapp_webhook_events_received_at
  on public.whatsapp_webhook_events(received_at desc);
create index if not exists idx_whatsapp_webhook_events_kind
  on public.whatsapp_webhook_events(event_kind, event_subtype);
create index if not exists idx_whatsapp_webhook_events_message_id
  on public.whatsapp_webhook_events(message_id)
  where message_id is not null;

alter table public.whatsapp_webhook_events enable row level security;

drop policy if exists whatsapp_webhook_events_select_admin on public.whatsapp_webhook_events;
create policy whatsapp_webhook_events_select_admin
  on public.whatsapp_webhook_events
  for select to authenticated
  using (public.current_user_role() in ('admin', 'reception', 'receptionist'));

-- Service role escribe vía Edge Function (bypass RLS); igualmente declaramos manage admin.
drop policy if exists whatsapp_webhook_events_manage_admin on public.whatsapp_webhook_events;
create policy whatsapp_webhook_events_manage_admin
  on public.whatsapp_webhook_events
  for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- 3. Función para actualizar status de mensaje saliente (delivered/read/failed)
-- Cuando Meta entregue un status, ligamos por wamid (provider_response->>'messages'[0].id).
create or replace function public.apply_whatsapp_status_event(
  p_message_id text,
  p_status text,
  p_timestamp timestamptz,
  p_error text default null
)
returns void
language plpgsql
security definer
as $$
begin
  if p_message_id is null then return; end if;

  update public.whatsapp_logs
  set
    status = coalesce(p_status, status),
    delivered_at = case when p_status in ('delivered','read') then coalesce(delivered_at, p_timestamp) else delivered_at end,
    read_at = case when p_status = 'read' then coalesce(read_at, p_timestamp) else read_at end,
    error_message = case when p_status = 'failed' then coalesce(p_error, error_message) else error_message end
  where (provider_response->'messages'->0->>'id') = p_message_id
     or (provider_response->>'message_id') = p_message_id;
end;
$$;
