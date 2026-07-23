import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const DEFAULT_PUBLIC_ORIGIN = "https://saharaclubspa.com"
const DEFAULT_ALLOWED_ORIGINS = [
  DEFAULT_PUBLIC_ORIGIN,
  "https://www.saharaclubspa.com",
]
const DEFAULT_ALLOWED_HEADERS =
  "authorization, x-client-info, apikey, content-type, stripe-signature, x-internal-secret"

type CorsOptions = {
  methods?: string
  allowedHeaders?: string
  cacheControl?: string
}

type RateLimitOptions = {
  windowMs: number
  maxAttempts: number
  nowMs?: number
}

type RateLimitBucket = {
  count: number
  resetAt: number
}

type AuthorizeOptions = {
  supabaseUrl?: string
  serviceRoleKey?: string
  internalSecret?: string | null
  allowedRoles?: string[]
}

export type AuthorizationResult =
  | { ok: true; mode: "service_role" | "internal_secret" | "user_role"; role?: string }
  | { ok: false; status: number; error: string }

export const OPERATIONAL_ROLES = [
  "admin",
  "super_admin",
  "owner",
  "manager",
  "reception",
  "receptionist",
  "staff",
  "sales",
]

const rateLimitBuckets = new Map<string, RateLimitBucket>()

export function allowedOriginsFromEnv(): string[] {
  const extra = (Deno.env.get("SAHARA_ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean)
  return [...DEFAULT_ALLOWED_ORIGINS, ...extra]
}

export function isAllowedOrigin(origin: string | null, allowedOrigins = allowedOriginsFromEnv()) {
  if (!origin) return true
  let parsed: URL
  try {
    parsed = new URL(origin)
  } catch {
    return false
  }

  const isLocalhost = parsed.hostname === "localhost" || parsed.hostname === "127.0.0.1"
  if (isLocalhost && (parsed.protocol === "http:" || parsed.protocol === "https:")) {
    return true
  }

  return allowedOrigins.includes(parsed.origin)
}

export function corsHeadersFor(req: Request, options: CorsOptions = {}) {
  const origin = req.headers.get("origin")
  const allowOrigin = isAllowedOrigin(origin) && origin ? origin : DEFAULT_PUBLIC_ORIGIN
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": options.allowedHeaders ?? DEFAULT_ALLOWED_HEADERS,
    "Access-Control-Allow-Methods": options.methods ?? "GET, POST, OPTIONS",
    "Cache-Control": options.cacheControl ?? "no-store",
    "Vary": "Origin",
  }
}

export function preflightResponse(req: Request, options: CorsOptions = {}) {
  return new Response("ok", { headers: corsHeadersFor(req, options) })
}

export function jsonResponseFor(
  req: Request,
  body: unknown,
  status = 200,
  options: CorsOptions = {},
) {
  return new Response(JSON.stringify(body), {
    headers: {
      ...corsHeadersFor(req, options),
      "Content-Type": "application/json",
    },
    status,
  })
}

export function clientIpKey(req: Request): string {
  const raw = String(
    req.headers.get("x-forwarded-for") ??
      req.headers.get("cf-connecting-ip") ??
      req.headers.get("x-real-ip") ??
      "local",
  )
  const first = raw.split(",")[0]?.trim() || "local"
  return first.replace(/[^a-zA-Z0-9:._-]/g, "").slice(0, 64) || "unknown"
}

export function checkRateLimit(key: string, options: RateLimitOptions) {
  const now = options.nowMs ?? Date.now()
  const bucketKey = String(key || "unknown").slice(0, 180)
  const current = rateLimitBuckets.get(bucketKey)
  if (!current || current.resetAt <= now) {
    rateLimitBuckets.set(bucketKey, { count: 1, resetAt: now + options.windowMs })
    return { ok: true as const }
  }
  current.count += 1
  if (current.count > options.maxAttempts) {
    return {
      ok: false as const,
      error: "rate_limited",
      status: 429,
      resetAt: current.resetAt,
    }
  }
  return { ok: true as const }
}

export function resetSecurityRateLimitsForTests() {
  rateLimitBuckets.clear()
}

export async function fingerprintValue(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(String(value ?? "")),
  )
  const hex = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
  return `sha256:${hex.slice(0, 24)}`
}

