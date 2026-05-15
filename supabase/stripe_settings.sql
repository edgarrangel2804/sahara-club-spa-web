create extension if not exists pgcrypto;

create table if not exists public.stripe_settings (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null,
  environment_mode text not null default 'testing',
  publishable_key text not null default '',
  secret_key_encrypted text not null default '',
  secret_key_masked text not null default '',
  webhook_secret_encrypted text not null default '',
  webhook_secret_masked text not null default '',
  stripe_account_id text not null default '',
  connection_status text not null default 'not_configured',
  last_validated_at timestamptz,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stripe_settings_environment_check
    check (environment_mode in ('testing', 'production'))
);

create unique index if not exists idx_stripe_settings_branch_env
  on public.stripe_settings(branch_id, environment_mode);

create unique index if not exists idx_stripe_settings_active_branch
  on public.stripe_settings(branch_id)
  where is_active = true;

create or replace function public.touch_stripe_settings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_stripe_settings_updated_at on public.stripe_settings;
create trigger trg_stripe_settings_updated_at
before update on public.stripe_settings
for each row execute function public.touch_stripe_settings_updated_at();

alter table public.stripe_settings enable row level security;

drop policy if exists stripe_settings_admin_manage on public.stripe_settings;
create policy stripe_settings_admin_manage
  on public.stripe_settings
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  );
