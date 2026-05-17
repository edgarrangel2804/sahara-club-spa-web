-- ============================================================
-- Sahara Club Spa - Finanzas Proveedores Payload
-- Entrega la pantalla de proveedores ya agregada desde la base.
-- ============================================================

create or replace function public.finance_supplier_payload(
  p_branch_id uuid default null
)
returns jsonb
language sql
stable
as $$
with base_rows as (
  select
    se.id,
    coalesce(nullif(trim(coalesce(se.supplier_name, '')), ''), 'Proveedor') as supplier_name,
    coalesce(nullif(trim(coalesce(se.category, '')), ''), 'Sin categoria') as category,
    coalesce(nullif(trim(coalesce(se.description, '')), ''), 'Sin referencia') as description,
    coalesce(nullif(trim(coalesce(se.invoice_number, '')), ''), '') as invoice_number,
    coalesce(nullif(trim(coalesce(se.payment_method, '')), ''), 'sin definir') as payment_method,
    coalesce(se.status, 'pendiente') as status,
    se.amount::numeric(12, 2) as amount,
    coalesce(se.expense_date::timestamptz, se.created_at, now()) as movement_at
  from public.supplier_expenses se
  where p_branch_id is null or se.branch_id = p_branch_id
),
supplier_latest as (
  select supplier_name, max(movement_at) as last_movement_at
  from base_rows
  group by 1
),
supplier_first as (
  select supplier_name, min(movement_at) as first_movement_at
  from base_rows
  group by 1
),
supplier_totals as (
  select supplier_name, sum(amount)::numeric(12, 2) as total
  from base_rows
  group by 1
),
summary as (
  select
    coalesce((select count(*) from supplier_latest), 0)::int as total_suppliers,
    coalesce((
      select count(*)
      from supplier_first
      where first_movement_at >= date_trunc('month', current_date)
    ), 0)::int as new_this_month_count,
    coalesce((
      select count(*)
      from supplier_latest
      where last_movement_at >= now() - interval '60 days'
    ), 0)::int as active_suppliers_count,
    coalesce((
      select count(distinct supplier_name)
      from base_rows
      where lower(status) = 'pendiente'
    ), 0)::int as pending_supplier_entity_count,
    coalesce((
      select count(distinct supplier_name)
      from base_rows
      where lower(status) = 'vencido'
    ), 0)::int as overdue_supplier_entity_count,
    coalesce((
      select sum(amount)
      from base_rows
      where lower(status) = 'pendiente'
    ), 0)::numeric(12, 2) as pending_amount,
    coalesce((
      select count(*)
      from base_rows
      where lower(status) = 'pendiente'
    ), 0)::int as pending_entries,
    coalesce((
      select sum(amount)
      from base_rows
      where lower(status) = 'vencido'
    ), 0)::numeric(12, 2) as overdue_amount,
    coalesce((
      select count(*)
      from base_rows
      where lower(status) = 'vencido'
    ), 0)::int as overdue_entries,
    coalesce((
      select sum(amount)
      from base_rows
      where lower(status) = 'pagado'
        and movement_at >= date_trunc('month', current_date)
    ), 0)::numeric(12, 2) as paid_this_month,
    coalesce((
      select sum(amount)
      from base_rows
      where lower(status) = 'pagado'
        and movement_at >= date_trunc('month', current_date) - interval '1 month'
        and movement_at < date_trunc('month', current_date)
    ), 0)::numeric(12, 2) as paid_previous_month,
    coalesce((
      select count(*)
      from base_rows
      where lower(status) <> 'pagado'
    ), 0)::int as pending_invoices_count
),
top_supplier as (
  select supplier_name, total
  from supplier_totals
  order by total desc, supplier_name asc
  limit 1
),
monthly_series as (
  select
    to_char(month_start, 'Mon') as label,
    coalesce((
      select sum(br.amount)
      from base_rows br
      where br.movement_at >= month_start
        and br.movement_at < (month_start + interval '1 month')
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
  from base_rows
  group by 1
  order by value desc, label asc
),
rows_payload as (
  select
    id,
    supplier_name,
    category,
    description,
    invoice_number,
    payment_method,
    amount,
    status,
    movement_at
  from base_rows
  order by movement_at desc, amount desc, supplier_name asc
)
select jsonb_build_object(
  'summary',
  (
    select jsonb_build_object(
      'total_suppliers', s.total_suppliers,
      'new_this_month_count', s.new_this_month_count,
      'active_suppliers_count', s.active_suppliers_count,
      'inactive_suppliers_count', greatest(s.total_suppliers - s.active_suppliers_count, 0),
      'pending_supplier_entity_count', s.pending_supplier_entity_count,
      'overdue_supplier_entity_count', s.overdue_supplier_entity_count,
      'pending_amount', s.pending_amount,
      'pending_entries', s.pending_entries,
      'overdue_amount', s.overdue_amount,
      'overdue_entries', s.overdue_entries,
      'paid_this_month', s.paid_this_month,
      'paid_previous_month', s.paid_previous_month,
      'pending_invoices_count', s.pending_invoices_count,
      'top_supplier_name', coalesce((select ts.supplier_name from top_supplier ts), 'Sin datos'),
      'top_supplier_total', coalesce((select ts.total from top_supplier ts), 0)
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
  'rows',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', rp.id,
        'supplier_name', rp.supplier_name,
        'category', rp.category,
        'description', rp.description,
        'invoice_number', rp.invoice_number,
        'payment_method', rp.payment_method,
        'amount', rp.amount,
        'status', rp.status,
        'movement_at', rp.movement_at
      )
      order by rp.movement_at desc, rp.amount desc, rp.supplier_name asc
    )
    from rows_payload rp
  ), '[]'::jsonb),
  'summary_rows',
  (
    select jsonb_build_array(
      jsonb_build_object('label', 'Total proveedores', 'value', s.total_suppliers::text),
      jsonb_build_object('label', 'Activos', 'value', s.active_suppliers_count::text),
      jsonb_build_object('label', 'Pagos pendientes', 'value', to_char(s.pending_amount, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Pagos vencidos', 'value', to_char(s.overdue_amount, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Pagado este mes', 'value', to_char(s.paid_this_month, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Proveedor mayor', 'value', coalesce((select ts.supplier_name from top_supplier ts), 'Sin datos')),
      jsonb_build_object('label', 'Facturas por revisar', 'value', s.pending_invoices_count::text)
    )
    from summary s
  )
);
$$;

grant execute on function public.finance_supplier_payload(uuid) to authenticated;
