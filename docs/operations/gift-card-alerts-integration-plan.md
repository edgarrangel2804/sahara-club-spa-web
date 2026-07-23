# Gift Card Alerts Manual Integration Plan

Scope: integrate the Gift Card Alerts feature behavior manually into the
regularized digital fulfillment baseline. The feature worktree is reference
only; no merge, cherry-pick, wholesale replacement, remote write, deploy,
Stripe live call, or real WhatsApp send is allowed.

## Commit Comparison Matrix

| Capacidad | Rama feature | Regularization | Accion |
|---|---|---|---|
| Reception event `gift_card_purchased` | Adds event type, columns, unique index, and Flutter rendering. | Migration `20260722010000_gift_card_digital_fulfillment.sql` already adds the event, columns, FKs, metadata, and unique index. Flutter model still lacks fields. | ADAPTAR |
| Gift Card creation | Adds older fulfillment blocks in Stripe helpers. | Current fulfillment creates one card per `order_item_id`, validates recipient/dedication/validity, generates PDF, and delivers WhatsApp. | REEMPLAZADO POR IMPLEMENTACION NUEVA |
| Reception alert creation | Inserts one alert per Gift Card and ignores duplicates. | Current helper inserts alert and ignores `23505`, but does not refresh visible asset/delivery status on retry. | PORTAR MANUALMENTE |
| Reception UI fields | Model/banner/bell show buyer, product, amount, masked code/phone and channel. | Reception UI handles booking/deposit alerts and keeps booking-less alerts, but Gift Card fields are not parsed/rendered. | PORTAR MANUALMENTE |
| Navigation from alert | Feature sends Gift Card alert to `ventas`. | Regularization already has `ventas`, `clientes`, and alert opening hooks. No Gift Card detail route exists yet. | ADAPTAR |
| Admin WhatsApp notification | Adds `_shared/admin_notifications.ts`, its tests, and a dedicated `admin_notification_deliveries` table/RPC. | Current digital fulfillment already has `gift_card_deliveries` claim ledger and WhatsApp helpers. | ADAPTAR |
| Admin delivery ledger | Dedicated table keyed by notification kind, Gift Card and recipient hash. | `gift_card_deliveries` can hold delivery type + destination hash; only missing `admin_whatsapp_purchase_alert` type. | REEMPLAZADO POR IMPLEMENTACION NUEVA |
| Admin recipient source | Reads `ai_settings.ai_admin_numbers`, guarded by `human_backup_enabled` in feature. | Existing admin flows already use `ai_admin_numbers`; business requirement says no hardcoded phones. | ADAPTAR |
| Channel rule | Feature sends admin notices only for web purchases. | Current channels are `web`, `whatsapp`, `reception`, and `unknown`; manual reception sale is operator-created. | ADAPTAR |
| Feature tests | Covers admin message, dedupe, skipped channels and retry. | Current Deno tests cover digital fulfillment, token, validity and PII. | REQUIERE PRUEBA |

## File/Object Comparison Matrix

