import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  corsHeaders,
  DEFAULT_BRANCH_ID,
  loadBusinessSettings,
  normalizePhone,
  renderTemplate,
  sendMetaTextMessage,
} from "../_shared/whatsapp_business.ts"

type QueueRow = {
  id: string
  branch_id: string | null
  event_type: string
  reservation_id: string | null
  customer_id: string | null
  template_id: string | null
  payload: Record<string, unknown> | null
  retry_count: number
}

type TemplateRow = {
  id: string
  template_key: string
  template_name: string
  message_body: string
  is_active: boolean
  language_code: string
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  })
}

async function getTemplate(
  supabase: ReturnType<typeof createClient>,
  eventType: string,
  branchId: string | null,
  templateId?: string | null,
) {
  if (templateId) {
    const { data, error } = await supabase
      .from("whatsapp_templates")
      .select("id, template_key, template_name, message_body, is_active, language_code")
      .eq("id", templateId)
      .maybeSingle()

    if (error) throw error
    return data as TemplateRow | null
  }

  const resolvedBranchId = branchId || DEFAULT_BRANCH_ID

  let exactBranchQuery = supabase
    .from("whatsapp_templates")
    .select("id, template_key, template_name, message_body, is_active, language_code")
    .eq("trigger_event", eventType)
    .eq("is_active", true)
    .limit(1)

  if (resolvedBranchId) {
    const { data, error } = await exactBranchQuery.eq("branch_id", resolvedBranchId).maybeSingle()
    if (error) throw error
    if (data) return data as TemplateRow
  }

  const { data, error } = await supabase
    .from("whatsapp_templates")
    .select("id, template_key, template_name, message_body, is_active, language_code")
    .eq("trigger_event", eventType)
    .eq("is_active", true)
    .is("branch_id", null)
    .limit(1)
    .maybeSingle()

  if (error) throw error
  return data as TemplateRow | null
}

async function buildContext(
  supabase: ReturnType<typeof createClient>,
  reservationId: string | null,
  payload: Record<string, unknown> | null,
) {
  if (!reservationId) {
    return payload ?? {}
  }

  const { data, error } = await supabase.rpc("build_whatsapp_context", {
    p_reservation_id: reservationId,
    p_payload: payload ?? {},
  })

  if (error) throw error
  return (data ?? {}) as Record<string, unknown>
}

async function markQueueStatus(
  supabase: ReturnType<typeof createClient>,
  queueId: string,
  values: Record<string, unknown>,
) {
  const { error } = await supabase.from("whatsapp_queue").update(values).eq("id", queueId)
  if (error) throw error
}

async function insertLog(
  supabase: ReturnType<typeof createClient>,
  queue: QueueRow,
  template: TemplateRow | null,
  phone: string,
  rendered: string,
  status: string,
  providerResponse: Record<string, unknown>,
  errorMessage?: string,
) {
  const payload = {
    booking_id: queue.reservation_id,
    reservation_id: queue.reservation_id,
    customer_id: queue.customer_id,
    template_id: template?.id ?? null,
    queue_id: queue.id,
    phone,
    message_rendered: rendered,
    status,
    provider: "meta_cloud_api",
    provider_response: providerResponse,
    sent_at: status === "sent" ? new Date().toISOString() : null,
    created_at: new Date().toISOString(),
    error_message: errorMessage ?? null,
    event_type: queue.event_type,
    type: queue.event_type,
  }

  const { error } = await supabase.from("whatsapp_logs").insert(payload)
  if (error) throw error
}

