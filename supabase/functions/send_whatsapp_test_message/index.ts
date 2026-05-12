import {
  assertAdminRequest,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  jsonResponse,
  loadBusinessSettings,
  normalizePhone,
  sendMetaTextMessage,
} from "../_shared/whatsapp_business.ts"

const TEST_MESSAGE =
  "Hola, este es un mensaje de prueba de Sahara Club Spa. Tu conexion de WhatsApp Business esta funcionando correctamente."

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const phone = normalizePhone(String(body.phone ?? "").trim())

    if (!phone) {
      return jsonResponse(
        { error: "Ingresa un numero de telefono para la prueba." },
        400,
      )
    }

    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)
    const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)

    if (!settings || !settings.accessToken || !settings.row.phone_number_id) {
      return jsonResponse(
        { error: "La conexion de WhatsApp Business no esta lista para enviar pruebas." },
        400,
      )
    }

    const response = await sendMetaTextMessage(
      settings.accessToken,
      settings.row.phone_number_id,
      phone,
      TEST_MESSAGE,
    )

    if (!response.ok) {
      console.error("send_whatsapp_test_message", response.data)
      return jsonResponse({
        ok: false,
        message:
          "No pudimos enviar el mensaje de prueba. Verifica el numero y el estado de la conexion con Meta.",
      }, 400)
    }

    return jsonResponse({
      ok: true,
      message: "Mensaje de prueba enviado correctamente.",
      phone,
      provider_response: response.data,
    })
  } catch (error) {
    console.error("send_whatsapp_test_message", error)
    return jsonResponse(
      { error: "No se pudo enviar el mensaje de prueba." },
      400,
    )
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
