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
| Gift Cards | PRODUCTIVO | `gift_cards` exists with balances, client/service links, and ecommerce lineage. |
| Anticipos | PRODUCTIVO | Booking deposit fields, Stripe checkout, payment requirements, PDF receipts, voucher lookup, and AI deposit settings exist. |
| Historial de spa | PARCIAL | Appointment status history and client stats exist, but the record is spread across multiple SQL files. |
| Evaluaciones | NO COMPROBABLE | No certified schema for intake/evaluation records was identified in the baseline path. |
| Consentimientos | NO EXISTE | No verified consent workflow was found in the regularized baseline. |
| Rituales | PARCIAL | Service/product metadata can represent rituals, but there is no dedicated ritual domain model. |
| Seguimiento | PARCIAL | WhatsApp, reminders, AI handoff, and client notes support follow-up; coverage is fragmented. |

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
