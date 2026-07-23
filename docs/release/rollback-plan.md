# Rollback Plan

Estado: propuesta, no ejecutada.

## Antes del despliegue

| Evidencia | Accion |
|---|---|
| Backup remoto | Crear backup/snapshot antes de migrar. |
| Schema snapshot | Guardar estructura y lista de migrations remotas. |
| Functions list | Guardar nombre, version y `updated_at` de cada Edge Function. |
| Deployment activo | Registrar URL, alias, fecha y SHA Vercel. |
| Hashes | Registrar HEAD Git y hashes de assets criticos. |
| Branches | Registrar `origin/main`, rama RC y PR futuro. |

## Fallo de migracion

1. Detener proceso.
2. No desplegar Edge ni frontend.
3. Identificar migracion fallida y objeto afectado.
4. Si no hubo commit parcial irreversible, restaurar desde backup.
5. Si hubo cambios parciales con datos nuevos, aplicar migracion correctiva revisada.
6. Repetir reset local con la correccion antes de nuevo intento.

No usar comandos destructivos sin backup confirmado y aprobacion humana.

## Fallo Edge

1. No desplegar frontend nuevo si Edge no esta sano.
2. Revertir la funcion afectada a la version anterior desde Supabase Dashboard/CLI con version conocida.
3. Mantener esquema compatible si ya fue aplicado.
4. Desactivar flujo nuevo por configuracion cuando exista kill switch.
5. Revisar logs sanitizados, sin imprimir tokens ni PII.

## Fallo Web

1. Rollback Vercel al deployment anterior registrado.
2. Mantener migraciones/Edge si son compatibles con web anterior.
3. Si el web anterior no soporta cambios de esquema, activar modo mantenimiento o ocultar entrada del flujo nuevo.

## Fallo Gift Card

1. No borrar tarjetas ni pagos.
2. Detener venta nueva de Gift Cards si el fulfillment falla.
3. Conservar orden/pago como fuente de verdad.
4. Reintentar fulfillment idempotente por `order_item_id`.
5. Resolver entrega/PDF con atencion manual si WhatsApp o Storage fallan.
6. Registrar acciones manuales.

## Fallo WhatsApp

1. Mantener compra y cita; no revertir pagos.
2. Reenvio manual desde recepcion cuando el ledger lo permita.
3. No reintentar destinos exitosos.
4. Revisar configuracion Meta sin exponer token.

## Fallo de seguridad

1. Desactivar endpoint o funcion afectada.
2. Rotar secreto si hay sospecha de exposicion.
3. Revertir deployment web si amplia superficie publica.
4. Revisar logs con filtros de PII/tokens.
5. Aplicar parche y pruebas antes de reactivar.

## Fallo por RPCs de reserva/IA

1. No activar `web_concierge` ni `whatsapp-ai-router` para reservas nuevas.
2. Mantener derivacion a recepcion/WhatsApp manual.
3. Aplicar migracion correctiva sobre `20260722040000_ai_booking_rpcs.sql`.
4. Certificar `supabase db reset`, `supabase/tests/ai_booking_rpcs.sql` y smoke de reserva mock antes de reintentar despliegue.
