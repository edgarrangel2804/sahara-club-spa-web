# AI Booking RPCs Recovery Plan

Fecha local: 2026-07-23.

Worktree: `C:\Proyectos\sahara-club-spa-web-regularization`
Rama: `chore/regularize-production-baseline`
Baseline previo: `04970fb85ec424b00d789f4281ba761067364e6c`

## Objetivo

Recuperar en migraciones reproducibles las RPCs que usan `web_concierge` y
`whatsapp-ai-router` para reservas asistidas por IA:

- `check_availability_for_booking_from_ai`
- `create_pending_booking_from_ai`
- `check_booking_payment_requirement`

El criterio de cierre es que `supabase db reset` cree las tres funciones, sus
dependencias minimas, sus grants seguros y una prueba SQL local verificable.

## Evidencia fuente

| Fuente | Uso | Decision |
|---|---|---|
| `supabase/functions/web_concierge/index.ts` | Contrato actual del concierge web | La funcion de creacion debe aceptar `p_email`, `p_therapist_id` y devolver `booking_id`. |
| `supabase/functions/whatsapp-ai-router/index.ts` | Contrato actual del bot WhatsApp | Debe devolver `created`, `duplicate_prevented`, `client_is_new`, waiver/deposito y respetar `p_therapist_id`. |
| `supabase/staff_availability.sql` | Implementacion historica mas completa de disponibilidad | Se recupera la variante con staff, horarios, blocks y capacidad. |
| `supabase/ai_pending_booking_flow.sql` | Implementacion historica de creacion pending | Se toma como base, ampliada con email, branch, idempotencia y recheck transaccional. |
| `supabase/ai_booking_payment_waiver.sql` | Waiver por gift card/membresia | Base para `check_booking_payment_requirement`. |
| `supabase/packages_anticipo_waiver.sql` | Waiver por paquetes | Se conserva como deteccion defensiva solo si existen las tablas de paquetes. |
| `supabase/ai_foundation.sql`, `schedule_blocks.sql` | Tablas soporte | Se recuperan objetos minimos requeridos por disponibilidad. |

No se usaran datos productivos, Stripe real, Meta/WhatsApp real, deploys ni
escrituras remotas de Supabase.

## Plan de implementacion

1. Crear contrato documentado antes de migrar.
2. Agregar una migracion aditiva `20260722040000_ai_booking_rpcs.sql`.
3. Crear dependencias reproducibles:
   - `business_hours`
   - `business_closed_days`
   - `business_settings`
   - `schedule_blocks`
   - `staff_services`
   - `staff_working_hours`
   - `staff_time_off`
4. Sembrar solo configuracion estructural minima:
   - sucursal default `11111111-1111-1111-1111-111111111111`
   - horario placeholder por semana
   - `business_settings` por sucursal
5. Reinstalar RPCs como `SECURITY DEFINER` con `search_path = public, pg_temp`.
6. Revocar `public`, `anon` y `authenticated`; conceder ejecucion solo a
   `service_role`.
7. Agregar idempotencia fuerte para creacion:
   - columna `bookings.ai_idempotency_key`
   - indice unico parcial
   - `p_request_id` opcional
   - fallback hash server-side si un consumidor legacy no lo manda
8. Actualizar consumidores Edge para mandar `p_request_id` reproducible:
   - WhatsApp: incluye `wamid` cuando existe mas los datos del slot.
   - Web: hash deterministico amplio del intento de reserva.
9. Agregar pruebas:
   - SQL: disponibilidad, waiver/deposito, creacion, idempotencia y grants.
   - Deno: normalizacion/argumentos compartidos para web y WhatsApp.
10. Ejecutar validaciones locales sin servicios reales.

## Riesgos y mitigaciones

| Riesgo | Mitigacion |
|---|---|
| RPCs historicas no aceptan `p_email` | Firma ampliada compatible por argumentos nombrados. |
| Duplicados por retry de LLM/webhook | `p_request_id` + indice unico + lock transaccional. |
| Sobre-reserva por carrera concurrente | `pg_advisory_xact_lock` por slot y recheck de disponibilidad dentro de la RPC de creacion. |
| Tablas de paquetes no migradas en baseline | `check_booking_payment_requirement` usa SQL dinamico solo si existen. |
| RLS impide detectar colisiones | Funciones de disponibilidad son `SECURITY DEFINER` y solo devuelven disponibilidad/slots. |
| Exposicion publica de RPCs | Grants cerrados a `service_role`; endpoints publicos siguen detras de Edge Functions. |

## Criterio de no alcance

- No se migra el modulo completo de paquetes ni `products`.
- No se despliegan Edge Functions.
- No se hacen pagos reales ni llamadas reales a Meta/WhatsApp.
- No se cambia el repo original ni el worktree de Gift Card Alerts.
