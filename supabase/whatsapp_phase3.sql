-- Sahara Club Spa - WhatsApp FASE 3
-- Automatización (pg_cron), concurrencia (SKIP LOCKED), dead-letter,
-- métricas, RLS endurecido, observabilidad y cleanup.

-- ---------------------------------------------------------------------------
-- 1. Extender whatsapp_queue con columnas de orquestación
-- ---------------------------------------------------------------------------
alter table public.whatsapp_queue
  add column if not exists correlation_id uuid not null default gen_random_uuid(),
  add column if not exists priority smallint not null default 100,
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by text,
  add column if not exists worker_run_id uuid,
  add column if not exists last_error_code integer,
  add column if not exists last_error_type text,            -- 'transient' | 'permanent' | null
  add column if not exists dead_letter_reason text,
  add column if not exists dead_letter_at timestamptz,
  add column if not exists last_attempt_at timestamptz;

-- Relax CHECK para soportar nuevos estados manteniendo retro-compat.
alter table public.whatsapp_queue drop constraint if exists whatsapp_queue_status_check;
alter table public.whatsapp_queue
  add constraint whatsapp_queue_status_check
  check (status in (
    'queued','pending','processing','processed','sent','delivered','read',
    'failed','retrying','skipped','cancelled','dead_letter'
  ));

-- ---------------------------------------------------------------------------
-- 2. Índices faltantes
-- ---------------------------------------------------------------------------
create index if not exists idx_whatsapp_queue_status_priority_schedule
  on public.whatsapp_queue (status, priority, scheduled_at)
  where status in ('queued','pending','retrying');

create index if not exists idx_whatsapp_queue_locked
  on public.whatsapp_queue (locked_at) where locked_at is not null;

create index if not exists idx_whatsapp_queue_correlation
  on public.whatsapp_queue (correlation_id);

create index if not exists idx_whatsapp_queue_dead_letter
  on public.whatsapp_queue (dead_letter_at desc) where status='dead_letter';

create index if not exists idx_whatsapp_logs_phone
  on public.whatsapp_logs (phone) where phone is not null and phone <> '';

create index if not exists idx_whatsapp_logs_wamid
  on public.whatsapp_logs ((provider_response->'messages'->0->>'id'))
  where provider_response is not null;

create index if not exists idx_whatsapp_logs_created_status
  on public.whatsapp_logs (created_at desc, status);

create index if not exists idx_whatsapp_logs_booking
  on public.whatsapp_logs (booking_id) where booking_id is not null;

-- ---------------------------------------------------------------------------
-- 3. Tabla whatsapp_worker_runs (observabilidad)
-- ---------------------------------------------------------------------------
create table if not exists public.whatsapp_worker_runs (
  id uuid primary key default gen_random_uuid(),
  worker_id text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  jobs_claimed integer not null default 0,
  jobs_sent integer not null default 0,
  jobs_failed integer not null default 0,
  jobs_dead_letter integer not null default 0,
  meta_rate_limit_hit boolean not null default false,
  error_message text,
  duration_ms integer
);

create index if not exists idx_whatsapp_worker_runs_started
  on public.whatsapp_worker_runs (started_at desc);

-- ---------------------------------------------------------------------------
-- 4. claim_whatsapp_jobs() — SKIP LOCKED, atómico, concurrencia-safe
-- ---------------------------------------------------------------------------
create or replace function public.claim_whatsapp_jobs(
  p_limit integer default 25,
  p_worker_id text default 'worker-default',
  p_lock_ttl interval default interval '5 minutes'
)
returns setof public.whatsapp_queue
language plpgsql
security definer
as $$
begin
  -- Reset locks expirados (worker crasheado)
  update public.whatsapp_queue
  set locked_at = null, locked_by = null
  where locked_at is not null
    and locked_at < now() - p_lock_ttl
    and status = 'processing';

  return query
  with cte as (
    select id
    from public.whatsapp_queue
    where status in ('queued','pending','retrying')
      and scheduled_at <= now()
      and locked_at is null
    order by priority asc, scheduled_at asc
    limit p_limit
    for update skip locked
  )
  update public.whatsapp_queue q
  set status = 'processing',
      locked_at = now(),
      locked_by = p_worker_id,
      last_attempt_at = now()
  from cte
  where q.id = cte.id
  returning q.*;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. enqueue_due_whatsapp_reminders v2 — sin loops, JOIN + filter por rango
-- ---------------------------------------------------------------------------
create or replace function public.enqueue_due_whatsapp_reminders(
  p_now timestamptz default now()
)
returns integer
language plpgsql
security definer
as $$
declare
  total_inserted integer := 0;
  batch_inserted integer;
  windows record;
