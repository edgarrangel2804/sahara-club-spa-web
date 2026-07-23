# Deployment Manifest

Estado: propuesta, no ejecutada.

Veredicto actual: `BLOQUEADO POR SUPABASE`.

## Git

| Campo | Valor |
|---|---|
| Rama origen | `chore/regularize-production-baseline` |
| HEAD | `d132e36c1daca65b9e12fd017b4175b7473e1492` |
| Base | `f38833922e7a8dac300c0b57067c9654c38e7b99` |
| Commits adelante de `origin/main` | 43 |
| Estrategia futura | Abrir PR, revisar, CI, backup remoto, merge controlado. No push/deploy desde esta certificacion. |

## Migraciones

| Orden | Archivo | Objetos afectados | Compatibilidad | Riesgo | Rollback logico |
|---:|---|---|---|---|---|
| 1 | `20260721000000_ecommerce_notification_baseline.sql` | ecommerce, profiles, bookings, settings, initial RLS | Base amplia | ALTO | Restaurar backup o migracion correctiva |
| 2 | `20260721000100_reception_alerts_baseline.sql` | `reception_alerts`, Realtime, policies | Agrega alertas | MEDIO | Desactivar productores/alert UI |
| 3 | `20260721000200_reception_alert_producers.sql` | triggers productores de alertas | Depende de bookings | MEDIO | Drop/disable triggers correctivos |
| 4 | `20260722010000_gift_card_digital_fulfillment.sql` | `gift_cards`, transactions, deliveries, Storage metadata | Agrega fulfillment | ALTO | No borrar tarjetas; migracion correctiva |
| 5 | `20260722020000_integrate_gift_card_alerts.sql` | alerta Gift Card, admin notification ledger | Depende Gift Cards | MEDIO | Desactivar alertas admin |
| 6 | `20260722030000_security_hardening_functions.sql` | security definer/search_path helpers | Endurece RPCs | ALTO | Migracion correctiva, no rollback ciego |
| 7 | `20260722030100_security_hardening_rls_grants.sql` | RLS/grants commerce/admin | Reduce acceso | ALTO | Migracion correctiva basada en backup |
| 8 | `20260722030200_security_hardening_storage.sql` | buckets privados y policies Storage | Reduce acceso | ALTO | Ajustar policies; no hacer buckets publicos |

Nota bloqueante: agregar una migracion revisada para RPCs de reserva/IA antes de despliegue si esos flujos deben quedar certificados desde cero.

## Edge Functions

| Funcion | Estado local | Seguridad | `verify_jwt` esperado | Secrets requeridos | Orden |
|---|---|---|---|---|---:|
| `create_checkout_session` | modificada | Publica controlada, server-side pricing | default/true | Stripe, Supabase | 1 |
| `confirm_order_payment` | modificada | Publica controlada, Stripe verify | default/true | Stripe, Supabase, Gift Card token secret | 2 |
| `stripe_webhook` | modificada | Webhook firmado | false | Stripe webhook, Supabase, internal | 3 |
| `create_booking_deposit_checkout` | modificada | Interna/publica controlada | false | Stripe, voucher secret, allowlist | 4 |
| `deposit_voucher` | modificada | Publica por token firmado | false | `DEPOSIT_VOUCHER_SIGNING_SECRET`, TTL | 5 |
| `send_deposit_receipt` | modificada | Interna/operacional | false | WhatsApp, Supabase, internal | 6 |
| `gift_card_download` | nueva | Publica por token firmado | false | `GIFT_CARD_DOWNLOAD_SIGNING_SECRET`, TTL | 7 |
| `gift_card_reception_actions` | nueva | Operacional con JWT | true | Supabase, WhatsApp | 8 |
| `notify_admins` | modificada | Interna service/internal secret | false | WhatsApp, internal | 9 |
| `auto_confirm_bookings` | modificada | Interna cron/service | false | Supabase, internal | 10 |
| `notify_unpaid_deposits` | modificada | Interna cron/service | false | Supabase, WhatsApp | 11 |
| `whatsapp-ai-router` | modificada | Webhook/router controlado | false | WhatsApp, Anthropic, Supabase | 12 |
| `web_concierge` | modificada | Publica con CORS/rate limits | false | Anthropic, Supabase, allowlist | 13 |
| `setup_admin_template_v2` | modificada | Neutralizada | default/true o false actual | Ninguno operativo | 14 |

## Web

| Item | Valor |
|---|---|
| Build command local | `flutter build web --release` PASS |
| Vercel config | `buildCommand: bash build.sh`, `outputDirectory: build/web` |
| Assets criticos | `assets/videos/Portada-2.mp4`, `assets/experiencia/*.png` |
| Rutas publicas | `/`, `/pagar-anticipo`, `/pagar-anticipo/:bookingId`, `/comprobante-anticipo.html` |
| Gift Card download | Edge `gift_card_download` con token firmado |
| Comprobantes | `deposit_voucher` + `voucher_token` |

## Storage

| Bucket | Privacidad | Policies | Creacion | Verificacion |
|---|---|---|---|---|
| `gift-card-assets` | Privado | Service role only | Migracion storage/hardening | SQL local PASS |
| `receipts` | Privado | Service role only | Migracion storage/hardening | SQL local PASS |

## Secrets requeridos

No incluir valores.

| Nombre | Clasificacion |
|---|---|
| `DEPOSIT_VOUCHER_SIGNING_SECRET` | NUEVO/VERIFICAR |
| `DEPOSIT_VOUCHER_TOKEN_TTL_SECONDS` | NUEVO/VERIFICAR |
| `GIFT_CARD_DOWNLOAD_SIGNING_SECRET` | NUEVO/VERIFICAR |
| `GIFT_CARD_DOWNLOAD_TOKEN_TTL_SECONDS` | NUEVO/VERIFICAR |
| `SAHARA_INTERNAL_FUNCTION_SECRET` | NUEVO/VERIFICAR |
| Stripe secret key | VERIFICAR |
| Stripe webhook secret | VERIFICAR |
| WhatsApp/Meta access token | VERIFICAR |
| WhatsApp phone number/business ids | VERIFICAR |
| Supabase URL/anon/service role | YA EXISTE/VERIFICAR |
| Anthropic key o vault RPC correspondiente | VERIFICAR |
| CORS/allowed origins | ACTUALIZAR |

## Orden de despliegue propuesto

No ejecutar hasta resolver bloqueo Supabase.

1. Backup remoto y snapshot de schema.
2. Registrar estado actual remoto: Git, Supabase functions, migrations, buckets, Vercel deployment.
3. Configurar/verificar secrets nuevos.
4. Agregar migracion faltante para RPCs de reserva/IA o decidir desactivar flujos dependientes.
5. Aplicar migraciones.
6. Verificar RLS, grants, buckets privados y Realtime.
7. Desplegar Edge Functions en orden de dependencias.
8. Smoke tests sandbox/local controlado.
9. Desplegar Flutter Web.
10. Prueba supervisada de anticipo.
11. Prueba supervisada de Gift Card.
12. Confirmar Recepcion.
13. Confirmar WhatsApp.
14. Monitoreo.
15. Cierre o rollback.
