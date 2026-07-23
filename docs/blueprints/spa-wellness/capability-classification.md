# Capability Classification

Status values:

- PRODUCTIVO: exists in Sahara and is used operationally.
- PARCIAL: exists but is incomplete, drifted, or lacks full certification.
- FOUNDATION: useful base for NEXORA, but needs redesign before reuse.
- NO EXISTE: no verified implementation found.
- NO COMPROBABLE: evidence is insufficient in Git/local schema.

## Universal NEXORA

| Capability | Status | Notes |
|---|---:|---|
| Clientes | PRODUCTIVO | `profiles` and `clients` model staff/client identity plus spa client records. Needs cleanup before reuse. |
| Agenda | PRODUCTIVO | `bookings` drives appointments, state, deposits, source channels, and staff assignment. |
| Órdenes | PRODUCTIVO | `orders` and `order_items` support ecommerce and Gift Card purchases. |
| Pagos | PRODUCTIVO | `payments` is unified across ecommerce, bookings, memberships, and sales. |
| Notificaciones | PARCIAL | `reception_alerts`, WhatsApp admin alerts, unpaid deposit alerts, and receipt dispatch exist, but idempotency and caller auth need hardening. |
| WhatsApp | PRODUCTIVO | Meta settings, logs, templates, queue, router functions, admin notifications, and receipt delivery exist with drift. |
| Realtime | PRODUCTIVO | `reception_alerts` is published for live reception UI updates. |
| Roles | PARCIAL | `profiles.role`, helper functions, and role permissions exist, but naming and policies are inconsistent. |
| Configuración | PARCIAL | Business, Stripe, WhatsApp, and AI settings exist, but config and code are mixed. |
| Auditoría | PARCIAL | Some audit tables/functions exist; coverage is uneven. |
| Workflows | FOUNDATION | Real operational flows exist, but orchestration is coupled to Sahara schema and Edge Functions. |
| IA | PARCIAL | AI settings, conversations, WhatsApp router, web concierge, admin reporting, and support windows exist; certification is incomplete. |

## Spa & Wellness

| Capability | Status | Notes |
|---|---:|---|
| Terapeutas | PRODUCTIVO | `staff`, therapist roles, assignments, availability, and working hours exist. |
| Cabinas | PARCIAL | `bookings.cabin` and room capacity settings exist; dedicated cabin model is not fully normalized. |
| Servicios | PRODUCTIVO | `services` holds catalog, duration, price, wellness metadata, and giftable service support. |
| Paquetes | PRODUCTIVO | Package schema and package consumption flows exist, but are not part of this baseline. |
| Membresías | PRODUCTIVO | Membership plans and client memberships exist with payments and entitlements. |
| Gift Cards | PRODUCTIVO | `gift_cards` now has local digital fulfillment coverage: recipient/dedication metadata, `valid_from`/`expires_on`, private assets, signed downloads, WhatsApp delivery ledger, reception action endpoint, and redemption RPC. |
| Anticipos | PRODUCTIVO | Booking deposit fields, Stripe checkout, payment requirements, PDF receipts, voucher lookup, and AI deposit settings exist. |
| Historial de spa | PARCIAL | Appointment status history and client stats exist, but the record is spread across multiple SQL files. |
| Evaluaciones | NO COMPROBABLE | No certified schema for intake/evaluation records was identified in the baseline path. |
| Consentimientos | NO EXISTE | No verified consent workflow was found in the regularized baseline. |
| Rituales | PARCIAL | Service/product metadata can represent rituals, but there is no dedicated ritual domain model. |
| Seguimiento | PARCIAL | WhatsApp, reminders, AI handoff, and client notes support follow-up; coverage is fragmented. |

## Reception And Agenda Regularization

Fase 2 classifies the recovered reception and agenda runtime without moving it to NEXORA.

### Universal NEXORA Candidates

