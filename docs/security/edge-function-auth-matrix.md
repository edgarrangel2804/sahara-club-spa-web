# Edge Function Auth Matrix

Status after local hardening. `verify_jwt=false` is acceptable only when the
function has an explicit in-code boundary.

| Function | `verify_jwt` | Caller | Auth/control | Notes |
|---|---:|---|---|---|
| `whatsapp-webhook` | false | Meta | Verify token + HMAC app secret | Must remain public for Meta. |
| `stripe_webhook` | false | Stripe | Stripe signature + timestamp tolerance | No browser contract. |
| `deposit_voucher` | false | Browser receipt page | HMAC voucher token, TTL, rate limit | No anon key/table access. |
| `gift_card_download` | false | Browser Gift Card link | HMAC Gift Card token, TTL, rate limit | Returns minimal card payload + signed asset URL. |
| `create_appointment_deposit_payment_intent` | false | Legacy browser payment page | Pending booking check, server amount, CORS/rate limit | Still exposes PaymentIntent by booking id; signed checkout is preferred. |
| `web_concierge` | false | Public landing chat | CORS allowlist, body caps, message caps, rate limit | Uses service role internally only after input controls. |
| `create_booking_deposit_checkout` | false | WhatsApp AI/router/internal | Pending booking check, server amount, signed voucher success URL, rate limit | Ignores caller-supplied amount/currency. |
| `notify_unpaid_deposits` | false | Cron/internal | Service role Bearer or `SAHARA_INTERNAL_FUNCTION_SECRET` | Sends admin WhatsApp best-effort. |
| `notify_admins` | false | DB trigger/internal | Service role Bearer or `SAHARA_INTERNAL_FUNCTION_SECRET` | No unauthenticated send path. |
| `auto_confirm_bookings` | false | Cron/internal | Service role Bearer or `SAHARA_INTERNAL_FUNCTION_SECRET` | `force=1` is protected by the same gate. |
| `send_deposit_receipt` | false | Stripe webhook or reception | Service role, internal secret, or operational JWT role | `download_link` returns signed Storage URL without WhatsApp send. |
| `gift_card_reception_actions` | true | Reception/admin UI | JWT + operational role check | Existing role assertion remains. |
| `create_checkout_session` | default true | Store/WhatsApp with anon/user/service JWT | Server-side service/Gift Card pricing, return URL allowlist, rate limit | Unsupported product types are blocked until server catalog exists. |
| `confirm_order_payment` | default true | Store success page with anon/user JWT | Stripe status verification + rate limit | Returns Gift Card download token only after Stripe reports paid. |
| `setup_admin_template_v2` | default true | None | Returns 410 | Kept neutralized. |

## Shared Runtime Controls

- `runtime_security.ts` centralizes CORS allowlisting, JSON/preflight
  responses, IP keys, in-memory rate limits, token fingerprints, service-role
  detection, internal-secret authorization, operational-role authorization, and
  technical log sanitization.
- Allowed browser origins default to `https://saharaclubspa.com`,
  `https://www.saharaclubspa.com`, `localhost`, and `127.0.0.1`. Extra origins
  may be supplied by `SAHARA_ALLOWED_ORIGINS`.
- Internal endpoints should use service role Bearer where possible. The
  `SAHARA_INTERNAL_FUNCTION_SECRET` path is for schedulers/triggers that cannot
  pass a Supabase JWT reliably.
