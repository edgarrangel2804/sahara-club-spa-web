-- ─────────────────────────────────────────────────────────────────────────────
-- Sahara Club Spa — Módulo Paquetes: esquema + lógica COMPLETA (estado vivo)
-- Generado el 2026-06-08 a partir de la base remota (fkbyxhwdcsgrrixalzwf) para
-- versionar lo que hasta ahora vivía solo en el remoto (RPC/triggers/columnas).
-- Es 100% idempotente y aditivo: seguro de re-ejecutar.
--
-- Resumen del flujo (base CAJA):
--  • products.is_package = PLANTILLA editable (+ package_items: servicios/cantidades).
--  • Vender (sell_client_package): crea client_packages (copia congelada: snapshot
--    + package_id + plan), 1 client_package_sessions por servicio×cantidad,
--    registra el INGRESO del anticipo en sales, y arma client_package_payments.
--  • Abonos (pay_package_installment): al cobrar un abono, lo marca pagado y
--    registra su ingreso en sales ese día. NO toca pending_amount (es generada).
--  • Consumo: al confirmar un booking con waiver_reason='package' un trigger marca
--    una sesión 'usada' (ver packages_anticipo_waiver.sql).
--  • sync_package_sessions: recalcula sessions_used/remaining y alterna
--    activo↔completado en cada cambio de sesiones.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) Columnas evolucionadas de client_packages (aditivo)
alter table public.client_packages
  add column if not exists service_id          uuid references public.services(id) on delete set null,
  add column if not exists base_service_id     uuid references public.services(id) on delete set null,
  add column if not exists sessions_total      int     not null default 0,
  add column if not exists sessions_used        int     not null default 0,
  add column if not exists sessions_remaining   int     not null default 0,
  add column if not exists origin              text    not null default 'nueva_venta',
  add column if not exists sale_id             uuid    references public.sales(id) on delete set null,
  add column if not exists migration_note      text,
  add column if not exists adjusted_by         uuid,
  add column if not exists adjusted_at         timestamptz,
  add column if not exists updated_at          timestamptz not null default now();

-- 2) Bitácora de auditoría de paquetes
create table if not exists public.client_package_audit_log (
  id                uuid primary key default gen_random_uuid(),
  client_package_id uuid references public.client_packages(id) on delete cascade,
  adjusted_by       uuid,
  action            text,
  sessions_before   int,
  sessions_after    int,
  notes             text,
  created_at        timestamptz not null default now()
);
create index if not exists cpal_client_package_id_idx
  on public.client_package_audit_log(client_package_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) Funciones
-- ─────────────────────────────────────────────────────────────────────────────