| Capability | Status | Notes |
|---|---:|---|
| Agenda engine | FOUNDATION | Bookings, calendar ranges, staff assignment, availability checks, realtime refresh, and state transitions are real, but UI/domain logic is still monolithic. |
| Appointment states | FOUNDATION | The operational states are known and documented; they need one canonical state machine before reuse. |
| Internal alerts | FOUNDATION | `reception_alerts` plus Realtime and bell/banner UI are a reusable pattern after model/schema hardening. |
| Realtime refresh | FOUNDATION | Bookings, payments, messages, schedule blocks, and alerts use live subscriptions with debounce/reload behavior. |
| Reception roles | FOUNDATION | Staff login and configurable module permissions are reusable concepts; role names require normalization. |
| Booking sync | FOUNDATION | `BookingSyncService` centralizes fetch/validate/upsert and availability RPC calls, but still depends on Sahara schema. |
| Timezone helper | FOUNDATION | Tijuana commercial date helpers are now testable; NEXORA needs provider-backed timezone support before broad reuse. |
| Audit warnings | FOUNDATION | UI warns before status changes that trigger customer WhatsApp messages; a generic audit contract should live outside widgets. |

### Vertical Spa & Wellness

| Capability | Status | Notes |
|---|---:|---|
| Therapists | PRODUCTIVO | Agenda assigns staff, validates availability, and displays therapist live state. |
| Rooms/cabins | PARCIAL | Availability checks include room capacity, but UI/modeling is not fully normalized. |
| Services | PRODUCTIVO | Service catalog, price, duration, and booking linkage are active. |
| Treatment duration | PRODUCTIVO | Duration drives grid placement, validation, and sales draft creation. |
| Deposits | PRODUCTIVO | Deposit-required/paid states exist; receipt UI is deferred to a later Flutter receipt phase. |
| Packages | PARCIAL | Package waiver/session usage exists in booking creation; package domain still needs separate certification. |
| Sessions | PARCIAL | Service session start/end flow exists through `in_progress -> completed -> awaiting_payment`. |
| Future contraindications | NO EXISTE | No certified intake/contraindication workflow in this phase. |
| Spa reception operation | PRODUCTIVO | Staff login, agenda, clients, sales, messages, alerts, and booking status actions are operational. |

### Legacy

| Item | Classification | Notes |
|---|---|---|
| AgendaPage monolith | LEGACY DO NOT COPY | The file is productive but mixes UI, domain rules, Supabase calls, WhatsApp actions, and sales navigation. |
| Coupled navigation | LEGACY DO NOT COPY | Alert, sales, chat, clients, and agenda navigation are stateful callbacks inside the page. |
| Duplicated states | LEGACY DO NOT COPY | Status labels/colors/actions exist in Flutter and SQL/Edge paths. |
| Domain logic in widgets | LEGACY DO NOT COPY | Availability, sales draft, message emission, package selection, and history logic live in widget state. |
| Sahara hardcodes | LEGACY DO NOT COPY | Branch names, role assumptions, copy, and phone/WhatsApp flows remain Sahara-specific. |
| WhatsApp actions in UI | LEGACY DO NOT COPY | Message center and status changes can trigger real provider side effects through RPC/triggers. |
| Historical lack of tests | LEGACY DO NOT COPY | Fase 2 adds focused tests, but the broader agenda surface remains untested. |

## Clients And Receipts Regularization

Fase 3 classifies recovered client/contact and deposit receipt surfaces without
moving them to NEXORA.

### Universal NEXORA Candidates

| Capability | Status | Notes |
|---|---:|---|
| Client contact identity | FOUNDATION | Pure helpers now normalize phone/email and identify probable duplicates, but no merge workflow is implemented. |
| Signed public document access | FOUNDATION | Public voucher access now uses backend-generated HMAC tokens with purpose, scope, TTL, constant-time signature checks, and minimal responses. |
| Public payment voucher | FOUNDATION | `deposit_voucher` now rejects weak public identifiers, validates `voucher_token`, checks paid status, rate-limits attempts, and returns minimal paid-only data. |
| Receipt action gate | FOUNDATION | Flutter helper prevents duplicate explicit receipt actions and sanitizes UI errors. |
| Private receipt retrieval | FOUNDATION | Reception can open signed Storage URLs after UUID validation; bucket/RLS ownership still belongs to Sahara runtime. |
| Controlled link regeneration | FOUNDATION | Receipt links can be regenerated by backend without changing payment state; stateless token revocation is a documented limitation. |

### Vertical Spa & Wellness

