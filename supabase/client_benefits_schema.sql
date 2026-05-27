-- Sahara Club Spa - Beneficios del cliente (gift cards + membresías)
-- ----------------------------------------------------------------------------
-- Prepara las tablas para gift cards vinculadas a cliente, transacciones,
-- uso de membresías y entitlements por plan. NO toca el flujo de anticipo
-- todavía — solo deja la estructura lista para el módulo de Clientes.

-- 1. gift_cards: agregar vínculo a cliente + fechas de validez
alter table public.gift_cards
  add column if not exists client_id uuid references public.clients(id) on delete set null,
  add column if not exists valid_from timestamptz default now(),
  add column if not exists expires_at timestamptz,
  add column if not exists notes text;

create index if not exists idx_gift_cards_client on public.gift_cards(client_id) where client_id is not null;
create index if not exists idx_gift_cards_status_active
  on public.gift_cards(client_id, status, expires_at)
  where status = 'active';

-- 2. gift_card_transactions: histórico de carga / consumo / ajuste
create table if not exists public.gift_card_transactions (
  id uuid primary key default gen_random_uuid(),
  gift_card_id uuid not null references public.gift_cards(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  type text not null check (type in ('load','redeem','refund','adjust','expire')),
  amount numeric not null,
  balance_before numeric,
  balance_after numeric,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now()
);
create index if not exists idx_gift_card_tx_card on public.gift_card_transactions(gift_card_id, created_at desc);
create index if not exists idx_gift_card_tx_client on public.gift_card_transactions(client_id, created_at desc);

-- 3. membership_entitlements: qué servicios cubre cada plan (opcional, granular)
--    Si vacío para un plan → el plan permite cualquier servicio activo.
create table if not exists public.membership_entitlements (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.membership_plans(id) on delete cascade,
  service_id uuid not null references public.services(id) on delete cascade,
  sessions_allowed_per_period int default 1,
  created_at timestamptz default now(),
  unique(plan_id, service_id)
);
create index if not exists idx_membership_ent_plan on public.membership_entitlements(plan_id);

-- 4. membership_usage: cada vez que se consume una sesión de membresía
create table if not exists public.membership_usage (
  id uuid primary key default gen_random_uuid(),
  client_membership_id uuid not null references public.client_memberships(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  used_at timestamptz default now(),
  created_by uuid references public.profiles(id),
  notes text
);
create index if not exists idx_membership_usage_cm on public.membership_usage(client_membership_id, used_at desc);
create index if not exists idx_membership_usage_client on public.membership_usage(client_id, used_at desc);

-- 5. RLS básico: solo admin/recepción puede insertar/editar/borrar
--    (Lectura abierta a authenticated; políticas duras quedan para una sesión
--    posterior dedicada a hardening RLS.)
alter table public.gift_card_transactions enable row level security;
alter table public.membership_entitlements enable row level security;
alter table public.membership_usage enable row level security;

drop policy if exists gift_card_tx_read on public.gift_card_transactions;
create policy gift_card_tx_read on public.gift_card_transactions
  for select to authenticated using (true);

drop policy if exists membership_ent_read on public.membership_entitlements;
create policy membership_ent_read on public.membership_entitlements
  for select to authenticated using (true);

drop policy if exists membership_usage_read on public.membership_usage;
create policy membership_usage_read on public.membership_usage
  for select to authenticated using (true);

-- 6. Vista o RPC: resumen de beneficios + cálculo de requires_deposit
create or replace function public.get_customer_benefits_summary(p_client_id uuid)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_now timestamptz := now();
  v_gc record;
  v_cm record;
  v_plan record;
  v_sessions_used int := 0;
  v_sessions_remaining int := 0;
  v_customer_type text := 'regular';
  v_has_gc boolean := false;
  v_gc_balance numeric := 0;
  v_gc_expires timestamptz;
  v_has_membership boolean := false;
  v_plan_name text;
  v_membership_start date;
  v_membership_end date;
  v_requires_deposit boolean := true;
  v_waiver_reason text;
begin
  if p_client_id is null then
    return jsonb_build_object('ok', false, 'error', 'client_id required');
  end if;

  -- Gift card: la más reciente activa con saldo > 0 y no vencida
  select gc.id, gc.current_balance, gc.expires_at, gc.status, gc.code
  into v_gc
  from public.gift_cards gc
  where gc.client_id = p_client_id
    and gc.status = 'active'
    and coalesce(gc.current_balance, 0) > 0
    and (gc.expires_at is null or gc.expires_at > v_now)
  order by gc.expires_at nulls last, gc.created_at desc
  limit 1;

  if found then
    v_has_gc := true;
    v_gc_balance := coalesce(v_gc.current_balance, 0);
    v_gc_expires := v_gc.expires_at;
  end if;

  -- Membresía activa: la más reciente con status='active', dentro de fechas
  select cm.id, cm.plan_id, cm.status, cm.start_date, cm.end_date,
         cm.sessions_used, cm.sessions_total
  into v_cm
  from public.client_memberships cm
  where cm.client_id = p_client_id
    and cm.status = 'active'
    and (cm.start_date is null or cm.start_date <= current_date)
    and (cm.end_date is null or cm.end_date >= current_date)
  order by cm.end_date desc nulls last, cm.created_at desc
  limit 1;

  if found then
    v_has_membership := true;
    v_membership_start := v_cm.start_date;
    v_membership_end := v_cm.end_date;
    v_sessions_used := coalesce(v_cm.sessions_used, 0);
    v_sessions_remaining := greatest(coalesce(v_cm.sessions_total, 0) - v_sessions_used, 0);

    select name into v_plan_name from public.membership_plans where id = v_cm.plan_id;
  end if;

  -- Tipo del cliente (prioridad: membresía > gift card > regular)
  if v_has_membership then v_customer_type := 'membership';
  elsif v_has_gc then v_customer_type := 'gift_card';
  else v_customer_type := 'regular';
  end if;

  -- Regla de anticipo (waiver):
  --  - membresía activa con sesiones disponibles → SIN anticipo
  --  - gift card activa con saldo > 0 → SIN anticipo
  --  - resto → REQUIERE anticipo
  if v_has_membership and v_sessions_remaining > 0 then
    v_requires_deposit := false;
    v_waiver_reason := 'active_membership_with_sessions';
  elsif v_has_gc and v_gc_balance > 0 then
    v_requires_deposit := false;
    v_waiver_reason := 'active_gift_card_with_balance';
  else
    v_requires_deposit := true;
    v_waiver_reason := null;
  end if;

  return jsonb_build_object(
    'ok', true,
    'client_id', p_client_id,
    'customer_type', v_customer_type,
    'has_active_gift_card', v_has_gc,
    'gift_card_balance', v_gc_balance,
    'gift_card_expires_at', v_gc_expires,
    'has_active_membership', v_has_membership,
    'membership_plan', v_plan_name,
    'membership_start_date', v_membership_start,
    'membership_end_date', v_membership_end,
    'sessions_used', v_sessions_used,
    'sessions_remaining', v_sessions_remaining,
    'requires_deposit', v_requires_deposit,
    'waiver_reason', v_waiver_reason
  );
end;
$$;

grant execute on function public.get_customer_benefits_summary(uuid) to authenticated;
grant execute on function public.get_customer_benefits_summary(uuid) to service_role;

-- 7. Verificación
select
  (select count(*) from information_schema.columns where table_schema='public' and table_name='gift_cards' and column_name in ('client_id','valid_from','expires_at','notes')) as gift_cards_new_cols,
  (select count(*) from information_schema.tables where table_schema='public' and table_name='gift_card_transactions') as has_gift_card_tx,
  (select count(*) from information_schema.tables where table_schema='public' and table_name='membership_entitlements') as has_membership_ent,
  (select count(*) from information_schema.tables where table_schema='public' and table_name='membership_usage') as has_membership_usage;
