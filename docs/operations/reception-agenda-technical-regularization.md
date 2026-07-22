# Reception Agenda Technical Regularization

Scope: Fase 2 regularization for reception, agenda, booking sync, and internal alerts in `C:\Proyectos\sahara-club-spa-web-regularization`.

No remote writes, no Gift Card Alerts integration, no production WhatsApp, no Stripe live, no deploy.

## Code Changes

| Area | Change | Reason |
|---|---|---|
| AgendaPage | Removed the out-of-scope `deposit_receipt_actions.dart` import and changed the `Comprobante` button to a local deferred SnackBar. | The receipt module belongs to a later phase and would break `flutter analyze`. The action now performs no remote side effect. |
| BookingSyncService | Reused `BookingTimeUtils` for booking date formatting and Tijuana ISO timestamps. | Removes duplicated timezone logic and keeps availability RPC timestamps testable. |
| ReceptionAlertsService | Replaced fixed UTC-7 date calculation with DST-rule Tijuana helper. Added pure alert filtering/deduping. | Avoids stale-day bugs around DST and preserves future commercial alerts without `booking_id` or `booking_date`. |
| Reception login | Formatted and line-ending normalized only. | No behavior change in this phase. |
| Tests | Added model/service/timezone helper tests. | Covers nullable alert fields, unknown types, commercial alerts, dedupe, and Tijuana date conversion. |

## AgendaPage Functional Map

| Area | Current code | Recovered change | Risk | Dependency |
|---|---|---|---|---|
| Calendario | `_AgendaPageState`, `_AgendaCalendarHours`, day/week/month controls. | Recovered full operational agenda surface. | MEDIO: monolithic widget and implicit state. | Flutter UI, Supabase bookings. |
| Vista diaria/semanal | `_DayGrid`, `_WeekGrid`, therapist/day grid. | Recovered responsive agenda views. | MEDIO: hard to test as one unit. | `_Booking`, therapists, schedule blocks. |
| Horarios | Business hours constants and staff working-hour loaders. | Recovered schedule expansion and staff-time-off handling. | MEDIO: timezone/date boundaries need more tests later. | `staff_working_hours`, `staff_time_off`, `schedule_blocks`. |
| Recepcion | Module nav, role-aware visible modules, reception login. | Recovered staff-only login and top-nav operations. | MEDIO: `reception` vs `receptionist` naming drift. | `staff`, `role_permissions`. |
| Campana de alertas | `ReceptionAlertsBell`, `_loadAlerts`, `_subscribeToAlertsRealtime`. | Recovered bell and floating alert stack. | BAJO-MEDIO: Supabase reconnect behavior is provider-owned, not explicitly retried. | `reception_alerts` Realtime. |
| Confirmacion | `_updateBookingStatus`, `_confirmClientNotification`. | Recovered confirmation with WhatsApp warning. | MEDIO: WhatsApp side effect is trigger-driven and external to UI tests. | booking trigger, WhatsApp templates/logs. |
| Cancelacion | Dialog action sets `cancelled` after confirmation prompt. | Recovered cancellation action. | MEDIO: external triggers may notify clients. | booking triggers, WhatsApp. |
| Reagenda | `_rescheduleBooking`, `_statusAfterReschedule`. | Recovered status after reschedule and notification warning. | MEDIO: status rules are spread across UI and SQL. | bookings, availability RPC. |
| Cobro | `AgendaSalesService`, `_ChargeBookingDialog`, `_openSaleFromBooking`. | Recovered sale creation after service completion. | MEDIO-ALTO: sales/payment state spans multiple tables. | sales, sale_items, payments. |
| Anticipos | payment requirement fields, deposit fields, `payment_received` realtime. | Recovered deposit visibility and payment toast. | MEDIO: receipt action deferred. | Stripe webhook, booking deposits, receipts phase. |
| Comprobantes | Button remains visible for paid/deposit states but now deferred. | Compile-safe placeholder. | BAJO: no receipt is sent until next phase. | Future `lib/features/receipts`. |
| Gift Cards | Booking waiver display and `giftCardId` indicators only. | Preserved operational display; no alert integration. | MEDIO: feature branch has alert model/UI additions pending. | future Gift Card Alerts merge. |
| Paquetes | Active package check and package waiver at booking save. | Recovered package session consumption path. | MEDIO: package domain not regularized here. | client packages, bookings. |
| Clientes | Client autocomplete/history and `clients` record mapping. | Recovered client-record fallback and history dialog. | MEDIO: duplicate-name fallback remains pragmatic. | `clients`, `profiles`. |
| Terapeutas | Staff loaders, therapist assignment, availability RPC. | Recovered therapist validation and live status. | MEDIO: capacity/availability logic is SQL-owned. | `staff`, `check_staff_availability`. |
| Estados de cita | `_statusLabel`, `_statusColor`, dialog actions. | Recovered expanded status family. | ALTO: states are duplicated in UI, SQL, Edge, and triggers. | bookings, WhatsApp, sales. |
| Acciones WhatsApp | Message center and template RPC. | Recovered operator-triggered WhatsApp selector. | ALTO: real sends are external side effects; not exercised locally. | `whatsapp_send_template_to_booking`. |
| Dialogos y navegacion | Booking detail, new booking, charge, client history, module nav. | Recovered full reception workflow. | MEDIO: many callbacks coupled to `_AgendaPageState`. | UI widgets and Supabase services. |

