export const DEPOSIT_VOUCHER_PURPOSE = "deposit_voucher"
export const DEPOSIT_VOUCHER_VERSION = 1
export const DEFAULT_DEPOSIT_VOUCHER_TTL_SECONDS = 60 * 60 * 24 * 7
export const MAX_DEPOSIT_VOUCHER_TTL_SECONDS = 60 * 60 * 24 * 30
export const MIN_DEPOSIT_VOUCHER_TTL_SECONDS = 60
export const VOUCHER_CLOCK_SKEW_SECONDS = 300

const BASE64URL_RE = /^[A-Za-z0-9_-]+$/
const NONCE_RE = /^[A-Za-z0-9_-]{16,96}$/

export type DepositVoucherPayload = {
  version: number
  purpose: string
  booking_id: string
  order_id: string | null
  issued_at: number
  expires_at: number
  nonce: string
}

export type VerifyVoucherTokenResult =
  | { ok: true; payload: DepositVoucherPayload }
  | { ok: false; error: string; status: number }

export type VoucherRateLimitResult =
  | { ok: true; remaining: number; resetAt: number }
  | { ok: false; error: "rate_limited"; status: 429; resetAt: number }

const voucherRateLimitBuckets = new Map<string, { count: number; resetAt: number }>()

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value)
}

export function isValidStripeSessionId(value: string): boolean {
  return /^cs_(test|live)_[A-Za-z0-9_]{8,220}$/.test(value)
}

export function isValidVoucherTokenFormat(value: string): boolean {
  const token = value.trim()
  if (token.length < 80 || token.length > 2200) return false
  const [payload, signature, extra] = token.split(".")
  return extra === undefined &&
    Boolean(payload && signature && BASE64URL_RE.test(payload) && BASE64URL_RE.test(signature))
}

export function parseVoucherTokenInput(input: {
  voucherToken?: string | null
  token?: string | null
  sessionId?: string | null
  bookingId?: string | null
}): { ok: true; voucherToken: string } | { ok: false; error: string; status: number } {
  const voucherToken = String(input.voucherToken ?? input.token ?? "").trim()
  const sessionId = String(input.sessionId ?? "").trim()
  const bookingId = String(input.bookingId ?? "").trim()
  if (voucherToken) {
    if (!isValidVoucherTokenFormat(voucherToken)) {
      return { ok: false, error: "malformed_token", status: 400 }
    }
    return { ok: true, voucherToken }
  }
  if (sessionId || bookingId) {
    return { ok: false, error: "voucher_token_required", status: 400 }
  }
  return { ok: false, error: "voucher_token_required", status: 400 }
}

export function parseVoucherTokenTtl(value?: string | null): number {
  const raw = String(value ?? "").trim()
  const seconds = raw ? Number(raw) : DEFAULT_DEPOSIT_VOUCHER_TTL_SECONDS
  if (
    !Number.isInteger(seconds) ||
    seconds < MIN_DEPOSIT_VOUCHER_TTL_SECONDS ||
    seconds > MAX_DEPOSIT_VOUCHER_TTL_SECONDS
  ) {
    throw new Error("invalid_token_ttl")
  }
  return seconds
}

export function requireVoucherSigningSecret(value?: string | null): string {
  const secret = String(value ?? "").trim()
  if (!secret) throw new Error("voucher_signing_secret_required")
  if (secret.length < 32) throw new Error("voucher_signing_secret_too_short")
  return secret
}

export function randomVoucherNonce(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24))
  return bytesToBase64Url(bytes)
}

export function canonicalVoucherPayload(payload: DepositVoucherPayload): string {
  return JSON.stringify({
    version: payload.version,
    purpose: payload.purpose,
    booking_id: payload.booking_id,
    order_id: payload.order_id ?? null,
    issued_at: payload.issued_at,
    expires_at: payload.expires_at,
    nonce: payload.nonce,
  })
}

export async function createDepositVoucherToken(input: {
  bookingId: string
  orderId?: string | null
  secret: string
  ttlSeconds?: number
  nowSeconds?: number
  nonce?: string
}): Promise<{ token: string; payload: DepositVoucherPayload }> {
  const secret = requireVoucherSigningSecret(input.secret)
  const ttlSeconds = input.ttlSeconds ?? DEFAULT_DEPOSIT_VOUCHER_TTL_SECONDS
  if (
    !Number.isInteger(ttlSeconds) ||
    ttlSeconds < MIN_DEPOSIT_VOUCHER_TTL_SECONDS ||
    ttlSeconds > MAX_DEPOSIT_VOUCHER_TTL_SECONDS
  ) {
    throw new Error("invalid_token_ttl")
  }
  const bookingId = input.bookingId.trim()
  if (!isUuid(bookingId)) throw new Error("invalid_booking_id")
  const orderId = String(input.orderId ?? "").trim()
  if (orderId && !isUuid(orderId)) throw new Error("invalid_order_id")

  const issuedAt = Math.floor(input.nowSeconds ?? Date.now() / 1000)
  const nonce = input.nonce ?? randomVoucherNonce()
  if (!NONCE_RE.test(nonce)) throw new Error("invalid_token_nonce")

  const payload: DepositVoucherPayload = {
    version: DEPOSIT_VOUCHER_VERSION,
    purpose: DEPOSIT_VOUCHER_PURPOSE,
    booking_id: bookingId,
    order_id: orderId || null,
    issued_at: issuedAt,
    expires_at: issuedAt + ttlSeconds,
    nonce,
  }
  const payloadSegment = bytesToBase64Url(
    new TextEncoder().encode(canonicalVoucherPayload(payload)),
  )
  const signature = await hmacSha256Base64Url(payloadSegment, secret)
  return { token: `${payloadSegment}.${signature}`, payload }
}

