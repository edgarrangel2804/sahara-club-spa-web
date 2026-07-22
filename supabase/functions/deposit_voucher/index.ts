// Sahara Club Spa - deposit_voucher
// ---------------------------------------------------------------------------
// Devuelve los datos del comprobante (voucher) de un anticipo de cita para
// mostrarlos en la página pública de comprobante (web/comprobante-anticipo.html),
// a la que Stripe redirige tras el pago (success_url con ?session_id=...).
//
// GET  ?session_id=cs_...   o   ?booking_id=uuid
// POST { booking_id } | { session_id }
// Respuesta: { ok, folio, cliente, servicio, fecha, hora, monto, pagado }
//
// verify_jwt=false: la consume el navegador con el anon key.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), {
    headers: { ...cors, "Content-Type": "application/json" },
    status: s,
  })

function folio(id: string): string {
  return "SAHARA-" + id.replace(/-/g, "").slice(0, 8).toUpperCase()
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors })
  try {
    const url = new URL(req.url)
    let sessionId = url.searchParams.get("session_id") ?? ""
    let bookingId = url.searchParams.get("booking_id") ?? ""
    if (!sessionId && !bookingId && req.method === "POST") {
      const body = await req.json().catch(() => ({}))
      sessionId = String(body.session_id ?? "")
      bookingId = String(body.booking_id ?? "")
    }
    if (!sessionId && !bookingId) return json({ ok: false, error: "missing_id" }, 400)

    const sb: any = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    let query = sb
      .from("bookings")
      .select(
        "id, status, payment_status, booking_date, booking_time, deposit_amount, " +
          "service_name, service_id, client_record_id",
      )
    query = sessionId ? query.eq("stripe_session_id", sessionId) : query.eq("id", bookingId)
    const { data: bk } = await query.maybeSingle()
    if (!bk) return json({ ok: false, error: "not_found" }, 404)

    const b = bk as unknown as Record<string, unknown>

    let serviceName = String(b.service_name ?? "")
    if (!serviceName && b.service_id) {
      const { data: svc } = await sb.from("services").select("name").eq("id", b.service_id)
        .maybeSingle()
      serviceName = (svc as { name?: string } | null)?.name ?? "Servicio"
    }

    let clientName = "Cliente"
    if (b.client_record_id) {
      const { data: c } = await sb.from("clients").select("full_name").eq("id", b.client_record_id)
        .maybeSingle()
      clientName = (c as { full_name?: string } | null)?.full_name ?? "Cliente"
    }

    const paid = b.payment_status === "paid" ||
      b.status === "confirmed" || b.status === "payment_received"

    return json({
      ok: true,
      folio: folio(String(b.id)),
      cliente: clientName,
      servicio: serviceName || "Servicio",
      fecha: String(b.booking_date ?? ""),
      hora: String(b.booking_time ?? "").slice(0, 5),
      monto: Number(b.deposit_amount ?? 200),
      pagado: paid,
    })
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500)
  }
})
