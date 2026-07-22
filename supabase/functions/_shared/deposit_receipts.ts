export type VoucherLookup =
  | { ok: true; kind: "session_id" | "token"; value: string }
  | { ok: false; error: string }

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value)
}

export function isValidStripeSessionId(value: string): boolean {
  return /^cs_(test|live)_[A-Za-z0-9_]{8,220}$/.test(value)
}

export function parseVoucherLookup(input: {
  token?: string | null
  sessionId?: string | null
  bookingId?: string | null
}): VoucherLookup {
  const token = String(input.token ?? "").trim()
  const sessionId = String(input.sessionId ?? "").trim()
  const bookingId = String(input.bookingId ?? "").trim()
  if (token) {
    if (!/^[A-Za-z0-9_.-]{24,320}$/.test(token)) {
      return { ok: false, error: "invalid_token" }
    }
    return { ok: true, kind: "token", value: token }
  }
  if (sessionId) {
    if (!isValidStripeSessionId(sessionId)) {
      return { ok: false, error: "invalid_session_id" }
    }
    return { ok: true, kind: "session_id", value: sessionId }
  }
  if (bookingId) {
    return { ok: false, error: "public_booking_id_not_allowed" }
  }
  return { ok: false, error: "missing_id" }
}

export function folioFromBooking(bookingId: string): string {
  return "SAHARA-" + bookingId.replace(/-/g, "").slice(0, 8).toUpperCase()
}

export function maskClientName(value: unknown): string {
  const parts = String(value ?? "").trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return "Cliente Sahara"
  if (parts.length === 1) return parts[0]
  return `${parts[0]} ${parts[parts.length - 1].slice(0, 1).toUpperCase()}.`
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
    folio: folioFromBooking(String(opts.booking.id ?? "")),
    cliente: maskClientName(opts.clientName),
    servicio: opts.serviceName || "Servicio",
    fecha: String(opts.booking.booking_date ?? ""),
    hora: String(opts.booking.booking_time ?? "").slice(0, 5),
    monto: publicDepositAmount(opts.booking),
    moneda: "MXN",
    pagado: true,
    comercio: "Sahara Club Spa",
  }
}

export function sanitizePublicError(error: unknown): string {
  const text = error instanceof Error ? error.message : String(error ?? "")
  const lower = text.toLowerCase()
  if (lower.includes("not_found")) return "not_found"
  if (lower.includes("paid") || lower.includes("payment")) return "payment_required"
  if (lower.includes("token")) return "invalid_token"
  if (lower.includes("session")) return "invalid_session_id"
  return "receipt_unavailable"
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
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

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

export async function signVoucherToken(sessionId: string, secret: string): Promise<string> {
  if (!isValidStripeSessionId(sessionId)) throw new Error("invalid_session_id")
  if (!secret) throw new Error("token_secret_required")
  const signature = await hmacSha256Base64Url(sessionId, secret)
  return `${sessionId}.${signature}`
}

export async function verifyVoucherToken(
  token: string,
  secret: string,
): Promise<{ ok: true; sessionId: string } | { ok: false; error: string }> {
  if (!secret) return { ok: false, error: "token_unavailable" }
  const [sessionId, signature, extra] = token.split(".")
  if (extra !== undefined || !sessionId || !signature || !isValidStripeSessionId(sessionId)) {
    return { ok: false, error: "invalid_token" }
  }
  const expected = await hmacSha256Base64Url(sessionId, secret)
  if (!timingSafeEqual(signature, expected)) return { ok: false, error: "invalid_token" }
  return { ok: true, sessionId }
}
