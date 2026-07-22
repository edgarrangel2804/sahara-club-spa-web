import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

export const DEFAULT_BRANCH_ID = "11111111-1111-1111-1111-111111111111"

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// The recovered runtime does not ship generated Supabase DB types. Keep this
// client loose so Deno can type-check the Edge Functions without inventing a
// partial schema that would drift from production.
export type AdminClient = any

export type StripeSettingsRow = {
  id: string
  branch_id: string
  environment_mode: "testing" | "production"
  publishable_key: string
  secret_key_encrypted: string
  secret_key_masked: string
  webhook_secret_encrypted: string
  webhook_secret_masked: string
  stripe_account_id: string
  connection_status: string
  last_validated_at: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export function createAdminClient(): AdminClient {
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
  if (!authHeader) throw new Error("Unauthorized")

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

  if (userError || !user) throw new Error("Unauthorized")

  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle()

  if (profileError || !profile || !["admin", "super_admin"].includes(profile.role)) {
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
  if (!secret) throw new Error("Missing service role key")

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

export function sanitizeStripeSettings(row: StripeSettingsRow | null) {
  if (!row) {
    return {
      id: null,
      branch_id: DEFAULT_BRANCH_ID,
      environment_mode: "testing",
      publishable_key: "",
      secret_key_masked: "",
      webhook_secret_masked: "",
      stripe_account_id: "",
      connection_status: "not_configured",
      last_validated_at: null,
      is_active: false,
      created_at: null,
      updated_at: null,
      has_secret_key: false,
      has_webhook_secret: false,
    }
  }

  return {
    id: row.id,
    branch_id: row.branch_id,
    environment_mode: row.environment_mode,
    publishable_key: row.publishable_key,
    secret_key_masked: row.secret_key_masked,
    webhook_secret_masked: row.webhook_secret_masked,
    stripe_account_id: row.stripe_account_id,
    connection_status: row.connection_status,
    last_validated_at: row.last_validated_at,
    is_active: row.is_active,
    created_at: row.created_at,
    updated_at: row.updated_at,
    has_secret_key: Boolean(row.secret_key_encrypted),
    has_webhook_secret: Boolean(row.webhook_secret_encrypted),
  }
}

export async function getStripeSettingsRows(
  supabase: AdminClient,
  branchId = DEFAULT_BRANCH_ID,
) {
  const { data, error } = await supabase
    .from("stripe_settings")
    .select("*")
    .eq("branch_id", branchId)
    .order("environment_mode")

  if (error) throw error
  return (data ?? []) as StripeSettingsRow[]
}

export async function getStripeSettingsRow(
  supabase: AdminClient,
  branchId = DEFAULT_BRANCH_ID,
  environmentMode = "testing",
) {
  const { data, error } = await supabase
    .from("stripe_settings")
    .select("*")
    .eq("branch_id", branchId)
    .eq("environment_mode", environmentMode)
    .maybeSingle()

  if (error) throw error
  return (data ?? null) as StripeSettingsRow | null
}

export async function loadStripeSettings(
  supabase: AdminClient,
  branchId = DEFAULT_BRANCH_ID,
  environmentMode = "testing",
) {
  const row = await getStripeSettingsRow(supabase, branchId, environmentMode)
  if (!row) return null

  return {
    row,
    secretKey: await decryptSecret(row.secret_key_encrypted),
    webhookSecret: await decryptSecret(row.webhook_secret_encrypted),
  }
}

export async function loadActiveStripeSettings(
  supabase: AdminClient,
  branchId = DEFAULT_BRANCH_ID,
) {
  const { data, error } = await supabase
    .from("stripe_settings")
    .select("*")
    .eq("branch_id", branchId)
    .eq("is_active", true)
    .maybeSingle()

  if (error) throw error
  const row = (data ?? null) as StripeSettingsRow | null
  if (!row) return null

  return {
    row,
    secretKey: await decryptSecret(row.secret_key_encrypted),
    webhookSecret: await decryptSecret(row.webhook_secret_encrypted),
  }
}

export async function testStripeSecretKey(secretKey: string) {
  const response = await fetch("https://api.stripe.com/v1/account", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${secretKey}`,
    },
  })

  const data = await response.json().catch(() => ({})) as Record<string, unknown>
  return { ok: response.ok, status: response.status, data }
}
