// Sahara Club Spa - Trigger Webhook DB → envío de "confirmación de cita"
// Recibe payload de Supabase Database Webhook sobre tabla bookings.
// Solo dispara cuando status pasa a 'confirmed'.
// Usa templates Meta oficiales desde whatsapp_templates (Fase 2).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  loadBusinessSettings,
  normalizePhone,
} from "../_shared/whatsapp_business.ts"
import {
  bodyParamsForTemplateKey,
  buildMetaTemplatePayload,
  resolveTemplateForEvent,
  sendMetaTemplate,
} from "../_shared/meta_templates.ts"

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createAdminClient()
    const payload = await req.json().catch(() => ({})) as {
      record?: { id?: string; status?: string }
      old_record?: { status?: string }
    }
    const record = payload.record ?? {}
    const oldRecord = payload.old_record ?? {}

    if (record.status !== "confirmed" || oldRecord.status === "confirmed") {
      return jsonResponse({ message: "No action needed" })
    }
    if (!record.id) {
      return jsonResponse({ error: "missing booking id" }, 400)
    }

    const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)
    if (!settings || !settings.accessToken || !settings.row.phone_number_id) {
      return jsonResponse({ error: "WhatsApp config missing" }, 200)
    }

    const template = await resolveTemplateForEvent(
      supabase,
      "reservation_confirmed",
      DEFAULT_BRANCH_ID,
      null,
    )
    if (!template) {
      return jsonResponse({ error: "Template reservation_confirmed no existe" }, 200)
    }
    if (template.meta_template_status !== "approved" || !template.meta_template_name) {
      return jsonResponse({
        error: "Template reservation_confirmed no aprobado en Meta",
        status: template.meta_template_status,
      }, 200)
    }

    // Reusa build_whatsapp_context para construir todas las variables del booking
    const { data: ctx, error: ctxErr } = await supabase.rpc("build_whatsapp_context", {
      p_reservation_id: record.id,
      p_payload: {},
    })
    if (ctxErr) throw ctxErr
    const vars = (ctx ?? {}) as Record<string, unknown>

    const phone = normalizePhone(String(vars.telefono ?? ""))
    if (!phone) return jsonResponse({ error: "Cliente sin telefono" }, 200)

    const bodyParams = bodyParamsForTemplateKey(template.template_key, vars)
    const tmplPayload = buildMetaTemplatePayload(template, phone, { bodyParams })
    const res = await sendMetaTemplate(
      settings.accessToken,
      settings.row.phone_number_id,
      tmplPayload,
    )
    const wamid = (res.data as { messages?: Array<{ id?: string }> })?.messages?.[0]?.id ?? null
    const metaErr = !res.ok
      ? ((res.data as { error?: Record<string, unknown> })?.error ?? {})
      : {}

    await supabase.from("whatsapp_logs").insert({
      booking_id: record.id,
      reservation_id: record.id,
      template_id: template.id,
      phone,
      message_rendered: `[template:${template.meta_template_name}] ${bodyParams.join(" | ")}`,
      status: res.ok ? "sent" : "failed",
      provider: "meta_cloud_api",
      provider_response: { ...(res.data ?? {}), message_id: wamid },
      payload_sent: tmplPayload,
      meta_template_name: template.meta_template_name,
      meta_template_status: template.meta_template_status,
      meta_language: template.meta_language,
      meta_error_code: (metaErr as { code?: number })?.code ?? null,
      meta_error_subcode: (metaErr as { error_subcode?: number })?.error_subcode ?? null,
      meta_error_message: (metaErr as { message?: string })?.message ?? null,
      window_type: "template",
      sent_at: res.ok ? new Date().toISOString() : null,
      created_at: new Date().toISOString(),
      error_message: res.ok ? null : JSON.stringify(res.data),
      event_type: "reservation_confirmed",
      type: "reservation_confirmed",
    })

    return jsonResponse({
      ok: res.ok,
      wamid,
      template: template.meta_template_name,
      meta: res.data,
    }, res.ok ? 200 : 400)
  } catch (error) {
    console.error("whatsapp-confirmation", error)
    return jsonResponse({ error: (error as Error)?.message ?? String(error) }, 400)
  }
})
