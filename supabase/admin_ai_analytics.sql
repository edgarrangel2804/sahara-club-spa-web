-- Sahara Club Spa - Analítica para el ADMIN IA vía WhatsApp (modo director)
-- ----------------------------------------------------------------------------
-- RPCs read-only usadas SOLO por la Edge Function whatsapp-ai-router cuando el
-- número es admin (is_ai_admin). Dan acceso a finanzas, nómina, clientes
-- recurrentes, membresías y prospectos — todo con datos REALES de Sahara.
--
-- SEGURIDAD:
--   - security definer + grant SOLO a service_role (nunca anon/authenticated).
--   - Solo LECTURA. No mutan nada.
--   - Si una tabla está vacía, devuelven ceros / listas vacías con banderas
--     'has_data' para que la IA diga la verdad ("aún no hay datos cargados")
--     en lugar de inventar.
--   - Zona horaria America/Tijuana en todos los cortes de fecha.

-- ---------------------------------------------------------------------------
-- 1. Estado de resultados (ingresos - gastos - nómina = utilidad)
-- ---------------------------------------------------------------------------
create or replace function public.admin_financial_summary_from_ai(
  p_from date default null,
  p_to   date default null
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_from date := coalesce(p_from, date_trunc('month', (now() at time zone 'America/Tijuana'))::date);
  v_to   date := coalesce(p_to, (now() at time zone 'America/Tijuana')::date);
  v_income numeric := 0;
  v_income_by_method jsonb := '[]'::jsonb;
  v_income_tx int := 0;
  v_var_expenses numeric := 0;
  v_var_count int := 0;
  v_supplier numeric := 0;
  v_supplier_count int := 0;
  v_fixed_monthly numeric := 0;
  v_fixed_count int := 0;
  v_payroll numeric := 0;
  v_payroll_count int := 0;
  v_net numeric;
begin
  -- Ingresos pagados (sales)
  select coalesce(sum(total),0), count(*)
  into v_income, v_income_tx
  from public.sales
  where payment_status = 'paid'
    and (created_at at time zone 'America/Tijuana')::date between v_from and v_to;

  select coalesce(jsonb_agg(jsonb_build_object('method', method, 'amount', amt) order by amt desc), '[]'::jsonb)
  into v_income_by_method
  from (
    select coalesce(payment_method,'otro') as method, sum(total) as amt
    from public.sales
    where payment_status = 'paid'
      and (created_at at time zone 'America/Tijuana')::date between v_from and v_to
    group by coalesce(payment_method,'otro')
  ) m;

  -- Gastos variables
  select coalesce(sum(amount),0), count(*) into v_var_expenses, v_var_count
  from public.expenses where date between v_from and v_to;

  -- Gastos a proveedores
  select coalesce(sum(amount),0), count(*) into v_supplier, v_supplier_count
  from public.supplier_expenses where expense_date between v_from and v_to;

  -- Gastos fijos mensuales activos (se reportan como compromiso mensual)
  select coalesce(sum(amount),0), count(*) into v_fixed_monthly, v_fixed_count
  from public.fixed_expenses
  where coalesce(status,'active') = 'active'
    and coalesce(frequency,'mensual') in ('mensual','monthly');

  -- Nómina cuyo periodo cae dentro del rango
  select coalesce(sum(total_pay),0), count(*) into v_payroll, v_payroll_count
  from public.payroll_entries
  where period_start <= v_to and period_end >= v_from;

  v_net := v_income - v_var_expenses - v_supplier - v_payroll - v_fixed_monthly;

  return jsonb_build_object(
    'range', jsonb_build_object('from', v_from, 'to', v_to),
    'income', jsonb_build_object(
      'total_mxn', v_income, 'transactions', v_income_tx,
      'by_method', v_income_by_method, 'has_data', v_income_tx > 0),
    'variable_expenses', jsonb_build_object('total_mxn', v_var_expenses, 'count', v_var_count, 'has_data', v_var_count > 0),
    'supplier_expenses', jsonb_build_object('total_mxn', v_supplier, 'count', v_supplier_count, 'has_data', v_supplier_count > 0),
    'fixed_expenses_monthly', jsonb_build_object('total_mxn', v_fixed_monthly, 'count', v_fixed_count, 'has_data', v_fixed_count > 0),
    'payroll', jsonb_build_object('total_mxn', v_payroll, 'entries', v_payroll_count, 'has_data', v_payroll_count > 0),
    'net_profit_mxn', v_net,
    'note', 'Gastos fijos son compromiso mensual. Nómina por periodos que tocan el rango.'
  );
end;
$$;

revoke all on function public.admin_financial_summary_from_ai(date,date) from public;
grant execute on function public.admin_financial_summary_from_ai(date,date) to service_role;

-- ---------------------------------------------------------------------------
-- 2. Gastos fijos del mes (detalle)
-- ---------------------------------------------------------------------------
create or replace function public.admin_fixed_expenses_from_ai()
returns jsonb
language plpgsql
stable
security definer
as $$
declare v_items jsonb; v_total numeric;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
            'name', name, 'category', category, 'amount_mxn', amount,
            'frequency', frequency, 'due_day', due_day, 'status', status
          ) order by amount desc), '[]'::jsonb),
         coalesce(sum(amount) filter (where coalesce(status,'active')='active'),0)
  into v_items, v_total
  from public.fixed_expenses;
  return jsonb_build_object('items', v_items, 'monthly_total_active_mxn', v_total,
                            'has_data', jsonb_array_length(v_items) > 0);