| Capability | Status | Notes |
|---|---:|---|
| Client profiles | PRODUCTIVO | `ClientsModule` is operational for spa clients, histories, benefits, packages, memberships, and Gift Cards. |
| Deposit PDF receipts | PRODUCTIVO | `send_deposit_receipt` generates PDF receipts for paid bookings and uploads them to private Storage. |
| Reception receipt resend | PRODUCTIVO | Agenda can open the real receipt dialog and request WhatsApp resend explicitly. |
| Public deposit voucher page | PRODUCTIVO | HTML uses `voucher_token`, removes the token from browser history, has no anon key, and renders minimal paid receipt fields. |
| Deposit voucher TTL | PRODUCTIVO | Access tokens are reusable during TTL and do not create payments, receipts, or WhatsApp sends when reopened. |

### Legacy

| Item | Classification | Notes |
|---|---|---|
| `ClientsModule` monolith | LEGACY DO NOT COPY | Productive but mixes UI, Supabase queries, histories, benefits, packages, memberships, Gift Cards, sales, and receipt actions. |
| Public voucher by raw identifier | LEGACY DO NOT COPY | `booking_id` and `session_id` are not authorization. Use scoped signed tokens with purpose and expiry. |
| Hardcoded public HTML config | LEGACY DO NOT COPY | Do not place anon keys in HTML or depend on public table selects for documents. |
| Tokens in logs or query PII | LEGACY DO NOT COPY | Do not log voucher tokens, customer PII, payment ids, or internal identifiers in public document flows. |
| Automatic WhatsApp resend from UI | LEGACY DO NOT COPY | Receipt resend must remain an explicit operator action with idempotency/rate-limit before reuse. |

## Gift Card Digital Fulfillment Regularization

This phase classifies the paid Gift Card digital fulfillment path without
deploying it or moving code to NEXORA.

### Universal NEXORA Candidates

| Capability | Status | Notes |
|---|---:|---|
| Digital entitlements | FOUNDATION | A paid order item can create one durable entitlement with code, balance, status, commercial validity, and redemption history. |
| Gift fulfillment | FOUNDATION | Fulfillment is decomposed into paid-order verification, idempotent entitlement creation, asset generation, delivery, and alerting. |
| Recipient delivery | FOUNDATION | Recipient delivery stores normalized contact separately from public payloads and masks contact details for internal alerts. |
| Signed downloads | FOUNDATION | Public access uses purpose-scoped HMAC tokens with TTL and no PII in URLs. |
| Asset generation | FOUNDATION | Edge runtime can generate PDF assets without Chromium and store them in private Storage with hashes. |
| Delivery idempotency | FOUNDATION | `gift_card_deliveries` models `gift_card_id + destination_hash + delivery_type` claims for retries and duplicate suppression. |
| Expiration policies | FOUNDATION | Commercial validity uses calendar-month date math, not fixed day offsets. |
| Redemption | FOUNDATION | `redeem_service_gift_card` is the backend gate for active status, validity window, balance, and duplicate booking prevention. |
| Audit trail | FOUNDATION | Transactions, delivery attempts, token fingerprints, and reception alerts create a reusable audit shape. |
| Channel retries | FOUNDATION | Webhook, download, WhatsApp, and reception actions can complete pending steps without recreating the Gift Card. |

### Vertical Spa & Wellness

| Capability | Status | Notes |
|---|---:|---|
| Gift Card por tratamiento | PRODUCTIVO | Gift Cards now snapshot the selected service name, price, description, currency, and purchase date. |
| Paquetes de sesiones | PARCIAL | Schema and snapshot fields support package ids/names/sessions, but package purchase fulfillment still needs a dedicated certification pass. |
| Experiencias | PRODUCTIVO | Digital card PDF renders the service/package/experience purchased at payment time. |
| Vigencia comercial | PRODUCTIVO | `valid_from` and `expires_on` are date fields with three calendar month behavior. |
| Dedicatorias | PRODUCTIVO | Buyer can provide a sanitized dedication shown in the authorized card/PDF. |
| Reserva posterior | PARCIAL | WhatsApp copy instructs the recipient to reserve by replying; appointment creation from Gift Card code remains a separate flow. |
| Canje en recepcion | PRODUCTIVO | Backend redemption RPC enforces validity and balance before consuming the card. |
| QR de tratamiento | PRODUCTIVO | The QR carries only the opaque redemption code, not PII or payment identifiers. |

### Legacy