-- Venta unificada (multi-servicio + snapshot + plan + ingreso del anticipo).
-- Sirve tanto para paquetes de Productos como para servicios-tipo-paquete.
CREATE OR REPLACE FUNCTION public.sell_client_package(
  p_client_id uuid, p_package_id uuid, p_name text, p_lines jsonb, p_total numeric,
  p_plan_type text, p_installments integer, p_initial_payment numeric,
  p_payment_method text DEFAULT 'efectivo'::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_cp_id    uuid;
  v_sale_id  uuid;
  v_line     jsonb;
  v_i        int;
  v_qty      int;
  v_n        int := greatest(1, coalesce(p_installments, 1));
  v_total_sessions int := 0;
  v_base     numeric;
  v_amount   numeric;
  v_remaining_paid numeric := coalesce(p_initial_payment, 0);
  v_name     text := coalesce(nullif(trim(p_name), ''), 'Paquete');
begin
  for v_line in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_total_sessions := v_total_sessions + greatest(1, coalesce((v_line->>'quantity')::int, 1));
  end loop;

  insert into public.client_packages(
    client_id, package_id, name, status, total_amount, paid_amount,
    payment_plan_type, installments_count, items_snapshot, origin,
    sessions_total, sessions_used, sessions_remaining
  ) values (
    p_client_id, p_package_id, v_name, 'activo', p_total, coalesce(p_initial_payment, 0),
    p_plan_type, v_n, p_lines, 'nueva_venta',
    v_total_sessions, 0, v_total_sessions
  ) returning id into v_cp_id;

  for v_line in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_qty := greatest(1, coalesce((v_line->>'quantity')::int, 1));
    for v_i in 1..v_qty loop
      insert into public.client_package_sessions(
        client_package_id, client_id, service_id, service_name, status
      ) values (
        v_cp_id, p_client_id, nullif(v_line->>'service_id', '')::uuid,
        v_line->>'service_name', 'pendiente'
      );
    end loop;
  end loop;

  if coalesce(p_initial_payment, 0) > 0 then
    insert into public.sales(
      client_id, customer_id, total, subtotal, payment_method,
      payment_status, sale_status, status, created_by, notes
    ) values (
      null, p_client_id, p_initial_payment, p_initial_payment, p_payment_method,
      'paid', 'completed', 'paid', p_created_by,
      'Venta de paquete: ' || v_name || case when v_n > 1 then ' (anticipo)' else '' end
    ) returning id into v_sale_id;

    insert into public.sale_items(sale_id, name, description, quantity, unit_price, total_price)
    values (v_sale_id, v_name, v_total_sessions || ' sesiones de paquete', 1,
            p_initial_payment, p_initial_payment);

    update public.client_packages set sale_id = v_sale_id where id = v_cp_id;
  end if;

  v_base := floor(p_total / v_n);
  for v_i in 1..v_n loop
    if v_i = v_n then v_amount := p_total - v_base * (v_n - 1);
    else v_amount := v_base; end if;
    insert into public.client_package_payments(
      client_package_id, client_id, installment_number, amount, status, paid_at, payment_method
    ) values (
      v_cp_id, p_client_id, v_i, v_amount,
      case when v_remaining_paid >= v_amount and v_amount > 0 then 'pagado' else 'pendiente' end,
      case when v_remaining_paid >= v_amount and v_amount > 0 then now() else null end,
      case when v_remaining_paid >= v_amount and v_amount > 0 then p_payment_method else null end
    );
    if v_remaining_paid >= v_amount and v_amount > 0 then
      v_remaining_paid := v_remaining_paid - v_amount;
    end if;
  end loop;

  insert into public.client_package_audit_log(
    client_package_id, adjusted_by, action, sessions_before, sessions_after, notes
  ) values (v_cp_id, p_created_by, 'venta', null, v_total_sessions, 'Venta de paquete (flujo unificado)');

  return v_cp_id;
end;
$function$;

-- Cobro de un abono (base caja): marca pagado + registra ingreso del día.
CREATE OR REPLACE FUNCTION public.pay_package_installment(
  p_payment_id uuid, p_payment_method text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_cp_id uuid; v_client_id uuid; v_amount numeric; v_n int; v_status text;
  v_name text; v_sale_id uuid;
begin
  select client_package_id, client_id, amount, installment_number, status
    into v_cp_id, v_client_id, v_amount, v_n, v_status
  from public.client_package_payments where id = p_payment_id for update;

  if not found or v_status = 'pagado' then return; end if;

  update public.client_package_payments
     set status = 'pagado', paid_at = now(), payment_method = p_payment_method
   where id = p_payment_id;

  select name into v_name from public.client_packages where id = v_cp_id;

  insert into public.sales(
    client_id, customer_id, total, subtotal, payment_method,
    payment_status, sale_status, status, created_by, notes
  ) values (
    null, v_client_id, v_amount, v_amount, p_payment_method,
    'paid', 'completed', 'paid', p_created_by,
    'Abono ' || v_n || ' de paquete: ' || coalesce(v_name, 'Paquete')
  ) returning id into v_sale_id;

  insert into public.sale_items(sale_id, name, description, quantity, unit_price, total_price)
  values (v_sale_id, coalesce(v_name, 'Paquete'), 'Abono ' || v_n, 1, v_amount, v_amount);

  update public.client_packages
     set paid_amount = (
       select coalesce(sum(amount), 0) from public.client_package_payments
       where client_package_id = v_cp_id and status = 'pagado')
   where id = v_cp_id;
end;
$function$;

-- Recalcula contadores y alterna activo↔completado (trigger).
CREATE OR REPLACE FUNCTION public.sync_package_sessions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_pkg_id uuid := coalesce(NEW.client_package_id, OLD.client_package_id);
  v_total  int;
  v_used   int;
begin
  select sessions_total into v_total
  from public.client_packages where id = v_pkg_id for update;
  if not found then return coalesce(NEW, OLD); end if;

  select count(*) into v_used
  from public.client_package_sessions
  where client_package_id = v_pkg_id and status = 'usada';

  update public.client_packages set
    sessions_used = v_used,
    sessions_remaining = greatest(0, coalesce(v_total, 0) - v_used),
    status = case
      when coalesce(v_total, 0) > 0 and v_used >= v_total then 'completado'
      when status = 'completado' and v_used < coalesce(v_total, 0) then 'activo'
      else status
    end,
    updated_at = now()
  where id = v_pkg_id;

  return coalesce(NEW, OLD);
end;
$function$;

drop trigger if exists trg_sync_package_sessions on public.client_package_sessions;
create trigger trg_sync_package_sessions
  after insert or update or delete on public.client_package_sessions
  for each row execute function public.sync_package_sessions();

-- Vence paquetes activos cuya vigencia expiró (llamar por cron o a demanda).
CREATE OR REPLACE FUNCTION public.expire_old_client_packages()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare v_count int;
begin
  update public.client_packages
     set status = 'vencido', updated_at = now()
   where status = 'activo' and expires_at is not null and expires_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

-- create_client_package: alta directa (migración de paquetes existentes,
-- 1 solo servicio base × N sesiones). Conservada para el flujo "Registrar existente".
CREATE OR REPLACE FUNCTION public.create_client_package(
  p_client_id uuid, p_service_id uuid, p_base_service_id uuid, p_sessions_total integer,
  p_sessions_used integer DEFAULT 0, p_total_amount numeric DEFAULT 0,
  p_origin text DEFAULT 'nueva_venta'::text, p_sale_id uuid DEFAULT NULL::uuid,
  p_migration_note text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid,
  p_name text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_cp_id    uuid;
  v_sessions_remaining integer := GREATEST(0, p_sessions_total - p_sessions_used);
  v_status   text := CASE WHEN v_sessions_remaining = 0 THEN 'completado' ELSE 'activo' END;
  v_name     text;
  v_i        integer;
BEGIN
  IF p_name IS NOT NULL AND trim(p_name) <> '' THEN
    v_name := trim(p_name);
  ELSE
    SELECT name INTO v_name FROM public.services WHERE id = p_service_id;
    v_name := COALESCE(v_name, 'Paquete');
  END IF;

  INSERT INTO public.client_packages(
    client_id, service_id, base_service_id, name, status,
    sessions_total, sessions_used, sessions_remaining,
    total_amount, paid_amount, origin, sale_id,
    migration_note, adjusted_by, adjusted_at
  ) VALUES (
    p_client_id, p_service_id, p_base_service_id, v_name, v_status,
    p_sessions_total, p_sessions_used, v_sessions_remaining,
    p_total_amount, p_total_amount, p_origin, p_sale_id,
    p_migration_note,
    CASE WHEN p_origin = 'migracion_manual' THEN p_created_by END,
    CASE WHEN p_origin = 'migracion_manual' THEN now() END
  ) RETURNING id INTO v_cp_id;

  FOR v_i IN 1..p_sessions_used LOOP
    INSERT INTO public.client_package_sessions(
      client_package_id, client_id, service_id, service_name, status, used_at
    ) SELECT v_cp_id, p_client_id, p_base_service_id, name, 'usada', now()
      FROM public.services WHERE id = p_base_service_id;
  END LOOP;

  FOR v_i IN 1..v_sessions_remaining LOOP
    INSERT INTO public.client_package_sessions(
      client_package_id, client_id, service_id, service_name, status
    ) SELECT v_cp_id, p_client_id, p_base_service_id, name, 'pendiente'
      FROM public.services WHERE id = p_base_service_id;
  END LOOP;

  INSERT INTO public.client_package_audit_log(
    client_package_id, adjusted_by, action, sessions_before, sessions_after, notes
  ) VALUES (
    v_cp_id, p_created_by,
    CASE p_origin WHEN 'migracion_manual' THEN 'migracion' ELSE 'venta' END,
    NULL, v_sessions_remaining, COALESCE(p_migration_note, 'Paquete creado')
  );

  RETURN v_cp_id;
END;
$function$;
