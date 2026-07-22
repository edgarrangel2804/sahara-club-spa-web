// Sahara Club Spa - notify_admins
// ---------------------------------------------------------------------------
// Aviso a los ADMINISTRADORES (ai_admin_numbers + human_backup_numbers) por
// WhatsApp texto libre cuando una cita cambia de estado, SIN IMPORTAR el origen
// (recepción/panel, bot, POS, webhook de pago). Lo invoca el trigger
// handle_booking_whatsapp_events vía pg_net en cada transición relevante.
//
// Body: { booking_id: uuid, event: 'confirmed'|'cancelled'|'rescheduled' }
// verify_jwt=false: lo llama la base de datos (server-to-server).
//
// Best-effort: nunca rompe el flujo de la cita. Registra cada envío en
// whatsapp_logs (trazabilidad). El texto libre llega si el admin tiene ventana
// de 24h abierta con el negocio.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { DEFAULT_BRANCH_ID, loadBusinessSettings } from "../_shared/whatsapp_business.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status: s,
  })

function createAdminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

// Solo dígitos; quita "00" internacional; antepone 52 a números MX de 10 dígitos.
function normalizePhone(raw: string): string {
  let clean = String(raw ?? "").replace(/\D/g, "")
  if (clean.startsWith("00")) clean = clean.slice(2)
  if (clean.length === 10) clean = "52" + clean
  return clean
}

function fmtDateLong(dateStr: string): string {
  try {
    const [y, m, d] = dateStr.split("-").map((n) => parseInt(n, 10))
    const meses = [
      "enero",
      "febrero",
      "marzo",
      "abril",
      "mayo",
      "junio",
      "julio",
      "agosto",
      "septiembre",
      "octubre",
      "noviembre",
      "diciembre",
    ]
    return `${d} de ${meses[(m - 1) % 12]} de ${y}`
  } catch {
    return dateStr
  }
}
function fmtTime(t: string): string {
  if (!t) return ""
  const [h, min] = t.split(":")
  let hh = parseInt(h, 10)
  const ap = hh >= 12 ? "PM" : "AM"
  hh = hh % 12
  if (hh === 0) hh = 12
  return `${hh}:${min} ${ap}`
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  try {
    const body = await req.json().catch(() => ({}))
    const bookingId = String(body.booking_id ?? "").trim()
    const event = String(body.event ?? "").trim() // confirmed | cancelled | rescheduled
    if (!bookingId || !event) return json({ ok: false, error: "missing_params" }, 400)

    const sb = createAdminClient()

    // 1. Datos de la cita
    const { data: b } = await sb
      .from("bookings")
      .select(
        "booking_date, booking_time, service_name, service_id, client_record_id, therapist_id, payment_status",
      )
      .eq("id", bookingId)
      .maybeSingle()
    if (!b) return json({ ok: false, error: "booking_not_found" }, 404)
    const bk = b as Record<string, unknown>

    const { data: c } = await sb.from("clients").select("full_name, phone")
      .eq("id", bk.client_record_id as string).maybeSingle()
    const cliente = (c as { full_name?: string } | null)?.full_name ?? "Cliente"

    let servicio = String(bk.service_name ?? "")
    if (!servicio && bk.service_id) {
      const { data: sv } = await sb.from("services").select("name").eq(
        "id",
        bk.service_id as string,
      ).maybeSingle()
      servicio = (sv as { name?: string } | null)?.name ?? "Servicio"
    }
    if (!servicio) servicio = "Servicio"

    let terapeuta = ""
    if (bk.therapist_id) {
      const { data: st } = await sb.from("staff").select("full_name").eq(
        "id",
        bk.therapist_id as string,
      ).maybeSingle()
      terapeuta = (st as { full_name?: string } | null)?.full_name ?? ""
    }

    const fecha = fmtDateLong(String(bk.booking_date ?? ""))
    const hora = fmtTime(String(bk.booking_time ?? "").slice(0, 5))
    const isPaid = String(bk.payment_status ?? "") === "paid"

    // 2. Números de administradores + recepción
    const { data: s } = await sb.from("ai_settings")
      .select("human_backup_enabled, human_backup_numbers, ai_admin_numbers").eq("id", 1)
      .maybeSingle()
    if ((s as { human_backup_enabled?: boolean } | null)?.human_backup_enabled !== true) {
      return json({ ok: true, sent: 0, reason: "admin_alerts_disabled" })
    }
    const backups =
      ((s as { human_backup_numbers?: string[] } | null)?.human_backup_numbers ?? []) as string[]
    const admins =
      ((s as { ai_admin_numbers?: string[] } | null)?.ai_admin_numbers ?? []) as string[]

    // 3. Credenciales Meta — mismo método que las funciones que SÍ envían.
    //    La tabla guarda el token ENCRIPTADO en access_token_encrypted y se
    //    organiza por branch_id (NO existe is_active/access_token planos).
    //    loadBusinessSettings desencripta el token correctamente.
    const biz = await loadBusinessSettings(sb, DEFAULT_BRANCH_ID)
    const accessToken = Deno.env.get("META_ACCESS_TOKEN") || biz?.accessToken || ""
    const phoneNumberId = Deno.env.get("META_PHONE_NUMBER_ID") || biz?.row.phone_number_id || ""
    if (!accessToken || !phoneNumberId) {
      return json({ ok: false, error: "missing_meta_config" }, 500)
    }

    // 4. Texto según el evento (cambio YA ejecutado en la agenda)
    const datos = [
      `*Cliente:* ${cliente}`,
      `*Servicio:* ${servicio}`,
      fecha ? `*Fecha:* ${fecha}` : "",
      hora ? `*Hora:* ${hora}` : "",
      terapeuta ? `*Especialista:* ${terapeuta}` : "",
    ].filter(Boolean)
    let header = ""
    if (event === "confirmed") {
      header = isPaid ? "✅ *Cita CONFIRMADA (anticipo pagado)*" : "✅ *Cita CONFIRMADA*"
    } else if (event === "cancelled") {
      header = "🚫 *Cita CANCELADA*"
    } else if (event === "rescheduled") {
      header = "🔄 *Cita REAGENDADA*"
    } else {
      header = "🔔 *Cambio en una cita*"
    }
    const text = [header, "", ...datos, "", "Ya quedó reflejado en la agenda de Sahara."].join("\n")

    // 5. Enviar a admins + recepción (dedup por últimos 10 dígitos) + loguear
    const seen = new Set<string>()
    let sent = 0
    for (const raw of [...admins, ...backups]) {
      const tail = String(raw).replace(/\D/g, "").slice(-10)
      if (tail.length !== 10 || seen.has(tail)) continue
      seen.add(tail)
      const to = normalizePhone(String(raw))
      let ok = false
      try {
        const res = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
          method: "POST",
          headers: { "content-type": "application/json", Authorization: `Bearer ${accessToken}` },
          body: JSON.stringify({
            messaging_product: "whatsapp",
            to,
            type: "text",
            text: { body: text },
          }),
        })
        ok = res.ok
      } catch (_) {
        ok = false
      }
      try {
        await sb.from("whatsapp_logs").insert({
          phone: to,
          message_rendered: text,
          event_type: `admin_${event}`,
          type: `admin_${event}`,
          status: ok ? "sent" : "failed",
          reservation_id: bookingId,
          window_type: "free_text",
          provider: "meta",
          sent_at: new Date().toISOString(),
        })
      } catch (_) { /* best-effort */ }
      if (ok) sent += 1
    }

    return json({ ok: true, sent })
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500)
  }
})