end;
$$;
revoke all on function public.admin_fixed_expenses_from_ai() from public;
grant execute on function public.admin_fixed_expenses_from_ai() to service_role;

-- ---------------------------------------------------------------------------
-- 3. Nómina por periodo (detalle por empleado)
-- ---------------------------------------------------------------------------
create or replace function public.admin_payroll_summary_from_ai(
  p_from date default null,
  p_to   date default null
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_from date := coalesce(p_from, date_trunc('month', (now() at time zone 'America/Tijuana'))::date);
  v_to   date := coalesce(p_to, (now() at time zone 'America/Tijuana')::date);
  v_items jsonb; v_total numeric; v_n int;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
            'employee', coalesce(st.full_name,'(sin nombre)'),
            'period', pe.period_start::text || ' → ' || pe.period_end::text,
            'base_salary', pe.base_salary, 'commissions', pe.commissions,
            'bonuses', pe.bonuses, 'tips', pe.tips, 'deductions', pe.deductions,
            'total_pay', pe.total_pay, 'payment_status', pe.payment_status
          ) order by pe.total_pay desc), '[]'::jsonb),
         coalesce(sum(pe.total_pay),0), count(*)
  into v_items, v_total, v_n
  from public.payroll_entries pe
  left join public.staff st on st.id = pe.employee_id
  where pe.period_start <= v_to and pe.period_end >= v_from;

  return jsonb_build_object(
    'range', jsonb_build_object('from', v_from, 'to', v_to),
    'entries', v_items, 'total_mxn', v_total, 'count', v_n, 'has_data', v_n > 0);
end;
$$;
revoke all on function public.admin_payroll_summary_from_ai(date,date) from public;
grant execute on function public.admin_payroll_summary_from_ai(date,date) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Clientes recurrentes (con nombres + visitas + última visita)
-- ---------------------------------------------------------------------------
create or replace function public.admin_recurring_clients_from_ai(
  p_min_visits int default 2,
  p_limit int default 20
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare v_items jsonb; v_total_recurring int;
begin
  with agg as (
    select b.client_record_id as cid,
           count(*) filter (where b.status not in ('cancelled','no_show')) as bookings_total,
           count(*) filter (where b.status = 'completed') as visits_completed,
           max(b.booking_date) filter (where b.status = 'completed') as last_visit,
           min(b.booking_date) as first_booking
    from public.bookings b
    where b.client_record_id is not null
    group by b.client_record_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
            'name', coalesce(c.full_name,'(sin nombre)'),
            'phone', c.phone, 'email', c.email,
            'bookings_total', a.bookings_total,
            'visits_completed', a.visits_completed,
            'last_visit', a.last_visit,
            'first_booking', a.first_booking
          ) order by a.bookings_total desc, a.visits_completed desc), '[]'::jsonb),
         count(*)
  into v_items, v_total_recurring
  from agg a
  join public.clients c on c.id = a.cid
  where a.bookings_total >= greatest(p_min_visits,1);

  return jsonb_build_object(
    'min_visits', greatest(p_min_visits,1),
    'recurring_count', v_total_recurring,
    'clients', (select jsonb_agg(x) from (
                  select * from jsonb_array_elements(v_items) limit greatest(p_limit,1)
                ) x),
    'has_data', v_total_recurring > 0);
