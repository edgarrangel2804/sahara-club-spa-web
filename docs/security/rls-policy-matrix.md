# RLS Policy Matrix

Baseline validated locally with `supabase db reset` after
`20260722030000_security_hardening.sql`.

## Commerce Tables

| Table | Anon grants | Authenticated read | Authenticated write | Service role |
|---|---:|---|---|---|
| `orders` | none | Owner (`customer_id = auth.uid()`) or operational roles | Operational roles only | Full |
| `order_items` | none | Owner through parent order or operational roles | Operational roles only | Full |
| `payments` | none | Owner through `client_id`, linked order, linked booking/client record, or operational roles | Operational roles only | Full |
| `gift_cards` | none | Client owner through `clients.profile_id`, linked order owner, or operational roles | Operational roles only | Full |
| `gift_card_transactions` | none | Card owner or operational roles | No direct authenticated writes | Full |
| `gift_card_deliveries` | none | none | none | Full |

Operational roles are evaluated through `public.has_any_role(...)` and include
`admin`, `super_admin`, `reception`, `receptionist`, and `sales` for commerce
policies. The helper reads active `profiles` and `staff.auth_user_id` records.

## Existing Operational Tables

| Table | Hardening action | Notes |
|---|---|---|
| `profiles` | Revoked anon grants | Existing owner/role RLS remains. |
| `clients` | Revoked anon grants | Existing owner/role RLS remains. |
| `bookings` | Revoked anon grants | Existing client/staff/therapist RLS remains. |
| `reception_alerts` | Revoked anon grants | Reception/admin select/update RLS remains; Realtime still honors RLS. |
| `ai_settings` | Revoked anon grants | Existing role-scoped policies remain. |
| `business_whatsapp_settings` | Revoked anon grants | Existing admin policies remain. |
| `whatsapp_logs` | Revoked anon grants | Existing staff/admin policies remain. |

## Function Grants

| Function | Public/anon | Authenticated | Service role | Notes |
|---|---:|---:|---:|---|
| `current_user_role()` | no | execute | execute | `SECURITY DEFINER`, `search_path = public, pg_temp`. |
| `get_user_role()` | no | execute | execute | Compatibility wrapper. |
| `has_any_role(text[])` | no | execute | execute | Central RLS role helper. |
| `log_reception_alert(...)` | no | no | execute | Prevents public RPC alert injection. |
| `claim_gift_card_delivery(...)` | no | no | execute | Delivery claims are backend-only. |
| `complete_gift_card_delivery(...)` | no | no | execute | Delivery completion is backend-only. |
| `redeem_service_gift_card(...)` | no | execute | execute | Internal role check blocks non-operational callers. |

All listed `SECURITY DEFINER` functions now set `search_path = public, pg_temp`.

## Validation Snapshot

- `supabase db reset`: passed after migration.
- `anon_private_grants`: `0` for commerce, alert, WhatsApp log, and config
  tables.
- Dynamic role test: `set local role anon; select count(*) from public.orders`
  raised `insufficient_privilege` and was caught as expected.
- Storage policies: `gift_card_assets_service_role_all` and
  `receipts_service_role_all` exist on `storage.objects` for `service_role`
  only.
