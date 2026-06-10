-- ============================================================================
-- availability_funcs_security_definer.sql
-- Las funciones de disponibilidad deben ver TODAS las citas (de todos los
-- clientes) para detectar colisiones y capacidad de cuartos.
--
-- Bug: la app móvil llama check_availability_for_booking_from_ai como usuario
-- 'authenticated' (cliente). Como las funciones NO eran SECURITY DEFINER,
-- corrían bajo la RLS del cliente, que solo le permite ver SUS propias citas
-- (bookings: client_id = auth.uid()). Resultado: la verificación de colisión y
-- de capacidad de cuartos solo contaba las citas del propio cliente, así que
-- reportaba "disponible" aunque el horario ya estuviera lleno con citas de
-- otros → permitía sobre-reservar desde la app. (Vía WhatsApp funcionaba porque
-- esas llamadas usan service_role, que ignora RLS.)
--
-- Fix: SECURITY DEFINER + search_path fijo. Las funciones solo devuelven
-- disponibilidad/slots sugeridos (sin exponer datos sensibles de otros
-- clientes), así que es seguro ejecutarlas como owner.
--
-- IMPORTANTE: ejecutar DESPUÉS de (re)crear estas funciones — un CREATE OR
-- REPLACE posterior sin SECURITY DEFINER revertiría el fix. Si se reaplica
-- staff_availability.sql / ai_availability_check.sql, volver a correr esto.
-- ============================================================================

alter function public.check_availability_for_booking_from_ai(
  uuid, date, time without time zone, integer, uuid, uuid
) security definer set search_path = public;

alter function public.check_staff_availability(
  uuid, uuid, timestamp with time zone, integer, uuid, uuid, boolean
) security definer set search_path = public;

alter function public._first_free_staff_slots_for_day(
  date, uuid, integer, uuid, uuid, integer
) security definer set search_path = public;
