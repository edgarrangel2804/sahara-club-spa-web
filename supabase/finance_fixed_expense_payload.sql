-- ============================================================
-- Sahara Club Spa - Finanzas Gastos Fijos Payload
-- Entrega la pantalla de gastos fijos ya agregada desde la base.
-- ============================================================

create or replace function public.finance_fixed_expense_payload(
  p_branch_id uuid default null
)
returns jsonb
language sql
stable
as $$
with base_rows as (
  select
    fe.id,
    coalesce(nullif(trim(coalesce(fe.name, '')), ''), 'Sahara Club Spa') as provider,
    coalesce(nullif(trim(coalesce(fe.category, '')), ''), 'Gasto fijo') as category,
    coalesce(nullif(trim(coalesce(fe.name, '')), ''), 'Gasto fijo') as title,
    fe.amount::numeric(12, 2) as amount,
    coalesce(nullif(trim(coalesce(fe.frequency, '')), ''), 'mensual') as frequency,
    coalesce(fe.status, 'pendiente') as status,
    coalesce(fe.due_day, 1) as due_day,
    coalesce(fe.created_at, now()) as created_at
  from public.fixed_expenses fe
  where p_branch_id is null or fe.branch_id = p_branch_id
),
rows_with_due as (
  select
    br.*,
    case
      when (
        make_date(
          extract(year from current_date)::int,
          extract(month from current_date)::int,
          least(
            greatest(br.due_day, 1),
            extract(day from (date_trunc('month', current_date) + interval '1 month - 1 day'))::int
          )
        ) < current_date
        and lower(br.status) <> 'vencido'
      )
      then make_date(
        extract(year from (current_date + interval '1 month'))::int,
        extract(month from (current_date + interval '1 month'))::int,
        least(
          greatest(br.due_day, 1),
          extract(day from (date_trunc('month', current_date + interval '1 month') + interval '1 month - 1 day'))::int
        )
      )
      else make_date(
        extract(year from current_date)::int,
        extract(month from current_date)::int,
        least(
          greatest(br.due_day, 1),
          extract(day from (date_trunc('month', current_date) + interval '1 month - 1 day'))::int
        )
      )
    end as due_date
  from base_rows br
),
summary as (
  select
    coalesce(sum(amount), 0)::numeric(12, 2) as total_mensual,
    count(*)::int as total_rows,
    coalesce(sum(amount) filter (where lower(status) = 'pagado'), 0)::numeric(12, 2) as pagado_total,
    coalesce(sum(amount) filter (where lower(status) = 'pendiente'), 0)::numeric(12, 2) as pendiente_total,
    coalesce(sum(amount) filter (where lower(status) = 'vencido'), 0)::numeric(12, 2) as vencido_total,
    count(*) filter (where lower(status) = 'pagado')::int as pagado_count,
    count(*) filter (where lower(status) = 'pendiente')::int as pendiente_count,
    count(*) filter (where lower(status) = 'vencido')::int as vencido_count
  from rows_with_due
),
next_payment as (
  select
    title,
    amount,
    due_date,
    status
  from rows_with_due
  where lower(status) <> 'pagado'
  order by due_date asc, amount desc, title asc
  limit 1
),
monthly_series as (
  select
    to_char(month_start, 'Mon') as label,
    coalesce((
      select sum(r.amount)
      from rows_with_due r
      where r.created_at >= month_start
        and r.created_at < (month_start + interval '1 month')
    ), 0)::numeric(12, 2) as value
  from generate_series(
    date_trunc('month', current_date) - interval '5 months',
    date_trunc('month', current_date),
    interval '1 month'
  ) as month_start
),
category_breakdown as (
  select
    initcap(replace(category, '_', ' ')) as label,
    sum(amount)::numeric(12, 2) as value
  from rows_with_due
  group by 1
  order by value desc, label asc
),
status_breakdown as (
  select
    case
      when lower(status) = 'pagado' then 'Pagado'
      when lower(status) = 'pendiente' then 'Pendiente'
      when lower(status) = 'vencido' then 'Vencido'
      else initcap(replace(status, '_', ' '))
    end as label,
    sum(amount)::numeric(12, 2) as value
  from rows_with_due
  group by 1
  order by value desc, label asc
),
top_expense as (
  select title
  from rows_with_due
  order by amount desc, title asc
  limit 1
),
top_frequency as (
  select initcap(replace(frequency, '_', ' ')) as label
  from rows_with_due
  group by 1
  order by count(*) desc, label asc
  limit 1
),
rows_payload as (
  select
    id,
    provider,
    category,
    title,
    amount,
    frequency,
    status,
    due_day,
    due_date
  from rows_with_due
  order by due_date asc, amount desc, title asc
)
select jsonb_build_object(
  'summary',
  (
    select jsonb_build_object(
      'total_mensual', s.total_mensual,
      'total_rows', s.total_rows,
      'pagado_total', s.pagado_total,
      'pendiente_total', s.pendiente_total,
      'vencido_total', s.vencido_total,
      'pagado_count', s.pagado_count,
      'pendiente_count', s.pendiente_count,
      'vencido_count', s.vencido_count,
      'promedio_mensual', (
        select coalesce(avg(ms.value), 0)::numeric(12, 2)
        from monthly_series ms
      ),
      'monthly_series_count', (
        select count(*)::int
        from monthly_series
      ),
      'next_payment_title', coalesce((select np.title from next_payment np), ''),
      'next_payment_amount', coalesce((select np.amount from next_payment np), 0),
      'next_payment_due_date', (select np.due_date from next_payment np)
    )
    from summary s
  ),
  'monthly_series',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', ms.label,
        'value', ms.value
      )
      order by ms.label
    )
    from monthly_series ms
  ), '[]'::jsonb),
  'category_breakdown',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', cb.label,
        'value', cb.value
      )
      order by cb.value desc, cb.label asc
    )
    from category_breakdown cb
  ), '[]'::jsonb),
  'status_breakdown',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', sb.label,
        'value', sb.value
      )
      order by sb.value desc, sb.label asc
    )
    from status_breakdown sb
  ), '[]'::jsonb),
  'rows',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', rp.id,
        'name', rp.provider,
        'category', rp.category,
        'title', rp.title,
        'amount', rp.amount,
        'frequency', rp.frequency,
        'status', rp.status,
        'due_day', rp.due_day,
        'due_date', rp.due_date
      )
      order by rp.due_date asc, rp.amount desc, rp.title asc
    )
    from rows_payload rp
  ), '[]'::jsonb),
  'summary_rows',
  (
    select jsonb_build_array(
      jsonb_build_object('label', 'Total mensual', 'value', to_char(s.total_mensual, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Pagado', 'value', to_char(s.pagado_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Pendiente', 'value', to_char(s.pendiente_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Vencido', 'value', to_char(s.vencido_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Mayor gasto', 'value', coalesce((select te.title from top_expense te), 'Sin datos')),
      jsonb_build_object(
        'label', 'Proximo pago',
        'value',
        coalesce(
          (
            select np.title || ' - ' || to_char(np.due_date, 'DD Mon')
            from next_payment np
          ),
          'Sin pendientes'
        )
      ),
      jsonb_build_object(
        'label', 'Frecuencia principal',
        'value', coalesce((select tf.label from top_frequency tf), 'Sin datos')
      )
    )
    from summary s
  )
);
$$;

grant execute on function public.finance_fixed_expense_payload(uuid) to authenticated;
