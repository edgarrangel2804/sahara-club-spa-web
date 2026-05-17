-- ============================================================
-- Sahara Club Spa - Finanzas Dashboard Payload
-- Entrega el dashboard principal ya agregado desde la base.
-- ============================================================

create or replace function public.finance_dashboard_payload(
  p_branch_id uuid default null
)
returns jsonb
language sql
stable
as $$
with paid_sales as (
  select
    s.id,
    s.appointment_id,
    s.professional_id,
    s.created_at,
    coalesce(
      nullif(s.total, 0),
      nullif(coalesce(s.subtotal, 0) - coalesce(s.discount, 0) + coalesce(s.tax, 0), 0),
      (
        select sum(
          coalesce(
            nullif(si.total_price, 0),
            coalesce(nullif(si.unit_price, 0), coalesce(si.price, 0)) *
              coalesce(nullif(si.quantity, 0), 1)
          )
        )
        from public.sale_items si
        where si.sale_id = s.id
      ),
      0
    )::numeric(12, 2) as total
  from public.sales s
  where (p_branch_id is null or s.branch_id = p_branch_id)
    and (
      lower(trim(coalesce(s.payment_status, ''))) in ('paid', 'pagado', 'completed', 'completado', 'complete', 'settled')
      or lower(trim(coalesce(s.status, ''))) in ('paid', 'pagado', 'completed', 'completado', 'complete', 'settled')
      or lower(trim(coalesce(s.sale_status, ''))) in ('paid', 'pagado', 'completed', 'completado', 'complete', 'settled')
    )
),
paid_bookings_without_sale as (
  select
    b.id,
    b.booking_date,
    b.therapist_id,
    coalesce(srv.price, 0)::numeric(12, 2) as total
  from public.bookings b
  left join public.services srv on srv.id = b.service_id
  where (p_branch_id is null or coalesce(b.sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid) = p_branch_id)
    and lower(trim(coalesce(b.status::text, ''))) in ('paid', 'pagado', 'completed', 'completado', 'complete', 'settled')
    and not exists (
      select 1
      from paid_sales ps
      where ps.appointment_id = b.id
    )
),
income_ops as (
  select ps.created_at::date as day, ps.total
  from paid_sales ps
  union all
  select pb.booking_date::date as day, pb.total
  from paid_bookings_without_sale pb
),
expense_ops as (
  select coalesce(fe.created_at::date, current_date) as day, fe.amount::numeric(12, 2) as amount
  from public.fixed_expenses fe
  where p_branch_id is null or fe.branch_id = p_branch_id
  union all
  select coalesce(se.expense_date, se.created_at::date, current_date) as day, se.amount::numeric(12, 2) as amount
  from public.supplier_expenses se
  where p_branch_id is null or se.branch_id = p_branch_id
  union all
  select coalesce(pe.paid_at::date, pe.period_end, pe.period_start, pe.created_at::date, current_date) as day,
         pe.total_pay::numeric(12, 2) as amount
  from public.payroll_entries pe
  where p_branch_id is null or pe.branch_id = p_branch_id
),
summary as (
  select
    coalesce((select sum(total) from income_ops), 0)::numeric(12, 2) as ingresos_totales,
    coalesce((select count(*) from income_ops), 0)::int as operaciones_cobradas,
    coalesce((select sum(amount) from expense_ops), 0)::numeric(12, 2) as egresos_totales,
    coalesce((select count(*) from expense_ops), 0)::int as egresos_count,
    coalesce((
      select sum(pe.total_pay)
      from public.payroll_entries pe
      where (p_branch_id is null or pe.branch_id = p_branch_id)
        and lower(trim(coalesce(pe.payment_status, ''))) <> 'pagado'
    ), 0)::numeric(12, 2) as pending_payroll_amount,
    coalesce((
      select count(*)
      from public.payroll_entries pe
      where (p_branch_id is null or pe.branch_id = p_branch_id)
        and lower(trim(coalesce(pe.payment_status, ''))) <> 'pagado'
    ), 0)::int as pending_payroll_count,
    coalesce((
      select sum(se.amount)
      from public.supplier_expenses se
      where (p_branch_id is null or se.branch_id = p_branch_id)
        and lower(trim(coalesce(se.status, ''))) <> 'pagado'
    ), 0)::numeric(12, 2) as pending_supplier_amount,
    coalesce((
      select count(*)
      from public.supplier_expenses se
      where (p_branch_id is null or se.branch_id = p_branch_id)
        and lower(trim(coalesce(se.status, ''))) <> 'pagado'
    ), 0)::int as pending_supplier_count,
    coalesce((
      select count(*)
      from public.bookings b
      where (p_branch_id is null or coalesce(b.sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid) = p_branch_id)
        and lower(trim(coalesce(b.status::text, ''))) = 'awaiting_payment'
    ), 0)::int as citas_pendientes_cobro,
    coalesce((
      select count(*)
      from public.bookings b
      where (p_branch_id is null or coalesce(b.sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid) = p_branch_id)
        and lower(trim(coalesce(b.status::text, ''))) in ('completed', 'paid')
    ), 0)::int as servicios_realizados,
    coalesce((
      select count(*)
      from public.bookings b
      where (p_branch_id is null or coalesce(b.sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid) = p_branch_id)
        and lower(trim(coalesce(b.status::text, ''))) = 'completed'
    ), 0)::int as citas_completadas
),
summary_calc as (
  select
    s.*,
    (s.ingresos_totales - s.egresos_totales)::numeric(12, 2) as ganancia_neta,
    case
      when s.ingresos_totales = 0 then 0
      else round(((s.ingresos_totales - s.egresos_totales) / s.ingresos_totales) * 100, 2)
    end::numeric(12, 2) as margen_ganancia,
    case
      when s.operaciones_cobradas = 0 then 0
      else round(s.ingresos_totales / s.operaciones_cobradas, 2)
    end::numeric(12, 2) as ticket_promedio
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
    coalesce((select sum(i.total) from income_ops i where i.day = d.day), 0)::numeric(12, 2) as ingresos,
    coalesce((select sum(e.amount) from expense_ops e where e.day = d.day), 0)::numeric(12, 2) as egresos
  from days d
  order by d.day
),
expense_breakdown as (
  select label, value
  from (
    select 'Gastos Fijos'::text as label, coalesce(sum(fe.amount), 0)::numeric(12, 2) as value
    from public.fixed_expenses fe
    where p_branch_id is null or fe.branch_id = p_branch_id
    union all
    select 'Nomina'::text as label, coalesce(sum(pe.total_pay), 0)::numeric(12, 2) as value
    from public.payroll_entries pe
    where p_branch_id is null or pe.branch_id = p_branch_id
    union all
    select 'Proveedores'::text as label, coalesce(sum(se.amount), 0)::numeric(12, 2) as value
    from public.supplier_expenses se
    where p_branch_id is null or se.branch_id = p_branch_id
  ) breakdown
  where value > 0
),
top_services as (
  select
    coalesce(nullif(trim(coalesce(si.description, si.name)), ''), 'Sin concepto') as label,
    sum(
      coalesce(
        nullif(si.total_price, 0),
        coalesce(nullif(si.unit_price, 0), coalesce(si.price, 0)) *
          coalesce(nullif(si.quantity, 0), 1)
      )
    )::numeric(12, 2) as value
  from paid_sales ps
  join public.sale_items si on si.sale_id = ps.id
  group by 1
  order by value desc, label asc
  limit 5
),
therapist_performance as (
  select
    coalesce(st.id::text, coalesce(b.therapist_id::text, 'sin_terapeuta')) as id,
    coalesce(nullif(st.full_name, ''), 'Sin terapeuta') as name,
    count(*) filter (
      where lower(trim(coalesce(b.status::text, ''))) in ('completed', 'paid')
    )::int as services_completed,
    count(*) filter (
      where lower(trim(coalesce(b.status::text, ''))) = 'cancelled'
    )::int as cancelled,
    count(*) filter (
      where lower(trim(coalesce(b.status::text, ''))) = 'no_show'
    )::int as no_shows,
    coalesce(sum(coalesce(ps.total, pb.total, 0)), 0)::numeric(12, 2) as revenue
  from public.bookings b
  left join public.staff st on st.id = b.therapist_id
  left join paid_sales ps on ps.appointment_id = b.id
  left join paid_bookings_without_sale pb on pb.id = b.id
  where p_branch_id is null or coalesce(b.sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid) = p_branch_id
  group by 1, 2
  order by revenue desc, name asc
  limit 5
),
cash_flow as (
  select 'Saldo estimado'::text as label,
         sc.ganancia_neta::numeric(12, 2) as value
  from summary_calc sc
  union all
  select 'Ingresos del mes'::text as label,
         coalesce((
           select sum(i.total)
           from income_ops i
           where i.day >= date_trunc('month', current_date)::date
         ), 0)::numeric(12, 2) as value
  union all
  select 'Egresos del mes'::text as label,
         coalesce((
           select sum(e.amount)
           from expense_ops e
           where e.day >= date_trunc('month', current_date)::date
         ), 0)::numeric(12, 2) as value
),
alerts as (
  select *
  from (
    select
      'receivables'::text as kind,
      'Cobros pendientes'::text as title,
      'Hay ' || sc.citas_pendientes_cobro || ' citas esperando cobro estimado de ' ||
        to_char(round(sc.ticket_promedio * sc.citas_pendientes_cobro, 2), 'FM$999,999,990.00') || '.' as message,
      'Hoy'::text as stamp,
      1 as ord
    from summary_calc sc
    where sc.citas_pendientes_cobro > 0

    union all

    select
      'payroll_pending'::text as kind,
      'Nomina pendiente'::text as title,
      'Quedan ' || to_char(sc.pending_payroll_amount, 'FM$999,999,990.00') ||
        ' pendientes por pagar al equipo.' as message,
      'Hoy'::text as stamp,
      2 as ord
    from summary_calc sc
    where sc.pending_payroll_amount > 0

    union all

    select
      'suppliers_pending'::text as kind,
      'Proveedores pendientes'::text as title,
      'Se acumulan ' || to_char(sc.pending_supplier_amount, 'FM$999,999,990.00') ||
        ' en facturas de proveedores.' as message,
      'Hoy'::text as stamp,
      3 as ord
    from summary_calc sc
    where sc.pending_supplier_amount > 0

    union all

    select
      'low_margin'::text as kind,
      'Margen presionado'::text as title,
      'El margen actual es ' || round(sc.margen_ganancia, 2) || '% y requiere revision.' as message,
      'Analitica'::text as stamp,
      4 as ord
    from summary_calc sc
    where sc.margen_ganancia < 20 and sc.ingresos_totales > 0

    union all

    select
      'no_sales_today'::text as kind,
      'Sin ventas hoy'::text as title,
      'No hay ingresos cobrados registrados durante la jornada de hoy.' as message,
      'Hoy'::text as stamp,
      5 as ord
    from summary_calc sc
    where coalesce((
      select sum(i.total)
      from income_ops i
      where i.day = current_date
    ), 0) = 0

    union all

    select
      'stable'::text as kind,
      'Sin alertas criticas'::text as title,
      'La operacion financiera se ve estable con los datos actuales.' as message,
      'Actual'::text as stamp,
      99 as ord
    from summary_calc sc
    where not exists (
      select 1
      from summary_calc s2
      where s2.citas_pendientes_cobro > 0
         or s2.pending_payroll_amount > 0
         or s2.pending_supplier_amount > 0
         or (s2.margen_ganancia < 20 and s2.ingresos_totales > 0)
         or coalesce((
              select sum(i.total)
              from income_ops i
              where i.day = current_date
            ), 0) = 0
    )
  ) alert_rows
  order by ord
)
select jsonb_build_object(
  'summary',
  (
    select jsonb_build_object(
      'ingresos_totales', sc.ingresos_totales,
      'operaciones_cobradas', sc.operaciones_cobradas,
      'egresos_totales', sc.egresos_totales,
      'egresos_count', sc.egresos_count,
      'ganancia_neta', sc.ganancia_neta,
      'margen_ganancia', sc.margen_ganancia,
      'pending_payroll_amount', sc.pending_payroll_amount,
      'pending_payroll_count', sc.pending_payroll_count,
      'pending_supplier_amount', sc.pending_supplier_amount,
      'pending_supplier_count', sc.pending_supplier_count,
      'citas_pendientes_cobro', sc.citas_pendientes_cobro,
      'cuentas_por_cobrar_estimadas', round(sc.ticket_promedio * sc.citas_pendientes_cobro, 2),
      'ticket_promedio', sc.ticket_promedio,
      'servicios_realizados', sc.servicios_realizados,
      'citas_completadas', sc.citas_completadas
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
  'top_services',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', ts.label,
        'value', ts.value
      )
      order by ts.value desc, ts.label asc
    )
    from top_services ts
  ), '[]'::jsonb),
  'top_therapists',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', tp.id,
        'name', tp.name,
        'revenue', tp.revenue,
        'services_completed', tp.services_completed,
        'cancelled', tp.cancelled,
        'no_shows', tp.no_shows
      )
      order by tp.revenue desc, tp.name asc
    )
    from therapist_performance tp
  ), '[]'::jsonb),
  'cash_flow',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', cf.label,
        'value', cf.value
      )
      order by
        case cf.label
          when 'Saldo estimado' then 1
          when 'Ingresos del mes' then 2
          else 3
        end
    )
    from cash_flow cf
  ), '[]'::jsonb),
  'alerts',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'kind', a.kind,
        'title', a.title,
        'message', a.message,
        'stamp', a.stamp
      )
      order by a.ord
    )
    from alerts a
  ), '[]'::jsonb)
);
$$;

grant execute on function public.finance_dashboard_payload(uuid) to authenticated;
