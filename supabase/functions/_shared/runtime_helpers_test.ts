import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { getConnectionStatusForDraft, normalizePhone } from "./whatsapp_business.ts"
import {
  buildPricing,
  normalizeCurrency,
  normalizeType,
  toMinorUnits,
  verifyStripeSignature,
} from "./stripe_checkout.ts"
import {
  buildDepositVoucherSuccessUrl,
  checkVoucherRateLimit,
  constantTimeEqual,
  createDepositVoucherToken,
  customerDisplayName,
  isPaidBooking,
  parseVoucherTokenInput,
  parseVoucherTokenTtl,
  publicVoucherPayload,
  requireVoucherSigningSecret,
  resetVoucherRateLimitForTests,
  verifyDepositVoucherToken,
  voucherTokenFingerprint,
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

Deno.test("deposit voucher input requires signed voucher_token only", async () => {
  const secret = "local-test-deposit-voucher-signing-secret"
  const bookingId = "00000000-0000-4000-8000-000000000000"
  const { token } = await createDepositVoucherToken({
    bookingId,
    secret,
    nowSeconds: 1000,
    nonce: "abcdefghijklmnopqrstuvwx",
  })

  assertEquals(parseVoucherTokenInput({ voucherToken: token }), {
    ok: true,
    voucherToken: token,
  })
  assertEquals(parseVoucherTokenInput({ sessionId: "cs_test_1234567890abcdef" }), {
    ok: false,
    error: "voucher_token_required",
    status: 400,
  })
  assertEquals(parseVoucherTokenInput({ bookingId }), {
    ok: false,
    error: "voucher_token_required",
    status: 400,
  })
})

Deno.test("deposit voucher tokens validate signature, payload, and reuse during TTL", async () => {
  const secret = "local-test-deposit-voucher-signing-secret"
  const bookingId = "00000000-0000-4000-8000-000000000000"
  const { token, payload } = await createDepositVoucherToken({
    bookingId,
    secret,
    ttlSeconds: 600,
    nowSeconds: 1000,
    nonce: "abcdefghijklmnopqrstuvwx",
  })

  assertEquals(payload.booking_id, bookingId)
  assertEquals(payload.purpose, "deposit_voucher")
  assertEquals(payload.expires_at, 1600)
  assertEquals(await verifyDepositVoucherToken(token, secret, 1200), {
    ok: true,
    payload,
  })
  assertEquals(await verifyDepositVoucherToken(token, secret, 1200), {
    ok: true,
    payload,
  })
})

Deno.test("deposit voucher tokens reject tampering and malformed base64url", async () => {
  const secret = "local-test-deposit-voucher-signing-secret"
  const bookingId = "00000000-0000-4000-8000-000000000000"
  const { token } = await createDepositVoucherToken({
    bookingId,
    secret,
    nowSeconds: 1000,
    nonce: "abcdefghijklmnopqrstuvwx",
  })
  const [payloadSegment, signature] = token.split(".")
  const alteredPayload = payloadSegment.slice(0, -1) +
    (payloadSegment.endsWith("A") ? "B" : "A")

  assertEquals(await verifyDepositVoucherToken(`${alteredPayload}.${signature}`, secret, 1001), {
    ok: false,
    error: "invalid_signature",
    status: 401,
  })
  assertEquals(await verifyDepositVoucherToken(token.slice(0, 30), secret, 1001), {
    ok: false,
    error: "malformed_token",
    status: 400,
  })
  assertEquals(await verifyDepositVoucherToken("not$base64.signature", secret, 1001), {
    ok: false,
    error: "malformed_token",
    status: 400,
  })
})

Deno.test("deposit voucher tokens enforce expiration, purpose, version, and time bounds", async () => {
  const secret = "local-test-deposit-voucher-signing-secret"
  const bookingId = "00000000-0000-4000-8000-000000000000"
  const base = {
    version: 1,
    purpose: "deposit_voucher",
    booking_id: bookingId,
    order_id: null,
    issued_at: 1000,
    expires_at: 1600,
    nonce: "abcdefghijklmnopqrstuvwx",
  }

  const expired = await signedTestVoucher({ ...base, expires_at: 1001 }, secret)
  assertEquals(await verifyDepositVoucherToken(expired, secret, 1200), {
    ok: false,
    error: "token_expired",
    status: 403,
  })

  const future = await signedTestVoucher({ ...base, issued_at: 2000, expires_at: 2600 }, secret)
  assertEquals(await verifyDepositVoucherToken(future, secret, 1000), {
    ok: false,
    error: "token_not_yet_valid",
    status: 403,
  })

  const wrongPurpose = await signedTestVoucher({ ...base, purpose: "gift_card" }, secret)
  assertEquals(await verifyDepositVoucherToken(wrongPurpose, secret, 1200), {
    ok: false,
    error: "invalid_token_purpose",
    status: 403,
  })

  const wrongVersion = await signedTestVoucher({ ...base, version: 2 }, secret)
  assertEquals(await verifyDepositVoucherToken(wrongVersion, secret, 1200), {
    ok: false,
    error: "unsupported_token_version",
    status: 403,
  })
})

Deno.test("deposit voucher token configuration rejects missing secrets and invalid TTLs", () => {
  assertThrows(
    () => requireVoucherSigningSecret(""),
    Error,
    "voucher_signing_secret_required",
  )
  assertThrows(
    () => requireVoucherSigningSecret("short"),
    Error,
    "voucher_signing_secret_too_short",
  )
  assertEquals(parseVoucherTokenTtl(null), 604800)
  assertThrows(() => parseVoucherTokenTtl("0"), Error, "invalid_token_ttl")
  assertThrows(() => parseVoucherTokenTtl("not-a-number"), Error, "invalid_token_ttl")
})

Deno.test("deposit receipt helpers expose only paid minimal public voucher data", () => {
  assertEquals(isPaidBooking({ status: "pending", payment_status: "unpaid" }), false)
  assertEquals(isPaidBooking({ status: "payment_received" }), true)
  assertEquals(isPaidBooking({ deposit_paid_cents: 25000 }), true)
  assertEquals(customerDisplayName(" Ana Maria Lopez Perez "), "Ana Maria Lopez Perez")

  const payload = publicVoucherPayload({
    booking: {
      id: "00000000-0000-4000-8000-000000000000",
      booking_date: "2026-07-22",
      booking_time: "10:30:00",
      deposit_paid_cents: 25000,
      deposit_paid_at: "2026-07-22T18:30:00Z",
    },
    serviceName: "Masaje relajante",
    clientName: "Ana Maria Lopez Perez",
  })

  assertEquals(payload, {
    ok: true,
    business_name: "Sahara Club Spa",
    receipt_number: "SAHARA-00000000",
    customer_display_name: "Ana Maria Lopez Perez",
    service_name: "Masaje relajante",
    amount: 250,
    currency: "MXN",
    paid_at: "2026-07-22T18:30:00Z",
    booking_date: "2026-07-22",
    booking_time: "10:30",
    payment_status: "paid",
    receipt_status: "available",
  })
  assertEquals("email" in payload, false)
  assertEquals("phone" in payload, false)
  assertEquals("booking_id" in payload, false)
})

Deno.test("voucher success URLs are allowlisted and encode the token", async () => {
  const secret = "local-test-deposit-voucher-signing-secret"
  const { token } = await createDepositVoucherToken({
    bookingId: "00000000-0000-4000-8000-000000000000",
    secret,
    nowSeconds: 1000,
    nonce: "abcdefghijklmnopqrstuvwx",
  })
  const successUrl = buildDepositVoucherSuccessUrl({
    baseUrl: "https://saharaclubspa.com/comprobante-anticipo.html?x=bad#frag",
    voucherToken: token,
  })
  const url = new URL(successUrl)
  assertEquals(url.origin + url.pathname, "https://saharaclubspa.com/comprobante-anticipo.html")
  assertEquals(url.searchParams.get("voucher_token"), token)
  assertEquals(url.hash, "")
  assertThrows(
    () =>
      buildDepositVoucherSuccessUrl({
        baseUrl: "https://evil.example/steal",
        voucherToken: token,
      }),
    Error,
    "invalid_success_url",
  )
})

Deno.test("voucher audit helpers avoid raw tokens and rate limit repeated attempts", async () => {
  resetVoucherRateLimitForTests()
  const token = "token-value-that-should-never-be-logged"
  const fingerprint = await voucherTokenFingerprint(token)
  assert(!fingerprint.includes(token))
  assert(fingerprint.startsWith("sha256:"))
  assertEquals(
    checkVoucherRateLimit(fingerprint, {
      nowMs: 1000,
      maxAttempts: 2,
      windowMs: 1000,
    }).ok,
    true,
  )
  assertEquals(
    checkVoucherRateLimit(fingerprint, {
      nowMs: 1100,
      maxAttempts: 2,
      windowMs: 1000,
    }).ok,
    true,
  )
  assertEquals(
    checkVoucherRateLimit(fingerprint, {
      nowMs: 1200,
      maxAttempts: 2,
      windowMs: 1000,
    }),
    { ok: false, error: "rate_limited", status: 429, resetAt: 2000 },
  )
  assertEquals(constantTimeEqual("abc", "abc"), true)
  assertEquals(constantTimeEqual("abc", "abd"), false)
})

async function signedTestVoucher(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const payloadSegment = bytesToBase64Url(
    new TextEncoder().encode(JSON.stringify({
      version: payload.version,
      purpose: payload.purpose,
      booking_id: payload.booking_id,
      order_id: payload.order_id ?? null,
      issued_at: payload.issued_at,
      expires_at: payload.expires_at,
      nonce: payload.nonce,
    })),
  )
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payloadSegment))
  return `${payloadSegment}.${bytesToBase64Url(new Uint8Array(digest))}`
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}
