# End To End Flow Certification

Fecha local: 2026-07-23.

Regla: no se usaron Stripe real, Meta/WhatsApp real, clientes reales, pagos reales ni webhooks productivos. Las evidencias son tests unitarios/locales, build Flutter, Deno tests, SQL local y smoke de runtime.

Bloqueo formal: `supabase db reset` aplica todas las migraciones, pero termina con exit 1 por timeout del healthcheck local de Storage. La base reconstruida queda utilizable, Storage queda `healthy` despues y las pruebas SQL pasan; aun asi, la certificacion integral no se declara release final mientras ese comando no cierre en verde.

## Resumen

| Flujo | Resultado | Riesgo principal |
|---|---|---|
| Reserva web | CERTIFICADO LOCAL CON BLOQUEO CLI | `web_concierge` invoca RPCs reconstruidas y probadas; smoke sin LLM real. |
| Reserva WhatsApp | CERTIFICADO LOCAL CON BLOQUEO CLI | `whatsapp-ai-router` invoca las mismas RPCs reconstruidas y probadas; smoke sin Meta real. |
| Anticipo | CERTIFICACION PENDIENTE | Tokens, voucher y helpers pasan; no se probo Stripe sandbox externo. |
| Gift Card | CERTIFICACION PENDIENTE | Fulfillment y tokens pasan; funciones nuevas no estan desplegadas remoto. |
| Canje | CERTIFICADO LOCAL | RPC `redeem_service_gift_card` existe con `search_path` y tests helper pasan. |
| Recepcion | CERTIFICADO LOCAL | Alertas, acciones, RLS/Realtimes y grants locales pasan; remoto pendiente. |
| Landing | CERTIFICADO | Assets, secciones, Store y concierge cliente pasan en tests/build. |

## Reserva web

| Paso | Prueba | Resultado | Evidencia | Riesgo |
|---|---|---|---|---|
| Catalogo | `web_concierge` compila y consulta `services` | PASS tecnico | `deno task edge:check` | BAJO |
| Seleccion | Prompt usa catalogo server-side | PASS tecnico | handler compilado | BAJO |
| Cliente | Input normalizado en handler | PASS tecnico | Deno check | MEDIO |
| Cita | RPC `create_pending_booking_from_ai` | PASS local | `supabase/tests/ai_booking_rpcs.sql`, duracion server-side, PII-safe response e idempotencia | MEDIO |
| Anticipo | `create_booking_deposit_checkout` compila | PASS tecnico | Deno check | MEDIO |
| Checkout mock | No llamada externa | NO EJECUTADO | Restriccion de no Stripe real | MEDIO |
| Confirmacion | Depende de RPC/checkout | PASS local parcial | RPC crea `pending_reception`; checkout externo no ejecutado | MEDIO |

## Reserva WhatsApp

| Paso | Prueba | Resultado | Evidencia | Riesgo |
|---|---|---|---|---|
| Mensaje mock | Runtime helper tests | PASS parcial | `deno task edge:test` | MEDIO |
| Concierge/router | `whatsapp-ai-router` compila | PASS tecnico | `edge:check` | MEDIO |
| Seleccion | Reglas en router | PASS tecnico | source checked | MEDIO |
| Checkout mock | No llamada externa | NO EJECUTADO | Restriccion de no Meta/Stripe real | MEDIO |
| Cita | RPCs de disponibilidad/booking | PASS local | `supabase/tests/ai_booking_rpcs.sql`, 18 aserciones de comportamiento + 6 de grants | MEDIO |

## Anticipo

| Paso | Prueba | Resultado | Evidencia | Riesgo |
|---|---|---|---|---|
| Pago confirmado mock | Helpers de firma y estado | PASS | Deno tests voucher | BAJO |
| Booking confirmado | Handler compila | PASS tecnico | `stripe_webhook` check | MEDIO |
| Comprobante | `send_deposit_receipt` compila | PASS tecnico | `edge:check` | MEDIO |
| Token firmado | Tests HMAC/TTL | PASS | Deno tests | BAJO |
| Consulta publica limitada | HTML y helper tests | PASS | Flutter receipt tests + SQL buckets | BAJO |

## Gift Card

