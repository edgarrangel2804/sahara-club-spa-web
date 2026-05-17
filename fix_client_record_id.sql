-- ══════════════════════════════════════════════════════════════════════
-- FIX: Vincular bookings existentes con su client_record_id correcto
-- Une profiles con clients por nombre exacto y actualiza las reservas
-- ══════════════════════════════════════════════════════════════════════

-- PASO 1 (preview): Ver qué reservas se van a actualizar antes de ejecutar
SELECT
  b.id,
  b.booking_date,
  b.status,
  p.full_name AS profile_name,
  c.id        AS client_record_id_a_asignar
FROM bookings b
JOIN profiles p ON p.id = b.client_id
JOIN clients  c ON LOWER(TRIM(c.full_name)) = LOWER(TRIM(p.full_name))
WHERE b.client_record_id IS NULL
ORDER BY b.booking_date DESC;

-- ══════════════════════════════════════════════════════════════════════
-- PASO 2 (ejecución): Ejecutar el UPDATE después de confirmar el preview
-- ══════════════════════════════════════════════════════════════════════
UPDATE bookings b
SET client_record_id = c.id
FROM profiles p
JOIN clients c ON LOWER(TRIM(c.full_name)) = LOWER(TRIM(p.full_name))
WHERE b.client_id = p.id
  AND b.client_record_id IS NULL;

-- ══════════════════════════════════════════════════════════════════════
-- PASO 3 (verificación): Confirmar que las reservas quedaron vinculadas
-- ══════════════════════════════════════════════════════════════════════
SELECT
  b.booking_date,
  b.status,
  b.client_record_id,
  c.full_name
FROM bookings b
JOIN clients c ON c.id = b.client_record_id
WHERE c.full_name ILIKE '%rodrigo%'
ORDER BY b.booking_date DESC;
