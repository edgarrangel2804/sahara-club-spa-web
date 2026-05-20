create table if not exists public.cash_box_movements (
  id uuid primary key,
  branch_id uuid null,
  movement_type text not null check (movement_type in ('entrada', 'salida')),
  description text not null,
  amount numeric(12, 2) not null check (amount > 0),
  responsible_name text null,
  status text not null default 'registrado',
  notes text null,
  movement_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists cash_box_movements_branch_idx
  on public.cash_box_movements (branch_id, movement_at desc);

grant select, insert, update on public.cash_box_movements to authenticated;