begin
  -- Definimos las ventanas en una sola query con UNION ALL: (event_type, offset, slack)
  for windows in
    select * from (values
      ('reminder_24h'::text, interval '24 hours', interval '30 minutes'),
      ('reminder_3h',        interval '3 hours',  interval '30 minutes'),
      ('reminder_1h',        interval '1 hour',   interval '20 minutes')
    ) as w(event_type, offset_, slack)
  loop
    with candidates as (
      select b.id as booking_id, b.client_record_id, coalesce(b.sucursal_id, public.get_default_branch_id()) as branch_id
      from public.bookings b
      where b.status = 'confirmed'
        and ((b.booking_date::text || ' ' || b.booking_time::text)::timestamp
              between (p_now + windows.offset_ - windows.slack)
                  and (p_now + windows.offset_))
    ),
    filtered as (
      select c.*
      from candidates c
      where not exists (
        select 1 from public.whatsapp_logs l
        where l.reservation_id = c.booking_id
          and l.event_type = windows.event_type
      )
      and not exists (
        select 1 from public.whatsapp_queue q
        where q.reservation_id = c.booking_id
          and q.event_type = windows.event_type
          and q.status not in ('failed','dead_letter','cancelled')
      )
    )
    insert into public.whatsapp_queue (
      branch_id, event_type, reservation_id, customer_id, payload, status, scheduled_at
    )
    select branch_id, windows.event_type, booking_id, client_record_id,
           '{}'::jsonb, 'queued', p_now
    from filtered;

    get diagnostics batch_inserted = ROW_COUNT;
    total_inserted := total_inserted + coalesce(batch_inserted, 0);
  end loop;

  return total_inserted;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Acción admin: mover a dead_letter / cancelar / reintentar
-- ---------------------------------------------------------------------------
create or replace function public.whatsapp_mark_dead_letter(p_id uuid, p_reason text)
returns void language sql security definer as $$
  update public.whatsapp_queue
  set status='dead_letter', dead_letter_reason=p_reason, dead_letter_at=now(),
      locked_at=null, locked_by=null
  where id = p_id;
$$;

create or replace function public.whatsapp_cancel_job(p_id uuid)
returns void language sql security definer as $$
  update public.whatsapp_queue
  set status='cancelled', locked_at=null, locked_by=null
  where id = p_id and status in ('queued','pending','retrying','dead_letter');
$$;

create or replace function public.whatsapp_requeue_job(p_id uuid)
returns void language sql security definer as $$
  update public.whatsapp_queue
  set status='queued', retry_count=0, scheduled_at=now(),
      locked_at=null, locked_by=null, error_message=null,
      last_error_code=null, last_error_type=null,
      dead_letter_reason=null, dead_letter_at=null
  where id = p_id;
$$;

-- ---------------------------------------------------------------------------
-- 7. Vista de métricas (24h y 7d) + dashboard queue
-- ---------------------------------------------------------------------------
create or replace view public.whatsapp_metrics_24h as
with logs as (
  select * from public.whatsapp_logs where created_at >= now() - interval '24 hours'
)
select
  count(*) filter (where status = 'sent') as sent_count,
  count(*) filter (where status in ('delivered','read')) as delivered_count,
  count(*) filter (where status = 'read') as read_count,
  count(*) filter (where status = 'failed') as failed_count,
  count(*) filter (where status = 'retrying') as retry_count,
  case when count(*) filter (where status='sent') > 0
       then round(100.0 * count(*) filter (where status in ('delivered','read'))
                       / nullif(count(*) filter (where status='sent'),0), 2)
  end as delivery_rate_pct,
  case when count(*) filter (where status='sent') > 0
       then round(100.0 * count(*) filter (where status='read')
                       / nullif(count(*) filter (where status='sent'),0), 2)
  end as read_rate_pct,
  case when count(*) > 0
       then round(100.0 * count(*) filter (where status='sent') / count(*), 2)
  end as success_rate_pct,
  avg(extract(epoch from (delivered_at - sent_at))) filter (where delivered_at is not null and sent_at is not null) as avg_delivery_seconds,
  (select count(*) from public.whatsapp_queue where status in ('queued','pending','retrying')) as queue_size,
  (select count(*) from public.whatsapp_queue where status='dead_letter') as dead_letter_size,
  (select count(*) from public.whatsapp_queue
     where status='processing' and locked_at < now() - interval '5 minutes') as stuck_jobs,
  (select max(started_at) from public.whatsapp_worker_runs) as last_worker_run_at
from logs;

