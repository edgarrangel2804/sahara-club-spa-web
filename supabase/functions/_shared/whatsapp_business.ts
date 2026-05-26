import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

export const DEFAULT_BRANCH_ID = "11111111-1111-1111-1111-111111111111"
export const META_GRAPH_API_VERSION = "v21.0"
export const META_GRAPH_BASE_URL = `https://graph.facebook.com/${META_GRAPH_API_VERSION}`

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

export type AdminClient = ReturnType<typeof createClient>

export type BusinessWhatsAppRow = {
  id: string
  branch_id: string
  business_name: string
  meta_business_id: string
  whatsapp_business_account_id: string
  phone_number_id: string
  whatsapp_phone_number: string
  access_token_encrypted: string
  access_token_masked: string
  app_id: string
  app_secret_encrypted: string
  app_secret_masked: string
  webhook_verify_token: string
  connection_status: string
  last_validated_at: string | null
  created_at: string
  updated_at: string
  environment: string
  is_sandbox: boolean
  webhook_status: string
  webhook_last_event_at: string | null
  webhook_last_verified_at: string | null
  webhook_last_error: string | null
}

export function createAdminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

export async function assertAdminRequest(
  req: Request,
  adminClient: AdminClient,
) {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    throw new Error("Unauthorized")
  }

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    },
  )

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser()

  if (userError || !user) {
    throw new Error("Unauthorized")
  }

  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle()

  if (profileError || profile?.role != "admin") {
    throw new Error("Forbidden")
  }

  return user
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  })
}

function bytesToBase64(bytes: Uint8Array) {
  let binary = ""
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte)
  })
  return btoa(binary)
}

function base64ToBytes(value: string) {
  const binary = atob(value)
  return Uint8Array.from(binary, (char) => char.charCodeAt(0))
}

async function deriveEncryptionKey() {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  if (!secret) {
    throw new Error("Missing service role key")
  }

  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(secret),
  )

  return crypto.subtle.importKey(
    "raw",
    digest,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  )
}

export async function encryptSecret(value: string) {
  if (!value) return ""
  const key = await deriveEncryptionKey()
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(value),
  )

  return `${bytesToBase64(iv)}:${bytesToBase64(new Uint8Array(encrypted))}`
}

export async function decryptSecret(value: string) {
  if (!value) return ""
  const [ivBase64, cipherBase64] = value.split(":")
  if (!ivBase64 || !cipherBase64) return ""

  const key = await deriveEncryptionKey()
  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: base64ToBytes(ivBase64) },
    key,
    base64ToBytes(cipherBase64),
  )

  return new TextDecoder().decode(decrypted)
}

export function maskSecret(value: string, keep = 4) {
  if (!value) return ""
  const tail = value.length <= keep ? value : value.slice(-keep)
  return `••••${tail}`
}

/**
 * Normaliza teléfonos para WhatsApp Cloud API.
 *
 * REGLA MX (default): los celulares mexicanos requieren el prefijo "521"
 * (52 = país + 1 = móvil). Si solo va "52" sin "1", Meta devuelve `accepted`
 * pero algunos mensajes nunca se entregan (sin status callback).
 *
 * - 10 dígitos        → 521 + número  (asume MX celular)
 * - 12 dígitos 52...  → 521 + últimos 10 (corrige falta del "1")
 * - 13 dígitos 521... → tal cual
 * - 11 dígitos 1...   → US/Canadá, tal cual (no agrega 52)
 * - cualquier otro    → tal cual
 */
export function normalizePhone(phone: string) {
  const clean = (phone || "").replace(/\D/g, "")
  if (clean.length === 0) return clean
  if (clean.length === 13 && clean.startsWith("521")) return clean
  if (clean.length === 12 && clean.startsWith("52")) return `521${clean.slice(2)}`
  if (clean.length === 10) return `521${clean}`
  if (clean.length === 11 && clean.startsWith("1")) return clean
  return clean
}

export function getConnectionStatusForDraft(input: {
  phone_number_id?: string
  whatsapp_business_account_id?: string
  whatsapp_phone_number?: string
  access_token_present?: boolean
}) {
  const hasAnyValue = Boolean(
    input.phone_number_id || input.whatsapp_business_account_id ||
      input.whatsapp_phone_number || input.access_token_present,
  )
  const hasRequired = Boolean(
    input.phone_number_id && input.whatsapp_business_account_id &&
      input.whatsapp_phone_number && input.access_token_present,
  )

  if (hasRequired) return "pending"
  if (hasAnyValue) return "pending"
  return "not_configured"
}

