import {
  assertAdminRequest,
  callMetaApi,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  jsonResponse,
  loadBusinessSettings,
  normalizePhone,
  sendMetaTextMessage,
} from "../_shared/whatsapp_business.ts"
import {
  bodyParamsForTemplateKey,
  buildMetaTemplatePayload,
  isWithinCustomerServiceWindow,
  resolveTemplateForEvent,
  sendMetaTemplate,
} from "../_shared/meta_templates.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)
    const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)

    if (!settings || !settings.accessToken || !settings.row.phone_number_id) {
      return jsonResponse(
        { error: "La configuracion de WhatsApp Business no esta lista." },
        400,
      )
    }

    const eventType = String(body.event_type ?? body.eventType ?? "")
    const template = await resolveTemplateForEvent(
      supabase,
      eventType,
      DEFAULT_BRANCH_ID,
      body.template_id ?? body.templateId ?? null,
    )
    if (!template) {
      return jsonResponse({ error: "No se encontro plantilla para el evento." }, 404)
    }

    // Construye contexto (vars dinámicas) usando build_whatsapp_context si hay reservation_id
    let vars = (body.payload ?? {}) as Record<string, unknown>
    if (body.reservation_id || body.reservationId) {
      const { data, error } = await supabase.rpc("build_whatsapp_context", {
        p_reservation_id: String(body.reservation_id ?? body.reservationId),
        p_payload: vars,
      })
      if (error) throw error
      vars = (data ?? {}) as Record<string, unknown>
    }

    const targetPhone = normalizePhone(String(body.phone ?? vars.telefono ?? ""))
    if (!targetPhone) {
      return jsonResponse({ error: "No se encontro telefono destino." }, 400)
    }

    const bodyParams = Array.isArray(body.body_params)
      ? (body.body_params as string[])
      : bodyParamsForTemplateKey(template.template_key, vars)

    const allowFreeText = body.allow_free_text === true
    const withinWindow = await isWithinCustomerServiceWindow(supabase, targetPhone)

    let metaResponse
    let payloadSent: Record<string, unknown>
    let windowType: "template" | "free_text_within_24h"

    if (allowFreeText && withinWindow) {
      // Camino libre solo si admin pidió explícitamente Y hay ventana 24h activa.
      const rendered = String(body.message ?? template.message_body ?? "")
      windowType = "free_text_within_24h"
      payloadSent = {
        messaging_product: "whatsapp",
        to: targetPhone,
        type: "text",
        text: { body: rendered },
      }
      metaResponse = await sendMetaTextMessage(
        settings.accessToken,
        settings.row.phone_number_id,
        targetPhone,
        rendered,
      )
    } else {
      // Camino oficial: template Meta aprobado.
      const tmplPayload = buildMetaTemplatePayload(template, targetPhone, {
        bodyParams,
      })
      payloadSent = tmplPayload as unknown as Record<string, unknown>
      windowType = "template"
      metaResponse = await sendMetaTemplate(
        settings.accessToken,
        settings.row.phone_number_id,
        tmplPayload,
      )
    }

    const metaErr = !metaResponse.ok
      ? ((metaResponse.data as { error?: Record<string, unknown> })?.error ?? {})
      : {}
    const wamid = (metaResponse.data as { messages?: Array<{ id?: string }> })?.messages?.[0]?.id ?? null

    await supabase.from("whatsapp_logs").insert({
      reservation_id: body.reservation_id ?? body.reservationId ?? null,
      customer_id: body.customer_id ?? body.customerId ?? null,
      template_id: template.id,
      phone: targetPhone,
      message_rendered: payloadSent?.template
        ? `[template:${template.meta_template_name}] ${bodyParams.join(" | ")}`
        : String((payloadSent as { text?: { body?: string } }).text?.body ?? ""),
      status: metaResponse.ok ? "sent" : "failed",
      provider: "meta_cloud_api",
      provider_response: { ...(metaResponse.data ?? {}), message_id: wamid },
      payload_sent: payloadSent,
      meta_template_name: template.meta_template_name,
      meta_template_status: template.meta_template_status,
      meta_language: template.meta_language,
      meta_error_code: (metaErr as { code?: number })?.code ?? null,
      meta_error_subcode: (metaErr as { error_subcode?: number })?.error_subcode ?? null,
      meta_error_message: (metaErr as { message?: string })?.message ?? null,
      window_type: windowType,
      sent_at: metaResponse.ok ? new Date().toISOString() : null,
      created_at: new Date().toISOString(),
      error_message: metaResponse.ok ? null : JSON.stringify(metaResponse.data),
      event_type: eventType || template.template_key,
      type: eventType || template.template_key,
    })

    if (!metaResponse.ok) {
      return jsonResponse({
        ok: false,
        meta_error: metaErr,
        window_type: windowType,
      }, 400)
    }

    return jsonResponse({
      ok: true,
      window_type: windowType,
      template: template.meta_template_name,
      wamid,
      meta: metaResponse.data,
    })
  } catch (error) {
    console.error("send_whatsapp_template_message", error)
    return jsonResponse(
      { error: (error as Error)?.message ?? "Error desconocido" },
      400,
    )
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}

// Re-export para uso interno opcional
export { callMetaApi }
