// Sahara Club Spa - deposit_voucher
// ---------------------------------------------------------------------------
// Public limited voucher endpoint for appointment deposits.
//
// POST { voucher_token }
// Response: minimal paid receipt JSON. No anon table access and no internal IDs.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  checkVoucherRateLimit,
  isPaidBooking,
  parseVoucherTokenInput,
  publicVoucherPayload,
  sanitizePublicError,
  verifyDepositVoucherToken,
  voucherTokenFingerprint,
} from "../_shared/deposit_receipts.ts"
import { clientIpKey, jsonResponseFor, preflightResponse } from "../_shared/runtime_security.ts"

async function readVoucherRequest(req: Request): Promise<{
  voucherToken?: string
  token?: string
  sessionId?: string
  bookingId?: string
}> {
  const url = new URL(req.url)
  if (req.method === "GET") {
    return {
      voucherToken: url.searchParams.get("voucher_token") ?? undefined,
      token: url.searchParams.get("token") ?? undefined,
      sessionId: url.searchParams.get("session_id") ?? undefined,
      bookingId: url.searchParams.get("booking_id") ?? undefined,
    }
  }
  const body = await req.json().catch(() => ({})) as Record<string, unknown>
  return {
    voucherToken: String(body.voucher_token ?? body.voucherToken ?? ""),
    token: String(body.token ?? ""),
    sessionId: String(body.session_id ?? ""),
    bookingId: String(body.booking_id ?? ""),
  }
}

async function auditVoucherEvent(event: string, voucherToken: string): Promise<void> {
  const tokenHash = voucherToken ? await voucherTokenFingerprint(voucherToken) : "missing"
  console.info("deposit_voucher audit", { event, token_hash: tokenHash })
}

Deno.serve(async (req) => {
  const json = (body: unknown, status = 200) => jsonResponseFor(req, body, status)
  if (req.method === "OPTIONS") return preflightResponse(req)
  if (req.method !== "POST" && req.method !== "GET") {
    return json({ ok: false, error: "method_not_allowed" }, 405)
  }

  let voucherToken = ""
  try {
    const input = await readVoucherRequest(req)
    const parsed = parseVoucherTokenInput(input)
    if (!parsed.ok) return json({ ok: false, error: parsed.error }, parsed.status)
    voucherToken = parsed.voucherToken

    const tokenHash = await voucherTokenFingerprint(voucherToken)
    const ipPrefix = clientIpKey(req)
    const rateLimit = checkVoucherRateLimit(`${tokenHash}:${ipPrefix}`)
    if (!rateLimit.ok) {
      await auditVoucherEvent("rate_limited", voucherToken)
      return json({ ok: false, error: rateLimit.error }, rateLimit.status)
    }

    const verified = await verifyDepositVoucherToken(
      voucherToken,
      Deno.env.get("DEPOSIT_VOUCHER_SIGNING_SECRET") ?? "",
    )
    if (!verified.ok) {
      await auditVoucherEvent(verified.error, voucherToken)
      return json({ ok: false, error: verified.error }, verified.status)
    }

    const sb: any = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const { data: bk } = await sb
      .from("bookings")
      .select(
        "id, status, payment_status, booking_date, booking_time, deposit_amount, " +
          "deposit_paid_cents, deposit_paid_at, service_name, service_id, client_record_id",
      )
      .eq("id", verified.payload.booking_id)
      .maybeSingle()
    if (!bk) {
      await auditVoucherEvent("not_found", voucherToken)
      return json({ ok: false, error: "not_found" }, 404)
    }

    const booking = bk as Record<string, unknown>
    if (!isPaidBooking(booking)) {
      await auditVoucherEvent("payment_required", voucherToken)
      return json({ ok: false, error: "payment_required" }, 409)
    }

    let serviceName = String(booking.service_name ?? "")
    if (!serviceName && booking.service_id) {
      const { data: svc } = await sb.from("services").select("name").eq("id", booking.service_id)
        .maybeSingle()
      serviceName = (svc as { name?: string } | null)?.name ?? "Servicio"
    }

    let clientName = "Cliente Sahara"
    if (booking.client_record_id) {
      const { data: client } = await sb.from("clients").select("full_name").eq(
        "id",
        booking.client_record_id,
      ).maybeSingle()
      clientName = (client as { full_name?: string } | null)?.full_name ?? "Cliente Sahara"
    }

    await auditVoucherEvent("success", voucherToken)
    return json(publicVoucherPayload({ booking, serviceName, clientName }))
  } catch (e) {
    if (voucherToken) await auditVoucherEvent("internal_error", voucherToken)
    console.warn("deposit_voucher failed:", sanitizePublicError(e))
    return json({ ok: false, error: "receipt_unavailable" }, 500)
  }
})
