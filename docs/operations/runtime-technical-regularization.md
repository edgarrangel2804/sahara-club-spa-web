# Runtime Technical Regularization

Fecha local de trabajo: 2026-07-21 / 2026-07-22 America/Tijuana.

Esta fase parte del commit de recuperacion exacta `fbd88e7` y agrega solo
regularizacion tecnica para poder auditar, compilar y probar el runtime
recuperado. No incluye trabajo de Gift Card Alerts, no modifica remoto y no
incorpora SQL suelto, HTML publico ni Flutter.

## Cambios Tecnicos

- Se agrego `deno.json` con tareas acotadas al runtime recuperado:
  - `deno task edge:fmt`
  - `deno task edge:lint`
  - `deno task edge:check`
  - `deno task edge:test`
- Se agrego `deno.lock` para fijar dependencias resueltas por Deno.
- Se agregaron tests puros en
  `supabase/functions/_shared/runtime_helpers_test.ts`.
- Se regularizo el tipado de clientes Supabase en helpers legacy como `any`
  documentado. Motivo: el runtime recuperado no trae tipos generados de DB y
  Supabase JS infiere tablas como `never`, lo que impide `deno check` aunque el
  codigo sea valido en runtime.
- Se cambio `web_concierge` de import `jsr:@supabase/supabase-js@2` a
  `https://esm.sh/@supabase/supabase-js@2` para evitar dependencia local de
  `node_modules` durante `deno check`.
- Se corrigieron avisos reales de lint sin cambiar contratos de negocio:
  variables no usadas, `const` preferible y un `await` explicito.

## Validacion Deno

Resultado final:

| Comando | Resultado |
|---|---|
| `deno task edge:fmt` | OK, 15 archivos revisados |
| `deno task edge:lint` | OK, 14 archivos revisados |
| `deno task edge:check` | OK, 12 entradas revisadas incluyendo test y funciones recuperadas |
| `deno task edge:test` | OK, 4 tests pasaron |

Tests cubiertos:

- Normalizacion WhatsApp MX/US en `normalizePhone`.
- Estado de configuracion Meta en `getConnectionStatusForDraft`.
- Helpers Stripe de moneda, tipos, centavos y pricing.
- Verificacion HMAC `v1` de Stripe webhook.

## Validacion Supabase Local

| Comando | Resultado |
|---|---|
| `supabase status` | OK con Docker elevado; stack local corriendo |
| `supabase db reset` | OK; aplico migraciones locales reconstruidas |
| `supabase functions serve --env-file .audit/edge-runtime.local.env` | OK; runtime local arranco y fue detenido |

Notas:

- El primer intento de `functions serve` fallo por BOM en el `.env` temporal
  generado por PowerShell. Se corrigio escribiendo el archivo como ASCII.
- El smoke de `functions serve` uso variables dummy en `.audit/`; no se usaron
  secretos reales y no se hizo ninguna llamada a Stripe, Meta, Anthropic ni
  webhooks.
- Supabase CLI omitio variables `SUPABASE_*` del `.env` temporal porque las
  inyecta el runtime local.
- Versiones observadas: Supabase CLI `2.95.4`; edge runtime local
  `1.73.13`; Deno local `2.9.3`.

## Matriz Runtime

| Componente | Entrada | Salida/efecto | Estado tecnico | Riesgo o nota |
|---|---|---|---|---|
| `stripe_webhook` | Stripe webhook | Confirma pagos, actualiza bookings/orders, invoca `send_deposit_receipt` | `deno check` OK | Mantener validacion de firma Stripe; fallback WhatsApp conserva lectura legacy de config |
| `create_booking_deposit_checkout` | Router WhatsApp / concierge web | Crea o reutiliza Stripe Checkout para anticipo | `deno check` OK | Publico en config actual; valida `booking_id` en `pending_payment` |
| `send_deposit_receipt` | `stripe_webhook` / recepcion | Genera PDF, guarda en bucket `receipts`, envia documento WhatsApp | `deno check` OK | Usa service role; si se publica requiere control de abuso/reenvio |
| `deposit_voucher` | Browser posterior al pago | Devuelve datos del voucher por `session_id` o `booking_id` | `deno check` OK | Riesgo de PII por identificador; requiere hardening antes de ampliar exposicion |
| `notify_unpaid_deposits` | Cron local/remoto | Alerta anticipos impagos a admins/backup | `deno check` OK | Config actual ya lo marca `verify_jwt=false`; conserva consulta legacy `access_token/is_active` |
| `notify_admins` | Trigger/pg_net | Notifica cambios de cita a admins/backup | `deno check` OK | Usa `loadBusinessSettings`; si se publica necesita caller controlado |
| `auto_confirm_bookings` | Cron | Confirma citas pagadas del dia siguiente a las 20:00 Tijuana | `deno check` OK | No marcar publico sin hardening: escribe bookings y acepta `?force=1` |
| `web_concierge` | Chat publico web | Consulta catalogo/FAQ/horarios, llama IA, puede crear booking y checkout | `deno check` OK | Usa service role desde endpoint publico; requiere rate limit/abuse guard |
| `whatsapp-ai-router` | Mensaje WhatsApp normalizado | Orquesta IA, tools, reservas, pagos y notificaciones | `deno check` OK | No se cambio `verify_jwt`; endpoint no tiene guard propio de autenticacion |
| `setup_admin_template_v2` | HTTP | Responde siempre 410 Gone | `deno check` OK | Funcion neutralizada, candidata a eliminacion futura |

## Decision Sobre `verify_jwt=false`

No se agregaron nuevos `verify_jwt=false` en `supabase/config.toml` durante esta
fase, aunque varias fuentes recuperadas lo mencionan en comentarios. Motivo:
marcar endpoints con service role o escritura como publicos cambia el blast
radius de seguridad. Antes de aplicar esos cambios se requiere una fase de
hardening o aprobacion explicita por funcion.

El config existente ya conserva `verify_jwt=false` para:

- `whatsapp-webhook`
- `stripe_webhook`
- `create_booking_deposit_checkout`
- `notify_unpaid_deposits`
- `create_appointment_deposit_payment_intent`
- `create_meta_template`

Pendientes de decision antes de despliegue:

- `notify_admins`
- `send_deposit_receipt`
- `deposit_voucher`
- `web_concierge`
- `setup_admin_template_v2`

No recomendar publicar sin cambios:

- `auto_confirm_bookings`
- `whatsapp-ai-router`

## Hallazgos Que No Se Corrigieron En Esta Fase

- `notify_unpaid_deposits` aun consulta `business_whatsapp_settings` con
  columnas legacy `access_token` e `is_active`, mientras el helper moderno usa
  secretos cifrados por `branch_id`.
- `send_deposit_receipt` solo recupera `phone_number_id` desde DB; el token Meta
  debe venir por env (`META_ACCESS_TOKEN`) o el envio falla best-effort.
- `deposit_voucher` devuelve datos de comprobante por identificador sin firma de
  un solo uso.
- `web_concierge` y `whatsapp-ai-router` usan service role y deben tener
  rate-limit, observabilidad y proteccion contra abuso antes de exponerse mas.
- Hay logs WhatsApp con telefonos y mensajes completos; revisar retencion y
  minimizacion de PII en una fase posterior.
