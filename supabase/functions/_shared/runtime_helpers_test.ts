import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { getConnectionStatusForDraft, normalizePhone } from "./whatsapp_business.ts"
import {
  buildPricing,
  normalizeCurrency,
  normalizeType,
  toMinorUnits,
  verifyStripeSignature,
} from "./stripe_checkout.ts"
import {
  isPaidBooking,
  maskClientName,
  parseVoucherLookup,
  publicVoucherPayload,
  signVoucherToken,
  verifyVoucherToken,
} from "./deposit_receipts.ts"

Deno.test("normalizePhone keeps WhatsApp Cloud API dialing rules stable", () => {
  assertEquals(normalizePhone("646 151 9597"), "5216461519597")
  assertEquals(normalizePhone("+52 646 151 9597"), "5216461519597")
  assertEquals(normalizePhone("+5216461519597"), "5216461519597")
  assertEquals(normalizePhone("001 602 587 7771"), "16025877771")
  assertEquals(normalizePhone("+1 602 587 7771"), "16025877771")
  assertEquals(normalizePhone(""), "")
})

Deno.test("getConnectionStatusForDraft marks empty and partial Meta settings as pending/not configured", () => {
  assertEquals(getConnectionStatusForDraft({}), "not_configured")
  assertEquals(getConnectionStatusForDraft({ phone_number_id: "123" }), "pending")
  assertEquals(
    getConnectionStatusForDraft({
      phone_number_id: "123",
      whatsapp_business_account_id: "456",
      whatsapp_phone_number: "+526461519597",
      access_token_present: true,
    }),
    "pending",
  )
})

Deno.test("Stripe amount helpers preserve MXN cents and gift card type normalization", () => {
  assertEquals(normalizeCurrency("MXN"), "mxn")
  assertEquals(normalizeCurrency(" usd "), "usd")
  assertEquals(normalizeCurrency(""), "mxn")
  assertEquals(normalizeType("giftcard"), "gift_card")
  assertEquals(normalizeType("membership"), "membership")
  assertEquals(toMinorUnits(199.995), 20000)

  assertEquals(
    buildPricing(
      [
        {
          product_id: "svc-1",
          name: "Masaje",
          unit_price: 100,
          quantity: 2,
          product_type: "service",
        },
        {
          product_id: "svc-2",
          name: "Facial",
          unit_price: 50,
          quantity: 1,
          product_type: "service",
        },
      ],
      { member_credit: 20, service_charge: 5 },
    ),
    {
      subtotal: 250,
      memberCredit: 20,
      serviceCharge: 5,
      total: 235,
    },
  )
})

Deno.test("verifyStripeSignature accepts valid v1 signatures only", async () => {
  const payload = JSON.stringify({ id: "evt_test", type: "checkout.session.completed" })
  const secret = "whsec_test"
  const timestamp = "1719870000"
  const signedPayload = `${timestamp}.${payload}`
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signedPayload),
  )
  const signature = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")

  assertEquals(
    await verifyStripeSignature(payload, `t=${timestamp},v1=${signature}`, secret),
    true,
  )
  assertEquals(
    await verifyStripeSignature(payload, `t=${timestamp},v1=bad${signature}`, secret),
    false,
  )
  assertEquals(await verifyStripeSignature(payload, null, secret), false)
})

Deno.test("deposit voucher lookup rejects public booking ids and validates Stripe sessions", () => {
  assertEquals(parseVoucherLookup({ bookingId: "00000000-0000-4000-8000-000000000000" }), {
    ok: false,
    error: "public_booking_id_not_allowed",
  })
  assertEquals(parseVoucherLookup({ sessionId: "bad" }), {
    ok: false,
    error: "invalid_session_id",
  })
  assertEquals(parseVoucherLookup({ sessionId: "cs_test_1234567890abcdef" }), {
    ok: true,
    kind: "session_id",
    value: "cs_test_1234567890abcdef",
  })
})

Deno.test("deposit voucher tokens are signed and tamper resistant", async () => {
  const secret = "voucher-secret"
  const sessionId = "cs_test_1234567890abcdef"
  const token = await signVoucherToken(sessionId, secret)
  assertEquals(await verifyVoucherToken(token, secret), { ok: true, sessionId })
  assertEquals(await verifyVoucherToken(token + "x", secret), {
    ok: false,
    error: "invalid_token",
  })
  assertEquals(await verifyVoucherToken(token, ""), {
    ok: false,
    error: "token_unavailable",
  })
})

Deno.test("deposit receipt helpers expose only paid minimal public voucher data", () => {
  assertEquals(isPaidBooking({ status: "pending", payment_status: "unpaid" }), false)
  assertEquals(isPaidBooking({ status: "payment_received" }), true)
  assertEquals(isPaidBooking({ deposit_paid_cents: 25000 }), true)
  assertEquals(maskClientName("Ana Maria Lopez Perez"), "Ana P.")

  assertEquals(
    publicVoucherPayload({
      booking: {
        id: "00000000-0000-4000-8000-000000000000",
        booking_date: "2026-07-22",
        booking_time: "10:30:00",
        deposit_paid_cents: 25000,
      },
      serviceName: "Masaje relajante",
      clientName: "Ana Maria Lopez Perez",
    }),
    {
      ok: true,
      folio: "SAHARA-00000000",
      cliente: "Ana P.",
      servicio: "Masaje relajante",
      fecha: "2026-07-22",
      hora: "10:30",
      monto: 250,
      moneda: "MXN",
      pagado: true,
      comercio: "Sahara Club Spa",
    },
  )
})