end;
$$;
revoke all on function public.admin_recurring_clients_from_ai(int,int) from public;
grant execute on function public.admin_recurring_clients_from_ai(int,int) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Búsqueda / detalle de cliente (nombre o teléfono) con historial completo
-- ---------------------------------------------------------------------------
create or replace function public.admin_client_lookup_from_ai(
  p_query text
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_q text := trim(coalesce(p_query,''));
  v_digits text := regexp_replace(coalesce(p_query,''),'\D','','g');
  v_items jsonb;
begin
  if v_q = '' then
    return jsonb_build_object('matches', '[]'::jsonb, 'count', 0, 'error', 'query_required');
  end if;

  select coalesce(jsonb_agg(t order by (t->>'bookings_total')::int desc), '[]'::jsonb)
  into v_items
  from (
    select jsonb_build_object(
      'name', c.full_name, 'phone', c.phone, 'email', c.email,
      'birth_date', c.birth_date, 'notes', c.notes, 'client_since', c.created_at::date,
      'bookings_total', (select count(*) from public.bookings b where b.client_record_id = c.id and b.status not in ('cancelled','no_show')),
      'visits_completed', (select count(*) from public.bookings b where b.client_record_id = c.id and b.status = 'completed'),
      'last_visit', (select max(b.booking_date) from public.bookings b where b.client_record_id = c.id and b.status = 'completed'),
      'next_appointment', (select min(b.booking_date) from public.bookings b where b.client_record_id = c.id and b.booking_date >= (now() at time zone 'America/Tijuana')::date and b.status not in ('cancelled','no_show')),
      'recent_history', (
        select coalesce(jsonb_agg(jsonb_build_object('date', b.booking_date, 'time', to_char(b.booking_time,'HH24:MI'), 'service', b.service_name, 'status', b.status) order by b.booking_date desc), '[]'::jsonb)
        from (select * from public.bookings bb where bb.client_record_id = c.id order by bb.booking_date desc limit 8) b
      ),
      'membership', (
        select jsonb_build_object('status', m.status, 'end_date', m.end_date, 'sessions_used', m.sessions_used, 'sessions_total', m.sessions_total, 'auto_renew', m.auto_renew)
        from public.client_memberships m where m.client_id = c.id order by m.end_date desc limit 1
      )
    ) as t
    from public.clients c
    where c.full_name ilike '%'||v_q||'%'
       or (length(v_digits) >= 7 and right(regexp_replace(c.phone,'\D','','g'),10) = right(v_digits,10))
    order by c.created_at desc
    limit 5
  ) s;

  return jsonb_build_object('matches', v_items, 'count', jsonb_array_length(v_items));
end;
$$;
revoke all on function public.admin_client_lookup_from_ai(text) from public;
grant execute on function public.admin_client_lookup_from_ai(text) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Resumen de membresías (activas / por vencer / uso)
-- ---------------------------------------------------------------------------
create or replace function public.admin_memberships_summary_from_ai()
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_today date := (now() at time zone 'America/Tijuana')::date;
  v_active int; v_expiring int; v_auto int; v_items jsonb;
begin
  select count(*) filter (where status = 'active'),
         count(*) filter (where status = 'active' and end_date is not null and end_date <= v_today + 30),
         count(*) filter (where status = 'active' and auto_renew = true)
  into v_active, v_expiring, v_auto
  from public.client_memberships;

  select coalesce(jsonb_agg(jsonb_build_object(
            'client', coalesce(c.full_name,'(sin nombre)'),
            'phone', c.phone,
            'status', m.status, 'end_date', m.end_date,
            'sessions_used', m.sessions_used, 'sessions_total', m.sessions_total,
            'auto_renew', m.auto_renew,
            'days_to_expire', case when m.end_date is not null then (m.end_date - v_today) else null end
          ) order by m.end_date asc), '[]'::jsonb)
  into v_items
  from public.client_memberships m
  join public.clients c on c.id = m.client_id
  where m.status = 'active';

  return jsonb_build_object(
    'active', v_active, 'expiring_30d', v_expiring, 'auto_renew', v_auto,
    'memberships', v_items, 'has_data', v_active > 0);
end;
$$;
revoke all on function public.admin_memberships_summary_from_ai() from public;
grant execute on function public.admin_memberships_summary_from_ai() to service_role;

-- ---------------------------------------------------------------------------
-- 7. Prospectos / clientes nuevos en un rango
-- ---------------------------------------------------------------------------
create or replace function public.admin_prospects_from_ai(
  p_from date default null,
  p_to   date default null
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_from date := coalesce(p_from, date_trunc('month', (now() at time zone 'America/Tijuana'))::date);
  v_to   date := coalesce(p_to, (now() at time zone 'America/Tijuana')::date);
  v_new int; v_no_booking int; v_items jsonb;
begin
  with newc as (
    select c.id, c.full_name, c.phone, c.created_at,
           (select count(*) from public.bookings b where b.client_record_id = c.id and b.status not in ('cancelled','no_show')) as bookings
    from public.clients c
    where (c.created_at at time zone 'America/Tijuana')::date between v_from and v_to
  )
  select count(*), count(*) filter (where bookings = 0),
         coalesce(jsonb_agg(jsonb_build_object(
            'name', full_name, 'phone', phone,
            'registered', (created_at at time zone 'America/Tijuana')::date,
            'bookings', bookings,
            'is_lead', bookings = 0
         ) order by created_at desc), '[]'::jsonb)
  into v_new, v_no_booking, v_items
  from newc;

  return jsonb_build_object(
    'range', jsonb_build_object('from', v_from, 'to', v_to),
    'new_clients', v_new, 'leads_without_booking', v_no_booking,
    'prospects', v_items, 'has_data', v_new > 0);
end;
$$;
revoke all on function public.admin_prospects_from_ai(date,date) from public;
grant execute on function public.admin_prospects_from_ai(date,date) to service_role;
