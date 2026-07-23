# Production Delta Analysis

Fecha local: 2026-07-23.

Modo: solo lectura. No se hizo `supabase link`, `db pull`, `db push`, deploy, push, ni cambios remotos.

## Git

| Componente | Produccion | Release Candidate | Diferencia | Accion |
|---|---|---|---|---|
| `origin/main` | `f38833922e7a8dac300c0b57067c9654c38e7b99` | Rama local de regularizacion con recuperacion RPC | RC esta mas de 43 commits adelante | ACTUALIZAR via PR/merge futuro |
| Repo original protegido | 38 movimientos locales | No usado como fuente directa | Original conserva drift local | REQUIERE BACKUP antes de tocar |
| Worktree Gift Card Alerts | `feature/gift-card-reception-notifications`, `.audit/remote_public_schema.sql` untracked | No modificado | Worktree protegido queda aparte | SIN CAMBIO |

## Supabase remoto

Proyecto remoto listado por CLI: `sahara-club-spa` con ref `fkbyxhwdcsgrrixalzwf`.

| Componente | Produccion | Release Candidate | Diferencia | Accion |
|---|---|---|---|---|
| Proyecto | Existe en Supabase Management API | Local no linkeado | Project ref conocido, sin link local | SIN CAMBIO |
| Migraciones registradas | NO COMPROBABLE sin link o DB URL/password | 9 migraciones locales nuevas | No se comparo tabla remota de migraciones | NO COMPROBABLE |
| Edge `stripe_webhook` | ACTIVE v14, updated 2026-07-01 | Fuente local modificada/endurecida | Posible actualizar | ACTUALIZAR |
| Edge `create_checkout_session` | ACTIVE v4 | Fuente local modificada | Posible actualizar | ACTUALIZAR |
| Edge `confirm_order_payment` | ACTIVE v6 | Fuente local modificada | Posible actualizar | ACTUALIZAR |
| Edge `create_booking_deposit_checkout` | ACTIVE v5 | Fuente local modificada | Posible actualizar | ACTUALIZAR |
| Edge `notify_unpaid_deposits` | ACTIVE v5 | Fuente local modificada | Posible actualizar | ACTUALIZAR |
| Edge `notify_admins` | ACTIVE v2 | Fuente local endurecida | Posible actualizar | ACTUALIZAR |
| Edge `auto_confirm_bookings` | ACTIVE v1 | Fuente local endurecida | Posible actualizar | ACTUALIZAR |
| Edge `web_concierge` | ACTIVE v7 | Fuente local endurecida | Posible actualizar | ACTUALIZAR |
| Edge `send_deposit_receipt` | ACTIVE v2 | Fuente local endurecida | Posible actualizar | ACTUALIZAR |
| Edge `deposit_voucher` | ACTIVE v1 | Fuente local endurecida | Posible actualizar | ACTUALIZAR |
| Edge `setup_admin_template_v2` | ACTIVE v2 | Fuente local neutralizada | Posible actualizar o retirar futuro | ACTUALIZAR |
| Edge `gift_card_download` | No aparecio en listado remoto | Existe local | Nueva funcion para descarga firmada | CREAR |
| Edge `gift_card_reception_actions` | No aparecio en listado remoto | Existe local | Nueva funcion interna recepcion | CREAR |
| Tablas/policies remotas | NO COMPROBABLE | RLS/policies locales PASS parcial | No se introspecto remoto | NO COMPROBABLE |
| Buckets remotos | NO COMPROBABLE | `gift-card-assets`, `receipts` privados locales | No se introspecto remoto | NO COMPROBABLE |

## Vercel

| Componente | Produccion | Release Candidate | Diferencia | Accion |
|---|---|---|---|---|
| CLI global | No disponible | CLI vendorizado existe | Se uso `node_modules/.bin/vercel.cmd` | SIN CAMBIO |
| Auth Vercel | Token local invalido | No se pudo listar deployments | Deployment activo NO COMPROBABLE | NO COMPROBABLE |
| `vercel.json` | NO COMPROBABLE remoto | Local define `buildCommand`, `build/web`, rewrites y headers | Config local lista | VERIFICAR |
| Deployment activo/SHA/alias | NO COMPROBABLE | No se desplego | Falta metadata read-only valida | NO COMPROBABLE |

## Drift critico local/remoto

| Drift | Impacto | Accion |
|---|---|---|
| RPCs de reserva migradas solo localmente | `web_concierge` y `whatsapp-ai-router` ya son reproducibles tras reset local, pero remoto no fue aplicado/verificado | APLICAR y verificar migraciones en release controlado |
| Funciones nuevas locales ausentes remoto | Gift Card download y reception actions no existen en produccion | CREAR solo despues de migraciones/secrets |
| Vercel no comprobable | No se puede confirmar SHA activo ni alias | Verificar token/proyecto antes de despliegue |
