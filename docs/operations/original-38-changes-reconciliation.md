# Original 38 Changes Reconciliation

Fecha local: 2026-07-22.

Worktree usado: `C:\Proyectos\sahara-club-spa-web-regularization`.
Rama: `chore/regularize-production-baseline`.
HEAD inicial verificado: `8d428671c38e4def07e34f41133e6935101525f6`.
Fuente unica de recuperacion: `C:\Proyectos\Backups\Sahara-Club-Spa\20260721-200207-pre-regularization`.

Restricciones aplicadas:

- No se modifico `C:\Proyectos\sahara-club-spa-web`.
- No se modifico `C:\Proyectos\sahara-club-spa-web-gift-card-alerts`.
- No se uso stash, merge, cherry-pick, rebase, push, deploy, Stripe real, WhatsApp real ni escrituras remotas de Supabase.
- No se copiaron fuentes desde el repositorio original protegido.
- No se versionaron `.audit`, dumps, backups, secretos, caches, builds ni temporales.

## Resultado

Los 38 movimientos del repositorio original quedaron reconciliados. El sitio publico recupera el video `Portada-2.mp4`, las imagenes `assets/experiencia/`, el chat web del concierge como cliente ligero y la mejora segura del panel IA. Los dominios de agenda, recepcion, clientes, comprobantes, runtime, WhatsApp, anticipos, gift cards y security hardening se mantienen desde las fases regularizadas previas o por implementaciones superiores.

## Inventario Exacto

