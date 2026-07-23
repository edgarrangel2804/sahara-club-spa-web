# Gift Card Digital Fulfillment Regularization

Scope: local implementation only in `C:\Proyectos\sahara-club-spa-web-regularization`.
No remote Supabase writes, no deploy, no Stripe live calls, no real WhatsApp sends.

## Audit Matrix

| Capacidad | Existe | Parcial | No existe | Fuente |
|---|---:|---:|---:|---|
| Destinatario | Si | No | No | Existing web form captured `recipient_name`; now enforced in `gift_card_page.dart`, `create_checkout_session`, and `gift_cards`. |
| Telefono destinatario | No | No | Si | Missing before; now captured, normalized to E.164, stored in `recipient_phone`, and used only server-side for delivery. |
| Nombre remitente | Si | No | No | Existing metadata/form; now required and persisted as `sender_name`. |
| Dedicatoria | Si | Si | No | Existing `message` was partial; now normalized to `dedication_message`, max 350 chars, no HTML/control chars, no technical logging. |
| Fecha de inicio | No | No | Si | Missing before; now buyer selects `valid_from` as local date and backend rejects past dates. |
| Vencimiento 3 meses | No | Si | No | Existing fulfillment used one month/`expires_at`; now uses `expires_on = valid_from + 3 calendar months`. |
| Generacion de tarjeta digital | No | Si | No | Existing public page/QR was frontend-only; now Edge runtime generates a PDF asset. |
| Descarga | No | Si | No | Existing lookup accepted weak identifiers; now download requires signed `gift_card_download` token. |
| WhatsApp destinatario | No | Si | No | Existing webhook sent a code URL to buyer; now delivery targets recipient phone after asset generation. |
| Copia comprador | No | No | Si | Missing before; now buyer opt-in controls `buyer_whatsapp_copy`. |
| Reenvio recepcion | No | Si | No | Feature branch had alert groundwork; now local backend action can view, generate link, resend recipient, or send buyer copy. |
| QR | Si | Si | No | Existing QR exposed code on public page; now PDF and authorized page render QR containing only opaque gift code. |
| Control de canje | No | Si | No | Existing waiver checks were date/balance-light; now transactional RPC enforces active, validity window, balance, and duplicate booking guard. |
| Expiracion backend | No | Si | No | Existing checks relied on `expires_at`; now `valid_from`/`expires_on` are backend constraints and redemption gates. |
| Idempotencia | Si | Si | No | Existing `order_item_id` upsert was partial; now creation, asset path, delivery ledger, and reception alert use stable keys. |

## Implemented Flow

1. Gift Card form captures recipient, recipient WhatsApp, sender, dedication, start date, buyer copy opt-in, and terms.
2. `create_checkout_session` validates Gift Card metadata and resolves service price/snapshot server-side.
3. Stripe-confirmed fulfillment calls `fulfillGiftCardItem` only after payment is paid.
4. `fulfillGiftCardItem` creates or reuses one `gift_cards` row per `order_item_id`.
5. `ensureGiftCardDigitalAsset` generates a PDF in Edge runtime, uploads it to private bucket `gift-card-assets`, stores path/status/hash, and returns a signed URL.
6. Recipient WhatsApp delivery and buyer copy delivery use `gift_card_deliveries` with `gift_card_id + destination_hash + delivery_type`.
7. `confirm_order_payment` returns signed download tokens to the success page.
8. `gift_card_download` validates the HMAC token, creates/recovers the signed Storage URL, records download, and returns a minimal authorized payload.
9. `gift_card_reception_actions` prepares internal reception/admin actions: view, download link, resend recipient, and send buyer copy.
10. `redeem_service_gift_card` validates active status, validity window, balance, and booking uniqueness before consuming balance.

## Security Notes

- Gift Card download URLs use purpose-scoped HMAC tokens; the URL does not contain phone, email, Stripe session, payment intent, or raw order id.
- Private Storage paths use internal ids only: `gift-cards/<gift_card_id>/<version>/gift-card.pdf`.
- Technical logs sanitize tokens and phones; dedication text is not logged.
- QR data is the opaque redemption code only.
- Reception actions require JWT plus operational `staff` or `profiles` role.

## Local-Only Boundaries

- Migration was created but not pushed.
- Edge Functions were checked locally but not deployed.
- WhatsApp delivery code was compiled/tested with mocks/helpers only; no real Meta send was executed.
- Stripe webhook was not replayed and no live Stripe API call was made.
