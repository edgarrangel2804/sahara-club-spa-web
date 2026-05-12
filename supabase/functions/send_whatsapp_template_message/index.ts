import {
  assertAdminRequest,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  jsonResponse,
  loadBusinessSettings,
  normalizePhone,
  renderTemplate,
  sendMetaTextMessage,
} from "../_shared/whatsapp_business.ts"

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

    let templateQuery = supabase
      .from("whatsapp_templates")
      .select("id, template_name, message_body, trigger_event")
      .limit(1)

    if (body.template_id) {
      templateQuery = templateQuery.eq("id", String(body.template_id))
    } else {
      templateQuery = templateQuery
        .eq("trigger_event", String(body.event_type ?? body.eventType ?? ""))
        .eq("is_active", true)
        .eq("branch_id", DEFAULT_BRANCH_ID)
    }

    const { data: template, error: templateError } = await templateQuery.maybeSingle()
    if (templateError) throw templateError
    if (!template) {
      return jsonResponse({ error: "No se encontro una plantilla activa." }, 404)
    }

    let vars = (body.payload ?? {}) as Record<string, unknown>
    if (body.reservation_id || body.reservationId) {
      const { data, error } = await supabase.rpc("build_whatsapp_context", {
        p_reservation_id: String(body.reservation_id ?? body.reservationId),
        p_payload: vars,
      })
      if (error) throw error
      vars = (data ?? {}) as Record<string, unknown>
    }

    const rendered = renderTemplate(String(template.message_body ?? ""), vars)
    const targetPhone = normalizePhone(
      String(body.phone ?? vars.telefono ?? ""),
    )

    if (!targetPhone) {
      return jsonResponse(
        { error: "No se encontro un telefono de destino para el envio." },
        400,
      )
    }

    const response = await sendMetaTextMessage(
      settings.accessToken,
      settings.row.phone_number_id,
      targetPhone,
      rendered,
    )

    const logPayload = {
      reservation_id: body.reservation_id ?? body.reservationId ?? null,
      customer_id: body.customer_id ?? body.customerId ?? null,
      template_id: template.id,
      phone: targetPhone,
      message_rendered: rendered,
      status: response.ok ? "sent" : "failed",
      provider: "meta_cloud_api",
      provider_response: response.data ?? {},
      sent_at: response.ok ? new Date().toISOString() : null,
      created_at: new Date().toISOString(),
      error_message: response.ok ? null : JSON.stringify(response.data),
      event_type: body.event_type ?? body.eventType ?? template.trigger_event,
      type: body.event_type ?? body.eventType ?? template.trigger_event,
    }

    await supabase.from("whatsapp_logs").insert(logPayload)

    if (!response.ok) {
      console.error("send_whatsapp_template_message", response.data)
      return jsonResponse({
        ok: false,
        message:
          "Meta rechazo el mensaje. Revisa la conexion o el formato del telefono.",
      }, 400)
    }

    return jsonResponse({
      ok: true,
      message: "Mensaje enviado correctamente.",
      rendered,
      phone: targetPhone,
      provider_response: response.data,
    })
  } catch (error) {
    console.error("send_whatsapp_template_message", error)
    return jsonResponse(
      { error: "No se pudo enviar el mensaje de plantilla." },
      400,
    )
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
