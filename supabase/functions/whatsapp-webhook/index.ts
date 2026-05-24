// Sahara Club Spa - WhatsApp Cloud API Webhook
// GET  -> Meta challenge verification (hub.mode / hub.challenge / hub.verify_token)
// POST -> Recibe eventos (messages, statuses) firmados con HMAC-SHA256 (App Secret)
//
// Endpoint público:
//   https://<PROJECT>.supabase.co/functions/v1/whatsapp-webhook
//
// Importante: Esta función debe desplegarse con `--no-verify-jwt` porque Meta
// no envía el JWT de Supabase. La autenticación de Meta es vía verify_token (GET)
// y X-Hub-Signature-256 (POST) usando el App Secret.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  corsHeaders,
  DEFAULT_BRANCH_ID,
  decryptSecret,
  getBusinessSettingsRow,
} from "../_shared/whatsapp_business.ts"

type WebhookEventRow = {
  branch_id: string | null
  environment: string
  event_kind: string
  event_subtype: string | null
  message_id: string | null
  phone_number_id: string | null
  waba_id: string | null
  from_phone: string | null
  to_phone: string | null
  signature_valid: boolean
  http_status: number
  raw_payload: unknown
  error_message: string | null
}

function adminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

function textResponse(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
  })
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function toHex(bytes: ArrayBuffer) {
  return Array.from(new Uint8Array(bytes))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
}

// Comparación constante (mitiga timing attacks).
function timingSafeEqualHex(a: string, b: string) {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return diff === 0
}

async function hmacSha256Hex(secret: string, payload: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  )
  return toHex(sig)
}

async function logEvent(
  supabase: ReturnType<typeof createClient>,
  row: WebhookEventRow,
) {
  const { error } = await supabase
    .from("whatsapp_webhook_events")
    .insert(row)
  if (error) console.error("logEvent insert failed", error)
}

async function updateWebhookStatus(
  supabase: ReturnType<typeof createClient>,
  fields: Record<string, unknown>,
) {
  const { error } = await supabase
    .from("business_whatsapp_settings")
    .update(fields)
    .eq("branch_id", DEFAULT_BRANCH_ID)
  if (error) console.error("updateWebhookStatus failed", error)
}

// ---------------------------------------------------------------------------
// GET: Meta challenge verification
// ---------------------------------------------------------------------------
async function handleGet(req: Request) {
  const url = new URL(req.url)
  const mode = url.searchParams.get("hub.mode")
  const token = url.searchParams.get("hub.verify_token")
  const challenge = url.searchParams.get("hub.challenge")

  const supabase = adminClient()
  const settings = await getBusinessSettingsRow(supabase, DEFAULT_BRANCH_ID)

  const expectedToken = (settings?.webhook_verify_token ?? "").trim()
  const environment = (settings as unknown as { environment?: string })?.environment ?? "sandbox"

  if (!expectedToken) {
    await updateWebhookStatus(supabase, {
      webhook_status: "error",
      webhook_last_error: "verify_token no configurado en business_whatsapp_settings",
    })
    return textResponse("verify_token not configured", 500)
  }

  if (mode === "subscribe" && token && challenge && timingSafeEqualHex(token, expectedToken)) {
    await updateWebhookStatus(supabase, {
      webhook_status: "verified",
      webhook_last_verified_at: new Date().toISOString(),
      webhook_last_error: null,
    })
    await logEvent(supabase, {
      branch_id: settings?.branch_id ?? null,
      environment,
      event_kind: "verification",
      event_subtype: "challenge_ok",
      message_id: null,
      phone_number_id: settings?.phone_number_id ?? null,
      waba_id: settings?.whatsapp_business_account_id ?? null,
      from_phone: null,
      to_phone: null,
      signature_valid: true,
      http_status: 200,
      raw_payload: { mode, hasChallenge: true },
      error_message: null,
    })
    // Meta exige devolver el challenge en texto plano, status 200.
    return textResponse(challenge, 200)
  }

  await updateWebhookStatus(supabase, {
    webhook_status: "error",
    webhook_last_error: `verify_token mismatch (mode=${mode ?? "null"})`,
  })
  await logEvent(supabase, {
    branch_id: settings?.branch_id ?? null,
    environment,
    event_kind: "verification",
    event_subtype: "challenge_failed",
    message_id: null,
    phone_number_id: settings?.phone_number_id ?? null,
    waba_id: settings?.whatsapp_business_account_id ?? null,
    from_phone: null,
    to_phone: null,
    signature_valid: false,
    http_status: 403,
    raw_payload: { mode, tokenReceived: Boolean(token) },
    error_message: "verify_token mismatch",
  })
  return textResponse("Forbidden", 403)
}

