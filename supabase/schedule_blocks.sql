create table if not exists public.schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid null,
  block_date date not null,
  start_minute integer not null check (start_minute >= 0 and start_minute <= 1439),
  end_minute integer not null check (end_minute > start_minute and end_minute <= 1440),
  scope text not null default 'day' check (scope in ('day', 'week')),
  title text not null default 'Horario bloqueado',
  notes text null,
  created_at timestamptz not null default now()
);

create index if not exists schedule_blocks_branch_date_idx
  on public.schedule_blocks (branch_id, block_date, start_minute);

grant select, insert, update, delete on public.schedule_blocks to authenticated;

alter table public.schedule_blocks enable row level security;

drop policy if exists "schedule_blocks_select_authenticated" on public.schedule_blocks;
drop policy if exists "schedule_blocks_insert_authenticated" on public.schedule_blocks;
drop policy if exists "schedule_blocks_update_authenticated" on public.schedule_blocks;
drop policy if exists "schedule_blocks_delete_authenticated" on public.schedule_blocks;

create policy "schedule_blocks_select_authenticated"
on public.schedule_blocks
for select
to authenticated
using (true);

create policy "schedule_blocks_insert_authenticated"
on public.schedule_blocks
for insert
to authenticated
with check (true);

create policy "schedule_blocks_update_authenticated"
on public.schedule_blocks
for update
to authenticated
using (true)
with check (true);

create policy "schedule_blocks_delete_authenticated"
on public.schedule_blocks
for delete
to authenticated
using (true);