async function processQueueJob(
  supabase: ReturnType<typeof createClient>,
  queue: QueueRow,
  config: {
    accessToken: string
    phoneNumberId: string
  },
) {
  await markQueueStatus(supabase, queue.id, {
    status: "processing",
    processed_at: new Date().toISOString(),
    error_message: null,
  })

  const template = await getTemplate(
    supabase,
    queue.event_type,
    queue.branch_id,
    queue.template_id,
  )

  if (!template) {
    await insertLog(supabase, queue, null, "", "", "skipped", {}, "No active template found")
    await markQueueStatus(supabase, queue.id, {
      status: "skipped",
      processed_at: new Date().toISOString(),
      error_message: "No active template found",
    })
    return { id: queue.id, status: "skipped" }
  }

  const vars = await buildContext(supabase, queue.reservation_id, queue.payload)
  const rendered = renderTemplate(template.message_body, vars)
  const phone = normalizePhone(String(vars.telefono ?? ""))

  if (!phone) {
    await insertLog(supabase, queue, template, "", rendered, "failed", {}, "Customer phone missing")
    await markQueueStatus(supabase, queue.id, {
      status: "failed",
      processed_at: new Date().toISOString(),
      error_message: "Customer phone missing",
      retry_count: queue.retry_count + 1,
    })
    return { id: queue.id, status: "failed", error: "Customer phone missing" }
  }

  const response = await sendMetaTextMessage(
    config.accessToken,
    config.phoneNumberId,
    phone,
    rendered,
  )
  if (response.ok) {
    await insertLog(supabase, queue, template, phone, rendered, "sent", response.data)
    await markQueueStatus(supabase, queue.id, {
      status: "processed",
      processed_at: new Date().toISOString(),
      provider_response: response.data,
    })
    return { id: queue.id, status: "processed" }
  }

  const nextRetryCount = queue.retry_count + 1
  const nextStatus = nextRetryCount >= 5 ? "failed" : "pending"
  const nextSchedule = new Date(Date.now() + nextRetryCount * 5 * 60 * 1000).toISOString()
  await insertLog(
    supabase,
    queue,
    template,
    phone,
    rendered,
    nextStatus === "failed" ? "failed" : "retrying",
    response.data ?? {},
    JSON.stringify(response.data),
  )
  await markQueueStatus(supabase, queue.id, {
    status: nextStatus,
    retry_count: nextRetryCount,
    processed_at: new Date().toISOString(),
    scheduled_at: nextStatus === "pending" ? nextSchedule : new Date().toISOString(),
    error_message: JSON.stringify(response.data),
    provider_response: response.data ?? {},
  })
  return { id: queue.id, status: nextStatus, error: response.data }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {}
    const action = body.action ?? "process"
    const businessSettings = await loadBusinessSettings(
      supabase,
      body.branch_id ?? body.branchId ?? DEFAULT_BRANCH_ID,
    )

    if (action === "preview") {
      const template = await getTemplate(
        supabase,
        body.event_type ?? body.eventType ?? "",
        body.branch_id ?? body.branchId ?? null,
        body.template_id ?? body.templateId ?? null,
      )
      if (!template) return jsonResponse({ error: "Template not found" }, 404)
      const vars = await buildContext(
        supabase,
        body.reservation_id ?? body.reservationId ?? null,
        body.payload ?? {},
      )
      return jsonResponse({
        template_id: template.id,
        rendered: renderTemplate(template.message_body, vars),
        vars,
      })
    }

    if (
      !businessSettings ||
      businessSettings.row.connection_status === "not_configured" ||
      !businessSettings.accessToken ||
      !businessSettings.row.phone_number_id
    ) {
      return jsonResponse({ error: "WhatsApp config missing or disabled" }, 400)
    }

    if (action === "test") {
      const template = await getTemplate(
        supabase,
        body.event_type ?? body.eventType ?? "",
        body.branch_id ?? body.branchId ?? null,
        body.template_id ?? body.templateId ?? null,
      )
      if (!template) return jsonResponse({ error: "Template not found" }, 404)
      const vars = await buildContext(
        supabase,
        body.reservation_id ?? body.reservationId ?? null,
        body.payload ?? {},
      )
      const rendered = renderTemplate(template.message_body, vars)
      const phone = normalizePhone(String(body.phone ?? vars.telefono ?? ""))
      const response = await sendMetaTextMessage(
        businessSettings.accessToken,
        businessSettings.row.phone_number_id,
        phone,
        rendered,
      )
      return jsonResponse({
        ok: response.ok,
        rendered,
        phone,
        provider_response: response.data,
      }, response.ok ? 200 : 400)
    }

    await supabase.rpc("enqueue_due_whatsapp_reminders", {
      p_now: new Date().toISOString(),
    }).catch(() => null)

    const limit = Number(body.limit ?? 20)
    const { data: queueRows, error } = await supabase
      .from("whatsapp_queue")
      .select("id, branch_id, event_type, reservation_id, customer_id, template_id, payload, retry_count")
      .in("status", ["pending", "retrying"])
      .lte("scheduled_at", new Date().toISOString())
      .order("scheduled_at", { ascending: true })
      .limit(limit)

    if (error) throw error

    const results = []
    for (const row of (queueRows ?? []) as QueueRow[]) {
      results.push(await processQueueJob(supabase, row, {
        accessToken: businessSettings.accessToken,
        phoneNumberId: businessSettings.row.phone_number_id,
      }))
    }

    return jsonResponse({
      processed: results.length,
      results,
    })
  } catch (error) {
    return jsonResponse({ error: error.message ?? String(error) }, 400)
  }
})
