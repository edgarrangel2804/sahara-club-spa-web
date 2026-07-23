# Legacy Do Not Copy

This file records productive Sahara behavior that may be real and useful, but should not be copied directly into NEXORA.

## Database And Migrations

- SQL outside `supabase/migrations` is the central drift risk. Sahara has many productive objects that were applied from loose SQL or directly against the remote database.
- Do not replay the full remote dump as a migration. Reconstruct capability baselines by domain, in order, with tests.
- Do not mix schema, one-off data repair, operational seed data, and experiments in the same SQL file.
- Do not rely on production-only objects that local reset cannot recreate.
- Do not leave functions deployed remotely without matching Git history.

## Security And RLS

- Do not copy `using (true)` RLS policies as a default pattern. Some ecommerce policies currently allow broad authenticated access.
- Do not copy anonymous read access for orders or order items without a signed, scoped token design.
- Do not expose `security definer` RPCs broadly unless the trust boundary is explicit and tested.
- Do not keep `verify_jwt = false` on Edge Functions without a written reason, compensating auth, and abuse tests.
- Do not grant broad anon/auth access just because Supabase dumps include default grants.
- Do not let `authenticated` mean "staff". Commerce RLS must distinguish owner access from operational roles.
- Do not leave `SECURITY DEFINER` functions without `search_path = public, pg_temp`.
- Do not expose delivery/redemption RPCs to anon; use service role or an explicit operational-role check.

## Edge Functions And Public Runtime

- Do not publish service-role Edge Functions just because the recovered source comment says `verify_jwt=false`.
- Do not copy `auto_confirm_bookings` with a public `?force=1` path; it writes bookings and needs a cron-only trust boundary.
- Do not expose `whatsapp-ai-router` without caller authentication, rate limiting, and abuse controls.
- Do not reuse `deposit_voucher` as a public lookup by `booking_id` or `session_id` without a scoped signed token.
- Do not reuse Gift Card public lookup by raw `code`, `order_id`, or Stripe `session_id`; use a scoped signed token with purpose `gift_card_download`.
- Do not use Stripe Checkout Session ID as authorization for public documents; it can be correlation only.
- Do not accept externally supplied `success_url` domains for appointment deposits. Build and allowlist the URL server-side.
- Do not log full voucher/document tokens; store at most an irreversible hash or short non-sensitive prefix.
- Do not ship public document links without purpose, scope, HMAC validation, and expiration.
- Do not embed a service-role web concierge without rate limits, prompt injection monitoring, and clear observability.
- Do not keep one-shot setup functions deployed after their setup task is complete; remove or keep them neutralized.
- Do not trust public CORS wildcard as harmless. Public/signed endpoints still need an origin allowlist and abuse limits.
- Do not trust caller-supplied appointment deposit amounts or checkout return domains.
- Do not expose the public web concierge UI unless the Edge Function keeps origin controls, body/message caps, rate limits, sanitized logs, and server-side secret ownership.

## Secrets And Configuration

- Do not place an anon key or other live project identifiers in standalone HTML files.
- Do not mix encrypted production configuration, masked display values, and runtime business settings without clear ownership.
- Do not require production secrets for local reset or local tests.
- Do not hardcode Sahara branch IDs, phone numbers, service names, prices, or copy into reusable NEXORA foundations.

## Domain Modeling

