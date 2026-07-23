# Security Surface Inventory

Scope: regularization worktree, local Supabase baseline after
`20260722030000_security_hardening.sql`.

## Data Surfaces

| Surface | Trust boundary | Current control |
|---|---|---|
| `orders`, `order_items` | Commerce records and product snapshots | No anon grants. Authenticated reads only own order or operational roles. Mutations require operational RLS or service role. |
| `payments` | Stripe/payment references and raw provider payload | No anon grants. Authenticated reads only own linked payment or operational roles. Mutations require operational RLS or service role. |
| `gift_cards` | Gift Card balance, code, validity, buyer/recipient metadata | No anon grants. Public access uses signed download token only. Authenticated reads own linked card or operational roles. |
| `gift_card_transactions` | Redemption/load/refund audit trail | No anon grants. Authenticated read only staff or card owner. Writes are service role/RPC only. |
| `gift_card_deliveries` | WhatsApp/download delivery ledger | Service role only. No anon/authenticated grants. |
| `reception_alerts` | Internal operational alerts | No anon grants. Authenticated select/update for reception/admin policies. Realtime remains scoped to RLS. |
| `whatsapp_logs`, `ai_settings`, `business_whatsapp_settings` | Provider logs/secrets/configuration | No anon grants. Existing authenticated RLS remains role-scoped. |
| `clients`, `bookings`, `profiles` | Customer/appointment PII | No anon grants. Existing authenticated RLS remains role/owner scoped. |

## Storage Surfaces

| Bucket | Public | Allowed MIME | Access model |
|---|---:|---|---|
| `gift-card-assets` | false | `application/pdf` | Service role Storage policy only; public receives signed URL through `gift_card_download` or reception action. |
| `receipts` | false | `application/pdf` | Service role Storage policy only; reception requests signed URL through `send_deposit_receipt` action `download_link`. |

## Public/Signed Endpoints

| Function | Public reason | Compensating controls |
|---|---|---|
| `whatsapp-webhook` | Meta webhook has no Supabase JWT | Meta verify token for GET and `X-Hub-Signature-256` for POST. |
| `stripe_webhook` | Stripe webhook has no Supabase JWT | Stripe signature verification now includes timestamp tolerance. |
| `deposit_voucher` | Public paid receipt page | HMAC voucher token with purpose/TTL, paid-only minimal payload, rate limit, no raw token logs. |
| `gift_card_download` | Public Gift Card download link | HMAC gift card token with purpose/TTL, rate limit by token fingerprint + IP, minimal payload. |
| `create_appointment_deposit_payment_intent` | Legacy embedded deposit page | Booking must be `pending_payment`; amount comes from booking/config/Stripe price; rate limit and CORS allowlist. |
| `web_concierge` | Public landing chat | CORS allowlist, body/message caps, rate limit before service-role work. |

## Internal/Operational Endpoints

| Function | Caller boundary |
|---|---|
| `notify_unpaid_deposits` | Requires service role Bearer or `SAHARA_INTERNAL_FUNCTION_SECRET`. |
| `notify_admins` | Requires service role Bearer or `SAHARA_INTERNAL_FUNCTION_SECRET`. |
| `auto_confirm_bookings` | Requires service role Bearer or `SAHARA_INTERNAL_FUNCTION_SECRET`; `force=1` is no longer public. |
| `send_deposit_receipt` | Requires service role, internal secret, or operational user role. |
| `gift_card_reception_actions` | Requires Supabase JWT and operational reception/admin role. |
| `create_checkout_session` | Callable by anon/user JWT, but prices/return URLs are server validated and rate limited. |
| `confirm_order_payment` | Callable by anon/user JWT after Stripe redirect; checks Stripe status server-side and rate limits. |
