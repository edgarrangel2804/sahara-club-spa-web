// Sahara Club Spa — Auto-confirmación de citas (Bloque 3)
//
// Regla de negocio (dueño): a las 20:00 (8 PM) hora Tijuana, las citas que YA
// pagaron su anticipo (status='payment_received') para el DÍA SIGUIENTE y que
// recepción NO confirmó, se avisan al número de emergencia (respaldo/admin) y
// el SISTEMA las confirma automáticamente (el anticipo garantiza el lugar).
//
// Disparo: cron a las 03:00 y 04:00 UTC (cubre PDT/PST). La función actúa solo
// cuando la hora local Tijuana es exactamente las 20. Idempotente.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { loadBusinessSettings, normalizePhone } from "../_shared/whatsapp_business.ts"
import {
  authorizeInternalRequest,
  jsonResponseFor,
  preflightResponse,
  sanitizeTechnicalLog,
} from "../_shared/runtime_security.ts"

function admin(): any {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

// "Ahora" en zona Tijuana como wall-clock.
function tijuanaNow(): Date {
  return new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
}

function ymd(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

Deno.serve(async (req: Request) => {
  const jsonResponse = (body: unknown, status = 200) => jsonResponseFor(req, body, status)
  if (req.method === "OPTIONS") return preflightResponse(req)
  if (req.method !== "POST") return jsonResponse({ ok: false, error: "method_not_allowed" }, 405)

  const authorization = await authorizeInternalRequest(req)
  if (!authorization.ok) {
    return jsonResponse({ ok: false, error: "not_authorized" }, authorization.status)
  }

  const sb = admin()
  const url = new URL(req.url)
  const force = url.searchParams.get("force") === "1" // para pruebas manuales

  // Gate horario: solo actúa a las 20:00 hora Tijuana (salvo ?force=1).
  const tjNow = tijuanaNow()
  if (!force && tjNow.getHours() !== 20) {
    return jsonResponse({ ok: true, skipped: "not_8pm_tijuana", tj_hour: tjNow.getHours() })
  }

  // Citas del DÍA SIGUIENTE que pagaron anticipo y siguen sin confirmar.
  const tomorrow = ymd(new Date(tjNow.getTime() + 86400000))
  const { data: rows, error } = await sb
    .from("bookings")
    .select(
      "id, booking_date, booking_time, status, service:services(name), client:clients(full_name, phone)",
    )
    .eq("status", "payment_received")
    .eq("booking_date", tomorrow)
  if (error) return jsonResponse({ ok: false, error: "query_failed" }, 200)

  const bookings = (rows ?? []) as Array<{
    id: string
    booking_date: string
    booking_time: string
    service: { name?: string } | null
    client: { full_name?: string; phone?: string } | null
  }>

  if (bookings.length === 0) {
    return jsonResponse({
      ok: true,
      date: tomorrow,
      confirmed: 0,
      note: "sin citas pagadas pendientes",
    })
  }

  // Destinatarios del aviso de emergencia: respaldo + admins (dedup por últimos 10).
  const { data: settings } = await sb
    .from("ai_settings")
    .select("human_backup_numbers, human_backup_enabled, ai_admin_numbers")
    .eq("id", 1)
    .maybeSingle()
  const backupEnabled =
    (settings as { human_backup_enabled?: boolean } | null)?.human_backup_enabled === true
  const backups = ((settings as { human_backup_numbers?: string[] } | null)?.human_backup_numbers ??
    []) as string[]
  const admins =
    ((settings as { ai_admin_numbers?: string[] } | null)?.ai_admin_numbers ?? []) as string[]
  const seen = new Set<string>()
  const emergencyTargets: string[] = []
  for (const list of [backups, admins]) {
    for (const n of list) {
      const tail = String(n).replace(/\D/g, "").slice(-10)
      if (tail.length === 10 && !seen.has(tail)) {
        seen.add(tail)
        emergencyTargets.push(n)
      }
    }
  }

  // Credenciales de WhatsApp (Meta) — mismo patrón que stripe_webhook.
  const biz = await loadBusinessSettings(sb).catch(() => null)
  const token = biz?.accessToken ?? ""
  const phoneId = biz?.row?.phone_number_id ?? ""
  async function sendWhatsApp(to: string, body: string) {
    if (!token || !phoneId) return
    try {
      await fetch(`https://graph.facebook.com/v21.0/${phoneId}/messages`, {
        method: "POST",
        headers: { "content-type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: normalizePhone(to),
          type: "text",
          text: { body },
        }),
      })
    } catch (_) { /* best-effort */ }
  }

  let confirmed = 0
  for (const b of bookings) {
    // Confirmar (idempotente: solo si sigue en payment_received).
    const { error: updErr } = await sb
      .from("bookings")
      .update({ status: "confirmed" })
      .eq("id", b.id)
      .eq("status", "payment_received")
    if (updErr) {
      console.warn("auto-confirm update failed", sanitizeTechnicalLog(updErr))
      continue
    }
    confirmed++

    const customer = b.client?.full_name ?? "Cliente"
    const svc = b.service?.name ?? "Servicio"
    const hora = (b.booking_time ?? "").slice(0, 5)

    // Aviso de emergencia a respaldo/admin.
    if (backupEnabled && emergencyTargets.length > 0) {
      const msg = [
        "⚠️ *Auto-confirmación de cita*",
        "",
        `*Cliente:* ${customer}`,
        `*Servicio:* ${svc}`,
        `*Fecha:* mañana ${b.booking_date} ${hora}`,
        "",
        "Pagó anticipo y no se confirmó manualmente antes de las 8 PM.",
        "El sistema la dejó *CONFIRMADA* automáticamente.",
      ].join("\n")
      for (const t of emergencyTargets) await sendWhatsApp(t, msg)
    }
    // Nota: el aviso de "cita confirmada" al cliente lo maneja el trigger de
    // cambio de estado de bookings (no lo duplicamos aquí).
  }

  return jsonResponse({ ok: true, date: tomorrow, found: bookings.length, confirmed })
})
