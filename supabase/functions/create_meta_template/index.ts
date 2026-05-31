// Sahara Club Spa - Crea/Submite una plantilla de mensaje en Meta WABA.
// Uso interno y puntual. Protegida con TEMPLATE_SETUP_KEY (header x-setup-key
// o query ?k=). verify_jwt=false porque se invoca server-to-server con la llave.
//
// POST con body opcional { name, language, category, body_text, examples[] }.
// Si no se manda body, crea la plantilla por defecto: pago_anticipo_recibido (#25).
//
// Devuelve la respuesta cruda de Meta. Una plantilla nueva queda en estado
// PENDING hasta que Meta la apruebe (minutos/horas). Luego corre sync_meta_templates
// para reflejarla en whatsapp_templates.

import {
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  loadBusinessSettings,
} from "../_shared/whatsapp_business.ts"

const DEFAULT_TEMPLATE = {
  name: "pago_anticipo_recibido",
  language: "es",
  category: "UTILITY",
  body_text:
    "💰 Pago de anticipo recibido\n\n" +
    "Cliente: {{1}}\n" +
    "Teléfono: {{2}}\n" +
    "Servicio: {{3}}\n" +
    "Fecha: {{4}} a las {{5}}\n" +
    "Monto: ${{6}} MXN\n\n" +
    "Cita pendiente de confirmar en la agenda Sahara.",
  examples: [
    "Ana López",
    "646 123 4567",
    "Masaje relajante 60 min",
    "sábado 6 de junio",
    "12:00",
    "200",
  ],
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  // ── Guard ────────────────────────────────────────────────────────────────
  const url = new URL(req.url)
  const provided = req.headers.get("x-setup-key") ?? url.searchParams.get("k")
  const expected = Deno.env.get("TEMPLATE_SETUP_KEY")
  if (!expected || provided !== expected) {
    return new Response(JSON.stringify({ error: "forbidden" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }

  try {
    const supabase = createAdminClient()
    const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)
    if (
      !settings || !settings.accessToken ||
      !settings.row.whatsapp_business_account_id
    ) {
      return new Response(
        JSON.stringify({ error: "Configuracion incompleta: falta token o WABA ID." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    const wabaIdEarly = settings.row.whatsapp_business_account_id

    // ── Modo consulta (solo lectura) ──────────────────────────────────────────
    // GET o ?action=status -> lista el estado de las plantillas en Meta sin
    // crear nada. Útil para checar si una plantilla recién enviada ya fue
    // aprobada (PENDING -> APPROVED/REJECTED).
    const action = url.searchParams.get("action")
    const nameFilter = url.searchParams.get("name")
    if (req.method === "GET" || action === "status") {
      const qs = nameFilter ? `&name=${encodeURIComponent(nameFilter)}` : ""
      const res = await fetch(
        `https://graph.facebook.com/v21.0/${wabaIdEarly}/message_templates?fields=name,status,category,language&limit=100${qs}`,
        { headers: { Authorization: `Bearer ${settings.accessToken}` } },
      )
      const data = await res.json().catch(() => ({}))
      return new Response(JSON.stringify({ ok: res.ok, status: res.status, data }), {
        status: res.ok ? 200 : 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    let spec = DEFAULT_TEMPLATE
    try {
      const incoming = await req.json()
      if (incoming && typeof incoming === "object" && incoming.body_text) {
        spec = { ...DEFAULT_TEMPLATE, ...incoming }
      }
    } catch {
      // sin body → usa DEFAULT_TEMPLATE
    }

    const components = [
      {
        type: "BODY",
        text: spec.body_text,
        ...(Array.isArray(spec.examples) && spec.examples.length > 0
          ? { example: { body_text: [spec.examples] } }
          : {}),
      },
    ]

    const wabaId = settings.row.whatsapp_business_account_id
    const res = await fetch(
      `https://graph.facebook.com/v21.0/${wabaId}/message_templates`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${settings.accessToken}`,
        },
        body: JSON.stringify({
          name: spec.name,
          language: spec.language,
          category: spec.category,
          components,
        }),
      },
    )
    const data = await res.json().catch(() => ({}))
    return new Response(
      JSON.stringify({ ok: res.ok, status: res.status, submitted: spec.name, data }),
      {
        status: res.ok ? 200 : 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    )
  } catch (error) {
    console.error("create_meta_template", error)
    return new Response(
      JSON.stringify({ error: (error as Error)?.message ?? "Error desconocido" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
