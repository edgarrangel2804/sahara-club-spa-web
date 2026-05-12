create extension if not exists pgcrypto;

create table if not exists public.business_whatsapp_settings (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.sucursales(id) on delete cascade,
  business_name text not null default '',
  meta_business_id text not null default '',
  whatsapp_business_account_id text not null default '',
  phone_number_id text not null default '',
  whatsapp_phone_number text not null default '',
  access_token_encrypted text not null default '',
  access_token_masked text not null default '',
  app_id text not null default '',
  app_secret_encrypted text not null default '',
  app_secret_masked text not null default '',
  webhook_verify_token text not null default '',
  connection_status text not null default 'not_configured',
  last_validated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_whatsapp_settings_branch_unique unique (branch_id),
  constraint business_whatsapp_settings_status_check
    check (connection_status in ('not_configured', 'pending', 'connected', 'error'))
);

create index if not exists idx_business_whatsapp_settings_branch
  on public.business_whatsapp_settings(branch_id);

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_business_whatsapp_settings_updated on public.business_whatsapp_settings;
create trigger on_business_whatsapp_settings_updated
before update on public.business_whatsapp_settings
for each row execute function public.handle_updated_at();

insert into public.business_whatsapp_settings (
  branch_id,
  business_name,
  connection_status
)
select
  '11111111-1111-1111-1111-111111111111'::uuid,
  'Sahara Club Spa',
  'not_configured'
where not exists (
  select 1
  from public.business_whatsapp_settings
  where branch_id = '11111111-1111-1111-1111-111111111111'::uuid
);

alter table public.business_whatsapp_settings enable row level security;

drop policy if exists business_whatsapp_settings_select_admin on public.business_whatsapp_settings;
create policy business_whatsapp_settings_select_admin
  on public.business_whatsapp_settings
  for select
  to authenticated
  using (public.current_user_role() = 'admin');

drop policy if exists business_whatsapp_settings_manage_admin on public.business_whatsapp_settings;
create policy business_whatsapp_settings_manage_admin
  on public.business_whatsapp_settings
  for all
  to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');