## Reception Alerts Flow

Flow:

`Postgres trigger/RPC -> reception_alerts -> Supabase Realtime -> ReceptionAlertsService -> ReceptionAlertsBell/ReceptionAlertBanner -> AgendaPage`

| Check | Result | Notes |
|---|---|---|
| Initial query | PASS | `fetchRecent` selects unresolved rows, booking dates from today forward, or rows with null `booking_date`. |
| INSERT Realtime | PASS | `subscribe` calls `onChanged` and parses the inserted payload for banner display. |
| UPDATE Realtime | PASS | `subscribe` calls `onChanged` so the bell/list reloads. |
| Seen | PASS | `markSeen` updates unseen rows with `seen_at` and current user id. |
| Resolved | PASS | `markResolved` sets `resolved_at` and current user id. |
| Old alerts | PASS | SQL filter plus `shouldKeepAlert` drop past booking alerts. |
| Null `booking_date` | PASS | Preserved for valid commercial or operational events. |
| Null `booking_id` | PASS | Model/service no longer assume booking id; future Gift Card alerts remain listable. |
| Ordering | PASS | DB orders by `created_at desc`; `normalizeAlertList` also sorts newest first. |
| Unknown types | PASS | Model falls back to `Evento`, notifications icon, neutral accent. |
| Reconnection | PARCIAL | Supabase channel owns reconnect; UI reloads on events but no explicit retry loop was added. |
| Duplicates | PASS | Floating banners already dedupe by id; service normalizes duplicate rows by id. |
| Errors | PARCIAL | UI catches and suppresses load/mark errors; no user-facing retry copy added in this phase. |

Alert types preserved: `booking_pending_reception`, `booking_cancelled`, `reschedule_requested`, `deposit_paid`, `requires_reception`, plus unknown/future events. `gift_card_purchased` is not integrated yet.

## Booking Sync Audit

| Scenario | Current behavior | Risk |
|---|---|---|
| New booking | `upsertBooking` validates client, therapist, service, time, duration, phone warning, and availability RPC before insert. | MEDIO: duplicate client names still need cleanup. |
| Confirmed | UI writes `confirmed`, emits a system message, and WhatsApp trigger may notify. | MEDIO: trigger-side idempotency must remain certified. |
| Cancelled | UI writes `cancelled` after operator confirmation. | MEDIO: external notifications are side effects. |
| Rescheduled | UI updates booking date/time/branch and status strategy; AI-managed bookings return to reception review. | MEDIO: status rules are split. |
| In service | `confirmed/rescheduled/checked_in -> in_progress`. | BAJO-MEDIO: legacy `checked_in` remains compatibility state. |
| Completed | `completed` creates/ensures a sale, then attempts `awaiting_payment`. | MEDIO-ALTO: sale creation must remain idempotent. |
| Payment received | Realtime on booking status `payment_received` shows a toast and pending count reload. | MEDIO: Stripe/webhook path outside Flutter tests. |
| Concurrent update | Realtime reload debounces booking changes. | MEDIO: no optimistic conflict resolution. |
| Missing/deleted booking | Fetch reload will drop it from UI; detail actions depend on current id. | BAJO-MEDIO. |

## Appointment State Matrix

| DB status | UI label | Color | Main actions | Expected transitions |
|---|---|---|---|---|
| `scheduled` | Agendada | `#C68A17` | Confirmar, Cancelar, No se presento, Editar, WhatsApp | `confirmed`, `cancelled`, `no_show` |
| `pending` | Agendada | `#C68A17` | Confirmar, Cancelar, No se presento, Editar, WhatsApp | `confirmed`, `cancelled`, `no_show` |
| `pending_reception` | Agendada - IA | `#FF8C00` | Confirmar, Cancelar, No se presento, Editar, WhatsApp | `confirmed`, `cancelled`, `no_show` |
| `pending_payment` | Agendada - esperando anticipo | `#C68A17` | Cancelar, Editar, WhatsApp | external payment path to `payment_received`; inconsistency: detail dialog does not expose Confirmar |
| `payment_received` | Pago recibido - por confirmar | `#1A9E65` | Confirmar, Cancelar, No se presento, Comprobante diferido, Editar | `confirmed`, `cancelled`, `no_show` |
| `confirmed` | Confirmada | `#1A9E65` | Iniciar sesion, Cancelar, No se presento, Comprobante diferido, Editar, WhatsApp | `in_progress`, `cancelled`, `no_show` |
| `checked_in` | En servicio | `#2088D8` | Iniciar sesion, Cancelar, Comprobante diferido, Editar | `in_progress`, `cancelled` |
| `in_progress` | En servicio | `#6A54E0` | Terminar sesion, Cancelar, Comprobante diferido | `completed`, then usually `awaiting_payment` |
| `completed` | Finalizada | `#666666` | Cobrar, Ver ticket, Comprobante diferido, Editar | `awaiting_payment`, then sales/payment flow |
| `awaiting_payment` | Pendiente de cobro | `#B06A1F` | Cobrar, Ver ticket, Editar | sales/payment flow to `paid` |
| `paid` | Pagada | `#0E8F55` | Ver ticket, Comprobante diferido, Pagada | terminal/financially closed |
| `cancelled` | Cancelada | `#B32D2D` | Editar, Historial, Chat | mostly terminal |
| `no_show` | No asistio | `#8B4D4D` | Cancelar, Editar, Historial, Chat | inconsistent; needs later policy decision |
| `rescheduled` | Reagendada | `#0A9AA4` | Iniciar sesion, Cancelar, No se presento, Comprobante diferido | `in_progress`, `cancelled`, `no_show` |