| # | Movimiento original | Estado | Resolucion |
|---:|---|---|---|
| 1 | `assets/videos/portada.mp4` `D` | REGULARIZADO | Se retiro del worktree regularizado. Reemplazado por `assets/videos/Portada-2.mp4`. Hash HEAD original: `6851a87f112b6918e7b6c134b3e6e3fc665e180607f8d99ed25bbe156784a7e8`. |
| 2 | `lib/config/web_media_paths.dart` `M` | PORTADO | `kHeroVideoWebUrl` apunta a `assets/assets/videos/Portada-2.mp4`. |
| 3 | `lib/features/admin/ai_control_panel.dart` `M` | PORTADO PARCIAL SEGURO | Se recuperaron etiquetas humanas de modo IA y mapeo legacy `assisted` como Publico. No se agregaron secretos ni service role en Flutter. |
| 4 | `lib/features/bookings/booking_sync_service.dart` `M` | YA REGULARIZADO | Cubierto por Fase 2 recepcion/agenda y pruebas de booking time/sync. No se re-copio. |
| 5 | `lib/features/clients/clients_module.dart` `M` | YA REGULARIZADO | Cubierto por Fase 3 clientes/comprobantes. No se re-copio. |
| 6 | `lib/features/reception_alerts/reception_alerts_service.dart` `M` | YA REGULARIZADO | Cubierto por Gift Card Alerts y security hardening. No se re-copio. |
| 7 | `lib/features/store/store_page.dart` `M` | REEMPLAZADO POR IMPLEMENTACION SUPERIOR | El original era un atajo a `GiftCardPage`; la rama actual conserva tienda completa y Gift Card Digital. No se reemplazo. |
| 8 | `lib/pages/agenda_page.dart` `M` | YA REGULARIZADO | Cubierto por Fases 2, 3, 3B y Gift Card Alerts. No se re-copio. |
| 9 | `lib/pages/landing_page.dart` `M` | PORTADO | Se recupero `ConciergeChat` como overlay del `Stack`, manteniendo checkout return y navegacion actual. |
| 10 | `lib/pages/reception_login_page.dart` `M` | YA REGULARIZADO | Cubierto por Fase 2 login/recepcion. No se re-copio. |
| 11 | `lib/widgets/contact_section.dart` `M` | PORTADO ADAPTADO | Boton de reservas abre `ConciergeChat`; WhatsApp queda como accion separada. |
| 12 | `lib/widgets/experience_section.dart` `M` | PORTADO | Pilares usan `assets/experiencia/01-presencia.png`, `02-conexion.png`, `03-transformacion.png`. |
| 13 | `lib/widgets/featured_section.dart` `M` | CLASIFICADO | Diferencias solo cosmeticas/contenido local. La rama actual no requiere port adicional. |
| 14 | `lib/widgets/footer.dart` `M` | CLASIFICADO | Diferencias menores de copy/datos. La rama actual no requiere port adicional. |
| 15 | `lib/widgets/hero_section.dart` `M` | PORTADO ADAPTADO | CTA sin URL abre concierge; si CMS trae URL, respeta `_openCta`. |
| 16 | `lib/widgets/ritual_card.dart` `M` | CLASIFICADO | Diferencia cosmetica menor. La rama actual no requiere port adicional. |
| 17 | `pubspec.yaml` `M` | PORTADO | Se declaro `assets/experiencia/`. |
| 18 | `supabase/functions/_shared/whatsapp_business.ts` `M` | YA REGULARIZADO | Cubierto por runtime y security hardening. No se re-copio. |
| 19 | `supabase/functions/create_booking_deposit_checkout/index.ts` `M` | YA REGULARIZADO | Cubierto por comprobante firmado y hardening de checkout. No se re-copio. |
| 20 | `supabase/functions/notify_unpaid_deposits/index.ts` `M` | YA REGULARIZADO | Cubierto por runtime regularizado. No se re-copio. |
| 21 | `supabase/functions/stripe_webhook/index.ts` `M` | YA REGULARIZADO | Cubierto por Gift Card fulfillment, comprobantes y hardening. No se re-copio. |
| 22 | `supabase/functions/whatsapp-ai-router/index.ts` `M` | YA REGULARIZADO | Cubierto por runtime, reglas IA y hardening. No se re-copio. |
| 23 | `assets/experiencia/01-presencia.png` `??` | PORTADO | Copiado desde backup verificado. SHA256: `e276c98ebbe622bfd8ebd925e6c25ffdb9df1b33ca662ea1a9aae5ac2cc8592d`. |
| 24 | `assets/experiencia/02-conexion.png` `??` | PORTADO | Copiado desde backup verificado. SHA256: `9153dda7e158f8b406b68f6adda396540c345b81b3a9e6c61cd6f44e927f1f86`. |
| 25 | `assets/experiencia/03-transformacion.png` `??` | PORTADO | Copiado desde backup verificado. SHA256: `2fedeae4ce7455ddfbe735cfc350dd8311daf8bab5cb3c41d809cd8feeb7a50b`. |
| 26 | `assets/videos/Portada-2.mp4` `??` | PORTADO | Copiado desde backup verificado. SHA256: `7b4273c2fa35d81b8d6ab769f9d4391f0db332c40942a7e4762c439d41bb5a28`. |
| 27 | `docs/auditoria-agenda-notificaciones.md` `??` | REEMPLAZADO POR DOCS SUPERIORES | Reconciliado por `reception-agenda-*`, `gift-card-alerts-*` y security docs. No se versiono el doc suelto original. |
| 28 | `docs/clientes-duplicados-pendientes.md` `??` | REEMPLAZADO POR DOCS SUPERIORES | Reconciliado por `clients-receipts-*` y helpers/tests de identidad. No se versiono el doc suelto original. |
| 29 | `lib/features/receipts/deposit_receipt_actions.dart` `??` | YA REGULARIZADO | Existe en rama actual con validaciones de URL/token y accion autorizada. No se re-copio. |
| 30 | `lib/widgets/concierge_chat.dart` `??` | PORTADO ADAPTADO | Se creo cliente regularizado con caps locales y endpoint `web_concierge` endurecido. |
| 31 | `supabase/ai_bot_rules_no_cancel_and_assisted.sql` `??` | CLASIFICADO NO VERSIONADO | Reglas aplicadas como comportamiento/documentacion del panel y router; SQL suelto no se ejecuta ni versiona. |
| 32 | `supabase/functions/auto_confirm_bookings/index.ts` `??` | YA REGULARIZADO | Existe con gate de service role/internal secret; `force=1` no queda publico. No se re-copio. |
| 33 | `supabase/functions/deposit_voucher/index.ts` `??` | YA REGULARIZADO | Existe con `voucher_token` HMAC, TTL y respuesta minima. No se re-copio. |
| 34 | `supabase/functions/notify_admins/index.ts` `??` | YA REGULARIZADO | Existe con autenticacion interna y logs sanitizados. No se re-copio. |
| 35 | `supabase/functions/send_deposit_receipt/index.ts` `??` | YA REGULARIZADO | Existe con action `download_link`, role/internal auth y sanitizacion. No se re-copio. |
| 36 | `supabase/functions/setup_admin_template_v2/index.ts` `??` | YA REGULARIZADO | Existe neutralizado con respuesta 410. No se re-copio. |
| 37 | `supabase/functions/web_concierge/index.ts` `??` | YA REGULARIZADO | Existe con CORS allowlist, body caps, message caps y rate limit. Flutter solo invoca esta funcion. |
| 38 | `web/comprobante-anticipo.html` `??` | YA REGULARIZADO | Existe con `voucher_token`, sin anon key y sin public table lookup. No se re-copio. |

