# Runtime Source Recovery

Fase 1 recupera fuentes runtime desde el respaldo verificado:

`C:\Proyectos\Backups\Sahara-Club-Spa\20260721-200207-pre-regularization`

No se copiaron fuentes directamente desde el working tree original. Antes de recuperar cada archivo se comparó el hash del respaldo contra `sha256-manifest.csv` y contra el archivo actual del repositorio original protegido. Todos los archivos recuperados coincidieron.

La comparación remota se hizo en modo lectura con `supabase functions list` usando el `project-ref` existente del worktree de comparación. La CLI confirmó existencia, estado, versión y fecha de actualización, pero no expuso `verify_jwt`.

La regularizacion tecnica posterior esta documentada en `docs/operations/runtime-technical-regularization.md`.

## Fuentes Recuperadas

| Función | Fuente | Hash SHA-256 | Estado remoto | Fecha remota | Confianza |
|---|---|---|---|---|---|
| `stripe_webhook` | `changed-files/supabase/functions/stripe_webhook/index.ts` | `ae3a8335010d6fb7de0eaf2d5448ec925c00cf80127d8f9b7fbd1c4c5bdfd891` | ACTIVE v14 | 2026-07-01 23:55:04 UTC | ALTA |
| `whatsapp-ai-router` | `changed-files/supabase/functions/whatsapp-ai-router/index.ts` | `0913051299033f6e12f2a7756b2fbb7bb1b9270d4d1ce6ac50864ad298a1ebbd` | ACTIVE v64 | 2026-07-04 01:28:01 UTC | ALTA |
| `_shared/whatsapp_business.ts` | `changed-files/supabase/functions/_shared/whatsapp_business.ts` | `9c2475842443363e21dd8e9c49aea3e50d918257e691c839cff4f40e9f005f3f` | Shared module, not listed as function | N/A | MEDIA |
| `create_booking_deposit_checkout` | `changed-files/supabase/functions/create_booking_deposit_checkout/index.ts` | `9dc65bf45e63e70679e52f0ccf52eb2d1e2e546fcc2effbbd7320d414fe8d1a2` | ACTIVE v5 | 2026-06-30 13:11:22 UTC | ALTA |
| `notify_unpaid_deposits` | `changed-files/supabase/functions/notify_unpaid_deposits/index.ts` | `7ac1711e7f1305481f0a794aa0560d22cd2fcdcd6bf530716b11dc2da74f3d17` | ACTIVE v5 | 2026-07-01 23:55:06 UTC | ALTA |
| `notify_admins` | `untracked-files/supabase/functions/notify_admins/index.ts` | `5a8c3dd8a295afca2d2ab20f8432d65a9c10fa5b7d71cbd5cf7c9bc46e56b951` | ACTIVE v2 | 2026-07-04 14:16:57 UTC | ALTA |
| `send_deposit_receipt` | `untracked-files/supabase/functions/send_deposit_receipt/index.ts` | `a85163ed16a589505761e8a5440a1558b0e4b5706d695444302a4b74619a76ad` | ACTIVE v2 | 2026-07-01 23:55:02 UTC | ALTA |
| `deposit_voucher` | `untracked-files/supabase/functions/deposit_voucher/index.ts` | `d06aee0623a4d37d0524c7066aaa1365fe3c4dcb1ea3bf4780cc5efbf43883d8` | ACTIVE v1 | 2026-06-30 13:10:00 UTC | ALTA |
| `auto_confirm_bookings` | `untracked-files/supabase/functions/auto_confirm_bookings/index.ts` | `d8fe83609ae59a1ff02d4244768b10c04e25d5d3c64c5962e57cea97d5a86d83` | ACTIVE v1 | 2026-06-25 01:45:32 UTC | ALTA |
| `setup_admin_template_v2` | `untracked-files/supabase/functions/setup_admin_template_v2/index.ts` | `7d9431ca88f309c92dbb878ab3c9c68547772af17bd2a3dc4a4cd8eef6978368` | ACTIVE v2 | 2026-06-27 04:52:49 UTC | ALTA |
| `web_concierge` | `untracked-files/supabase/functions/web_concierge/index.ts` | `ce4c65d8a00201b7e3241ff9342fb7e431bdf2f540a277f31a1f1528157189fe` | ACTIVE v7 | 2026-07-06 14:19:47 UTC | ALTA |

## Lectura De Comparación

| Función | Local original | Backup | Regularization | Remoto | Veredicto |
|---|---|---|---|---|---|
| `stripe_webhook` | Hash coincide | Hash coincide | Recuperada | ACTIVE v14 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `whatsapp-ai-router` | Hash coincide | Hash coincide | Recuperada | ACTIVE v64 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `_shared/whatsapp_business.ts` | Hash coincide | Hash coincide | Recuperada | No aplica | PRODUCCIÓN NO COMPROBABLE |
| `create_booking_deposit_checkout` | Hash coincide | Hash coincide | Recuperada | ACTIVE v5 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `notify_unpaid_deposits` | Hash coincide | Hash coincide | Recuperada | ACTIVE v5 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `notify_admins` | Hash coincide | Hash coincide | Recuperada | ACTIVE v2 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `send_deposit_receipt` | Hash coincide | Hash coincide | Recuperada | ACTIVE v2 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `deposit_voucher` | Hash coincide | Hash coincide | Recuperada | ACTIVE v1 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `auto_confirm_bookings` | Hash coincide | Hash coincide | Recuperada | ACTIVE v1 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `setup_admin_template_v2` | Hash coincide | Hash coincide | Recuperada | ACTIVE v2 | FUENTE RECUPERADA CON ALTA CONFIANZA |
| `web_concierge` | Hash coincide | Hash coincide | Recuperada | ACTIVE v7 | FUENTE RECUPERADA CON ALTA CONFIANZA |

## Archivos Revisados Pero No Recuperados

| Archivo | Resultado | Motivo |
|---|---|---|
| `supabase/ai_bot_rules_no_cancel_and_assisted.sql` | Excluido | SQL suelto; debe convertirse en migración o documentación en una fase separada. |
| `web/comprobante-anticipo.html` | Excluido | Contiene URL/JWT-like público; requiere reemplazo por flujo seguro antes de versionarse. |
| `lib/features/receipts/deposit_receipt_actions.dart` | Excluido | Pertenece a la fase posterior de Flutter/comprobantes. |

## Notas De Seguridad

La auditoría previa al staging no detectó secretos literales en las fuentes Edge recuperadas. Las coincidencias sensibles fueron referencias a variables de entorno (`SUPABASE_SERVICE_ROLE_KEY`, `META_ACCESS_TOKEN`, `META_PHONE_NUMBER_ID`) o nombres de columnas/configuración. No se imprimieron valores.
