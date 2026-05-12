import {
  assertAdminRequest,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  jsonResponse,
  loadBusinessSettings,
  sanitizeSettings,
  syncLegacyConfig,
  verifyMetaConnection,
} from "../_shared/whatsapp_business.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)
    const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)

    if (!settings) {
      return jsonResponse({ error: "No hay configuracion guardada." }, 404)
    }

    const missingFields = [
      !settings.row.phone_number_id ? "phone_number_id" : null,
      !settings.row.whatsapp_business_account_id ? "whatsapp_business_account_id" : null,
      !settings.row.whatsapp_phone_number ? "whatsapp_phone_number" : null,
      !settings.accessToken ? "access_token" : null,
    ].filter(Boolean)

    if (missingFields.length > 0) {
      return jsonResponse({
        error:
          "Faltan datos obligatorios para validar la conexion de WhatsApp Business.",
        missing_fields: missingFields,
      }, 400)
    }

    const validation = await verifyMetaConnection(
      settings.accessToken,
      settings.row.phone_number_id,
      settings.row.whatsapp_business_account_id,
    )

    const status = validation.ok ? "connected" : "error"
    const now = new Date().toISOString()

    const { data, error } = await supabase
      .from("business_whatsapp_settings")
      .update({
        connection_status: status,
        last_validated_at: now,
      })
      .eq("id", settings.row.id)
      .select("*")
      .single()

    if (error) throw error

    await syncLegacyConfig(supabase, {
      whatsappEnabled: status === "connected",
      phoneNumberId: settings.row.phone_number_id,
      businessId: settings.row.whatsapp_business_account_id,
      metaBusinessId: settings.row.meta_business_id,
    })

    if (!validation.ok) {
      console.error("test_whatsapp_connection", validation.data)
      return jsonResponse({
        ok: false,
        status: "error",
        message:
          "No pudimos validar la conexion con Meta. Revisa el Access Token y los IDs de WhatsApp Business.",
        settings: sanitizeSettings(data),
      }, 400)
    }

    return jsonResponse({
      ok: true,
      status: "connected",
      message: "La conexion con WhatsApp Business fue validada correctamente.",
      settings: sanitizeSettings(data),
      meta_summary: validation.data,
    })
  } catch (error) {
    console.error("test_whatsapp_connection", error)
    return jsonResponse(
      { error: "No se pudo probar la conexion con Meta." },
      400,
    )
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