## Store Capability Matrix

| Capacidad | Original protegido | Regularizacion actual | Decision |
|---|---|---|---|
| Entrada Tienda | Redirigia directo a `GiftCardPage`. | Tienda completa con categorias y detalle. | Mantener actual. |
| Gift Card Digital | Presente como unico flujo terminado. | Presente con `GiftCardPage`, `StoreProductType.giftCard`, fallback y checkout digital. | Preservar y probar. |
| Carrito | No presente en el atajo. | `StoreCartController`, `CartPage` y checkout. | Mantener actual. |
| Membresias | No cubierto por atajo. | CTA y navegacion a `VipMembershipsPage`. | Mantener actual. |
| Servicios/faciales/masajes | No cubierto por atajo. | Navegacion a paginas dedicadas y productos filtrados. | Mantener actual. |
| Riesgo de reemplazo | Alto: perderia tienda completa. | Bajo si solo se documenta y prueba Gift Card. | No reemplazar archivo. |

## Panel IA

| Aspecto | Resultado |
|---|---|
| Rol/acceso | El panel sigue viviendo en el modulo admin Flutter y usa el cliente Supabase de sesion. La autorizacion real depende de RLS/politicas de `ai_settings`. |
| Secretos | No se agrego service role, `SUPABASE_SERVICE_ROLE_KEY`, Anthropic key ni RPC de vault al cliente. |
| Cambio portado | Modo Apagado/Piloto/Publico con compatibilidad visual para `assisted`. |
| Cambio rechazado | Ningun SQL suelto ni runtime remoto fue ejecutado. |
| Riesgo residual | El control efectivo depende de las politicas de `ai_settings`; se mantiene cubierto por security hardening y pruebas de frontera. |

## Docs Y SQL Sueltos

Los documentos sueltos del backup fueron clasificados como evidencia historica. No se copiaron porque ya existen documentos de operacion por fase con trazabilidad superior.

El SQL `supabase/ai_bot_rules_no_cancel_and_assisted.sql` no se ejecuto. Su intencion se cubre por el texto del panel y por la clasificacion legacy: las reglas operativas deben entrar por migraciones revisadas, no como SQL suelto.

## Validaciones Planeadas

- `flutter pub get`
- `dart format` sobre archivos modificados
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test --no-pub -r expanded`
- `flutter build web --release`
- `git diff --check`
- `supabase db reset`
- `deno task edge:check`
- `deno task edge:test`