No new appointment states were introduced in this phase.

## Timezone

- Flutter now uses `BookingTimeUtils` for Tijuana commercial dates and local booking ISO strings.
- The helper applies Pacific/Tijuana DST rules: second Sunday in March at 02:00 through first Sunday in November at 02:00.
- `ReceptionAlertsService.todayPeninsula` no longer subtracts a fixed UTC-7 offset.
- Tests cover UTC-to-Tijuana date rollover and DST boundary offsets.
- Residual risk: without an IANA timezone package, future legal timezone changes require code update. Current behavior is safer than fixed offsets and keeps local tests dependency-free.

## Reception Security

| Area | Classification | Evidence |
|---|---|---|
| Login | MEDIO | `ReceptionLoginPage` requires Supabase auth, active `staff`, `can_login`, and role in `admin/reception/therapist`. |
| Roles | MEDIO | `RolePermissions` canonicalizes `reception` to `receptionist`; SQL still contains both names in policies. |
| Bookings RLS | MEDIO | Local migration includes staff policies for bookings; broad grants remain a blueprint risk. |
| Reception alerts RLS | MEDIO | Alerts are read by reception UI and updated for seen/resolved; exact policy ownership remains SQL-baseline dependent. |
| Client data | MEDIO | Agenda shows phone/name/history to staff modules. This is operationally needed but should not become public. |
| Service role | ALTO | Edge Functions and triggers write alerts/notifications using privileged paths; no remote changes were made. |
| Logs/PII | MEDIO | UI catches many errors quietly; SQL/Edge logging requires separate privacy review. |
| Route protection | MEDIO | Flutter route is protected by staff login, but browser-side route protection must rely on Supabase session and RLS. |

## Gift Card Alerts Comparison

| File | Regularization | Gift Card Feature | Conflict | Strategy |
|---|---|---|---|---|
| `lib/features/reception_alerts/reception_alert.dart` | Booking/deposit alert model; unknown event fallback. | Adds `gift_card_purchased`, order/payment/gift card fields, buyer/contact/product fields, metadata helpers, gift card title/icon/accent. | YES | FUSION MANUAL |
| `lib/features/reception_alerts/reception_alert_banner.dart` | Operational booking/deposit banner. | Adds gift-card-specific date/service/money display. | YES | EXTRAER COMPONENTE |
| `lib/features/reception_alerts/reception_alerts_bell.dart` | Operational bell/list for booking alerts. | Large UI changes for gift card alert details. | YES | FUSION MANUAL |
| `lib/features/reception_alerts/reception_alerts_service.dart` | Regularized timezone and dedupe; preserves null booking fields. | Older fixed UTC-7 service without timezone helper/dedupe. | YES | CONSERVAR REGULARIZATION, then add feature fields later |
| `lib/pages/agenda_page.dart` | No receipt import; `Comprobante` is deferred; no Gift Card alert navigation. | Imports receipt action, opens receipt dialog, routes `isGiftCardPurchase` alerts to `ventas`. | YES | FUSION MANUAL in later Gift Card phase |

Exact future integration point:

1. Extend `ReceptionAlert` with Gift Card purchase fields from the feature branch.
2. Add `gift_card_purchased` title/icon/accent and display helpers.
3. Add banner/bell presentation for commercial alerts as a component branch, not by replacing regularized widgets wholesale.
4. In AgendaPage `_openAlertTarget`, route Gift Card purchase alerts to `ventas`.
5. Restore receipt dialog only when `lib/features/receipts` is regularized in the client/receipt phase.

## Validation Snapshot

| Command | Result |
|---|---|
| `flutter test` | PASS: 12 tests |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | PASS: exit 0; 145 warnings/infos remain historical |
| `git diff --check` | PASS |
| `supabase db reset` | PASS: local reset completed; no remote migration was applied |

## Commits

| Commit | Purpose |
|---|---|
| `284370bb873680aa99d7e6fe964593aedda3a539` | Exact source recovery from verified backup. |
| `38da37f16ee43d5fbc595215878f13f710b5c3dd` | Technical regularization: timezone helper, alert normalization, deferred receipt action. |
| `770f5aed8b54d5a2bb02eba1138bb97076ec190e` | Tests for alerts and pure booking/time helpers. |
