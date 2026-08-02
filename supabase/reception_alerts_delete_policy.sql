-- ============================================================================
-- reception_alerts_delete_policy.sql
-- Permite a recepción/admin BORRAR notificaciones desde la campana (ícono de
-- basura, una por una). Complementa el borrado automático del cron y el
-- ocultado de las atendidas. Mismo criterio de rol que la política de update.
-- ============================================================================

drop policy if exists reception_alerts_delete_by_role on public.reception_alerts;
create policy reception_alerts_delete_by_role
  on public.reception_alerts
  for delete
  to authenticated
  using (current_user_role() = any (array['admin','reception','receptionist']));
