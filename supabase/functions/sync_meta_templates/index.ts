// Sahara Club Spa - Sincroniza templates locales contra el catálogo Meta WABA.
// GET / POST -> admin only. Devuelve { fetched, updated, marked_deleted, synced_at }.

import {
  assertAdminRequest,
  corsHeaders,
  createAdminClient,
  DEFAULT_BRANCH_ID,
  loadBusinessSettings,
} from "../_shared/whatsapp_business.ts"
import { syncMetaTemplates } from "../_shared/meta_templates.ts"

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)

    const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)
    if (!settings || !settings.accessToken || !settings.row.whatsapp_business_account_id) {
      return jsonResponse(
        { error: "Configuracion incompleta: falta access token o WABA ID." },
        400,
      )
    }

    const result = await syncMetaTemplates(
      supabase,
      settings.accessToken,
      settings.row.whatsapp_business_account_id,
    )

    return jsonResponse({ ok: true, ...result })
  } catch (error) {
    console.error("sync_meta_templates", error)
    return jsonResponse(
      { error: (error as Error)?.message ?? "Error desconocido" },
      400,
    )
  }
})