| Paso | Prueba | Resultado | Evidencia | Riesgo |
|---|---|---|---|---|
| Formulario | Validacion Dart | PASS | Flutter tests | BAJO |
| Destinatario/dedicatoria/fecha | Sanitizacion y fechas | PASS | Flutter/Deno tests | BAJO |
| Orden/pago confirmado mock | Helper fulfillment | PASS | Deno tests | MEDIO |
| Gift Card | Tabla/columnas existen | PASS | SQL schema local | BAJO |
| PDF/Storage privado | Buckets privados PDF | PASS | SQL schema local | BAJO |
| Enlace firmado | HMAC/TTL tests | PASS | Deno tests | BAJO |
| WhatsApp ledger | Delivery ledger e idempotencia | PASS local | Deno tests + indices | MEDIO |
| Alerta recepcion/admin | Alertas e indices | PASS local | Flutter/Deno/SQL | MEDIO |

## Canje

| Paso | Prueba | Resultado | Evidencia | Riesgo |
|---|---|---|---|---|
| Codigo | No se expone en logs de tests | PASS | Deno tests | BAJO |
| Vigencia | Tres meses calendario | PASS | Flutter/Deno tests | BAJO |
| Canje transaccional | RPC existe | PASS local | `redeem_service_gift_card` con `search_path` | BAJO |
| Saldo/sesiones | Helper bloquea estados invalidos | PASS | Deno tests | MEDIO |
| Auditoria | Transactions table existe | PASS | SQL schema local | BAJO |

## Recepcion

| Paso | Prueba | Resultado | Evidencia | Riesgo |
|---|---|---|---|---|
| Alerta | Alert model/service tests | PASS | Flutter tests | BAJO |
| Detalle | Gift Card action parsing | PASS | Flutter tests | BAJO |
| Ver tarjeta | Signed asset URL allowlist | PASS | Flutter tests | BAJO |
| Regenerar enlace | Backend action compila | PASS tecnico | `edge:check` | MEDIO |
| Reenvio explicito | Gate de double click | PASS | Flutter tests | BAJO |
| Resolver alerta | RLS/policies presentes | PASS local | SQL schema local y `security_boundaries.sql` | MEDIO |

## Landing

| Paso | Prueba | Resultado | Evidencia | Riesgo |
|---|---|---|---|---|
| Hero | Asset path case-sensitive | PASS | `landing_regularization_test.dart` | BAJO |
| Multimedia | `Portada-2.mp4` existe en build | PASS | build asset check | BAJO |
| Experiencia | PNGs recuperados | PASS | Flutter tests | BAJO |
| Store | Gift Card Digital preservada | PASS | Flutter tests | BAJO |
| Reservacion | CTA abre concierge | PASS cliente | Flutter tests/source | MEDIO por dependencias externas no reales |
| Concierge | Runtime smoke carga | PASS tecnico | `functions serve` | MEDIO por LLM externo no ejecutado |

## Timezone

| Requisito | Evidencia | Resultado |
|---|---|---|
| America/Tijuana | `booking_time_utils_test.dart`, `runtime_helpers_test.ts` | PASS |
| Cambio dia UTC/local | Flutter booking tests | PASS |
| Horario de verano | Flutter booking tests + Deno Gift Card helper | PASS |
| Citas futuras | Booking helper tests | PASS |
| Alertas | Reception alerts use Tijuana commercial date | PASS |
| `valid_from`/`expires_on` | Gift Card form and fulfillment tests | PASS |
| Tres meses calendario | Flutter/Deno tests | PASS |
| Ultimo dia de mes | Deno validity clamps month end | PASS |
| Cambio de ano | Cubierto por calendario helper | PASS parcial |
| Vigencia durante `expires_on` | Deno redemption helper | PASS |
| Tokens UTC | Deno token tests | PASS |

## Idempotencia

| Area | Evidencia | Resultado |
|---|---|---|
| Stripe evento/session duplicado | Indices `orders.stripe_session_id`, `payments.payment_intent_id`; helpers compilan | CERTIFICACION PENDIENTE |
| Gift Card mismo `order_item_id` | Unique `gift_cards_order_item_id_key` y Deno fulfillment tests | PASS local |
| Gift Card PDF/balance/vigencia no regenerados | Deno fulfillment tests | PASS helper |
| WhatsApp destinatario/comprador/admin | Delivery ledger tests y admin notification skip/retry | PASS helper |
| Reception alerts | Unique `reception_alerts_one_gift_card_purchase` | PASS local |
| Comprobantes | Voucher token tests TTL/reuse/tamper | PASS |
| Reserva IA web/WhatsApp | `bookings.ai_idempotency_key`, `p_request_id`, SQL replay, grants `service_role` only | PASS local |
