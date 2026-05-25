-- Sahara Club Spa - Foundation para Agente Recepcionista (Fase 0)
-- Tablas: business_hours, business_closed_days
-- Extensión: services + benefits/contraindications/recommended_for/internal_notes

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. business_hours: horario semanal estándar (1 row por día de semana)
-- ---------------------------------------------------------------------------
create table if not exists public.business_hours (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.sucursales(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),  -- 0=domingo, 6=sábado
  opens_at time,
  closes_at time,
  is_closed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_hours_open_close_check check (
    is_closed = true or (opens_at is not null and closes_at is not null and opens_at < closes_at)
  ),
  unique (branch_id, weekday)
);

create index if not exists idx_business_hours_branch on public.business_hours(branch_id);

drop trigger if exists on_business_hours_updated on public.business_hours;
create trigger on_business_hours_updated
before update on public.business_hours
for each row execute function public.handle_updated_at();

-- Seed con horario placeholder: lunes-sábado 10:00-19:00, domingo cerrado.
-- El admin lo edita en F1.
insert into public.business_hours (branch_id, weekday, opens_at, closes_at, is_closed)
select
  public.get_default_branch_id(),
  d.weekday,
  case when d.weekday = 0 then null else time '10:00' end,
  case when d.weekday = 0 then null else time '19:00' end,
  (d.weekday = 0)
from (values (0),(1),(2),(3),(4),(5),(6)) as d(weekday)
where not exists (
  select 1 from public.business_hours bh
  where bh.branch_id = public.get_default_branch_id() and bh.weekday = d.weekday
);

-- ---------------------------------------------------------------------------
-- 2. business_closed_days: excepciones (festivos, eventos, horario especial)
-- ---------------------------------------------------------------------------
create table if not exists public.business_closed_days (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.sucursales(id) on delete cascade,
  date date not null,
  reason text not null default '',
  custom_opens_at time,         -- null + custom_closes_at null = cerrado todo el día
  custom_closes_at time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint closed_days_custom_pair_check check (
    (custom_opens_at is null and custom_closes_at is null)
    or (custom_opens_at is not null and custom_closes_at is not null
        and custom_opens_at < custom_closes_at)
  ),
  unique (branch_id, date)
);

create index if not exists idx_business_closed_days_branch_date
  on public.business_closed_days(branch_id, date);

drop trigger if exists on_business_closed_days_updated on public.business_closed_days;
create trigger on_business_closed_days_updated
before update on public.business_closed_days
for each row execute function public.handle_updated_at();

-- ---------------------------------------------------------------------------
-- 3. ALTER services: campos para el agente recepcionista
-- ---------------------------------------------------------------------------
alter table public.services
  add column if not exists benefits text[] not null default '{}',
  add column if not exists contraindications text[] not null default '{}',
  add column if not exists recommended_for text[] not null default '{}',
  add column if not exists internal_notes text not null default '';

-- Índice GIN para búsquedas como "recommended_for contains 'estrés'"
create index if not exists idx_services_recommended_for
  on public.services using gin (recommended_for);
create index if not exists idx_services_benefits
  on public.services using gin (benefits);

-- ---------------------------------------------------------------------------
-- 4. Función helper: ¿está abierto el spa en esta fecha+hora?
-- ---------------------------------------------------------------------------
create or replace function public.is_business_open(
  p_at timestamptz default now(),
  p_branch_id uuid default null
) returns table (
  is_open boolean,
  reason text,
  opens_at time,
  closes_at time
)
language plpgsql
stable
as $$
declare
  v_branch uuid := coalesce(p_branch_id, public.get_default_branch_id());
  v_local timestamp := p_at at time zone 'America/Tijuana';
  v_date date := v_local::date;
  v_time time := v_local::time;
  v_closed record;
  v_hours record;
begin
  -- 1. Excepción del día (festivo o custom hours)?
  select * into v_closed
  from public.business_closed_days
  where branch_id = v_branch and date = v_date
  limit 1;

  if found then
    if v_closed.custom_opens_at is null then
      return query select false, coalesce(v_closed.reason,'closed_exception')::text, null::time, null::time;
      return;
    end if;
    return query select
      (v_time between v_closed.custom_opens_at and v_closed.custom_closes_at),
      coalesce(v_closed.reason, 'custom_hours')::text,
      v_closed.custom_opens_at,
      v_closed.custom_closes_at;
    return;
  end if;

  -- 2. Horario estándar del día de semana
  select * into v_hours
  from public.business_hours
  where branch_id = v_branch
    and weekday = extract(dow from v_local)::smallint
  limit 1;

  if not found or v_hours.is_closed then
    return query select false, 'weekly_closed'::text, null::time, null::time;
    return;
  end if;

  return query select
    (v_time between v_hours.opens_at and v_hours.closes_at),
    'weekly_hours'::text,
    v_hours.opens_at,
    v_hours.closes_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. RLS
-- ---------------------------------------------------------------------------
alter table public.business_hours enable row level security;
alter table public.business_closed_days enable row level security;

-- business_hours: lectura PÚBLICA (la web puede mostrar "horario de atención"),
-- escritura solo admin.
drop policy if exists business_hours_public_read on public.business_hours;
create policy business_hours_public_read
  on public.business_hours for select to anon, authenticated using (true);

drop policy if exists business_hours_admin_write on public.business_hours;
create policy business_hours_admin_write
  on public.business_hours for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- business_closed_days: lectura pública también (calendario web), escritura admin.
drop policy if exists business_closed_days_public_read on public.business_closed_days;
create policy business_closed_days_public_read
  on public.business_closed_days for select to anon, authenticated using (true);

drop policy if exists business_closed_days_admin_write on public.business_closed_days;
create policy business_closed_days_admin_write
  on public.business_closed_days for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');