| Item | Classification | Notes |
|---|---|---|
| Frontend-only Gift Card rendering | LEGACY DO NOT COPY | Cards must be generated server-side or from a trusted backend payload, not from unauthenticated URL parameters. |
| Gift Card price from client | LEGACY DO NOT COPY | The frontend can select a service, but the backend must resolve price, currency, and snapshot from server-side data. |
| Fixed day expiration | LEGACY DO NOT COPY | Do not model three months as 90 days; use calendar-month date math with a business timezone. |
| Raw code/session public lookup | LEGACY DO NOT COPY | Do not authorize card download by raw code, order id, or Stripe session id. Use signed purpose tokens. |
| WhatsApp without delivery ledger | LEGACY DO NOT COPY | Provider sends must be guarded by a delivery claim keyed by hashed destination and delivery type. |
| Regenerating cards on retry | LEGACY DO NOT COPY | Webhook retries must reuse `order_item_id`, asset path, code, validity, and delivery status. |

## Gift Card Operational Alerts Regularization

This phase classifies the manually integrated Gift Card purchase alert path
without deploying it or moving code to NEXORA.

### Universal NEXORA Candidates

| Capability | Status | Notes |
|---|---:|---|
| Internal commercial events | FOUNDATION | A paid commerce event can produce one internal operational alert without coupling it to appointments. |
| Operational alerts | FOUNDATION | `reception_alerts` can represent booking alerts and commercial alerts when event payloads are explicit and PII is masked. |
| Notification delivery ledger | FOUNDATION | `gift_card_deliveries` models recipient, buyer copy, download, resend, and admin WhatsApp attempts with one claim table. |
| Configurable recipients | FOUNDATION | Admin delivery reads `ai_settings.ai_admin_numbers` and dedupes normalized destinations instead of using hardcoded phones. |
| Atomic claims | FOUNDATION | Delivery claims use `gift_card_id + destination_hash + delivery_type` so retries do not resend successful destinations. |
| Controlled retries | FOUNDATION | Failed or pending deliveries can be claimed again, while sent or processing destinations are skipped. |
| Best-effort channels | FOUNDATION | PDF, Storage, recipient WhatsApp, buyer copy, and admin WhatsApp are operational side effects and must not undo a paid Gift Card. |
| Navigation from events | FOUNDATION | Alerts route to the existing operational context or dialog instead of assuming every alert has a booking. |
| Fulfillment state | FOUNDATION | Reception sees current asset and delivery state without reading raw provider payloads. |
| Sanitized audit | FOUNDATION | Logs and UI use masks, hashes, and status labels rather than full phone, payment ids, tokens, or full Gift Card codes. |

### Vertical Spa & Wellness

| Capability | Status | Notes |
|---|---:|---|
| Treatment Gift Card alert | PRODUCTIVO | `gift_card_purchased` identifies a paid spa treatment/experience Gift Card for reception follow-up. |
| Gift reception | PRODUCTIVO | Reception can identify buyer, recipient, product, amount, validity, delivery state, and copy request. |
| Experience validity | PRODUCTIVO | `valid_from` and `expires_on` are visible as commercial validity for the gifted experience. |
| Card resend | PRODUCTIVO | Reception can explicitly request resend to the recipient through the existing authorized Edge Function. |
| Buyer copy | PRODUCTIVO | Reception can send the buyer copy only when the original purchase requested it. |
| Packages and sessions | PARCIAL | Alert payload can display package/session snapshots, but package-specific purchase fulfillment remains a separate certification. |
| Delivery follow-up | PRODUCTIVO | Staff can see whether the digital asset and recipient delivery are pending, sent, failed, or skipped. |
| Reception redemption | PRODUCTIVO | The alert leads to the Gift Card context while redemption remains guarded by backend Gift Card RPCs. |

### Legacy

| Item | Classification | Notes |
|---|---|---|
| Booking-coupled alerts | LEGACY DO NOT COPY | Commercial alerts must not require `booking_id`, `booking_date`, or appointment navigation. |
| Hardcoded admin phones | LEGACY DO NOT COPY | Admin recipients belong in configuration and must be normalized/deduped before delivery. |
| Webhook sends without ledger | LEGACY DO NOT COPY | Admin WhatsApp from a webhook needs a delivery claim and retry state before each provider call. |
| Duplicate delivery tables | LEGACY DO NOT COPY | Do not create `admin_notification_deliveries` when `gift_card_deliveries` already models the same claim. |
| Always navigate to Agenda | LEGACY DO NOT COPY | Alert opening must route according to event domain, not assume a calendar booking exists. |
| PII in bell/banner | LEGACY DO NOT COPY | The general reception surface must not show full phones, email, payment ids, tokens, full code, or Stripe metadata. |
| Wholesale feature copying | LEGACY DO NOT COPY | Gift Card Alerts must be manually fused with the regularized fulfillment runtime, not pasted over canonical files. |
| Indiscriminate retries | LEGACY DO NOT COPY | Retrying all admin recipients can duplicate successful sends; only failed/pending destinations may be claimed. |

