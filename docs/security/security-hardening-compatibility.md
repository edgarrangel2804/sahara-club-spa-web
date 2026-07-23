# Security Hardening Compatibility

This pass intentionally keeps productive Sahara flows working while removing
the broadest public data paths.

## Preserved Flows

| Flow | Compatibility decision |
|---|---|
| Stripe webhook | Remains `verify_jwt=false`; Stripe signature now rejects stale timestamps. |
| WhatsApp webhook | Remains `verify_jwt=false`; Meta signature/verify token remain the boundary. |
| Store checkout for services/Gift Cards | Function remains callable by browser/WhatsApp, but price and return URLs are server validated. |
| Gift Card download | Public signed token flow remains. Adds rate limit and CORS allowlist. |
| Deposit voucher | Public signed token flow remains. Uses shared CORS/IP handling. |
| Deposit receipt resend | Reception still invokes `send_deposit_receipt`; function now checks operational JWT role. |
| Deposit receipt open/download | Flutter no longer calls Storage directly; it invokes `send_deposit_receipt` with `action: download_link`. |
| Cron/admin jobs | Jobs still run with service role or internal secret; unauthenticated calls are rejected. |

## Behavior Changes

| Area | Change | Reason |
|---|---|---|
| Anonymous table reads | Anon grants removed from private commerce, client, booking, alert, log, and config tables. | Public documents must use signed token endpoints, not table access. |
| Checkout pricing | `create_checkout_session` ignores browser totals and resolves services/Gift Cards from `services`. | Prevents price tampering. |
| Unsupported store product types | `digital`, `physical`, and `membership` checkout items are rejected until backed by server-owned product/fulfillment tables. | Existing fulfillment trusted client metadata such as access URLs/durations. |
| Appointment deposit checkout | Caller-supplied `amount` and `currency` are ignored. | Amount comes from `deposit_required_cents`, booking/config, or Stripe Price. |
| `auto_confirm_bookings?force=1` | No longer usable without service role/internal secret. | Prevents public booking status writes. |
| Receipt Storage | `receipts` bucket is private with service-role-only object policy. | Signed URLs are minted by Edge after authorization. |
| Gift Card Storage | `gift-card-assets` stays private with service-role-only object policy. | Public access is token-scoped and time-limited. |

## Known Follow-Ups

| Follow-up | Why it remains |
|---|---|
| Product catalog normalization | The frontend can fall back to mock products when `products` is absent. This pass blocks unsafe product types instead of inventing a product schema. |
| Full endpoint inventory in `config.toml` | This pass documented and configured the changed public/internal endpoints; untouched admin/test functions still need a separate full endpoint certification pass. |
| Delivery ledger for deposit receipts | Gift Cards have a delivery ledger. Deposit receipt WhatsApp resend still logs to `whatsapp_logs`; a dedicated idempotent receipt delivery claim can be added later. |
| Generated Supabase DB types | Edge Functions still use loose clients because the recovered runtime does not ship generated DB types. |
| Remote deployment certification | No deploy or remote Supabase write was performed in this phase. Local reset and local Deno/Flutter checks are the certification boundary. |