export async function verifyDepositVoucherToken(
  token: string,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<VerifyVoucherTokenResult> {
  const cleanToken = token.trim()
  if (!isValidVoucherTokenFormat(cleanToken)) {
    return { ok: false, error: "malformed_token", status: 400 }
  }
  let normalizedSecret = ""
  try {
    normalizedSecret = requireVoucherSigningSecret(secret)
  } catch {
    return { ok: false, error: "token_unavailable", status: 500 }
  }

  const [payloadSegment, signature] = cleanToken.split(".")
  const expectedSignature = await hmacSha256Base64Url(payloadSegment, normalizedSecret)
  if (!constantTimeEqual(signature, expectedSignature)) {
    return { ok: false, error: "invalid_signature", status: 401 }
  }

  const payload = decodeVoucherPayload(payloadSegment)
  if (!payload.ok) return payload
  const validation = validateVoucherPayload(payload.payload, nowSeconds)
  if (!validation.ok) return validation
  return { ok: true, payload: payload.payload }
}

function decodeVoucherPayload(
  payloadSegment: string,
): { ok: true; payload: DepositVoucherPayload } | { ok: false; error: string; status: number } {
  const bytes = base64UrlToBytes(payloadSegment)
  if (!bytes) return { ok: false, error: "malformed_token", status: 400 }
  let parsed: unknown
  try {
    parsed = JSON.parse(new TextDecoder().decode(bytes))
  } catch {
    return { ok: false, error: "malformed_token", status: 400 }
  }
  if (!parsed || typeof parsed !== "object") {
    return { ok: false, error: "malformed_token", status: 400 }
  }
  const record = parsed as Record<string, unknown>
  return {
    ok: true,
    payload: {
      version: Number(record.version),
      purpose: String(record.purpose ?? ""),
      booking_id: String(record.booking_id ?? ""),
      order_id: record.order_id === null || record.order_id === undefined
        ? null
        : String(record.order_id),
      issued_at: Number(record.issued_at),
      expires_at: Number(record.expires_at),
      nonce: String(record.nonce ?? ""),
    },
  }
}

export function validateVoucherPayload(
  payload: DepositVoucherPayload,
  nowSeconds = Math.floor(Date.now() / 1000),
): { ok: true } | { ok: false; error: string; status: number } {
  if (payload.version !== DEPOSIT_VOUCHER_VERSION) {
    return { ok: false, error: "unsupported_token_version", status: 403 }
  }
  if (payload.purpose !== DEPOSIT_VOUCHER_PURPOSE) {
    return { ok: false, error: "invalid_token_purpose", status: 403 }
  }
  if (!isUuid(payload.booking_id)) {
    return { ok: false, error: "invalid_booking_id", status: 400 }
  }
  if (payload.order_id && !isUuid(payload.order_id)) {
    return { ok: false, error: "invalid_order_id", status: 400 }
  }
  if (!Number.isInteger(payload.issued_at) || !Number.isInteger(payload.expires_at)) {
    return { ok: false, error: "invalid_token_time", status: 400 }
  }
  if (payload.expires_at <= payload.issued_at) {
    return { ok: false, error: "invalid_token_expiration", status: 400 }
  }
  if (payload.issued_at > nowSeconds + VOUCHER_CLOCK_SKEW_SECONDS) {
    return { ok: false, error: "token_not_yet_valid", status: 403 }
  }
  if (payload.expires_at < nowSeconds) {
    return { ok: false, error: "token_expired", status: 403 }
  }
  if (!NONCE_RE.test(payload.nonce)) {
    return { ok: false, error: "invalid_token_nonce", status: 400 }
  }
  return { ok: true }
}

export function buildDepositVoucherSuccessUrl(input: {
  baseUrl: string
  voucherToken: string
}): string {
  const baseUrl = String(input.baseUrl ?? "").trim() ||
    "https://saharaclubspa.com/comprobante-anticipo.html"
  const url = new URL(baseUrl)
  if (!isAllowedVoucherSuccessUrl(url)) {
    throw new Error("invalid_success_url")
  }
  if (!isValidVoucherTokenFormat(input.voucherToken)) {
    throw new Error("invalid_voucher_token")
  }
  url.search = ""
  url.hash = ""
  url.searchParams.set("voucher_token", input.voucherToken)
  return url.toString()
}

export function isAllowedVoucherSuccessUrl(url: URL): boolean {
  const hostname = url.hostname.toLowerCase()
  const isLocal = hostname === "localhost" || hostname === "127.0.0.1"
  const allowedHost = hostname === "saharaclubspa.com" || hostname === "www.saharaclubspa.com" ||
    isLocal
  if (!allowedHost) return false
  if (isLocal) return url.protocol === "http:" || url.protocol === "https:"
  return url.protocol === "https:"
}

export function folioFromBooking(bookingId: string): string {
  return "SAHARA-" + bookingId.replace(/-/g, "").slice(0, 8).toUpperCase()
}

export function customerDisplayName(value: unknown): string {
  const name = String(value ?? "").trim().replace(/\s+/g, " ")
  return name || "Cliente Sahara"
}

export function isPaidBooking(row: Record<string, unknown>): boolean {
  const status = String(row.status ?? "")
  const paymentStatus = String(row.payment_status ?? "")
  const depositPaidCents = Number(row.deposit_paid_cents ?? 0)
  return paymentStatus === "paid" || status === "payment_received" || depositPaidCents > 0
}

export function publicDepositAmount(row: Record<string, unknown>): number {
  const paidCents = Number(row.deposit_paid_cents ?? 0)
  if (Number.isFinite(paidCents) && paidCents > 0) {
    return Math.round(paidCents) / 100
  }
  const legacyAmount = Number(row.deposit_amount ?? 0)
  return Number.isFinite(legacyAmount) && legacyAmount > 0 ? legacyAmount : 0
}

export function publicVoucherPayload(opts: {
  booking: Record<string, unknown>
  serviceName: string
  clientName: string
}): Record<string, unknown> {
  return {
    ok: true,
    business_name: "Sahara Club Spa",
    receipt_number: folioFromBooking(String(opts.booking.id ?? "")),
    customer_display_name: customerDisplayName(opts.clientName),
    service_name: opts.serviceName || "Servicio",
    amount: publicDepositAmount(opts.booking),
    currency: "MXN",
    paid_at: String(opts.booking.deposit_paid_at ?? ""),
    booking_date: String(opts.booking.booking_date ?? ""),
    booking_time: String(opts.booking.booking_time ?? "").slice(0, 5),
    payment_status: "paid",
    receipt_status: "available",
  }
}

export function sanitizePublicError(error: unknown): string {
  const text = error instanceof Error ? error.message : String(error ?? "")
  const lower = text.toLowerCase()
  if (lower.includes("not_found")) return "not_found"
  if (lower.includes("paid") || lower.includes("payment")) return "payment_required"
  if (lower.includes("signature")) return "invalid_signature"
  if (lower.includes("expired")) return "token_expired"
  if (lower.includes("purpose")) return "invalid_token_purpose"
  if (lower.includes("token")) return "invalid_token"
  return "receipt_unavailable"
}

export async function voucherTokenFingerprint(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token))
  const hex = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
  return `sha256:${hex.slice(0, 16)}`
}

