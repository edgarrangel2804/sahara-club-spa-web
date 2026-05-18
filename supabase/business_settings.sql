create table if not exists public.business_settings (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete cascade,
  calendar_start_hour time not null default '00:00:00',
  calendar_end_hour time not null default '23:59:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_settings_branch_unique unique (branch_id)
);

create index if not exists idx_business_settings_branch
  on public.business_settings(branch_id);

create or replace function public.touch_business_settings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_business_settings_updated_at on public.business_settings;
create trigger trg_business_settings_updated_at
before update on public.business_settings
for each row execute function public.touch_business_settings_updated_at();

insert into public.business_settings (branch_id)
select s.id
from public.sucursales s
where not exists (
  select 1
  from public.business_settings bs
  where bs.branch_id = s.id
);

alter table public.business_settings enable row level security;

drop policy if exists business_settings_select_authenticated on public.business_settings;
create policy business_settings_select_authenticated
  on public.business_settings
  for select
  to authenticated
  using (true);

drop policy if exists business_settings_manage_authenticated on public.business_settings;
create policy business_settings_manage_authenticated
  on public.business_settings
  for all
  to authenticated
  using (true)
  with check (true);
