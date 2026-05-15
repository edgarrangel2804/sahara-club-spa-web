import {
  assertAdminRequest,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  encryptSecret,
  getStripeSettingsRow,
  getStripeSettingsRows,
  jsonResponse,
  maskSecret,
  sanitizeStripeSettings,
} from "../_shared/stripe_settings.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)

    if (req.method === "GET") {
      const rows = await getStripeSettingsRows(supabase, DEFAULT_BRANCH_ID)
      const activeRow = rows.find((row) => row.is_active) ?? rows[0] ?? null
      return jsonResponse({
        active_mode: activeRow?.environment_mode ?? "testing",
        settings: rows.map(sanitizeStripeSettings),
      })
    }

    const body = await req.json().catch(() => ({}))
    const action = String(body.action ?? "save").trim()

    if (action === "load") {
      const rows = await getStripeSettingsRows(supabase, DEFAULT_BRANCH_ID)
      const activeRow = rows.find((row) => row.is_active) ?? rows[0] ?? null
      return jsonResponse({
        active_mode: activeRow?.environment_mode ?? "testing",
        settings: rows.map(sanitizeStripeSettings),
      })
    }

    const environmentMode = String(body.environment_mode ?? "testing").trim() === "production"
      ? "production"
      : "testing"
    const current = await getStripeSettingsRow(
      supabase,
      DEFAULT_BRANCH_ID,
      environmentMode,
    )

    const secretKeyInput = String(body.secret_key ?? "").trim()
    const webhookSecretInput = String(body.webhook_secret ?? "").trim()

    const secretKeyEncrypted = secretKeyInput
      ? await encryptSecret(secretKeyInput)
      : current?.secret_key_encrypted ?? ""
    const webhookSecretEncrypted = webhookSecretInput
      ? await encryptSecret(webhookSecretInput)
      : current?.webhook_secret_encrypted ?? ""

    const isActive = Boolean(body.is_active ?? true)

    if (isActive) {
      await supabase
        .from("stripe_settings")
        .update({ is_active: false })
        .eq("branch_id", DEFAULT_BRANCH_ID)
    }

    const hasAnyCredential = Boolean(
      String(body.publishable_key ?? "").trim() ||
      secretKeyEncrypted ||
      webhookSecretEncrypted ||
      String(body.stripe_account_id ?? "").trim(),
    )

    const payload = {
      branch_id: DEFAULT_BRANCH_ID,
      environment_mode: environmentMode,
      publishable_key: String(body.publishable_key ?? "").trim(),
      secret_key_encrypted: secretKeyEncrypted,
      secret_key_masked: secretKeyInput
        ? maskSecret(secretKeyInput)
        : current?.secret_key_masked ?? "",
      webhook_secret_encrypted: webhookSecretEncrypted,
      webhook_secret_masked: webhookSecretInput
        ? maskSecret(webhookSecretInput)
        : current?.webhook_secret_masked ?? "",
      stripe_account_id: String(body.stripe_account_id ?? "").trim(),
      is_active: isActive,
      connection_status: hasAnyCredential ? "pending" : "not_configured",
    }

    const { data, error } = await supabase
      .from("stripe_settings")
      .upsert(payload, { onConflict: "branch_id,environment_mode" })
      .select("*")
      .single()

    if (error) throw error

    const rows = await getStripeSettingsRows(supabase, DEFAULT_BRANCH_ID)
    return jsonResponse({
      message: "Configuracion de Stripe guardada",
      active_mode:
        rows.find((row) => row.is_active)?.environment_mode ?? environmentMode,
      current: sanitizeStripeSettings(data),
      settings: rows.map(sanitizeStripeSettings),
    })
  } catch (error) {
    console.error("save_stripe_settings", error)
    return jsonResponse(
      { error: "No se pudo guardar la configuracion de Stripe." },
      400,
    )
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
