// Acciones admin sobre la cola: retry, cancel, requeue, bulk cleanup, export.
// Solo admin (vía assertAdminRequest).

import {
  assertAdminRequest, corsHeaders, createAdminClient,
} from "../_shared/whatsapp_business.ts"

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const supabase = createAdminClient()
    await assertAdminRequest(req, supabase)
    const body = await req.json().catch(() => ({}))
    const action = String(body.action ?? "").trim()
    const id = body.id ? String(body.id) : null

    switch (action) {
      case "retry":
      case "requeue": {
        if (!id) return jsonResponse({ error: "id requerido" }, 400)
        const { error } = await supabase.rpc("whatsapp_requeue_job", { p_id: id })
        if (error) throw error
        return jsonResponse({ ok: true, action, id })
      }
      case "cancel": {
        if (!id) return jsonResponse({ error: "id requerido" }, 400)
        const { error } = await supabase.rpc("whatsapp_cancel_job", { p_id: id })
        if (error) throw error
        return jsonResponse({ ok: true, action, id })
      }
      case "dead_letter": {
        if (!id) return jsonResponse({ error: "id requerido" }, 400)
        const reason = String(body.reason ?? "manual")
        const { error } = await supabase.rpc("whatsapp_mark_dead_letter", {
          p_id: id, p_reason: reason,
        })
        if (error) throw error
        return jsonResponse({ ok: true, action, id })
      }
      case "bulk_requeue_dead_letter": {
        const { data, error } = await supabase
          .from("whatsapp_queue")
          .update({
            status: "queued", retry_count: 0, scheduled_at: new Date().toISOString(),
            locked_at: null, locked_by: null, error_message: null,
            last_error_code: null, last_error_type: null,
            dead_letter_reason: null, dead_letter_at: null,
          })
          .eq("status", "dead_letter")
          .select("id")
        if (error) throw error
        return jsonResponse({ ok: true, requeued: data?.length ?? 0 })
      }
      case "cleanup": {
        const { data, error } = await supabase.rpc("cleanup_whatsapp_data", {
          p_logs_days: Number(body.logs_days ?? 90),
          p_events_days: Number(body.events_days ?? 60),
          p_terminal_queue_days: Number(body.queue_days ?? 30),
        })
        if (error) throw error
        return jsonResponse({ ok: true, deleted: data })
      }
      case "metrics": {
        const { data, error } = await supabase
          .from("whatsapp_metrics_24h").select("*").maybeSingle()
        if (error) throw error
        return jsonResponse({ ok: true, metrics: data })
      }
      case "export_logs": {
        const limit = Math.min(Number(body.limit ?? 500), 5000)
        const { data, error } = await supabase
          .from("whatsapp_logs")
          .select("created_at, status, event_type, phone, meta_template_name, meta_error_code, meta_error_message, message_rendered")
          .order("created_at", { ascending: false })
          .limit(limit)
        if (error) throw error
        return jsonResponse({ ok: true, rows: data ?? [] })
      }
      default:
        return jsonResponse({ error: `action desconocida: ${action}` }, 400)
    }
  } catch (e) {
    console.error("whatsapp_admin_actions", e)
    return jsonResponse({ error: (e as Error)?.message ?? "Error" }, 400)
  }
})
