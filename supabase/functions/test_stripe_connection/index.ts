import {
  assertAdminRequest,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  jsonResponse,
  loadStripeSettings,
  sanitizeStripeSettings,
  testStripeSecretKey,
} from "../_shared/stripe_settings.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)

    const body = await req.json().catch(() => ({}))
    const environmentMode = String(body.environment_mode ?? "testing").trim() === "production"
      ? "production"
      : "testing"

    const settings = await loadStripeSettings(
      supabase,
      DEFAULT_BRANCH_ID,
      environmentMode,
    )

    if (!settings) {
      return jsonResponse({ error: "No hay configuracion de Stripe guardada." }, 404)
    }

    const missingFields = [
      !settings.row.publishable_key ? "publishable_key" : null,
      !settings.secretKey ? "secret_key" : null,
      !settings.webhookSecret ? "webhook_secret" : null,
    ].filter(Boolean)

    if (missingFields.length > 0) {
      return jsonResponse({
        error: "Faltan datos obligatorios para validar la conexion de Stripe.",
        missing_fields: missingFields,
      }, 400)
    }

    const validation = await testStripeSecretKey(settings.secretKey)
    const status = validation.ok ? "connected" : "error"
    const now = new Date().toISOString()

    const { data, error } = await supabase
      .from("stripe_settings")
      .update({
        connection_status: status,
        last_validated_at: now,
      })
      .eq("id", settings.row.id)
      .select("*")
      .single()

    if (error) throw error

    if (!validation.ok) {
      return jsonResponse({
        ok: false,
        status: "error",
        message:
          "No pudimos validar la conexion con Stripe. Revisa secret key, webhook secret y cuenta.",
        settings: sanitizeStripeSettings(data),
        stripe_summary: validation.data,
      }, 400)
    }

    return jsonResponse({
      ok: true,
      status: "connected",
      message: "La conexion con Stripe fue validada correctamente.",
      settings: sanitizeStripeSettings(data),
      stripe_summary: validation.data,
    })
  } catch (error) {
    console.error("test_stripe_connection", error)
    return jsonResponse(
      { error: "No se pudo probar la conexion con Stripe." },
      400,
    )
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