- Do not trust product prices or payable totals from the frontend. Server-side pricing must own Gift Card, package, membership, and appointment charges.
- Do not accept product types in checkout unless a server-owned catalog/fulfillment source exists for that type.
- Do not trust frontend Gift Card fields for balance, expiration, status, code, or amount paid. The backend owns all commercial facts after payment.
- Do not generate Gift Card assets only in the browser from query params; authorized backend payloads and private Storage are the safe boundary.
- Do not calculate Gift Card validity with fixed offsets such as 90 days when the business rule is calendar months.
- Do not couple Stripe webhook behavior directly to unrelated booking and notification side effects without idempotent boundaries.
- Do not let optional domain FKs expand every migration into the whole schema. Define explicit domain ownership and migration order.
- Do not treat `profiles.role`, `staff.role`, and dynamic permissions as interchangeable. Normalize the role model before reuse.
- Do not copy duplicate names like `reception` and `receptionist` without a compatibility strategy.
- Do not copy `AgendaPage` as an application template. It is productive Sahara runtime, but it mixes calendar UI, booking writes, sales navigation, WhatsApp actions, and alert routing in one widget.
- Do not copy appointment status labels/colors/actions as separate switch statements. Extract one state machine first.
- Do not copy `ClientsModule` as a client-management template. It is productive Sahara runtime, but it mixes PII, histories, packages, memberships, Gift Cards, sales, Supabase calls, and receipt actions in one widget tree.
- Do not implement automatic client merges from phone/email heuristics without an audited review workflow.
- Do not replace a richer Store implementation with an older Gift Card-only shortcut; preserve broader catalog, cart, checkout, memberships, and digital fulfillment paths.

## Public Site And Assets

- Do not assume web asset paths are case-insensitive. `Portada-2.mp4` must remain exact in code, pubspec, tests, and filesystem.
- Do not keep deleted landing media as a fallback unless it is intentionally declared and tested.
- Do not paste public landing widgets over a newer checkout/navigation shell; manually fuse hero, contact, concierge, Store and asset changes.
- Do not treat decorative public media as throwaway. Public spa experience assets are part of the product baseline and need hashable backup provenance.
- Do not execute loose AI or content SQL from backup folders. Promote intended behavior through reviewed migrations and tests.

## Notifications And Idempotency

- Do not send WhatsApp/admin notifications from non-idempotent paths.
- Do not rely on status-only checks when a unique delivery ledger is needed.
- Do not couple reception UI alerts, WhatsApp provider logs, and Stripe fulfillment without explicit replay safety.
- Do not allow webhook replay to create duplicate Gift Cards, alerts, or admin notifications.
- Do not send Gift Card WhatsApp documents without a delivery ledger keyed by `gift_card_id`, hashed destination, and delivery type.
- Do not put recipient phones, emails, payment ids, or full Gift Card codes into WhatsApp/reception technical logs.
- Do not merge Gift Card Alerts by replacing regularized reception alert files wholesale. Model fields, banner rows, bell UI, and Agenda navigation need a manual fusion after receipt/client regularization.
- Do not couple Gift Card purchase alerts to `booking_id`, `booking_date`, or default Agenda navigation. Commercial alerts need their own event context.
- Do not show full phone, email, Payment Intent, Checkout Session, download token, full redemption code, full dedication, or Stripe metadata in the reception bell/banner.
- Do not create a second admin notification ledger when an existing delivery ledger can express `gift_card_id + destination_hash + delivery_type`.
- Do not hardcode administrative WhatsApp recipients. Use configured admin numbers, normalization, dedupe, and masked logs.
- Do not retry every administrative destination indiscriminately. Successful or processing deliveries must be skipped by atomic claim.
- Do not send provider messages from webhook paths unless the critical paid Gift Card state is already durable and provider failures are best-effort.
- Do not expose receipt resend actions without caller authentication, rate limiting, and a delivery ledger.
- Do not make public voucher lookup depend on raw `booking_id`; use a scoped signed token and return only minimal paid voucher data.
- Do not let the browser mint signed Storage URLs for private operational documents; route through authorized Edge actions.

## Developer Experience

- Do not accept a repository where local Supabase reset cannot recreate the productive baseline.
- Do not omit generated database types once schema ownership stabilizes.
- Do not leave undocumented remote drift between Git, Supabase, Edge Functions, and app code.
- Do not use Sahara as a NEXORA template until each capability has local migrations, reset certification, tests, and security review.
