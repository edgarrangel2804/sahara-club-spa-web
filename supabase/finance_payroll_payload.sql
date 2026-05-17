-- ============================================================
-- Sahara Club Spa - Finanzas Nomina Payload
-- Entrega la pantalla de nomina ya agregada desde la base.
-- ============================================================

create or replace function public.finance_payroll_payload(
  p_branch_id uuid default null
)
returns jsonb
language sql
stable
as $$
with base_rows as (
  select
    pe.id,
    pe.employee_id,
    coalesce(nullif(trim(coalesce(st.full_name, '')), ''), 'Empleado') as employee_name,
    coalesce(nullif(trim(coalesce(st.role, '')), ''), 'Empleado') as employee_role,
    pe.base_salary::numeric(12, 2) as base_salary,
    pe.commissions::numeric(12, 2) as commissions,
    pe.bonuses::numeric(12, 2) as bonuses,
    pe.deductions::numeric(12, 2) as deductions,
    pe.total_pay::numeric(12, 2) as total_pay,
    coalesce(pe.payment_status, 'pendiente') as payment_status,
    pe.period_start,
    pe.period_end,
    coalesce(pe.paid_at, pe.period_end::timestamptz, pe.created_at, now()) as movement_at
  from public.payroll_entries pe
  left join public.staff st on st.id = pe.employee_id
  where p_branch_id is null or pe.branch_id = p_branch_id
),
summary as (
  select
    coalesce(sum(total_pay), 0)::numeric(12, 2) as nomina_total,
    coalesce(sum(base_salary), 0)::numeric(12, 2) as sueldos_base,
    coalesce(sum(commissions), 0)::numeric(12, 2) as comisiones_total,
    coalesce(sum(bonuses), 0)::numeric(12, 2) as bonos_total,
    coalesce(sum(deductions), 0)::numeric(12, 2) as deducciones_total,
    coalesce(sum(total_pay) filter (where lower(payment_status) <> 'pagado'), 0)::numeric(12, 2) as pendiente_total,
    count(*) filter (where bonuses > 0)::int as bonos_count,
    count(*) filter (where deductions > 0)::int as deducciones_count,
    count(distinct employee_id)::int as empleados_count,
    coalesce(sum(total_pay) filter (where lower(payment_status) = 'pagado'), 0)::numeric(12, 2) as pagado_total
  from base_rows
),
previous_month as (
  select
    coalesce(sum(br.total_pay), 0)::numeric(12, 2) as total
  from base_rows br
  where br.movement_at >= date_trunc('month', current_date) - interval '1 month'
    and br.movement_at < date_trunc('month', current_date)
),
monthly_series as (
  select
    to_char(month_start, 'Mon') as label,
    coalesce((
      select sum(br.total_pay)
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
distribution as (
  select *
  from (
    select 'Sueldos'::text as label, coalesce(sum(base_salary), 0)::numeric(12, 2) as value from base_rows
    union all
    select 'Comisiones'::text as label, coalesce(sum(commissions), 0)::numeric(12, 2) as value from base_rows
    union all
    select 'Bonos'::text as label, coalesce(sum(bonuses), 0)::numeric(12, 2) as value from base_rows
    union all
    select 'Anticipos'::text as label, coalesce(sum(deductions), 0)::numeric(12, 2) as value from base_rows
  ) dist
  where value > 0
),
status_breakdown as (
  select *
  from (
    select 'Pagado'::text as label, coalesce(sum(total_pay) filter (where lower(payment_status) = 'pagado'), 0)::numeric(12, 2) as value from base_rows
    union all
    select 'Pendiente'::text as label, coalesce(sum(total_pay) filter (where lower(payment_status) <> 'pagado'), 0)::numeric(12, 2) as value from base_rows
    union all
    select 'Anticipos'::text as label, coalesce(sum(deductions), 0)::numeric(12, 2) as value from base_rows
    union all
    select 'Bonos'::text as label, coalesce(sum(bonuses), 0)::numeric(12, 2) as value from base_rows
  ) stat
  where value > 0
),
rows_payload as (
  select
    id,
    employee_id,
    employee_name,
    employee_role,
    base_salary,
    commissions,
    bonuses,
    deductions,
    total_pay,
    payment_status,
    period_start,
    period_end,
    movement_at
  from base_rows
  order by movement_at desc, total_pay desc, employee_name asc
),
next_cutoff as (
  select period_end
  from base_rows
  where lower(payment_status) <> 'pagado'
  order by period_end asc nulls last, movement_at asc
  limit 1
),
top_employee as (
  select employee_name, sum(total_pay)::numeric(12, 2) as total
  from base_rows
  group by 1
  order by total desc, employee_name asc
  limit 1
)
select jsonb_build_object(
  'summary',
  (
    select jsonb_build_object(
      'nomina_total', s.nomina_total,
      'sueldos_base', s.sueldos_base,
      'comisiones_total', s.comisiones_total,
      'bonos_total', s.bonos_total,
      'deducciones_total', s.deducciones_total,
      'pendiente_total', s.pendiente_total,
      'bonos_count', s.bonos_count,
      'deducciones_count', s.deducciones_count,
      'empleados_count', s.empleados_count,
      'pagado_total', s.pagado_total,
      'previous_month_total', coalesce((select pm.total from previous_month pm), 0),
      'next_cutoff', (select nc.period_end from next_cutoff nc)
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
  'distribution',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', d.label,
        'value', d.value
      )
      order by d.value desc, d.label asc
    )
    from distribution d
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
        'employee_id', rp.employee_id,
        'employee_name', rp.employee_name,
        'employee_role', rp.employee_role,
        'base_salary', rp.base_salary,
        'commissions', rp.commissions,
        'bonuses', rp.bonuses,
        'deductions', rp.deductions,
        'total_pay', rp.total_pay,
        'payment_status', rp.payment_status,
        'period_start', rp.period_start,
        'period_end', rp.period_end,
        'movement_at', rp.movement_at
      )
      order by rp.movement_at desc, rp.total_pay desc, rp.employee_name asc
    )
    from rows_payload rp
  ), '[]'::jsonb),
  'summary_rows',
  (
    select jsonb_build_array(
      jsonb_build_object('label', 'Total nomina', 'value', to_char(s.nomina_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Empleados', 'value', s.empleados_count::text),
      jsonb_build_object('label', 'Pagado', 'value', to_char(s.pagado_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Pendiente', 'value', to_char(s.pendiente_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Comisiones', 'value', to_char(s.comisiones_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Bonos', 'value', to_char(s.bonos_total, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Anticipos', 'value', to_char(s.deducciones_total, 'FM$999,999,990.00')),
      jsonb_build_object(
        'label', 'Proximo corte',
        'value',
        coalesce(
          (select to_char(nc.period_end, 'DD Mon') from next_cutoff nc),
          'Sin corte'
        )
      )
    )
    from summary s
  ),
  'top_employee',
  coalesce((
    select jsonb_build_object(
      'name', te.employee_name,
      'total', te.total
    )
    from top_employee te
  ), '{}'::jsonb)
);
$$;

grant execute on function public.finance_payroll_payload(uuid) to authenticated;
