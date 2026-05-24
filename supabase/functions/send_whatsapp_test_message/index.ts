// Sahara Club Spa - Mensaje de prueba manual desde admin
//
// Reglas:
// - SIEMPRE envía texto libre ("type":"text"), NUNCA templates.
// - Verifica ventana 24h ANTES de intentar: si no hay, devuelve 400 con causa clara.
// - Loguea todo en whatsapp_logs (payload, response Meta, wamid, error code).
// - Devuelve diagnóstico completo al frontend.

import {
  assertAdminRequest,
  callMetaApi,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  jsonResponse,
  loadBusinessSettings,
  normalizePhone,
} from "../_shared/whatsapp_business.ts"
import { isWithinCustomerServiceWindow } from "../_shared/meta_templates.ts"

const DEFAULT_TEST_MESSAGE = "Hola, esta es una prueba de Sahara Club Spa."

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const rawPhone = String(body.phone ?? "").trim()
    const phone = normalizePhone(rawPhone)
    const messageBody = String(body.message ?? DEFAULT_TEST_MESSAGE).trim() || DEFAULT_TEST_MESSAGE
    const force = body.force === true  // bypass de chequeo de ventana 24h (solo admin)

    if (!phone) {
      return jsonResponse({
        ok: false,
        error: "Ingresa un número de teléfono válido (formato internacional, mínimo 10 dígitos).",
        raw_phone: rawPhone,
      }, 400)
    }

    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)
    const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)

    if (!settings || !settings.accessToken || !settings.row.phone_number_id) {
      return jsonResponse({
        ok: false,
        error: "La configuración de WhatsApp Business no está lista (falta access_token o phone_number_id).",
      }, 400)
    }

    // -------------------------------------------------------------------
    // 1. Verificar ventana 24h
    // -------------------------------------------------------------------
    const withinWindow = await isWithinCustomerServiceWindow(supabase, phone)
    if (!withinWindow && !force) {
      return jsonResponse({
        ok: false,
        within_24h_window: false,
        no_window: true,
        phone,
        error:
          "No existe ventana activa de conversación. Primero el cliente debe enviar un mensaje al número de WhatsApp Business desde su celular. Una vez recibido (visible en whatsapp_webhook_events), tienes 24h para responder con texto libre.",
        hint:
          "Si el cliente ya envió un mensaje pero esta validación falla, revisa /functions/v1/whatsapp-webhook (Meta debe haberlo entregado) o pásalo como 'force: true' para enviar de todas formas.",
      }, 400)
    }

    // -------------------------------------------------------------------
    // 2. Enviar texto libre (NUNCA template para este endpoint)
    // -------------------------------------------------------------------
    const payloadSent = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: phone,
      type: "text",
      text: { preview_url: false, body: messageBody },
    }

    const startedAt = Date.now()
    const response = await callMetaApi<Record<string, unknown>>(
      `${settings.row.phone_number_id}/messages`,
      settings.accessToken,
      { method: "POST", body: JSON.stringify(payloadSent) },
    )
    const elapsedMs = Date.now() - startedAt

    const metaErr = !response.ok
      ? ((response.data as { error?: Record<string, unknown> })?.error ?? {}) as {
          code?: number; error_subcode?: number; message?: string; type?: string
        }
      : {}
    const wamid = (response.data as { messages?: Array<{ id?: string }> })?.messages?.[0]?.id ?? null
    const status = response.ok ? "sent" : "failed"

    // -------------------------------------------------------------------
    // 3. Loguear en whatsapp_logs (auditoría completa)
    // -------------------------------------------------------------------
    const { error: logErr } = await supabase.from("whatsapp_logs").insert({
      phone,
      message_rendered: messageBody,
      status,
      provider: "meta_cloud_api",
      provider_response: { ...(response.data ?? {}), http_status: response.status, message_id: wamid, elapsed_ms: elapsedMs },
      payload_sent: payloadSent,
      meta_error_code: metaErr.code ?? null,
      meta_error_subcode: metaErr.error_subcode ?? null,
      meta_error_message: metaErr.message ?? null,
      window_type: "free_text_within_24h",
      sent_at: response.ok ? new Date().toISOString() : null,
      created_at: new Date().toISOString(),
      error_message: response.ok ? null : JSON.stringify(response.data),
      event_type: "admin_test_message",
      type: "admin_test_message",
    })
    if (logErr) console.error("test_message log insert failed", logErr)

    // -------------------------------------------------------------------
    // 4. Respuesta detallada al frontend
    // -------------------------------------------------------------------
    if (!response.ok) {
      console.error("send_whatsapp_test_message FAILED", {
        phone, code: metaErr.code, message: metaErr.message,
      })
      return jsonResponse({
        ok: false,
        within_24h_window: withinWindow,
        forced: force,
        phone,
        http_status: response.status,
        meta_error: {
          code: metaErr.code ?? null,
          subcode: metaErr.error_subcode ?? null,
          message: metaErr.message ?? null,
          type: metaErr.type ?? null,
        },
        provider_response: response.data,
        payload_sent: payloadSent,
        elapsed_ms: elapsedMs,
        error: metaErr.message
          ? `Meta rechazó el mensaje: ${metaErr.message} (code ${metaErr.code ?? "n/a"})`
          : "Meta rechazó el mensaje. Revisa el detalle del provider_response.",
      }, 400)
    }

    return jsonResponse({
      ok: true,
      within_24h_window: withinWindow,
      forced: force,
      phone,
      http_status: response.status,
      wamid,
      elapsed_ms: elapsedMs,
      message_body: messageBody,
      payload_sent: payloadSent,
      provider_response: response.data,
      hint: "Verifica el estado delivered/read en whatsapp_webhook_events o en el dashboard de cola.",
    })
  } catch (error) {
    console.error("send_whatsapp_test_message EXCEPTION", error)
    return jsonResponse({
      ok: false,
      error: (error as Error)?.message ?? "Error desconocido al enviar el mensaje de prueba.",
    }, 500)
  }
})
