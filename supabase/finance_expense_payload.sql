-- ============================================================
-- Sahara Club Spa - Finanzas Gastos Payload
-- Entrega la pantalla de gastos ya agregada desde la base.
-- ============================================================

create or replace function public.finance_expense_payload(
  p_branch_id uuid default null
)
returns jsonb
language sql
stable
as $$
with expense_rows as (
  select
    'Gastos Fijos'::text as category,
    coalesce(nullif(trim(coalesce(fe.category, '')), ''), 'Gasto fijo') as raw_category,
    coalesce(nullif(trim(coalesce(fe.name, '')), ''), 'Gasto fijo') as title,
    coalesce(nullif(trim(coalesce(fe.frequency, '')), ''), 'Sin frecuencia') as subtitle,
    coalesce(nullif(trim(coalesce(fe.name, '')), ''), 'Sahara Club Spa') as responsible,
    coalesce(nullif(trim(coalesce(fe.payment_method, '')), ''), 'Sin definir') as payment_method,
    true as has_receipt,
    'gasto_fijo'::text as source,
    coalesce(fe.status, 'pendiente') as status,
    fe.amount::numeric(12, 2) as amount,
    coalesce(fe.created_at, now()) as expense_at
  from public.fixed_expenses fe
  where p_branch_id is null or fe.branch_id = p_branch_id

  union all

  select
    'Proveedores'::text as category,
    coalesce(nullif(trim(coalesce(se.category, '')), ''), 'Proveedor') as raw_category,
    coalesce(
      nullif(trim(coalesce(se.description, '')), ''),
      nullif(trim(coalesce(se.supplier_name, '')), ''),
      'Proveedor'
    ) as title,
    coalesce(nullif(trim(coalesce(se.supplier_name, '')), ''), 'Proveedor') as subtitle,
    coalesce(nullif(trim(coalesce(se.supplier_name, '')), ''), 'Proveedor') as responsible,
    coalesce(nullif(trim(coalesce(se.payment_method, '')), ''), 'Sin definir') as payment_method,
    (coalesce(nullif(trim(coalesce(se.invoice_number, '')), ''), '') <> '') as has_receipt,
    'proveedor'::text as source,
    coalesce(se.status, 'pendiente') as status,
    se.amount::numeric(12, 2) as amount,
    coalesce(se.expense_date::timestamptz, se.created_at, now()) as expense_at
  from public.supplier_expenses se
  where p_branch_id is null or se.branch_id = p_branch_id

  union all

  select
    'Nomina'::text as category,
    'Nomina'::text as raw_category,
    'Pago de nomina'::text as title,
    coalesce(nullif(trim(coalesce(st.full_name, '')), ''), 'Empleado') as subtitle,
    coalesce(nullif(trim(coalesce(st.full_name, '')), ''), 'Empleado') as responsible,
    'Transferencia'::text as payment_method,
    true as has_receipt,
    'nomina'::text as source,
    coalesce(pe.payment_status, 'pendiente') as status,
    pe.total_pay::numeric(12, 2) as amount,
    coalesce(pe.paid_at, pe.period_end::timestamptz, pe.period_start::timestamptz, pe.created_at, now()) as expense_at
  from public.payroll_entries pe
  left join public.staff st on st.id = pe.employee_id
  where p_branch_id is null or pe.branch_id = p_branch_id
),
summary as (
  select
    coalesce(sum(amount), 0)::numeric(12, 2) as gastos_totales,
    count(*)::int as movimientos_count,
    coalesce(sum(amount) filter (
      where lower(raw_category) like '%operativ%'
         or lower(title) like '%operativ%'
         or lower(raw_category) like '%limpieza%'
         or lower(title) like '%limpieza%'
         or lower(raw_category) like '%mantenimiento%'
         or lower(title) like '%mantenimiento%'
         or lower(raw_category) like '%software%'
         or lower(title) like '%software%'
         or lower(raw_category) like '%suscrip%'
         or lower(title) like '%suscrip%'
         or lower(raw_category) like '%publicidad%'
         or lower(title) like '%publicidad%'
         or lower(raw_category) like '%marketing%'
         or lower(title) like '%marketing%'
         or lower(raw_category) like '%telefono%'
         or lower(title) like '%telefono%'
         or lower(raw_category) like '%gas%'
         or lower(title) like '%gas%'
         or lower(raw_category) like '%agua%'
         or lower(title) like '%agua%'
         or lower(raw_category) like '%internet%'
         or lower(title) like '%internet%'
    ), 0)::numeric(12, 2) as gastos_operativos,
    coalesce(sum(amount) filter (where has_receipt), 0)::numeric(12, 2) as gastos_con_comprobante,
    coalesce(sum(amount) filter (where not has_receipt), 0)::numeric(12, 2) as gastos_sin_comprobante,
    count(*) filter (where not has_receipt)::int as gastos_sin_comprobante_count,
    coalesce(sum(amount) filter (
      where lower(raw_category) like '%imprev%'
         or lower(title) like '%imprev%'
         or lower(raw_category) like '%repar%'
         or lower(title) like '%repar%'
         or lower(raw_category) like '%urgente%'
         or lower(title) like '%urgente%'
         or lower(raw_category) like '%mantenimiento%'
         or lower(title) like '%mantenimiento%'
         or lower(raw_category) like '%otro%'
         or lower(title) like '%otro%'
    ), 0)::numeric(12, 2) as gastos_imprevistos,
    coalesce(sum(amount) filter (
      where expense_at::date >= date_trunc('month', current_date)::date
    ), 0)::numeric(12, 2) as gastos_mes,
    coalesce(sum(amount) filter (
      where expense_at::date = current_date
    ), 0)::numeric(12, 2) as gastos_hoy
  from expense_rows
),
summary_calc as (
  select
    s.*,
    round(s.gastos_mes / greatest(extract(day from current_date)::numeric, 1), 2)::numeric(12, 2) as promedio_diario
  from summary s
),
days as (
  select generate_series(
    date_trunc('month', current_date)::date,
    least(current_date, (date_trunc('month', current_date)::date + 9))::date,
    interval '1 day'
  )::date as day
),
trend as (
  select
    to_char(d.day, 'DD Mon') as label,
    coalesce((
      select sum(er.amount)
      from expense_rows er
      where er.expense_at::date = d.day
    ), 0)::numeric(12, 2) as ingresos,
    coalesce((
      select sum(er.amount)
      from expense_rows er
      where er.expense_at::date = ((date_trunc('month', current_date) - interval '1 month')::date + (d.day - date_trunc('month', current_date)::date))
    ), 0)::numeric(12, 2) as egresos
  from days d
  order by d.day
),
expense_breakdown as (
  select category as label, sum(amount)::numeric(12, 2) as value
  from expense_rows
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
  from expense_rows
  group by 1
  order by value desc, label asc
),
recent_expenses as (
  select
    category,
    raw_category,
    title,
    subtitle,
    responsible,
    payment_method,
    has_receipt,
    source,
    status,
    amount,
    expense_at
  from expense_rows
  order by expense_at desc
  limit 12
),
top_category as (
  select label
  from expense_breakdown
  order by value desc, label asc
  limit 1
),
top_supplier as (
  select responsible
  from expense_rows
  where category = 'Proveedores'
  group by 1
  order by sum(amount) desc, responsible asc
  limit 1
)
select jsonb_build_object(
  'summary',
  (
    select jsonb_build_object(
      'gastos_totales', sc.gastos_totales,
      'movimientos_count', sc.movimientos_count,
      'gastos_operativos', sc.gastos_operativos,
      'gastos_con_comprobante', sc.gastos_con_comprobante,
      'gastos_sin_comprobante', sc.gastos_sin_comprobante,
      'gastos_sin_comprobante_count', sc.gastos_sin_comprobante_count,
      'gastos_imprevistos', sc.gastos_imprevistos,
      'promedio_diario', sc.promedio_diario,
      'gastos_hoy', sc.gastos_hoy,
      'gastos_mes', sc.gastos_mes
    )
    from summary_calc sc
  ),
  'trend',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', t.label,
        'ingresos', t.ingresos,
        'egresos', t.egresos
      )
      order by t.label
    )
    from trend t
  ), '[]'::jsonb),
  'expense_breakdown',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', eb.label,
        'value', eb.value
      )
      order by eb.value desc, eb.label asc
    )
    from expense_breakdown eb
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
  'recent_expenses',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'category', re.category,
        'raw_category', re.raw_category,
        'title', re.title,
        'subtitle', re.subtitle,
        'responsible', re.responsible,
        'payment_method', re.payment_method,
        'has_receipt', re.has_receipt,
        'source', re.source,
        'status', re.status,
        'amount', re.amount,
        'date', re.expense_at
      )
      order by re.expense_at desc
    )
    from recent_expenses re
  ), '[]'::jsonb),
  'summary_rows',
  (
    select jsonb_build_array(
      jsonb_build_object('label', 'Gastos del Dia', 'value', to_char(sc.gastos_hoy, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Gastos del Mes', 'value', to_char(sc.gastos_mes, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Categoria mayor', 'value', coalesce((select tc.label from top_category tc), 'Sin datos')),
      jsonb_build_object('label', 'Proveedor principal', 'value', coalesce((select ts.responsible from top_supplier ts), 'Sin datos')),
      jsonb_build_object(
        'label', 'Gastos pendientes',
        'value', to_char(coalesce((select sum(amount) from expense_rows where lower(status) <> 'pagado'), 0), 'FM$999,999,990.00')
      ),
      jsonb_build_object('label', 'Comprobantes faltantes', 'value', sc.gastos_sin_comprobante_count::text)
    )
    from summary_calc sc
  )
);
$$;

grant execute on function public.finance_expense_payload(uuid) to authenticated;