## Security Hardening Regularization

This phase classifies security boundaries added after the commerce, receipt,
Gift Card fulfillment, and alert regularization work.

### Universal NEXORA Candidates

| Capability | Status | Notes |
|---|---:|---|
| RLS role helper | FOUNDATION | `has_any_role(text[])` centralizes active profile/staff role checks for reusable policy design. |
| Private commerce data boundary | FOUNDATION | Orders, items, payments, Gift Cards, transactions, deliveries, alerts, logs, and config now reject anon table access. |
| Signed asset delivery | FOUNDATION | Receipt and Gift Card PDFs live in private Storage and are exposed only by authorized Edge Functions or signed token flows. |
| Edge auth matrix | FOUNDATION | Public, signed, operational, and internal endpoints are classified in `docs/security/edge-function-auth-matrix.md`. |
| Runtime security helper | FOUNDATION | CORS allowlist, rate limits, fingerprints, internal auth, role auth, and log sanitization are reusable Edge patterns. |
| Server-side pricing | FOUNDATION | Checkout rehydrates services/Gift Cards from server data and rejects unsafe product types without server catalog ownership. |

### Vertical Spa & Wellness

| Capability | Status | Notes |
|---|---:|---|
| Gift Card asset privacy | PRODUCTIVO | `gift-card-assets` remains private; download requires a signed purpose token or reception role. |
| Deposit receipt privacy | PRODUCTIVO | `receipts` is private; reception obtains signed URLs through `send_deposit_receipt`. |
| Operational Gift Card redemption | PRODUCTIVO | `redeem_service_gift_card` requires an operational role and validates booking/client/service consistency. |
| Appointment deposit integrity | PRODUCTIVO | Deposit amount comes from booking/config/Stripe Price, not from browser payloads. |
| Internal admin notifications | PRODUCTIVO | Admin/unpaid/auto-confirm functions require service role or internal secret before using service role internally. |

### Security Legacy

| Item | Classification | Notes |
|---|---|---|
| Broad anon grants from dumps | LEGACY DO NOT COPY | Public data access belongs behind signed endpoints, not direct table grants. |
| Authenticated `using (true)` commerce policies | LEGACY DO NOT COPY | Authenticated does not mean operational staff; owner/staff distinctions must be explicit. |
| Public service-role jobs | LEGACY DO NOT COPY | Cron and provider jobs need service role/internal-secret gates before side effects. |
| Frontend totals and product metadata | LEGACY DO NOT COPY | Payment totals, fulfillment URLs, membership durations, and Gift Card commercial facts must be server-owned. |

## Public Spa Experience Regularization

This phase classifies the final public landing/store/admin reconciliation from
the original 38 local movements without copying protected worktrees wholesale.

### Universal NEXORA Candidates

| Capability | Status | Notes |
|---|---:|---|
| Public media manifest | FOUNDATION | Web runtime media paths are centralized in `lib/config/web_media_paths.dart`; asset existence and case-sensitive paths are covered by tests. |
| Public content composition | FOUNDATION | Landing sections are explicit widgets with scroll keys and recoverable public assets; the pattern can be rebuilt as a CMS-backed public shell. |
| Web concierge client | FOUNDATION | Flutter client is only a lightweight chat surface; trust boundary remains the hardened `web_concierge` Edge Function. |
| Store capability preservation | FOUNDATION | Store reconciliation protects a superior implementation from being overwritten by an older Gift Card-only shortcut. |
| Admin AI controls | FOUNDATION | UI maps operational modes to human labels while secrets remain server-side and RLS owns access. |

### Vertical Spa & Wellness

