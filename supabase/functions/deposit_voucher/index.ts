// Sahara Club Spa - deposit_voucher
// ---------------------------------------------------------------------------
// Public limited voucher endpoint for appointment deposits.
//
// GET  ?token=... or temporary compatibility ?session_id=cs_...
// POST { token } | { session_id }
// Response: { ok, folio, cliente, servicio, fecha, hora, monto, moneda, pagado }
//
// verify_jwt=false: consumed by the public voucher page with the anon key.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  isPaidBooking,
  parseVoucherLookup,
  publicVoucherPayload,
  sanitizePublicError,
  verifyVoucherToken,
} from "../_shared/deposit_receipts.ts"

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Cache-Control": "no-store",
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    headers: { ...cors, "Content-Type": "application/json" },
    status,
  })

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors })
  try {
    const url = new URL(req.url)
    let token = url.searchParams.get("token") ?? ""
    let sessionId = url.searchParams.get("session_id") ?? ""
    let bookingId = url.searchParams.get("booking_id") ?? ""
    if (!token && !sessionId && !bookingId && req.method === "POST") {
      const body = await req.json().catch(() => ({}))
      token = String(body.token ?? "")
      sessionId = String(body.session_id ?? "")
      bookingId = String(body.booking_id ?? "")
    }

    const lookup = parseVoucherLookup({ token, sessionId, bookingId })
    if (!lookup.ok) return json({ ok: false, error: lookup.error }, 400)

    let lookupSessionId = lookup.value
    if (lookup.kind === "token") {
      const verified = await verifyVoucherToken(
        lookup.value,
        Deno.env.get("DEPOSIT_VOUCHER_TOKEN_SECRET") ?? "",
      )
      if (!verified.ok) return json({ ok: false, error: verified.error }, 400)
      lookupSessionId = verified.sessionId
    }

    const sb: any = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const { data: bk } = await sb
      .from("bookings")
      .select(
        "id, status, payment_status, booking_date, booking_time, deposit_amount, " +
          "deposit_paid_cents, service_name, service_id, client_record_id",
      )
      .eq("stripe_session_id", lookupSessionId)
      .maybeSingle()
    if (!bk) return json({ ok: false, error: "not_found" }, 404)

    const booking = bk as Record<string, unknown>
    if (!isPaidBooking(booking)) return json({ ok: false, error: "payment_required" }, 409)

    let serviceName = String(booking.service_name ?? "")
    if (!serviceName && booking.service_id) {
      const { data: svc } = await sb.from("services").select("name").eq("id", booking.service_id)
        .maybeSingle()
      serviceName = (svc as { name?: string } | null)?.name ?? "Servicio"
    }

    let clientName = "Cliente"
    if (booking.client_record_id) {
      const { data: client } = await sb.from("clients").select("full_name").eq(
        "id",
        booking.client_record_id,
      ).maybeSingle()
      clientName = (client as { full_name?: string } | null)?.full_name ?? "Cliente"
    }

    return json(publicVoucherPayload({ booking, serviceName, clientName }))
  } catch (e) {
    console.warn("deposit_voucher failed:", sanitizePublicError(e))
    return json({ ok: false, error: "receipt_unavailable" }, 500)
  }
})