create or replace view public.whatsapp_queue_dashboard as
select
  q.id, q.status, q.priority, q.event_type, q.scheduled_at, q.last_attempt_at,
  q.retry_count, q.max_retries, q.error_message, q.last_error_code, q.last_error_type,
  q.dead_letter_reason, q.dead_letter_at, q.correlation_id, q.locked_by, q.locked_at,
  q.created_at, q.updated_at,
  t.meta_template_name, t.meta_template_status, t.template_key,
  c.full_name as customer_name, c.phone as customer_phone,
  b.booking_date, b.booking_time, b.id as booking_id
from public.whatsapp_queue q
left join public.whatsapp_templates t on t.id = q.template_id
left join public.clients c on c.id = q.customer_id
left join public.bookings b on b.id = q.reservation_id;

-- ---------------------------------------------------------------------------
-- 8. Cleanup automático (retención configurable)
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_whatsapp_data(
  p_logs_days integer default 90,
  p_events_days integer default 60,
  p_terminal_queue_days integer default 30
)
returns table(logs_deleted bigint, events_deleted bigint, queue_deleted bigint)
language plpgsql security definer as $$
declare
  v_logs bigint; v_events bigint; v_queue bigint;
begin
  delete from public.whatsapp_logs
   where created_at < now() - make_interval(days => p_logs_days);
  get diagnostics v_logs = ROW_COUNT;

  delete from public.whatsapp_webhook_events
   where received_at < now() - make_interval(days => p_events_days);
  get diagnostics v_events = ROW_COUNT;

  delete from public.whatsapp_queue
   where status in ('processed','sent','delivered','read','failed','cancelled','skipped')
     and updated_at < now() - make_interval(days => p_terminal_queue_days);
  get diagnostics v_queue = ROW_COUNT;

  return query select v_logs, v_events, v_queue;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. RLS endurecido — receptionist NO delete, NO update
-- ---------------------------------------------------------------------------
drop policy if exists whatsapp_queue_manage_staff on public.whatsapp_queue;
drop policy if exists whatsapp_queue_select_staff on public.whatsapp_queue;

create policy whatsapp_queue_select_staff
  on public.whatsapp_queue for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));

create policy whatsapp_queue_admin_full
  on public.whatsapp_queue for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists whatsapp_logs_manage_staff on public.whatsapp_logs;
drop policy if exists whatsapp_logs_select_staff on public.whatsapp_logs;

create policy whatsapp_logs_select_staff
  on public.whatsapp_logs for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));

create policy whatsapp_logs_admin_full
  on public.whatsapp_logs for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

alter table public.whatsapp_worker_runs enable row level security;
drop policy if exists whatsapp_worker_runs_admin on public.whatsapp_worker_runs;
create policy whatsapp_worker_runs_admin
  on public.whatsapp_worker_runs for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));

-- ---------------------------------------------------------------------------
-- 10. pg_cron — automatización
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Helper: invoca una Edge Function vía pg_net con service_role.
-- IMPORTANTE: requiere que existan los secrets app.settings.supabase_url y
-- app.settings.service_role_key. Si no existen, las llamadas no harán daño:
-- pg_net.http_post devolverá un request_id y el job se logueará como ejecutado.
create or replace function public.invoke_edge_function(
  p_function_name text,
  p_body jsonb default '{}'::jsonb
) returns bigint
language plpgsql
security definer
as $$
declare
  v_url text;
  v_key text;
  v_req_id bigint;
begin
  -- Lee desde GUC; si no existen, usa NULL y aborta limpio.
  begin v_url := current_setting('app.settings.supabase_url', true); exception when others then v_url := null; end;
  begin v_key := current_setting('app.settings.service_role_key', true); exception when others then v_key := null; end;

  if v_url is null or v_key is null then
    raise notice 'invoke_edge_function: faltan GUC app.settings.supabase_url/service_role_key';
    return null;
  end if;

  select net.http_post(
    url := v_url || '/functions/v1/' || p_function_name,
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer ' || v_key
    ),
    body := p_body
  ) into v_req_id;

  return v_req_id;
end;
$$;

-- Limpia cron jobs previos (idempotente).
do $$
declare j record;
begin
  for j in select jobid, jobname from cron.job where jobname like 'whatsapp_%'
  loop
    perform cron.unschedule(j.jobid);
  end loop;
end;
$$;

-- Job 1: worker cada 60s
select cron.schedule(
  'whatsapp_worker_tick',
  '* * * * *',
  $$ select public.invoke_edge_function('whatsapp-worker', '{"limit":25}'::jsonb); $$
);

-- Job 2: enqueue de recordatorios cada 5 min
select cron.schedule(
  'whatsapp_enqueue_reminders',
  '*/5 * * * *',
  $$ select public.enqueue_due_whatsapp_reminders(now()); $$
);

-- Job 3: cleanup diario 03:30
select cron.schedule(
  'whatsapp_cleanup',
  '30 3 * * *',
  $$ select public.cleanup_whatsapp_data(90, 60, 30); $$
);