| Capability | Status | Notes |
|---|---:|---|
| Immersive hero video | PRODUCTIVO | `Portada-2.mp4` replaces deleted `portada.mp4` and is declared through the Flutter web asset path. |
| Experience pillars | PRODUCTIVO | `assets/experiencia/*` images now support the public "Presencia/Conexion/Transformacion" section. |
| Concierge reservations | PRODUCTIVO | Public CTAs open the web concierge, which can guide new reservation intent through the existing backend. |
| Gift Card store entry | PRODUCTIVO | `StorePage` retains Gift Card Digital fulfillment while preserving broader catalog, cart and membership navigation. |
| AI operating modes | PRODUCTIVO | Admin UI presents Apagado, Piloto and Publico, with legacy `assisted` displayed as Publico. |

### Legacy

| Item | Classification | Notes |
|---|---|---|
| Wholesale landing copy | LEGACY DO NOT COPY | Public widgets must be fused with current checkout/navigation/security state, not pasted over the regularized branch. |
| Old store shortcut | LEGACY DO NOT COPY | The Gift Card-only `StorePage` was useful historically but would erase catalog/cart/membership capabilities. |
| Loose AI SQL | LEGACY DO NOT COPY | `ai_bot_rules_no_cancel_and_assisted.sql` is evidence, not an executable baseline; future changes need reviewed migrations. |
| Public chat without endpoint hardening | LEGACY DO NOT COPY | The UI is safe only because `web_concierge` has CORS, body caps, message caps, rate limit and sanitized logs. |
| Case-insensitive asset assumptions | LEGACY DO NOT COPY | Web assets must match exact case; `Portada-2.mp4` and `portada.mp4` are different runtime paths. |
| Direct browser Storage signing | LEGACY DO NOT COPY | Private document buckets should mint signed URLs through authorized backend actions. |

## Baseline Object Classification

| Object | Classification | Source |
|---|---|---|
| `profiles` | SOLO EXISTE EN REMOTO | Remote schema dump; required by roles and FKs. |
| `clients` | SOLO EXISTE EN REMOTO | Remote schema dump; required by bookings, Gift Cards, reception alerts, and WhatsApp logs. |
| `services` | SOLO EXISTE EN REMOTO | Remote schema dump; required by bookings and Gift Cards. |
| `staff` | SOLO EXISTE EN REMOTO | Remote schema dump; required by booking therapist FKs. |
| `sucursales` | SOLO EXISTE EN REMOTO | Remote schema dump; required by booking/business settings FKs. |
| `membership_plans` | SOLO EXISTE EN REMOTO | Remote schema dump; dependency of `client_memberships`. |
| `client_memberships` | SOLO EXISTE EN REMOTO | Remote schema dump; dependency of bookings/payments. |
| `bookings` | SOLO EXISTE EN REMOTO | Remote schema dump plus loose producer SQL. |
| `sales` | SOLO EXISTE EN REMOTO | Remote schema dump; dependency of `payments.sale_id`. |
| `orders` | NECESITA RECONCILIACIÓN | Loose SQL exists, but remote schema has additional production columns. |
| `order_items` | NECESITA RECONCILIACIÓN | Loose SQL exists, but remote schema has redemption columns. |
| `payments` | NECESITA RECONCILIACIÓN | Loose SQL exists as ecommerce-only; remote schema is unified. |
| `gift_cards` | NECESITA RECONCILIACIÓN | Loose SQL exists, remote schema adds client/service validity fields. |
| `business_whatsapp_settings` | NECESITA RECONCILIACIÓN | Loose SQL exists; remote schema adds environment/webhook state. |
| `ai_settings` | NECESITA RECONCILIACIÓN | Multiple loose SQL files extend the same singleton settings table. |
| `whatsapp_logs` | NECESITA RECONCILIACIÓN | Multiple loose SQL files extend logs for Meta, queue, and admin workflows. |
| `reception_alerts` | SQL SUELTO CANÓNICO | Loose SQL is canonical, remote confirms table/RLS/realtime. |
| `log_reception_alert` | SQL SUELTO CANÓNICO | Loose SQL and remote dump agree on core behavior. |
| `notify_reception_on_new_booking` | SQL SUELTO CANÓNICO | Loose SQL and remote dump define producer trigger. |
| `notify_reception_on_booking_change` | SQL SUELTO CANÓNICO | Loose SQL and remote dump define update producer trigger. |
| `admin_notification_deliveries` | YA TIENE MIGRACIÓN | Exists only in Gift Card Alerts branch; not integrated in this branch. |
