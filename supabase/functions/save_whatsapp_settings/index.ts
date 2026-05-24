import {
  assertAdminRequest,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  encryptSecret,
  getBusinessSettingsRow,
  getConnectionStatusForDraft,
  jsonResponse,
  maskSecret,
  sanitizeSettings,
  syncLegacyConfig,
} from "../_shared/whatsapp_business.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)

    if (req.method === "GET") {
      const row = await getBusinessSettingsRow(supabase, DEFAULT_BRANCH_ID)
      return jsonResponse({ settings: sanitizeSettings(row) })
    }

    const body = await req.json().catch(() => ({}))
    const action = body.action ?? "save"

    if (action === "load") {
      const row = await getBusinessSettingsRow(supabase, DEFAULT_BRANCH_ID)
      return jsonResponse({ settings: sanitizeSettings(row) })
    }

    const current = await getBusinessSettingsRow(supabase, DEFAULT_BRANCH_ID)
    const accessTokenInput = String(body.access_token ?? "").trim()
    const appSecretInput = String(body.app_secret ?? "").trim()

    const accessTokenEncrypted = accessTokenInput
      ? await encryptSecret(accessTokenInput)
      : current?.access_token_encrypted ?? ""
    const appSecretEncrypted = appSecretInput
      ? await encryptSecret(appSecretInput)
      : current?.app_secret_encrypted ?? ""

    const payload = {
      branch_id: DEFAULT_BRANCH_ID,
      business_name: String(body.business_name ?? "").trim(),
      meta_business_id: String(body.meta_business_id ?? "").trim(),
      whatsapp_business_account_id: String(body.whatsapp_business_account_id ?? "").trim(),
      phone_number_id: String(body.phone_number_id ?? "").trim(),
      whatsapp_phone_number: String(body.whatsapp_phone_number ?? "").trim(),
      access_token_encrypted: accessTokenEncrypted,
      access_token_masked: accessTokenInput
        ? maskSecret(accessTokenInput)
        : current?.access_token_masked ?? "",
      app_id: String(body.app_id ?? "").trim(),
      app_secret_encrypted: appSecretEncrypted,
      app_secret_masked: appSecretInput
        ? maskSecret(appSecretInput)
        : current?.app_secret_masked ?? "",
      webhook_verify_token: String(body.webhook_verify_token ?? "").trim(),
      environment: ["sandbox", "production"].includes(String(body.environment ?? "").trim())
        ? String(body.environment).trim()
        : (current?.environment ?? "sandbox"),
      connection_status: getConnectionStatusForDraft({
        phone_number_id: String(body.phone_number_id ?? "").trim(),
        whatsapp_business_account_id: String(body.whatsapp_business_account_id ?? "").trim(),
        whatsapp_phone_number: String(body.whatsapp_phone_number ?? "").trim(),
        access_token_present: Boolean(accessTokenEncrypted),
      }),
    }

    const { data, error } = await supabase
      .from("business_whatsapp_settings")
      .upsert(payload, { onConflict: "branch_id" })
      .select("*")
      .single()

    if (error) throw error

    await syncLegacyConfig(supabase, {
      whatsappEnabled: payload.connection_status === "connected",
      phoneNumberId: payload.phone_number_id,
      businessId: payload.whatsapp_business_account_id,
      metaBusinessId: payload.meta_business_id,
    })

    return jsonResponse({
      message: "Configuracion guardada",
      settings: sanitizeSettings(data),
    })
  } catch (error) {
    console.error("save_whatsapp_settings", error)
    return jsonResponse(
      { error: "No se pudo guardar la configuracion de WhatsApp." },
      400,
    )
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
