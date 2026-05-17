-- ============================================================
-- Sahara Club Spa - Finanzas Rendimiento Payload
-- Entrega la pantalla de rendimiento ya agregada desde la base.
-- ============================================================

create or replace function public.finance_performance_payload(
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
    coalesce(srv.price, 0)::numeric(12, 2) as total,
    coalesce(nullif(trim(coalesce(srv.name, '')), ''), 'Servicio agenda') as service_name
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
bookings_base as (
  select
    b.id,
    b.booking_date,
    b.therapist_id,
    coalesce(nullif(trim(coalesce(st.full_name, '')), ''), 'Sin terapeuta') as therapist_name,
    lower(trim(coalesce(b.status::text, ''))) as status,
    coalesce(srv.price, 0)::numeric(12, 2) as service_price,
    coalesce(nullif(trim(coalesce(srv.name, '')), ''), 'Servicio agenda') as service_name
  from public.bookings b
  left join public.staff st on st.id = b.therapist_id
  left join public.services srv on srv.id = b.service_id
  where p_branch_id is null or coalesce(b.sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid) = p_branch_id
),
therapist_rows as (
  select
    coalesce(bb.therapist_id::text, 'sin_terapeuta') as id,
    bb.therapist_name as name,
    count(*) filter (where bb.status in ('completed', 'paid'))::int as services_completed,
    count(*) filter (where bb.status = 'cancelled')::int as cancelled,
    count(*) filter (where bb.status = 'no_show')::int as no_shows,
    coalesce(sum(coalesce(ps.total, pb.total, 0)), 0)::numeric(12, 2) as revenue
  from bookings_base bb
  left join paid_sales ps on ps.appointment_id = bb.id
  left join paid_bookings_without_sale pb on pb.id = bb.id
  group by 1, 2
  order by revenue desc, name asc
),
service_revenue as (
  select label, sum(total)::numeric(12, 2) as value
  from (
    select
      coalesce(nullif(trim(coalesce(si.description, si.name)), ''), 'Sin concepto') as label,
      coalesce(
        nullif(si.total_price, 0),
        coalesce(nullif(si.unit_price, 0), coalesce(si.price, 0)) *
          coalesce(nullif(si.quantity, 0), 1)
      )::numeric(12, 2) as total
    from paid_sales ps
    join public.sale_items si on si.sale_id = ps.id

    union all

    select pb.service_name as label, pb.total
    from paid_bookings_without_sale pb
  ) items
  group by 1
  order by value desc, label asc
),
summary as (
  select
    coalesce((select count(*) from bookings_base), 0)::int as total_bookings,
    coalesce((select count(*) from bookings_base where status in ('completed', 'paid')), 0)::int as servicios_realizados,
    coalesce((select sum(total) from income_ops), 0)::numeric(12, 2) as ingresos_totales,
    coalesce((select sum(amount) from expense_ops), 0)::numeric(12, 2) as egresos_totales,
    coalesce((select count(*) from income_ops), 0)::int as operaciones_cobradas
),
summary_calc as (
  select
    s.*,
    case
      when s.total_bookings = 0 then 0
      else round((s.servicios_realizados::numeric / s.total_bookings::numeric) * 100, 2)
    end::numeric(12, 2) as rendimiento_general,
    case
      when s.operaciones_cobradas = 0 then 0
      else round(s.ingresos_totales / s.operaciones_cobradas, 2)
    end::numeric(12, 2) as ticket_promedio,
    case
      when s.ingresos_totales = 0 then 0
      else round(((s.ingresos_totales - s.egresos_totales) / s.ingresos_totales) * 100, 2)
    end::numeric(12, 2) as margen_promedio
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
    case
      when (
        select count(*)
        from bookings_base bb
        where bb.booking_date = d.day
      ) = 0 then 0
      else round((
        (
          select count(*)
          from bookings_base bb
          where bb.booking_date = d.day
            and bb.status in ('completed', 'paid')
        )::numeric /
        (
          select count(*)
          from bookings_base bb
          where bb.booking_date = d.day
        )::numeric
      ) * 100, 2)
    end::numeric(12, 2) as ingresos,
    case
      when (
        select count(*)
        from bookings_base bb
        where bb.booking_date = ((date_trunc('month', current_date) - interval '1 month')::date + (d.day - date_trunc('month', current_date)::date))
      ) = 0 then 0
      else round((
        (
          select count(*)
          from bookings_base bb
          where bb.booking_date = ((date_trunc('month', current_date) - interval '1 month')::date + (d.day - date_trunc('month', current_date)::date))
            and bb.status in ('completed', 'paid')
        )::numeric /
        (
          select count(*)
          from bookings_base bb
          where bb.booking_date = ((date_trunc('month', current_date) - interval '1 month')::date + (d.day - date_trunc('month', current_date)::date))
        )::numeric
      ) * 100, 2)
    end::numeric(12, 2) as egresos
  from days d
  order by d.day
),
profitable_services as (
  select label, value
  from service_revenue
  order by value desc, label asc
  limit 4
),
branch_breakdown as (
  select 'Sahara Club Spa'::text as label,
         coalesce((select ingresos_totales from summary_calc), 0)::numeric(12, 2) as value
),
top_employee as (
  select name, revenue
  from therapist_rows
  order by revenue desc, name asc
  limit 1
),
top_service as (
  select label, value
  from service_revenue
  order by value desc, label asc
  limit 1
),
low_performer_count as (
  select count(*)::int as total
  from therapist_rows tr
  where exists (
    select 1
    from (
      select revenue
      from therapist_rows
      order by revenue desc
      limit 1
    ) top_row
    where (tr.services_completed = 0)
       or (top_row.revenue > 0 and (tr.revenue < (top_row.revenue * 0.35) or tr.no_shows > 1))
  )
)
select jsonb_build_object(
  'summary',
  (
    select jsonb_build_object(
      'rendimiento_general', sc.rendimiento_general,
      'ticket_promedio', sc.ticket_promedio,
      'margen_promedio', sc.margen_promedio,
      'servicios_realizados', sc.servicios_realizados,
      'empleado_top_name', coalesce((select te.name from top_employee te), 'Sin datos'),
      'empleado_top_total', coalesce((select te.revenue from top_employee te), 0),
      'servicio_top_name', coalesce((select ts.label from top_service ts), 'Sin datos'),
      'servicio_top_count', coalesce((
        select count(*)
        from bookings_base bb
        where bb.service_name = (select ts.label from top_service ts)
          and bb.status in ('completed', 'paid')
      ), 0),
      'low_performer_count', coalesce((select lp.total from low_performer_count lp), 0)
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
  'profitable_services',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', ps.label,
        'value', ps.value
      )
      order by ps.value desc, ps.label asc
    )
    from profitable_services ps
  ), '[]'::jsonb),
  'branch_breakdown',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', bb.label,
        'value', bb.value
      )
    )
    from branch_breakdown bb
  ), '[]'::jsonb),
  'rows',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', tr.id,
        'name', tr.name,
        'services_completed', tr.services_completed,
        'cancelled', tr.cancelled,
        'no_shows', tr.no_shows,
        'revenue', tr.revenue
      )
      order by tr.revenue desc, tr.name asc
    )
    from therapist_rows tr
  ), '[]'::jsonb),
  'summary_rows',
  (
    select jsonb_build_array(
      jsonb_build_object('label', 'Rendimiento general', 'value', sc.rendimiento_general::text || '%'),
      jsonb_build_object('label', 'Ticket promedio', 'value', to_char(sc.ticket_promedio, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Margen promedio', 'value', sc.margen_promedio::text || '%'),
      jsonb_build_object('label', 'Servicios realizados', 'value', sc.servicios_realizados::text),
      jsonb_build_object('label', 'Empleado top', 'value', coalesce((select te.name from top_employee te), 'Sin datos')),
      jsonb_build_object('label', 'Servicio top', 'value', coalesce((select ts.label from top_service ts), 'Sin datos')),
      jsonb_build_object('label', 'Sucursal top', 'value', 'Sahara Club Spa'),
      jsonb_build_object(
        'label', 'Alerta',
        'value',
        case
          when coalesce((select lp.total from low_performer_count lp), 0) = 0
            then 'Sin alertas'
          else coalesce((select lp.total from low_performer_count lp), 0)::text || ' bajo'
        end
      )
    )
    from summary_calc sc
  )
);
$$;

grant execute on function public.finance_performance_payload(uuid) to authenticated;
