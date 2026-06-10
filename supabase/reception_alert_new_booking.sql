-- ============================================================================
-- reception_alert_new_booking.sql
-- Agrega el event_type 'booking_pending_reception' a reception_alerts.
-- Cubre: toda cita nueva creada por la IA de WhatsApp que entra a la agenda en
-- estado pending_reception / pending_payment y que recepción debe VALIDAR y
-- ASIGNAR TERAPEUTA. Antes este evento no existía, por eso las citas con
-- anticipo exonerado (membresía / gift card) no generaban alerta en el panel.
--
-- 100% ADITIVO e idempotente. No toca filas existentes.
-- ============================================================================

alter table public.reception_alerts
  drop constraint if exists reception_alerts_event_type_check;

alter table public.reception_alerts
  add constraint reception_alerts_event_type_check
  check (event_type in (
    'booking_pending_reception',
    'booking_cancelled',
    'reschedule_requested',
    'deposit_paid',
    'requires_reception'
  ));

-- Verificación
select conname, pg_get_constraintdef(oid) as def
from pg_constraint
where conrelid = 'public.reception_alerts'::regclass
  and conname = 'reception_alerts_event_type_check';
