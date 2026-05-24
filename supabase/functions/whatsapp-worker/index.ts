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
import {
  bodyParamsForTemplateKey,
  buildMetaTemplatePayload,
  isWithinCustomerServiceWindow,
  resolveTemplateForEvent,
  sendMetaTemplate,
  type TemplateRow,
} from "../_shared/meta_templates.ts"

type QueueRow = {
  id: string
  branch_id: string | null
  event_type: string
  reservation_id: string | null
  customer_id: string | null
  template_id: string | null
  payload: Record<string, unknown> | null
  retry_count: number
  max_retries: number
  correlation_id: string
}

const MAX_RETRIES = 5
const PERMANENT_META_CODES = new Set<number>([
  // Template / payload errors → no reintentar.
  131000, 131005, 131008, 131009, 131021, 131026, 131031, 131047, 131051,
  132000, 132001, 132005, 132007, 132012, 132015, 132016, 132068, 132069,
  133000, 133004, 133005, 133006, 133008, 133009, 133010, 133011,
])
// 130429 (rate limit), 1, 2, 80007 → transient
const RATE_LIMIT_CODES = new Set<number>([130429, 80007])

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  })
}

function structuredLog(level: "info" | "warn" | "error", msg: string, fields: Record<string, unknown> = {}) {
  const line = JSON.stringify({ ts: new Date().toISOString(), level, msg, ...fields })
  if (level === "error") console.error(line); else console.log(line)
}

function classifyMetaError(code: number | null): "transient" | "permanent" | "unknown" {
  if (code == null) return "unknown"
  if (RATE_LIMIT_CODES.has(code)) return "transient"
  if (PERMANENT_META_CODES.has(code)) return "permanent"
  // 5xx implícitos / network → transient. 4xx desconocidos → permanent por seguridad.
  if (code >= 500) return "transient"
  return "permanent"
}

function backoffMs(retry: number) {
  // Exponencial 30s, 60s, 120s, 240s, 480s + jitter ±25%
  const base = 30_000 * Math.pow(2, Math.max(0, retry - 1))
  const jitter = base * 0.25 * (Math.random() * 2 - 1)
  return Math.min(base + jitter, 15 * 60 * 1000)
}

async function buildContext(
  supabase: ReturnType<typeof createClient>,
  reservationId: string | null,
  payload: Record<string, unknown> | null,
) {
  if (!reservationId) return payload ?? {}
  const { data, error } = await supabase.rpc("build_whatsapp_context", {
    p_reservation_id: reservationId,
    p_payload: payload ?? {},
  })
  if (error) throw error
  return (data ?? {}) as Record<string, unknown>
}

async function insertLog(
  supabase: ReturnType<typeof createClient>,
  queue: QueueRow,
  workerRunId: string,
  template: TemplateRow | null,
  phone: string,
  rendered: string,
  status: string,
  providerResponse: Record<string, unknown>,
  extra: {
    payloadSent?: Record<string, unknown>
    windowType?: string
    metaErrorCode?: number | null
    metaErrorSubcode?: number | null
    metaErrorMessage?: string | null
    errorMessage?: string
  } = {},
) {
  const wamid =
    (providerResponse as { messages?: Array<{ id?: string }>; message_id?: string })?.messages?.[0]?.id
    ?? (providerResponse as { message_id?: string })?.message_id
    ?? null

  await supabase.from("whatsapp_logs").insert({
    booking_id: queue.reservation_id,
    reservation_id: queue.reservation_id,
    customer_id: queue.customer_id,
    template_id: template?.id ?? null,
    queue_id: queue.id,
    phone,
    message_rendered: rendered,
    status,
    provider: "meta_cloud_api",
    provider_response: {
      ...providerResponse, message_id: wamid,
      correlation_id: queue.correlation_id, worker_run_id: workerRunId,
    },
    payload_sent: extra.payloadSent ?? null,
    meta_template_name: template?.meta_template_name ?? null,
    meta_template_status: template?.meta_template_status ?? null,
    meta_language: template?.meta_language ?? null,
    meta_error_code: extra.metaErrorCode ?? null,
    meta_error_subcode: extra.metaErrorSubcode ?? null,
    meta_error_message: extra.metaErrorMessage ?? null,
    window_type: extra.windowType ?? null,
    sent_at: status === "sent" ? new Date().toISOString() : null,
    created_at: new Date().toISOString(),
    error_message: extra.errorMessage ?? null,
    event_type: queue.event_type,
    type: queue.event_type,
  })
}

