-- ══════════════════════════════════════════════════════════
-- PASO 1: Ver el ID del cliente Rodrigo Rangel en la tabla clients
-- ══════════════════════════════════════════════════════════
SELECT id, full_name, email, phone, created_at
FROM clients
WHERE full_name ILIKE '%rodrigo%';

-- ══════════════════════════════════════════════════════════
-- PASO 2: Ver TODAS las reservas donde client_record_id
--         apunta a algún registro de la tabla clients
--         (reemplaza el UUID con el resultado del PASO 1)
-- ══════════════════════════════════════════════════════════
SELECT
  b.id,
  b.booking_date,
  b.booking_time,
  b.status,
  b.client_id,
  b.client_record_id,
  c.full_name AS client_record_name,
  p.full_name AS profile_name
FROM bookings b
LEFT JOIN clients  c ON c.id = b.client_record_id
LEFT JOIN profiles p ON p.id = b.client_id
WHERE
  c.full_name ILIKE '%rodrigo%'
  OR p.full_name ILIKE '%rodrigo%'
ORDER BY b.booking_date DESC, b.booking_time DESC;

-- ══════════════════════════════════════════════════════════
-- PASO 3: Contar cuántas tienen client_record_id NULL
--         (estas NO aparecen en el historial actual)
-- ══════════════════════════════════════════════════════════
SELECT
  COUNT(*) FILTER (WHERE client_record_id IS NOT NULL) AS con_client_record_id,
  COUNT(*) FILTER (WHERE client_record_id IS NULL)     AS sin_client_record_id,
  COUNT(*) AS total
FROM bookings b
LEFT JOIN profiles p ON p.id = b.client_id
WHERE p.full_name ILIKE '%rodrigo%';