// ---------------------------------------------------------------------------
// POST: Meta events (messages, statuses)
// ---------------------------------------------------------------------------
async function handlePost(req: Request) {
  const supabase = adminClient()
  const settings = await getBusinessSettingsRow(supabase, DEFAULT_BRANCH_ID)
  const environment =
    (settings as unknown as { environment?: string })?.environment ?? "sandbox"

  const rawBody = await req.text()
  const signatureHeader = req.headers.get("x-hub-signature-256") ?? ""
  const appSecret = settings?.app_secret_encrypted
    ? await decryptSecret(settings.app_secret_encrypted).catch(() => "")
    : ""

  let signatureValid = false
  let signatureError: string | null = null

  if (!appSecret) {
    signatureError = "app_secret no configurado: no se puede validar la firma"
  } else if (!signatureHeader.startsWith("sha256=")) {
    signatureError = "Falta header X-Hub-Signature-256"
  } else {
    const expected = await hmacSha256Hex(appSecret, rawBody)
    const provided = signatureHeader.slice("sha256=".length).trim()
    signatureValid = timingSafeEqualHex(expected, provided)
    if (!signatureValid) signatureError = "Firma inválida"
  }

  let payload: Record<string, unknown> = {}
  try {
    payload = rawBody ? JSON.parse(rawBody) : {}
  } catch (_) {
    payload = { _parse_error: true, raw: rawBody.slice(0, 500) }
  }

  // Si la firma no es válida, registramos y devolvemos 401.
  if (!signatureValid) {
    await logEvent(supabase, {
      branch_id: settings?.branch_id ?? null,
      environment,
      event_kind: "unknown",
      event_subtype: "signature_invalid",
      message_id: null,
      phone_number_id: settings?.phone_number_id ?? null,
      waba_id: settings?.whatsapp_business_account_id ?? null,
      from_phone: null,
      to_phone: null,
      signature_valid: false,
      http_status: 401,
      raw_payload: payload,
      error_message: signatureError,
    })
    await updateWebhookStatus(supabase, {
      webhook_status: "error",
      webhook_last_error: signatureError,
    })
    return jsonResponse({ error: signatureError ?? "Unauthorized" }, 401)
  }

  // Procesar entries de Meta. Estructura típica:
  // { object: "whatsapp_business_account", entry: [{ id, changes: [{ value: { messaging_product, metadata, contacts?, messages?, statuses? } }] }] }
  const entries = Array.isArray((payload as { entry?: unknown }).entry)
    ? ((payload as { entry: unknown[] }).entry as unknown[])
    : []

  let storedCount = 0
  const inserts: WebhookEventRow[] = []

  for (const entry of entries) {
    const wabaId = (entry as { id?: string })?.id ?? null
    const changes = (entry as { changes?: unknown[] })?.changes ?? []
    for (const change of changes) {
      const value = (change as { value?: Record<string, unknown> })?.value ?? {}
      const metadata = (value.metadata ?? {}) as Record<string, unknown>
      const phoneNumberId =
        (metadata.phone_number_id as string | undefined) ?? null
      const displayPhone =
        (metadata.display_phone_number as string | undefined) ?? null

      const statuses = Array.isArray(value.statuses)
        ? (value.statuses as Record<string, unknown>[])
        : []
      const messages = Array.isArray(value.messages)
        ? (value.messages as Record<string, unknown>[])
        : []

      for (const status of statuses) {
        const messageId = (status.id as string | undefined) ?? null
        const statusName = (status.status as string | undefined) ?? null
        const tsRaw = status.timestamp as string | number | undefined
        const ts = tsRaw
          ? new Date(Number(tsRaw) * 1000).toISOString()
          : new Date().toISOString()
        const recipient =
          (status.recipient_id as string | undefined) ?? null
        const errors = status.errors as Array<Record<string, unknown>> | undefined
        const errMsg = errors && errors[0]
          ? JSON.stringify(errors[0])
          : null

        inserts.push({
          branch_id: settings?.branch_id ?? null,
          environment,
          event_kind: "status",
          event_subtype: statusName,
          message_id: messageId,
          phone_number_id: phoneNumberId,
          waba_id: wabaId,
          from_phone: displayPhone,
          to_phone: recipient,
          signature_valid: true,
          http_status: 200,
          raw_payload: status,
          error_message: errMsg,
        })

        if (messageId && statusName) {
          await supabase.rpc("apply_whatsapp_status_event", {
            p_message_id: messageId,
            p_status: statusName,
            p_timestamp: ts,
            p_error: errMsg,
          }).catch((err) => console.error("apply_whatsapp_status_event", err))
        }
      }

      for (const message of messages) {
        const messageId = (message.id as string | undefined) ?? null
        const messageType = (message.type as string | undefined) ?? "unknown"
        const fromPhone = (message.from as string | undefined) ?? null

        inserts.push({
          branch_id: settings?.branch_id ?? null,
          environment,
          event_kind: "message",
          event_subtype: messageType,
          message_id: messageId,
          phone_number_id: phoneNumberId,
          waba_id: wabaId,
          from_phone: fromPhone,
          to_phone: displayPhone,
          signature_valid: true,
          http_status: 200,
          raw_payload: message,
          error_message: null,
        })
      }

      // Si el value no trae ni messages ni statuses guardamos un evento "desconocido"
      // para no perder rastro (cambios de plantilla, account_update, etc.)
      if (statuses.length === 0 && messages.length === 0) {
        inserts.push({
          branch_id: settings?.branch_id ?? null,
          environment,
          event_kind: "unknown",
          event_subtype: (change as { field?: string })?.field ?? null,
          message_id: null,
          phone_number_id: phoneNumberId,
          waba_id: wabaId,
          from_phone: null,
          to_phone: displayPhone,
          signature_valid: true,
          http_status: 200,
          raw_payload: value,
          error_message: null,
        })
      }
    }
  }

  if (inserts.length > 0) {
    const { error } = await supabase
      .from("whatsapp_webhook_events")
      .insert(inserts)
    if (error) {
      console.error("bulk insert webhook events failed", error)
    } else {
      storedCount = inserts.length
    }
  }

  await updateWebhookStatus(supabase, {
    webhook_status: "verified",
    webhook_last_event_at: new Date().toISOString(),
    webhook_last_error: null,
  })

  // Meta exige siempre 200 para no reintentar (salvo error de firma → 401 arriba).
  return jsonResponse({ ok: true, stored: storedCount })
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    if (req.method === "GET") return await handleGet(req)
    if (req.method === "POST") return await handlePost(req)
    return jsonResponse({ error: "Method not allowed" }, 405)
  } catch (error) {
    console.error("whatsapp-webhook fatal", error)
    return jsonResponse(
      { error: (error as Error)?.message ?? "Unhandled error" },
      500,
    )
  }
})
