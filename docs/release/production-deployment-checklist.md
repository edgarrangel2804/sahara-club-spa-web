# Production Deployment Checklist

Estado: no ejecutar todavia.

| Paso | Responsable | Comando conceptual | Validacion | Resultado esperado | Detenerse si | Rollback asociado |
|---:|---|---|---|---|---|---|
| 1 | Tech lead | Crear backup remoto | Backup visible/restaurable | Snapshot confirmado | No hay backup | Fallo de migracion |
| 2 | Tech lead | Registrar estado actual | Git/Supabase/Vercel documentados | Hashes y versiones guardadas | Falta Vercel/Supabase metadata | Fallo Web/Edge |
| 3 | Admin Supabase | Verificar secrets | Solo nombres, no valores en docs | Secrets requeridos presentes | Falta secret critico | No desplegar |
| 4 | DB owner | Verificar RPCs de reserva/IA | `supabase db reset` + `supabase/tests/ai_booking_rpcs.sql` | Reserva web/WhatsApp reproducible y reset con exit 0 | RPCs no existen, grants incorrectos o reset sale 1 | Fallo por RPCs / reset local |
| 5 | DB owner | Aplicar migraciones | Migration table y schema | Todas aplicadas en orden | Error o drift inesperado | Fallo de migracion |
| 6 | Security | Verificar RLS/Storage | Queries de policies/buckets | Buckets privados, anon bloqueado | Anon accede a datos privados | Fallo seguridad |
| 7 | Backend | Desplegar Edge Functions | Versiones activas | Handlers nuevos/modificados activos | Handler no carga | Fallo Edge |
| 8 | QA | Smoke sandbox/local | No Stripe/WhatsApp real salvo prueba supervisada autorizada | Tokens/flows mock OK | Error de auth/token | Fallo Edge |
| 9 | Web | Deploy Flutter Web | Vercel deployment listo | Alias correcto y SHA esperado | Build falla o alias incorrecto | Fallo Web |
| 10 | Operaciones | Prueba anticipo supervisada | Pago sandbox/controlado | Comprobante y token OK | Pago real no autorizado | Fallo anticipo |
| 11 | Operaciones | Prueba Gift Card supervisada | Compra sandbox/controlada | PDF privado, token, alerta, ledger | Duplicado o PII expuesta | Fallo Gift Card |
| 12 | Recepcion | Confirmar alertas | Bell/banner/detalle | Alertas visibles y resolubles | No llega alerta | Fallo Recepcion |
| 13 | WhatsApp owner | Confirmar mensajes | Meta sandbox/controlado | Envio/ledger correctos | Envios duplicados o token error | Fallo WhatsApp |
| 14 | Tech lead | Monitoreo | Logs sin PII, errores bajos | Sistema estable | Error seguridad/finanzas | Fallo seguridad |
| 15 | Tech lead | Cierre | Checklist firmado | Release cerrado | Incidente abierto | Rollback especifico |

## Criterio de avance

No iniciar despliegue hasta que:

- `supabase db reset` cierre con exit 0, reconstruya las RPCs de reserva/IA requeridas y `supabase/tests/ai_booking_rpcs.sql` pase.
- `dart format --output=none --set-exit-if-changed .` pase o exista decision explicita de aceptar deuda de formato.
- Vercel tenga metadata read-only valida de proyecto, alias/deployment activo y SHA esperado.
- Secrets requeridos esten verificados por nombre.
- Rollback haya sido revisado por responsable humano.
