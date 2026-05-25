// Sahara Club Spa - Reporte automático diario a admins por WhatsApp
// Invocado por pg_cron cada 5 min. Decide internamente si toca enviar:
//   - admin_daily_report_enabled = true
//   - hora actual (TZ) >= admin_daily_report_time
//   - admin_daily_report_last_sent_date < today (TZ)
//
// Envía texto libre a cada número en ai_admin_numbers.
// Nota: requiere ventana 24h activa por admin (si no, Meta rechaza).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  corsHeaders,
  callMetaApi,
  loadBusinessSettings,
  normalizePhone,
  DEFAULT_BRANCH_ID,
} from "../_shared/whatsapp_business.ts"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
)

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function formatReport(today: Record<string, unknown>, wa: Record<string, unknown>, ai: Record<string, unknown>, tjDate: string): string {
  const t = today as Record<string, number | string>
  const w = wa as Record<string, number | null>
  const a = ai as Record<string, number | null>
  const lines: string[] = [
    `📊 *Resumen ${tjDate} – Sahara Club*`,
    "",
    `📅 Citas: ${t.total ?? 0}`,
    `  • Confirmadas: ${t.confirmed ?? 0}`,
    `  • Completadas: ${t.completed ?? 0}`,
    `  • Pendientes: ${t.pending ?? 0}`,
    `  • Canceladas: ${t.cancelled ?? 0}`,
    `💰 Ingresos pagados: $${Number(t.revenue_today ?? 0).toLocaleString("es-MX")} MXN`,
    "",
    `📱 WhatsApp 24h: ${w.sent_count ?? 0} enviados · ${w.delivery_rate_pct ?? "—"}% delivery`,
    `🤖 IA hoy: ${a.assistant_messages_today ?? 0} respuestas · $${Number(a.cost_today_usd ?? 0).toFixed(2)} USD`,
  ]
  return lines.join("\n")
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {}
    const force = body.force === true

    const { data: s, error: sErr } = await supabase
      .from("ai_settings").select("*").eq("id", 1).single()
    if (sErr || !s) throw new Error("ai_settings no encontrado")

    if (!s.admin_daily_report_enabled && !force) {
      return jsonResponse({ skipped: true, reason: "report_disabled" })
    }

    const tz = s.admin_daily_report_timezone ?? "America/Tijuana"
    const tjNow = new Date(new Date().toLocaleString("en-US", { timeZone: tz }))
    const tjDate = tjNow.toISOString().slice(0, 10)
    const tjTime = tjNow.toTimeString().slice(0, 5)
    const reportTime = (s.admin_daily_report_time ?? "20:30").slice(0, 5)
    const lastSent = s.admin_daily_report_last_sent_date

    // Validaciones de "toca enviar"
    if (!force) {
      if (tjTime < reportTime) {
        return jsonResponse({ skipped: true, reason: "before_report_time",
          tj_time: tjTime, report_time: reportTime })
      }
      if (lastSent === tjDate) {
        return jsonResponse({ skipped: true, reason: "already_sent_today",
          last_sent: lastSent })
      }
    }

    const admins: string[] = s.ai_admin_numbers ?? []
    if (admins.length === 0) {
      return jsonResponse({ skipped: true, reason: "no_admins" })
    }

    // Cargar config Meta
    const businessSettings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)
    if (!businessSettings || !businessSettings.accessToken || !businessSettings.row.phone_number_id) {
      throw new Error("WhatsApp config missing")
    }

    // Componer el reporte
    const [todayRes, waRes, aiRes] = await Promise.all([
      supabase.from("admin_today_summary").select().maybeSingle(),
      supabase.from("whatsapp_metrics_24h").select().maybeSingle(),
      supabase.from("ai_metrics_dashboard").select().maybeSingle(),
    ])
    const reportText = formatReport(
      todayRes.data ?? {},
      waRes.data ?? {},
      aiRes.data ?? {},
      tjDate,
    )

    // Enviar a cada admin
    const results: Array<Record<string, unknown>> = []
    for (const adminPhone of admins) {
      const phone = normalizePhone(adminPhone)
      try {
        const res = await callMetaApi<Record<string, unknown>>(
          `${businessSettings.row.phone_number_id}/messages`,
          businessSettings.accessToken,
          {
            method: "POST",
            body: JSON.stringify({
              messaging_product: "whatsapp",
              to: phone,
              type: "text",
              text: { body: reportText },
            }),
          },
        )
        const wamid = (res.data as { messages?: Array<{ id?: string }> })?.messages?.[0]?.id ?? null

        await supabase.from("whatsapp_logs").insert({
          phone,
          message_rendered: reportText,
          status: res.ok ? "sent" : "failed",
          provider: "meta_cloud_api",
          provider_response: { ...(res.data ?? {}), message_id: wamid },
          payload_sent: { type: "text", text: reportText },
          meta_template_name: null,
          meta_error_message: !res.ok
            ? JSON.stringify((res.data as { error?: unknown })?.error ?? res.data)
            : null,
          window_type: "free_text_within_24h",
          sent_at: res.ok ? new Date().toISOString() : null,
          created_at: new Date().toISOString(),
          event_type: "admin_daily_report",
          type: "admin_daily_report",
        })
        results.push({ phone, ok: res.ok, wamid })
      } catch (e) {
        results.push({ phone, ok: false, error: (e as Error).message })
      }
    }

    // Marcar enviado hoy (solo si al menos uno se envió OK)
    const anyOk = results.some((r) => r.ok === true)
    if (anyOk) {
      await supabase.from("ai_settings")
        .update({ admin_daily_report_last_sent_date: tjDate })
        .eq("id", 1)
    }

    return jsonResponse({
      ok: true, tj_date: tjDate, sent_count: results.filter((r) => r.ok).length,
      total_admins: admins.length, results,
    })
  } catch (e) {
    console.error("whatsapp-admin-daily-report", e)
    return jsonResponse({ error: (e as Error).message }, 500)
  }
})
