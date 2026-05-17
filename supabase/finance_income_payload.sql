-- ============================================================
-- Sahara Club Spa - Finanzas Ingresos Payload
-- Entrega la pantalla de ingresos ya agregada desde la base.
-- ============================================================

create or replace function public.finance_income_payload(
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
    'Cliente general'::text as client_name,
    coalesce(nullif(trim(coalesce(s.payment_method, '')), ''), 'pendiente') as payment_method,
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
    b.booking_time,
    b.therapist_id,
    coalesce(nullif(trim(coalesce(srv.name, '')), ''), 'Servicio agenda') as service_name,
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
service_items as (
  select
    coalesce(nullif(trim(coalesce(si.description, si.name)), ''), 'Sin concepto') as label,
    coalesce(
      nullif(si.total_price, 0),
      coalesce(nullif(si.unit_price, 0), coalesce(si.price, 0)) *
        coalesce(nullif(si.quantity, 0), 1)
    )::numeric(12, 2) as total,
    case
      when lower(coalesce(si.description, si.name, '')) like '%gift%' then 'Gift Cards'
      when lower(coalesce(si.description, si.name, '')) like '%membres%' then 'Membresias'
      when si.service_id is not null then 'Servicios'
      else 'Productos'
    end as item_type
  from paid_sales ps
  join public.sale_items si on si.sale_id = ps.id
),
all_service_items as (
  select label, total, item_type
  from service_items
  union all
  select pb.service_name as label, pb.total, 'Servicios' as item_type
  from paid_bookings_without_sale pb
),
therapist_performance as (
  select
    coalesce(st.id::text, coalesce(b.therapist_id::text, 'sin_terapeuta')) as id,
    coalesce(nullif(st.full_name, ''), 'Sin terapeuta') as name,
    coalesce(sum(coalesce(ps.total, pb.total, 0)), 0)::numeric(12, 2) as revenue
  from public.bookings b
  left join public.staff st on st.id = b.therapist_id
  left join paid_sales ps on ps.appointment_id = b.id
  left join paid_bookings_without_sale pb on pb.id = b.id
  where p_branch_id is null or coalesce(b.sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid) = p_branch_id
  group by 1, 2
  order by revenue desc, name asc
),
summary as (
  select
    coalesce((select sum(total) from income_ops where day = current_date), 0)::numeric(12, 2) as ingresos_hoy,
    coalesce((select count(*) from income_ops where day = current_date), 0)::int as operaciones_hoy,
    coalesce((select sum(total) from income_ops where day >= date_trunc('week', current_date)::date), 0)::numeric(12, 2) as ingresos_semana,
    coalesce((select sum(total) from income_ops where day >= (date_trunc('week', current_date)::date - interval '7 days')::date and day < date_trunc('week', current_date)::date), 0)::numeric(12, 2) as ingresos_semana_anterior,
    coalesce((select sum(total) from income_ops where day >= date_trunc('month', current_date)::date), 0)::numeric(12, 2) as ingresos_mes,
    coalesce((select sum(total) from income_ops where day >= (date_trunc('month', current_date) - interval '1 month')::date and day < date_trunc('month', current_date)::date), 0)::numeric(12, 2) as ingresos_mes_anterior,
    coalesce((select sum(total) from income_ops), 0)::numeric(12, 2) as ingresos_totales,
    coalesce((select count(*) from income_ops), 0)::int as operaciones_cobradas,
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
    coalesce((
      select sum(i.total)
      from income_ops i
      where i.day = ((date_trunc('month', current_date) - interval '1 month')::date + (d.day - date_trunc('month', current_date)::date))
    ), 0)::numeric(12, 2) as egresos
  from days d
  order by d.day
),
payment_breakdown as (
  select label, value
  from (
    select
      initcap(replace(ps.payment_method, '_', ' ')) as label,
      sum(ps.total)::numeric(12, 2) as value
    from paid_sales ps
    group by 1

    union all

    select
      'Sin metodo' as label,
      coalesce(sum(pb.total), 0)::numeric(12, 2) as value
    from paid_bookings_without_sale pb
  ) payment_rows
  where value > 0
),
type_breakdown as (
  select item_type as label, coalesce(sum(total), 0)::numeric(12, 2) as value
  from all_service_items
  group by 1
  order by value desc, label asc
),
recent_sales as (
  select *
  from (
    select
      ps.created_at,
      ps.client_name,
      ps.payment_method,
      ps.total,
      (
        select jsonb_agg(
          jsonb_build_object(
            'description', coalesce(nullif(trim(coalesce(si.description, si.name)), ''), 'Venta'),
            'name', coalesce(nullif(trim(si.name), ''), 'Venta')
          )
        )
        from public.sale_items si
        where si.sale_id = ps.id
      ) as sale_items
    from paid_sales ps

    union all

    select
      (pb.booking_date::timestamp + coalesce(pb.booking_time, time '00:00')) as created_at,
      'Cliente agenda'::text as client_name,
      'sin_metodo'::text as payment_method,
      pb.total,
      jsonb_build_array(
        jsonb_build_object(
          'description', pb.service_name,
          'name', pb.service_name
        )
      ) as sale_items
    from paid_bookings_without_sale pb
  ) rows
  order by created_at desc
  limit 8
),
top_service as (
  select label, value
  from (
    select label, sum(total)::numeric(12, 2) as value
    from all_service_items
    group by 1
  ) ranked
  order by value desc, label asc
  limit 1
),
top_therapist as (
  select name, revenue
  from therapist_performance
  where revenue > 0
  order by revenue desc, name asc
  limit 1
)
select jsonb_build_object(
  'summary',
  (
    select jsonb_build_object(
      'ingresos_hoy', sc.ingresos_hoy,
      'operaciones_hoy', sc.operaciones_hoy,
      'ingresos_semana', sc.ingresos_semana,
      'ingresos_semana_anterior', sc.ingresos_semana_anterior,
      'ingresos_mes', sc.ingresos_mes,
      'ingresos_mes_anterior', sc.ingresos_mes_anterior,
      'servicios_realizados', sc.servicios_realizados,
      'citas_completadas', sc.citas_completadas,
      'ticket_promedio', sc.ticket_promedio,
      'operaciones_cobradas', sc.operaciones_cobradas
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
  'payment_breakdown',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', pb.label,
        'value', pb.value
      )
      order by pb.value desc, pb.label asc
    )
    from payment_breakdown pb
  ), '[]'::jsonb),
  'type_breakdown',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'label', tb.label,
        'value', tb.value
      )
      order by tb.value desc, tb.label asc
    )
    from type_breakdown tb
  ), '[]'::jsonb),
  'recent_sales',
  coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'created_at', rs.created_at,
        'client_name', rs.client_name,
        'payment_method', rs.payment_method,
        'total', rs.total,
        'sale_items', coalesce(rs.sale_items, '[]'::jsonb)
      )
      order by rs.created_at desc
    )
    from recent_sales rs
  ), '[]'::jsonb),
  'summary_rows',
  (
    select jsonb_build_array(
      jsonb_build_object('label', 'Ventas hoy', 'value', to_char(sc.ingresos_hoy, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Ventas semana', 'value', to_char(sc.ingresos_semana, 'FM$999,999,990.00')),
      jsonb_build_object('label', 'Ventas mes', 'value', to_char(sc.ingresos_mes, 'FM$999,999,990.00')),
      jsonb_build_object(
        'label', 'Mejor servicio',
        'value', coalesce((select ts.label from top_service ts), 'Sin datos')
      ),
      jsonb_build_object(
        'label', 'Terapeuta top',
        'value', coalesce((select tt.name from top_therapist tt), 'Sin datos')
      )
    )
    from summary_calc sc
  )
);
$$;

grant execute on function public.finance_income_payload(uuid) to authenticated;
