// Sahara Club Spa - notify_unpaid_deposits
// ---------------------------------------------------------------------------
// Cron job (cada 5 min): busca bookings con status='pending_payment' que llevan
// más de 30 min sin pago y manda alerta WhatsApp a human_backup_numbers.
// Marca deposit_alerted_at para no spammear.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0"
import {
  authorizeInternalRequest,
  jsonResponseFor,
  preflightResponse,
  sanitizeTechnicalLog,
} from "../_shared/runtime_security.ts"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

// Trazabilidad (auditoría): registra en whatsapp_logs cada mensaje saliente.
// Best-effort: nunca lanza.
async function logOutbound(
  sb: any,
  opts: {
    phone: string
    body: string
    eventType: string
    status?: string
    reservationId?: string | null
  },
): Promise<void> {
  try {
    await sb.from("whatsapp_logs").insert({
      phone: String(opts.phone ?? "").replace(/\D/g, ""),
      message_rendered: opts.body,
      event_type: opts.eventType,
      type: opts.eventType,
      status: opts.status ?? "sent",
      reservation_id: opts.reservationId ?? null,
      window_type: "free_text",
      provider: "meta",
      sent_at: new Date().toISOString(),
    })
  } catch (e) {
    console.warn("logOutbound failed:", (e as Error).message)
  }
}

serve(async (req) => {
  const json = (body: unknown, status = 200) => jsonResponseFor(req, body, status)
  if (req.method === "OPTIONS") return preflightResponse(req)
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405)

  const authorization = await authorizeInternalRequest(req)
  if (!authorization.ok) {
    return json({ ok: false, error: "not_authorized" }, authorization.status)
  }

  const supabase: any = createClient(SUPABASE_URL, SERVICE_ROLE)

  // 1. Obtener candidatos
  const { data: candidates, error } = await supabase.rpc(
    "list_unpaid_deposit_bookings_for_alert",
  )
  if (error) return json({ error: error.message }, 500)
  const rows = (candidates ?? []) as Array<{
    booking_id: string
    client_phone: string
    client_name: string
    service_name: string
    booking_date: string
    booking_time: string
    minutes_since_created: number
  }>

  if (rows.length === 0) return json({ ok: true, alerted: 0 })

  // 2. Cargar backup numbers y access token
  const { data: settings } = await supabase
    .from("ai_settings")
    .select("human_backup_numbers, human_backup_enabled")
    .eq("id", 1)
    .maybeSingle()
  const enabled =
    (settings as { human_backup_enabled?: boolean } | null)?.human_backup_enabled === true
  const targets = ((settings as { human_backup_numbers?: string[] } | null)?.human_backup_numbers ??
    []) as string[]

  if (!enabled || targets.length === 0) {
    return json({ ok: true, alerted: 0, reason: "backup_disabled" })
  }

  const { data: wa } = await supabase
    .from("business_whatsapp_settings")
    .select("access_token, phone_number_id")
    .eq("is_active", true)
    .maybeSingle()
  const accessToken = (wa as { access_token?: string } | null)?.access_token
  const phoneNumberId = (wa as { phone_number_id?: string } | null)?.phone_number_id
  if (!accessToken || !phoneNumberId) return json({ error: "missing_meta_config" }, 500)

  let alerted = 0
  for (const r of rows) {
    const msg = [
      "⏰ *Anticipo sin pagar (30+ min)*",
      "",
      `*Cliente:* ${r.client_name}`,
      `*Teléfono:* ${r.client_phone}`,
      `*Servicio:* ${r.service_name}`,
      `*Cita solicitada:* ${r.booking_date} ${r.booking_time}`,
      `*Minutos sin pago:* ${r.minutes_since_created}`,
      "",
      "Considera dar seguimiento manual o cancelar.",
    ].join("\n")

    let alertedThisRow = false
    for (const t of targets) {
      try {
        const res = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
          method: "POST",
          headers: { "content-type": "application/json", Authorization: `Bearer ${accessToken}` },
          body: JSON.stringify({
            messaging_product: "whatsapp",
            to: String(t).replace(/\D/g, ""),
            type: "text",
            text: { body: msg },
          }),
        })
        await logOutbound(supabase, {
          phone: String(t),
          body: msg,
          eventType: "unpaid_deposit_admin",
          reservationId: r.booking_id ?? null,
          status: res.ok ? "sent" : "failed",
        })
        alertedThisRow = true
      } catch (e) {
        console.warn("notify failed for target", sanitizeTechnicalLog(e))
      }
    }

    if (alertedThisRow) {
      await supabase
        .from("bookings")
        .update({ deposit_alerted_at: new Date().toISOString() })
        .eq("id", r.booking_id)
      alerted++
    }
  }

  return json({ ok: true, alerted, checked: rows.length })
})