async function markQueueStatus(
  supabase: ReturnType<typeof createClient>,
  queueId: string,
  values: Record<string, unknown>,
) {
  await supabase.from("whatsapp_queue").update(values).eq("id", queueId)
}

async function processQueueJob(
  supabase: ReturnType<typeof createClient>,
  queue: QueueRow,
  workerRunId: string,
  config: { accessToken: string; phoneNumberId: string },
): Promise<{ result: "sent" | "failed" | "dead_letter" | "skipped"; rateLimit?: boolean }> {
  const template = await resolveTemplateForEvent(
    supabase, queue.event_type, queue.branch_id, queue.template_id,
  )

  if (!template) {
    await insertLog(supabase, queue, workerRunId, null, "", "", "skipped", {}, {
      errorMessage: "No active template found",
    })
    await markQueueStatus(supabase, queue.id, {
      status: "skipped", processed_at: new Date().toISOString(),
      error_message: "No active template found",
      locked_at: null, locked_by: null, worker_run_id: workerRunId,
    })
    return { result: "skipped" }
  }

  const vars = await buildContext(supabase, queue.reservation_id, queue.payload)
  const phone = normalizePhone(String(vars.telefono ?? ""))
  if (!phone) {
    await insertLog(supabase, queue, workerRunId, template, "", "", "failed", {}, {
      errorMessage: "Customer phone missing",
    })
    await markQueueStatus(supabase, queue.id, {
      status: "dead_letter", processed_at: new Date().toISOString(),
      dead_letter_reason: "Customer phone missing", dead_letter_at: new Date().toISOString(),
      locked_at: null, locked_by: null, worker_run_id: workerRunId,
      last_error_type: "permanent",
    })
    return { result: "dead_letter" }
  }

  let sendResult: { ok: boolean; data: Record<string, unknown> }
  let payloadSent: Record<string, unknown>
  let windowType: "template" | "free_text_within_24h"
  let renderedForLog: string

  if (template.meta_template_status === "approved" && template.meta_template_name) {
    const bodyParams = bodyParamsForTemplateKey(template.template_key, vars)
    try {
      const tmplPayload = buildMetaTemplatePayload(template, phone, { bodyParams })
      payloadSent = tmplPayload as unknown as Record<string, unknown>
      windowType = "template"
      renderedForLog = `[template:${template.meta_template_name}] ${bodyParams.join(" | ")}`
      sendResult = await sendMetaTemplate(config.accessToken, config.phoneNumberId, tmplPayload)
    } catch (err) {
      const msg = (err as Error).message
      await insertLog(supabase, queue, workerRunId, template, phone, "", "failed", {}, { errorMessage: msg })
      await markQueueStatus(supabase, queue.id, {
        status: "dead_letter", processed_at: new Date().toISOString(),
        dead_letter_reason: msg, dead_letter_at: new Date().toISOString(),
        locked_at: null, locked_by: null, worker_run_id: workerRunId,
        last_error_type: "permanent",
      })
      return { result: "dead_letter" }
    }
  } else {
    const within = await isWithinCustomerServiceWindow(supabase, phone)
    if (!within) {
      const msg = `Template "${template.template_key}" no aprobado (status=${template.meta_template_status}) y cliente fuera de ventana 24h.`
      await insertLog(supabase, queue, workerRunId, template, phone, "", "failed", {}, {
        errorMessage: msg, windowType: "template",
      })
      await markQueueStatus(supabase, queue.id, {
        status: "dead_letter", processed_at: new Date().toISOString(),
        dead_letter_reason: msg, dead_letter_at: new Date().toISOString(),
        locked_at: null, locked_by: null, worker_run_id: workerRunId,
        last_error_type: "permanent",
      })
      return { result: "dead_letter" }
    }
    const rendered = renderTemplate(template.message_body ?? "", vars)
    renderedForLog = rendered
    windowType = "free_text_within_24h"
    payloadSent = {
      messaging_product: "whatsapp", to: phone, type: "text", text: { body: rendered },
    }
    sendResult = await sendMetaTextMessage(config.accessToken, config.phoneNumberId, phone, rendered)
  }

  if (sendResult.ok) {
    await insertLog(supabase, queue, workerRunId, template, phone, renderedForLog, "sent", sendResult.data, {
      payloadSent, windowType,
    })
    await markQueueStatus(supabase, queue.id, {
      status: "sent", processed_at: new Date().toISOString(),
      provider_response: sendResult.data,
      locked_at: null, locked_by: null, worker_run_id: workerRunId,
      error_message: null, last_error_code: null, last_error_type: null,
    })
    return { result: "sent" }
  }

  const metaErr = ((sendResult.data as { error?: Record<string, unknown> })?.error ?? {}) as {
    code?: number; error_subcode?: number; message?: string
  }
  const code = typeof metaErr.code === "number" ? metaErr.code : null
  const errType = classifyMetaError(code)
  const rateLimit = code != null && RATE_LIMIT_CODES.has(code)
  const nextRetry = queue.retry_count + 1
  const giveUp = errType === "permanent" || nextRetry >= (queue.max_retries ?? MAX_RETRIES)

  if (giveUp) {
    await insertLog(supabase, queue, workerRunId, template, phone, renderedForLog, "failed", sendResult.data ?? {}, {
      payloadSent, windowType,
      metaErrorCode: code, metaErrorSubcode: metaErr.error_subcode ?? null,
      metaErrorMessage: metaErr.message ?? null,
      errorMessage: JSON.stringify(sendResult.data),
    })
    await markQueueStatus(supabase, queue.id, {
      status: "dead_letter", processed_at: new Date().toISOString(),
      dead_letter_reason: `${errType} error code=${code ?? "n/a"} msg=${metaErr.message ?? "n/a"}`,
      dead_letter_at: new Date().toISOString(),
      locked_at: null, locked_by: null, worker_run_id: workerRunId,
      last_error_code: code, last_error_type: errType,
      retry_count: nextRetry, provider_response: sendResult.data ?? {},
      error_message: JSON.stringify(sendResult.data),
    })
    return { result: "dead_letter", rateLimit }
  }

  // Retry transient
  const delay = backoffMs(nextRetry)
  const nextSchedule = new Date(Date.now() + delay).toISOString()
  await insertLog(supabase, queue, workerRunId, template, phone, renderedForLog, "retrying", sendResult.data ?? {}, {
    payloadSent, windowType,
    metaErrorCode: code, metaErrorSubcode: metaErr.error_subcode ?? null,
    metaErrorMessage: metaErr.message ?? null,
    errorMessage: JSON.stringify(sendResult.data),
  })
  await markQueueStatus(supabase, queue.id, {
    status: "retrying", retry_count: nextRetry,
    processed_at: new Date().toISOString(), scheduled_at: nextSchedule,
    locked_at: null, locked_by: null, worker_run_id: workerRunId,
    last_error_code: code, last_error_type: errType,
    error_message: JSON.stringify(sendResult.data),
    provider_response: sendResult.data ?? {},
  })
  return { result: "failed", rateLimit }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
  const workerRunId = crypto.randomUUID()
  const workerId = `wkr-${workerRunId.slice(0, 8)}`
  const startedAt = Date.now()

  // Registrar la ejecución desde el inicio (observabilidad)
  await supabase.from("whatsapp_worker_runs").insert({
    id: workerRunId, worker_id: workerId, started_at: new Date().toISOString(),
  })

  try {
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {}
    const action = body.action ?? "process"
    const branchId = body.branch_id ?? body.branchId ?? DEFAULT_BRANCH_ID

    const businessSettings = await loadBusinessSettings(supabase, branchId)

    if (action === "preview") {
      const template = await resolveTemplateForEvent(
        supabase, body.event_type ?? body.eventType ?? "",
        branchId, body.template_id ?? body.templateId ?? null,
      )
      if (!template) return jsonResponse({ error: "Template not found" }, 404)
      const vars = await buildContext(supabase, body.reservation_id ?? null, body.payload ?? {})
      const bodyParams = bodyParamsForTemplateKey(template.template_key, vars)
      const preview = template.meta_template_name
        ? buildMetaTemplatePayload(template, body.phone ?? "5215555555555", { bodyParams })
        : null
      return jsonResponse({
        template_id: template.id, meta_template_name: template.meta_template_name,
        meta_template_status: template.meta_template_status,
        body_params: bodyParams, meta_payload: preview, vars,
      })
    }

    if (
      !businessSettings || businessSettings.row.connection_status === "not_configured" ||
      !businessSettings.accessToken || !businessSettings.row.phone_number_id
    ) {
      await supabase.from("whatsapp_worker_runs").update({
        finished_at: new Date().toISOString(),
        error_message: "WhatsApp config missing", duration_ms: Date.now() - startedAt,
      }).eq("id", workerRunId)
      return jsonResponse({ error: "WhatsApp config missing or disabled" }, 400)
    }

    const limit = Number(body.limit ?? 25)
    const { data: jobs, error: claimErr } = await supabase.rpc("claim_whatsapp_jobs", {
      p_limit: limit, p_worker_id: workerId,
    })
    if (claimErr) throw claimErr

    structuredLog("info", "jobs_claimed", { workerRunId, count: (jobs ?? []).length })

    let sent = 0, failed = 0, dead = 0, rateHit = false
    for (const row of (jobs ?? []) as QueueRow[]) {
      try {
        const r = await processQueueJob(supabase, row, workerRunId, {
          accessToken: businessSettings.accessToken,
          phoneNumberId: businessSettings.row.phone_number_id,
        })
        if (r.result === "sent") sent++
        else if (r.result === "dead_letter") dead++
        else if (r.result === "failed") failed++
        if (r.rateLimit) rateHit = true
        if (rateHit) {
          // Backoff suave entre jobs si Meta nos limitó
          await new Promise((res) => setTimeout(res, 800))
        }
      } catch (e) {
        structuredLog("error", "job_exception", {
          workerRunId, jobId: row.id, error: (e as Error).message,
        })
        failed++
        await markQueueStatus(supabase, row.id, {
          status: "retrying",
          scheduled_at: new Date(Date.now() + backoffMs(row.retry_count + 1)).toISOString(),
          retry_count: row.retry_count + 1,
          locked_at: null, locked_by: null, worker_run_id: workerRunId,
          error_message: (e as Error).message, last_error_type: "transient",
        })
      }
    }

    await supabase.from("whatsapp_worker_runs").update({
      finished_at: new Date().toISOString(),
      jobs_claimed: (jobs ?? []).length, jobs_sent: sent,
      jobs_failed: failed, jobs_dead_letter: dead,
      meta_rate_limit_hit: rateHit, duration_ms: Date.now() - startedAt,
    }).eq("id", workerRunId)

    return jsonResponse({
      worker_run_id: workerRunId, claimed: (jobs ?? []).length,
      sent, failed, dead_letter: dead, rate_limit_hit: rateHit,
      duration_ms: Date.now() - startedAt,
    })
  } catch (error) {
    structuredLog("error", "worker_fatal", { workerRunId, error: (error as Error).message })
    await supabase.from("whatsapp_worker_runs").update({
      finished_at: new Date().toISOString(),
      error_message: (error as Error).message, duration_ms: Date.now() - startedAt,
    }).eq("id", workerRunId)
    return jsonResponse({ error: (error as Error)?.message ?? String(error) }, 400)
  }
})
