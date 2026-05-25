-- Sahara Club Spa - RESET OPERATIVO CONTROLADO
-- Borra datos operativos de prueba conservando estructura, config, auth, catálogo
-- y los 2 clientes con teléfono real (Rodrigo + Edgar).
-- Ejecutado 2026-05-25.

BEGIN;

-- 1. Logs y runs de sistema
DELETE FROM public.whatsapp_worker_runs;
DELETE FROM public.notification_log;
DELETE FROM public.notifications;
DELETE FROM public.messages;
DELETE FROM public.chat_messages;
DELETE FROM public.chat_conversations;
DELETE FROM public.chats;

-- 2. WhatsApp operativo
DELETE FROM public.whatsapp_logs;
DELETE FROM public.whatsapp_queue;
DELETE FROM public.whatsapp_webhook_events;

-- 3. Ventas y pagos (hijos antes)
DELETE FROM public.payments;
DELETE FROM public.sale_items;
DELETE FROM public.sales;
DELETE FROM public.order_items;
DELETE FROM public.orders;

-- 4. Caja / nómina / accesos (NO fixed_expenses)
DELETE FROM public.cash_box_movements;
DELETE FROM public.cash_register_sessions;
DELETE FROM public.payroll_entries;
DELETE FROM public.supplier_expenses;
DELETE FROM public.expenses;
DELETE FROM public.receipts;
DELETE FROM public.digital_access;

-- 5. Bookings + historial (historia primero)
DELETE FROM public.appointment_status_history;
DELETE FROM public.bookings;
DELETE FROM public.appointments;

-- 6. Membresías y gift cards
DELETE FROM public.client_memberships;
DELETE FROM public.memberships;
DELETE FROM public.gift_cards;

-- 7. Clientes sin teléfono (conserva Rodrigo + Edgar)
DELETE FROM public.clients
WHERE phone IS NULL OR trim(phone) = '';

COMMIT;