export function checkVoucherRateLimit(
  key: string,
  opts: { nowMs?: number; maxAttempts?: number; windowMs?: number } = {},
): VoucherRateLimitResult {
  const nowMs = opts.nowMs ?? Date.now()
  const maxAttempts = opts.maxAttempts ?? 30
  const windowMs = opts.windowMs ?? 10 * 60 * 1000
  const existing = voucherRateLimitBuckets.get(key)
  if (!existing || existing.resetAt <= nowMs) {
    const resetAt = nowMs + windowMs
    voucherRateLimitBuckets.set(key, { count: 1, resetAt })
    return { ok: true, remaining: maxAttempts - 1, resetAt }
  }
  if (existing.count >= maxAttempts) {
    return { ok: false, error: "rate_limited", status: 429, resetAt: existing.resetAt }
  }
  existing.count += 1
  return { ok: true, remaining: maxAttempts - existing.count, resetAt: existing.resetAt }
}

export function resetVoucherRateLimitForTests(): void {
  voucherRateLimitBuckets.clear()
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}

function base64UrlToBytes(value: string): Uint8Array | null {
  if (!BASE64URL_RE.test(value)) return null
  const padded = value.replace(/-/g, "+").replace(/_/g, "/") +
    "=".repeat((4 - (value.length % 4)) % 4)
  try {
    const binary = atob(padded)
    const bytes = new Uint8Array(binary.length)
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index)
    }
    return bytes
  } catch {
    return null
  }
}

async function hmacSha256Base64Url(value: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value))
  return bytesToBase64Url(new Uint8Array(digest))
}

export function constantTimeEqual(a: string, b: string): boolean {
  let diff = a.length ^ b.length
  const maxLength = Math.max(a.length, b.length)
  for (let index = 0; index < maxLength; index += 1) {
    const left = index < a.length ? a.charCodeAt(index) : 0
    const right = index < b.length ? b.charCodeAt(index) : 0
    diff |= left ^ right
  }
  return diff === 0
}
