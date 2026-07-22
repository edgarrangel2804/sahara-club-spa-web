# Signed Deposit Voucher Regularization

Fecha local de trabajo: 2026-07-22 America/Tijuana.

Esta fase parte del HEAD `91e5db131589e741392bbb600a5162d8a71f31ff` y
regulariza el acceso publico al comprobante de anticipo mediante un token HMAC
firmado por backend. No modifica remoto, no despliega funciones, no llama Stripe
live, no reejecuta webhooks y no integra Gift Card Alerts.

## Token

Formato:

`base64url(payload_json_canonico).base64url(hmac_sha256(payload_segment))`

Secret independiente:

- `DEPOSIT_VOUCHER_SIGNING_SECRET`

TTL configurable:

- `DEPOSIT_VOUCHER_TOKEN_TTL_SECONDS`
- default local: `604800` segundos, 7 dias
- minimo: 60 segundos
- maximo: 30 dias

Claims:

| Claim | Uso |
|---|---|
| `version` | Version del contrato; actual `1`. |
| `purpose` | Debe ser `deposit_voucher`. |
| `booking_id` | Scope interno del comprobante; no se muestra al publico. |
| `order_id` | Reservado, `null` para anticipo de cita. |
| `issued_at` | Unix seconds de emision. |
| `expires_at` | Unix seconds de expiracion obligatoria. |
| `nonce` | Entropia aleatoria para evitar tokens deterministas. |

No contiene nombre, telefono, email, monto, datos Stripe, service role ni
codigos internos.

## Flujo

1. `create_booking_deposit_checkout` valida `booking_id` interno y estado
   `pending_payment`.
2. Genera `voucher_token` con HMAC SHA-256.
3. Construye `success_url` desde allowlist propia, no desde el body del cliente.
4. Envia a Stripe una URL de exito con `voucher_token` codificado.
5. El navegador abre `web/comprobante-anticipo.html?voucher_token=...`.
6. El HTML lee el token y lo elimina de la barra con `history.replaceState`.
7. El HTML hace `POST` a `deposit_voucher` con JSON `{ voucher_token }`.
8. `deposit_voucher` valida estructura, firma, proposito, version y expiracion.
9. Solo despues consulta `bookings` con service role por `booking_id`.
10. Si el pago esta confirmado, devuelve datos publicos minimos.

## Respuesta Publica

Permitido:

- `business_name`
- `receipt_number`
- `customer_display_name`
- `service_name`
- `amount`
- `currency`
- `paid_at`
- `booking_date`
- `booking_time`
- `payment_status`
- `receipt_status`

Omitido:

- email
- telefono
- ids internos completos
- Payment Intent
- Checkout Session
- metadata
- notas internas
- URLs firmadas privadas
- tokens

## HTML

`web/comprobante-anticipo.html` ahora lee solo `voucher_token`, no contiene anon
key, no consulta tablas, invoca solo `deposit_voucher`, usa `POST`, valida JSON,
no usa `innerHTML`, no escribe el token en consola, no usa `localStorage` y
muestra estados de carga, error, pendiente y pagado.

## Flutter

`deposit_receipt_actions.dart` no firma tokens. Agrega allowlist de hosts,
validacion de `voucher_token` cuando aparece en un enlace, rechazo de HTTP salvo
localhost, limite razonable de longitud, parser de respuesta de enlace
autorizado y redaccion de tokens.

## Rate Limit Y Logs

`deposit_voucher` agrega rate limit en memoria por huella de token + prefijo de
IP. Los logs tecnicos registran `sha256:<prefijo>`, nunca el token completo.

Limitacion: al ser stateless, un token valido puede reutilizarse hasta su TTL.
No hay revocacion fina por token en esta fase.

## Success URL

El backend arma la URL destino con allowlist:

- `https://saharaclubspa.com/comprobante-anticipo.html`
- `https://www.saharaclubspa.com/...`
- `http://localhost/...`
- `http://127.0.0.1/...`

El cliente no controla el dominio. Cualquier query/hash previo se elimina antes
de agregar `voucher_token`.

## Validacion Ejecutada

| Comando | Resultado |
|---|---|
| `C:\Users\edgar\.deno\bin\deno.exe --version` | OK, Deno 2.9.3. |
| `deno fmt ...` | OK. |
| `deno task edge:fmt` | OK, 16 archivos. |
| `deno task edge:lint` | OK, 15 archivos. |
| `deno task edge:check` | OK. |
| `deno task edge:test` | OK, 12 tests. |
| `dart format ...` | OK. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | OK con deuda previa reportada; no falla. |
| `flutter test` | OK, 24 tests. |
| `git diff --check` | OK. |
| `supabase status` | OK, stack local corriendo. |
| `supabase db reset` | OK, migraciones locales aplicadas. |
| `supabase functions serve --env-file .audit/edge-runtime.local.env --no-verify-jwt` | OK smoke local; runtime arranco y fue detenido. |

Notas:

- El `.env` de `.audit` fue temporal y uso secretos falsos/locales.
- Supabase CLI omitio variables `SUPABASE_*` del env temporal porque las inyecta
  el runtime local.
- La CLI local sirve todas las funciones; no permite aislar por slug en esta
  version.

## Pendientes

- Configurar `DEPOSIT_VOUCHER_SIGNING_SECRET` como secret real antes de desplegar.
- Elegir TTL productivo final.
- Si se requiere revocacion antes de expiracion, agregar ledger persistente.
- Mantener `send_deposit_receipt` con autenticacion/rate-limit antes de exponerlo
  fuera de recepcion.
