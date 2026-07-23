# Clients Receipts Technical Regularization

Fecha local de trabajo: 2026-07-22 America/Tijuana.

Esta fase parte del commit de recuperacion exacta `5d170c5` y regulariza tres
superficies productivas recuperadas: modulo de clientes Flutter, acciones de
comprobante de anticipo en Agenda y pagina publica de comprobante. No modifica
el remoto, no despliega funciones, no reejecuta webhooks y no integra Gift Card
Alerts.

## Archivos Regularizados

| Archivo | Decision | Resultado |
|---|---|---|
| `lib/features/clients/clients_module.dart` | Mantener como runtime Sahara productivo | Se integra normalizacion minima de email/telefono sin reescribir el modulo monolitico. |
| `lib/features/clients/client_identity_helpers.dart` | Extraer helpers puros | Telefonos MX/Baja, emails sinteticos, duplicados probables y record canonico quedan testeables. |
| `lib/features/receipts/deposit_receipt_actions.dart` | Reconectar a Agenda con guardas | Carga URL firmada existente, reenvia WhatsApp solo por accion explicita y valida UUID/URL. |
| `lib/pages/agenda_page.dart` | Conexion minima | El boton de comprobante abre el dialogo real con `booking.id`. |
| `web/comprobante-anticipo.html` | Sanitizar pagina publica | Fase 3B reemplaza `token/session_id` temporal por `voucher_token` firmado; elimina anon key y renderiza con `textContent`. |
| `supabase/functions/deposit_voucher` | Reducir superficie publica | Rechaza identificadores publicos debiles, valida HMAC/TTL/proposito y exige pago confirmado. |
| `supabase/functions/send_deposit_receipt` | Endurecer reenvio | Valida UUID, exige booking pagado y sanitiza errores publicos. |
| `supabase/functions/_shared/deposit_receipts.ts` | Centralizar contrato | Lookup, firma/verificacion de token, pago, folio, monto y payload publico quedan en helper puro. |

## Contrato Flutter/Edge

| Flujo | Caller | Identificador permitido | Dato devuelto | Efecto secundario |
|---|---|---|---|---|
| Abrir comprobante en Agenda | Flutter autenticado | `booking_id` UUID interno | URL firmada del bucket privado si existe | Ninguno. |
| Reenviar comprobante | Flutter autenticado | `booking_id` UUID interno | `ok`, `folio`, `signed_url`, `whatsapp_sent` | Genera/sube PDF y envia WhatsApp best-effort. |
| Consultar voucher publico | Browser posterior al pago | `voucher_token` HMAC firmado | Folio, cliente display, servicio, fecha/hora, monto MXN | Ninguno. |

Notas de seguridad:

- `booking_id` queda prohibido en la consulta publica.
- Fase 3B elimina `session_id` como autorizacion del comprobante publico.
- El endpoint no devuelve telefono, email, notas, ids internos, metadata ni URL
  firmada privada.
- El HTML mantiene URL de proyecto para invocar la Edge Function, pero ya no
  contiene anon key ni consulta tablas directamente.

## Clientes

`ClientsModule` sigue clasificado como productivo Sahara y no copiable tal cual.
La regularizacion local se limita a identidad de contacto:

- telefono canonico para busqueda y guardado (`52` + 10 digitos en MX/Baja);
- limpieza de prefijo legacy `521`;
- email lower-case;
- emails sinteticos excluidos de deduplicacion;
- seleccion de cliente canonico por fecha de creacion.

Riesgo residual:

- el modulo continua mezclando UI, Supabase, historiales, paquetes,
  membresias, Gift Cards y ventas;
- no se implementa merge automatico de clientes en esta fase;
- la PII sigue visible para usuarios con acceso al modulo.

## Comprobantes

El dialogo de comprobante deja de asumir que reenviar es automatico. El operador
ve si existe PDF, puede abrirlo y puede ejecutar "Reenviar WhatsApp" de forma
explicita. La Edge Function `send_deposit_receipt` conserva el envio best-effort:
si Meta falla, puede devolver PDF generado sin confirmar WhatsApp.

La pagina publica de comprobante ahora:

- no usa `innerHTML` con datos remotos;
- valida formato de `voucher_token` antes de llamar Edge;
- usa `cache: no-store`;
- no acepta `booking_id`;
- muestra solo comprobante pagado.

## Validacion Ejecutada

| Comando | Resultado |
|---|---|
| `dart format ...` | OK en archivos Dart modificados. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | OK con deuda previa reportada; no falla. |
| `flutter test` | Fase 3B: OK, 24 tests pasaron. |
| `deno task edge:fmt/lint/check/test` | Fase 3B: OK con Deno local `C:\Users\edgar\.deno\bin\deno.exe`. |
| `supabase status` | OK; stack local corriendo. |
| `supabase db reset` | OK; aplico migraciones locales reconstruidas. |
| `supabase functions serve --no-verify-jwt` | OK smoke local; runtime arranco y fue detenido automaticamente. |

Tests agregados:

- `test/features/clients/client_identity_helpers_test.dart`
- `test/features/receipts/deposit_receipt_actions_test.dart`
- nuevos casos Deno en `supabase/functions/_shared/runtime_helpers_test.ts`

## Pendientes

- Ejecutar `deno task edge:fmt`, `edge:lint`, `edge:check` y `edge:test` en una
  terminal con Deno disponible en PATH. El smoke de `functions serve` si cargo
  el edge runtime local compatible con Deno.
- Configurar `DEPOSIT_VOUCHER_SIGNING_SECRET` y TTL productivo antes de
  desplegar el token firmado.
- Definir autenticacion/rate-limit para `send_deposit_receipt` antes de
  publicarlo o desplegarlo.
- No fusionar Gift Card Alerts todavia; requiere fase dedicada de composicion.