export function sanitizeSettings(row: BusinessWhatsAppRow | null) {
  if (!row) {
    return {
      id: null,
      branch_id: DEFAULT_BRANCH_ID,
      business_name: "",
      meta_business_id: "",
      whatsapp_business_account_id: "",
      phone_number_id: "",
      whatsapp_phone_number: "",
      access_token_masked: "",
      app_id: "",
      app_secret_masked: "",
      webhook_verify_token: "",
      connection_status: "not_configured",
      last_validated_at: null,
      created_at: null,
      updated_at: null,
      has_access_token: false,
      has_app_secret: false,
      environment: "sandbox",
      is_sandbox: true,
      webhook_status: "not_verified",
      webhook_last_event_at: null,
      webhook_last_verified_at: null,
      webhook_last_error: null,
      graph_api_version: META_GRAPH_API_VERSION,
    }
  }

  return {
    id: row.id,
    branch_id: row.branch_id,
    business_name: row.business_name,
    meta_business_id: row.meta_business_id,
    whatsapp_business_account_id: row.whatsapp_business_account_id,
    phone_number_id: row.phone_number_id,
    whatsapp_phone_number: row.whatsapp_phone_number,
    access_token_masked: row.access_token_masked,
    app_id: row.app_id,
    app_secret_masked: row.app_secret_masked,
    webhook_verify_token: row.webhook_verify_token,
    connection_status: row.connection_status,
    last_validated_at: row.last_validated_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
    has_access_token: Boolean(row.access_token_encrypted),
    has_app_secret: Boolean(row.app_secret_encrypted),
    environment: row.environment ?? "sandbox",
    is_sandbox: row.is_sandbox ?? true,
    webhook_status: row.webhook_status ?? "not_verified",
    webhook_last_event_at: row.webhook_last_event_at ?? null,
    webhook_last_verified_at: row.webhook_last_verified_at ?? null,
    webhook_last_error: row.webhook_last_error ?? null,
    graph_api_version: META_GRAPH_API_VERSION,
  }
}

export async function getBusinessSettingsRow(
  supabase: AdminClient,
  branchId = DEFAULT_BRANCH_ID,
) {
  const { data, error } = await supabase
    .from("business_whatsapp_settings")
    .select("*")
    .eq("branch_id", branchId)
    .maybeSingle()

  if (error) throw error
  return (data ?? null) as BusinessWhatsAppRow | null
}

export async function loadBusinessSettings(
  supabase: AdminClient,
  branchId = DEFAULT_BRANCH_ID,
) {
  const row = await getBusinessSettingsRow(supabase, branchId)
  if (!row) return null

  return {
    row,
    accessToken: await decryptSecret(row.access_token_encrypted),
    appSecret: await decryptSecret(row.app_secret_encrypted),
  }
}

export async function syncLegacyConfig(
  supabase: AdminClient,
  input: {
    whatsappEnabled: boolean
    phoneNumberId: string
    businessId: string
    metaBusinessId: string
  },
) {
  const payload = {
    whatsapp_enabled: input.whatsappEnabled,
    whatsapp_phone_number_id: input.phoneNumberId,
    whatsapp_business_id: input.businessId,
    whatsapp_phone_id: input.metaBusinessId,
    updated_at: new Date().toISOString(),
  }

  const { data, error } = await supabase
    .from("configuracion_sistema")
    .select("id")
    .limit(1)
    .maybeSingle()

  if (error) throw error

  if (!data?.id) {
    const { error: insertError } = await supabase
      .from("configuracion_sistema")
      .insert(payload)
    if (insertError) throw insertError
    return
  }

  const { error: updateError } = await supabase
    .from("configuracion_sistema")
    .update(payload)
    .eq("id", data.id)

  if (updateError) throw updateError
}

export async function callMetaApi<T>(
  path: string,
  accessToken: string,
  init?: RequestInit,
) {
  const response = await fetch(`${META_GRAPH_BASE_URL}/${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  })

  const data = await response.json().catch(() => ({})) as T
  return { ok: response.ok, status: response.status, data }
}

export async function verifyMetaConnection(
  accessToken: string,
  phoneNumberId: string,
  wabaId: string,
) {
  const phone = await callMetaApi<Record<string, unknown>>(
    `${phoneNumberId}?fields=id,verified_name,display_phone_number,quality_rating`,
    accessToken,
  )

  if (!phone.ok) return phone

  const business = await callMetaApi<Record<string, unknown>>(
    `${wabaId}?fields=id,name,message_template_namespace`,
    accessToken,
  )

  if (!business.ok) return business

  return {
    ok: true,
    status: 200,
    data: {
      phone: phone.data,
      business: business.data,
    },
  }
}

export async function sendMetaTextMessage(
  accessToken: string,
  phoneNumberId: string,
  phone: string,
  message: string,
) {
  return callMetaApi<Record<string, unknown>>(
    `${phoneNumberId}/messages`,
    accessToken,
    {
      method: "POST",
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: normalizePhone(phone),
        type: "text",
        text: {
          preview_url: true,
          body: message,
        },
      }),
    },
  )
}

export function renderTemplate(body: string, vars: Record<string, unknown>) {
  let result = body || ""
  for (const [key, raw] of Object.entries(vars)) {
    result = result.replaceAll(`[[${key}]]`, String(raw ?? ""))
  }
  return result
}