export function constantTimeEqual(
  left: string | null | undefined,
  right: string | null | undefined,
) {
  const a = String(left ?? "")
  const b = String(right ?? "")
  if (!a || !b || a.length !== b.length) return false
  let mismatch = 0
  for (let index = 0; index < a.length; index += 1) {
    mismatch |= a.charCodeAt(index) ^ b.charCodeAt(index)
  }
  return mismatch === 0
}

export function bearerToken(req: Request): string {
  const header = req.headers.get("authorization") ?? ""
  const match = header.match(/^Bearer\s+(.+)$/i)
  return match?.[1]?.trim() ?? ""
}

export function isServiceRoleRequest(req: Request, serviceRoleKey?: string | null): boolean {
  const expected = serviceRoleKey ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  return constantTimeEqual(bearerToken(req), expected)
}

export async function authorizeInternalRequest(
  req: Request,
  options: AuthorizeOptions = {},
): Promise<AuthorizationResult> {
  const supabaseUrl = options.supabaseUrl ?? Deno.env.get("SUPABASE_URL") ?? ""
  const serviceRoleKey = options.serviceRoleKey ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const internalSecret = options.internalSecret ?? Deno.env.get("SAHARA_INTERNAL_FUNCTION_SECRET")

  if (!supabaseUrl || !serviceRoleKey) {
    return { ok: false, status: 500, error: "server_auth_not_configured" }
  }
  if (isServiceRoleRequest(req, serviceRoleKey)) {
    return { ok: true, mode: "service_role" }
  }

  const suppliedSecret = req.headers.get("x-internal-secret")
  if (internalSecret && constantTimeEqual(suppliedSecret, internalSecret)) {
    return { ok: true, mode: "internal_secret" }
  }

  const allowedRoles = options.allowedRoles ?? []
  if (allowedRoles.length === 0) {
    return { ok: false, status: 401, error: "not_authorized" }
  }

  const token = bearerToken(req)
  if (!token) return { ok: false, status: 401, error: "not_authorized" }

  try {
    const supabase = createClient(supabaseUrl, serviceRoleKey)
    const { data: authData, error: userError } = await supabase.auth.getUser(token)
    const userId = authData?.user?.id
    if (userError || !userId) {
      return { ok: false, status: 401, error: "not_authorized" }
    }

    const [{ data: profile }, { data: staff }] = await Promise.all([
      supabase.from("profiles").select("role").eq("id", userId).maybeSingle(),
      supabase.from("staff").select("role, active").eq("auth_user_id", userId).maybeSingle(),
    ])

    const roles = [
      String((profile as { role?: string } | null)?.role ?? ""),
      ((staff as { active?: boolean; role?: string } | null)?.active === false)
        ? ""
        : String((staff as { role?: string } | null)?.role ?? ""),
    ].filter(Boolean)

    const allowed = roles.find((role) => allowedRoles.includes(role))
    if (!allowed) return { ok: false, status: 403, error: "not_authorized" }
    return { ok: true, mode: "user_role", role: allowed }
  } catch {
    return { ok: false, status: 401, error: "not_authorized" }
  }
}

export function sanitizeTechnicalLog(value: unknown): string {
  return String(value ?? "")
    .replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "[email]")
    .replace(/\b\+?\d[\d\s().-]{7,}\d\b/g, "[phone]")
    .replace(/[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}(?:\.[A-Za-z0-9_-]{20,})?/g, "[token]")
    .replace(
      /\b(authorization|access_token|token|secret|api[_-]?key|apikey)\s*[:=]\s*[^,\s}]+/gi,
      "$1=[redacted]",
    )
    .slice(0, 500)
}
