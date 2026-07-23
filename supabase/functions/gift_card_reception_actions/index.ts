// Sahara Club Spa - gift_card_reception_actions
// ---------------------------------------------------------------------------
// Internal reception/admin actions for paid Gift Cards. Requires a valid Supabase
// JWT and an active staff/profile role with operational access.
//
// Body:
// { gift_card_id: uuid, action: "view" | "download_link" | "resend_recipient" | "send_buyer_copy" }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0"
import {
  createGiftCardDownloadToken,
  deliverGiftCardToDestination,
  ensureGiftCardDigitalAsset,
  giftCardDownloadSigningSecret,
  publicGiftCardPayload,
} from "../_shared/gift_card_fulfillment.ts"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? ""
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? ""

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const ALLOWED_ACTIONS = new Set(["view", "download_link", "resend_recipient", "send_buyer_copy"])
const OPERATIONAL_ROLES = new Set(["admin", "owner", "manager", "reception", "receptionist"])

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return json(405, { ok: false, error: "method_not_allowed" })
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
    return json(500, { ok: false, error: "supabase_config_missing" })
  }

  const auth = await assertReceptionCaller(req)
  if (!auth.ok) return json(auth.status, { ok: false, error: auth.error })

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return json(400, { ok: false, error: "invalid_json_body" })
  }

  const giftCardId = String(body.gift_card_id ?? "").trim()
  const action = String(body.action ?? "view").trim()
  if (!UUID_RE.test(giftCardId)) return json(400, { ok: false, error: "invalid_gift_card_id" })
  if (!ALLOWED_ACTIONS.has(action)) return json(400, { ok: false, error: "invalid_action" })

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  try {
    const card = await loadGiftCard(supabase, giftCardId)
    if (!card) return json(404, { ok: false, error: "gift_card_not_found" })

    if (action === "send_buyer_copy" && card.buyer_copy_requested !== true) {
      return json(409, { ok: false, error: "buyer_copy_not_requested" })
    }

    const asset = await ensureGiftCardDigitalAsset(supabase, card)
    const token = await createReceptionDownloadToken(asset.card)

    if (action === "resend_recipient") {
      await deliverGiftCardToDestination(supabase, {
        card: asset.card,
        signedUrl: asset.signedUrl,
        phone: String(asset.card.recipient_phone ?? ""),
        deliveryType: "reception_resend",
      })
    } else if (action === "send_buyer_copy") {
      await deliverGiftCardToDestination(supabase, {
        card: asset.card,
        signedUrl: asset.signedUrl,
        phone: String(asset.card.purchaser_phone ?? ""),
        deliveryType: "buyer_whatsapp_copy",
      })
    }

    const refreshed = action === "view" || action === "download_link"
      ? asset.card
      : await loadGiftCard(supabase, giftCardId) ?? asset.card

    return json(200, {
      ...publicGiftCardPayload({ card: refreshed, signedUrl: asset.signedUrl }),
      action,
      download_token: token,
      reception: receptionSnapshot(refreshed),
    })
  } catch (error) {
    console.warn("gift_card_reception_actions failed:", sanitizeTechnicalError(error))
    return json(500, { ok: false, error: "gift_card_action_failed" })
  }
})

async function assertReceptionCaller(req: Request): Promise<
  | { ok: true; callerId: string; role: string }
  | { ok: false; status: number; error: string }
> {
  const authHeader = req.headers.get("Authorization") || ""
  const token = authHeader.replace(/^Bearer\s+/i, "")
  if (!token) return { ok: false, status: 401, error: "missing_bearer_token" }

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  })
  const { data: userData, error: userError } = await userClient.auth.getUser()
  const user = userData?.user
  if (userError || !user) return { ok: false, status: 401, error: "invalid_token" }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  const staffRole = await loadStaffRole(admin, user.id)
  if (staffRole && OPERATIONAL_ROLES.has(staffRole)) {
    return { ok: true, callerId: user.id, role: staffRole }
  }

  const profileRole = await loadProfileRole(admin, user.id)
  if (profileRole && OPERATIONAL_ROLES.has(profileRole)) {
    return { ok: true, callerId: user.id, role: profileRole }
  }

  return { ok: false, status: 403, error: "caller_not_authorized" }
}

async function loadStaffRole(supabase: any, userId: string): Promise<string | null> {
  const { data, error } = await supabase
    .from("staff")
    .select("role, active")
    .eq("auth_user_id", userId)
    .maybeSingle()
  if (error || !data || data.active === false) return null
  return String(data.role ?? "").trim().toLowerCase() || null
}

async function loadProfileRole(supabase: any, userId: string): Promise<string | null> {
  const { data, error } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle()
  if (error || !data) return null
  return String(data.role ?? "").trim().toLowerCase() || null
}

async function loadGiftCard(
  supabase: any,
  giftCardId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await supabase
    .from("gift_cards")
    .select("*")
    .eq("id", giftCardId)
    .maybeSingle()
  if (error) throw error
  return data ?? null
}

async function createReceptionDownloadToken(card: Record<string, unknown>): Promise<string> {
  const { token } = await createGiftCardDownloadToken({
    giftCardId: String(card.id ?? ""),
    orderItemId: String(card.order_item_id ?? "") || null,
    secret: giftCardDownloadSigningSecret(),
  })
  return token
}

function receptionSnapshot(card: Record<string, unknown>) {
  return {
    gift_card_id: String(card.id ?? ""),
    recipient_phone_masked: maskPhone(String(card.recipient_phone ?? "")),
    purchaser_phone_masked: maskPhone(String(card.purchaser_phone ?? "")),
    purchaser_name: String(card.purchaser_name ?? ""),
    recipient_name: String(card.recipient_name ?? ""),
    service_name: String(card.service_name ?? card.package_name ?? ""),
    valid_from: String(card.valid_from ?? "").slice(0, 10),
    expires_on: String(card.expires_on ?? card.expires_at ?? "").slice(0, 10),
    digital_asset_status: String(card.digital_asset_status ?? "pending"),
    delivery_status: String(card.delivery_status ?? "pending"),
    buyer_copy_requested: card.buyer_copy_requested === true,
    status: String(card.status ?? ""),
  }
}

function maskPhone(value: string): string {
  const digits = value.replace(/\D/g, "")
  if (digits.length <= 4) return digits ? `***${digits}` : ""
  return `***${digits.slice(-4)}`
}

function sanitizeTechnicalError(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error ?? "")
  return message
    .replace(/[A-Za-z0-9_-]{40,1800}\.[A-Za-z0-9_-]{32,220}/g, "[redacted-token]")
    .replace(/\+?\d[\d\s().-]{7,}\d/g, "[redacted-phone]")
    .slice(0, 300)
}