| Archivo u objeto | Feature | Regularization | Conflicto | Estrategia |
|---|---|---|---|---|
| `supabase/functions/stripe_webhook/index.ts` | Imports admin notifications and invokes them after Gift Card alert creation. | Webhook is cleaner and delegates Gift Card fulfillment to `_shared/stripe_checkout.ts`/`gift_card_fulfillment.ts`. | Medium: direct webhook changes could reintroduce old flow. | CONSERVAR REGULARIZATION; invoke admin notice from fulfillment helper. |
| `supabase/functions/_shared/gift_card_fulfillment.ts` | Not present in older feature form; feature used older `stripe_checkout.ts` alert helpers. | Canonical Gift Card pipeline: data validation, PDF, Storage, recipient/buyer delivery, reception action endpoint. | Low: needs status-refreshing alert RPC and admin notice call. | ADAPTAR AL MODELO NUEVO |
| `supabase/functions/_shared/admin_notifications.ts` | New helper with admin message, recipient normalization, masked logs and dedicated delivery table. | File does not exist; equivalent ledger exists in `gift_card_deliveries`. | Medium: useful behavior but duplicated storage model. | PORTAR BLOQUE ESPECIFICO and retarget to `gift_card_deliveries`. |
| `supabase/functions/_shared/whatsapp_business.ts` | Refactored in feature tests. | Current helper already exports `normalizePhone`, `loadBusinessSettings`, `sendMetaTextMessage`, and `callMetaApi`. | Low. | CONSERVAR REGULARIZATION |
| `supabase/functions/whatsapp-ai-router/index.ts` | Older Gift Card checkout channel support. | Current router already captures recipient phone, valid date, terms and channel `whatsapp`. | Low. | OMITIR COMO DUPLICADO |
| `lib/features/reception_alerts/reception_alert.dart` | Adds Gift Card fields, labels, icon, accent and metadata helpers. | Booking/deposit model only. | Low. | PORTAR BLOQUE ESPECIFICO |
| `lib/features/reception_alerts/reception_alerts_service.dart` | Keeps booking-less alerts. | Already keeps booking-less alerts and dedupes by id. | None. | CONSERVAR REGULARIZATION |
| `lib/features/reception_alerts/reception_alert_banner.dart` | Shows Gift Card product, amount, masked phone/code, and CTA "Ver compra". | Booking-oriented banner. | Low. | PORTAR BLOQUE ESPECIFICO |
| `lib/features/reception_alerts/reception_alerts_bell.dart` | Shows Gift Card product, amount, masked phone/code, and channel label. | Booking-oriented tile, but mark seen/resolved works. | Low. | PORTAR BLOQUE ESPECIFICO |
| `lib/pages/agenda_page.dart` | Routes Gift Card alert to `ventas`. | Has module nav and `_openAlertTarget`; no new route architecture. | Low. | ADAPTAR AL MODELO NUEVO |
| `lib/features/store/store_page.dart` | Large old feature diff, mostly unrelated/legacy store edits. | Current Gift Card purchase form and checkout are newer. | High if copied wholesale. | OMITIR COMO DUPLICADO |
| `lib/features/clients/clients_module.dart` | Not central to feature alert path. | Current clients module supports Gift Card benefit visibility and manual sale. | None. | CONSERVAR REGULARIZATION |
| `20260722000100_gift_card_reception_alerts.sql` | Adds columns, constraints, indexes for Gift Card alerts. | Already covered by `20260722010000_gift_card_digital_fulfillment.sql` except `payment_id` FK and order-item index nuance. | Low. | OMITIR COMO DUPLICADO; add only reconciler if needed. |
| `20260722000200_admin_notification_deliveries.sql` | Creates separate admin delivery table and claim RPC. | `gift_card_deliveries` already models delivery claim/status. | High: duplicate ledger. | NO PORTAR; extend existing ledger. |
| `20260721000000_ecommerce_notification_baseline.sql` | Earlier baseline dependency. | Already applied in regularization. | None. | CONSERVAR REGULARIZATION |
| `20260721000100_reception_alerts_baseline.sql` | Earlier baseline dependency. | Already applied in regularization. | None. | CONSERVAR REGULARIZATION |
| `20260721000200_reception_alert_producers.sql` | Earlier baseline dependency. | Already applied in regularization. | None. | CONSERVAR REGULARIZATION |
| `20260722010000_gift_card_digital_fulfillment.sql` | N/A in feature. | Canonical current Gift Card schema and RPC baseline. | None. | CONSERVAR REGULARIZATION |

## Integration Decisions

- Canonical event remains `gift_card_purchased`.
- The event is produced after paid order + Gift Card row + commercial snapshot + validity are persisted.
- Alert creation must not wait for recipient WhatsApp success; it may include current `digital_asset_status` and `delivery_status`.
- Alert idempotency must be enforced by the database. A retry may update only operational status fields in metadata/message, not historical buyer/order facts.
- Admin WhatsApp uses `ai_settings.ai_admin_numbers`; no hardcoded recipients.
- Admin notification channel rule: send for paid external checkout channels `web`, `whatsapp`, and `unknown`; skip `reception`, `manual`, and `admin` because a staff/admin user is already present in that purchase path.
- Admin delivery idempotency uses `gift_card_deliveries` with `delivery_type = admin_whatsapp_purchase_alert`, not a second table.
- Reception UI must not show full phone, email, payment intent, checkout session, download token, or full Gift Card code.
- The primary UI action is `Ver Gift Card`; it routes to the existing `ventas` context and may open an authorized action dialog without creating a new navigation architecture.

## Planned Local Changes

1. Add migration `20260722020000_integrate_gift_card_alerts.sql` to:
   - allow `admin_whatsapp_purchase_alert` in `gift_card_deliveries`;
   - allow explicit `manual`/`admin` purchase channel values for future compatibility;
   - add an atomic `log_gift_card_purchase_alert` RPC that inserts or updates only operational alert status fields;
   - grant the RPC only to `service_role`.
2. Add `_shared/admin_notifications.ts` adapted to:
   - build sanitized admin messages;
   - normalize/dedupe admin phones;
   - claim `gift_card_deliveries`;
   - insert masked `whatsapp_logs`;
   - complete delivery best-effort.
3. Update `gift_card_fulfillment.ts` to:
   - call the alert RPC instead of raw insert;
   - notify admins after recipient/buyer delivery attempts, best-effort only.
4. Update Flutter reception alert model/banner/bell and `AgendaPage` navigation.
5. Add focused Deno and Flutter tests.
