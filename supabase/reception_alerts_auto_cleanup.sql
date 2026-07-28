-- ============================================================================
-- reception_alerts_auto_cleanup.sql
-- Limpieza automática de la campana de notificaciones de recepción.
--
-- Reglas de negocio:
--   • Cualquier notificación con MÁS DE 20 DÍAS -> se borra (sin importar estado).
--   • Notificación ATENDIDA (status='resolved') -> se borra ~1 día después de
--     atenderse (coalesce(resolved_at, created_at) < now() - 1 día).
--
-- El historial de citas NO se pierde: vive en public.bookings, no en
-- reception_alerts. Estas notificaciones son transitorias por diseño.
--
-- Requiere pg_cron (ya instalado en el proyecto). El job corre cada hora, así
-- una notificación atendida nunca permanece más de ~1 día.
-- ============================================================================

create or replace function public.cleanup_reception_alerts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer;
begin
  delete from public.reception_alerts
  where created_at < now() - interval '20 days'
     or (status = 'resolved'
         and coalesce(resolved_at, created_at) < now() - interval '1 day');
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.cleanup_reception_alerts() from public;
revoke all on function public.cleanup_reception_alerts() from anon;
revoke all on function public.cleanup_reception_alerts() from authenticated;

-- Reprogramar de forma idempotente
do $$
begin
  perform cron.unschedule('reception-alerts-cleanup');
exception when others then
  null;
end $$;

-- Cada hora, en el minuto 7
select cron.schedule(
  'reception-alerts-cleanup',
  '7 * * * *',
  $$select public.cleanup_reception_alerts();$$
);
