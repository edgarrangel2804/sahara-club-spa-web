import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  createAdminClient as createStripeAdminClient,
  DEFAULT_BRANCH_ID,
  loadActiveStripeSettings,
} from "./stripe_settings.ts"
import { fulfillGiftCardItem } from "./gift_card_fulfillment.ts"

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, stripe-signature",
}

// The recovered runtime does not ship generated Supabase DB types. Keep this
// client loose so Deno can type-check the Edge Functions without inventing a
// partial schema that would drift from production.
export type AdminClient = any

export type CheckoutItem = {
  product_id: string
  base_product_id?: string | null
  name: string
  description?: string
  short_description?: string
  unit_price: number
  currency?: string
  quantity: number
  product_type: string
  image_url?: string
  duration_minutes?: number | null
  category_key?: string
  category_label?: string
  metadata?: Record<string, unknown>
}

export type CheckoutPricing = {
  subtotal?: number
  member_credit?: number
  service_charge?: number
  total?: number
}

export function createAdminClient(): AdminClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
    status,
  })
}

export function requireEnv(name: string) {
  const value = Deno.env.get(name)
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`)
  }
  return value
}

let _cachedStripeSecretKey: string | null = null
let _cachedStripeWebhookSecret: string | null = null

export async function loadStripeSecretKey() {
  if (_cachedStripeSecretKey) return _cachedStripeSecretKey

  const supabase = createStripeAdminClient()
  const active = await loadActiveStripeSettings(supabase, DEFAULT_BRANCH_ID)
  const value = active?.secretKey || Deno.env.get("STRIPE_SECRET_KEY") || ""
  if (!value) {
    throw new Error("Missing active Stripe secret key")
  }
  _cachedStripeSecretKey = value
  return value
}

export async function loadStripeWebhookSecret() {
  if (_cachedStripeWebhookSecret) return _cachedStripeWebhookSecret

  const supabase = createStripeAdminClient()
  const active = await loadActiveStripeSettings(supabase, DEFAULT_BRANCH_ID)
  const value = active?.webhookSecret || Deno.env.get("STRIPE_WEBHOOK_SECRET") || ""
  if (!value) {
    throw new Error("Missing active Stripe webhook secret")
  }
  _cachedStripeWebhookSecret = value
  return value
}

export function roundCurrency(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

export function toMinorUnits(value: number) {
  return Math.round(roundCurrency(value) * 100)
}

export function normalizeCurrency(value?: string) {
  return String(value ?? "MXN").trim().toLowerCase() || "mxn"
}

export function normalizeType(value?: string) {
  const type = String(value ?? "physical").trim().toLowerCase()
  if (type === "giftcard") return "gift_card"
  return type
}

export function buildPricing(items: CheckoutItem[], pricing?: CheckoutPricing) {
  const subtotal = roundCurrency(
    items.reduce((sum, item) => {
      return sum + roundCurrency(Number(item.unit_price ?? 0) * Number(item.quantity ?? 0))
    }, 0),
  )

  const requestedMemberCredit = Number(pricing?.member_credit ?? subtotal * 0.10)
  const requestedServiceCharge = Number(pricing?.service_charge ?? subtotal * 0.037)
  const memberCredit = roundCurrency(
    Math.max(0, requestedMemberCredit),
  )
  const serviceCharge = roundCurrency(
    Math.max(0, requestedServiceCharge),
  )
  const total = roundCurrency(subtotal - memberCredit + serviceCharge)

  return {
    subtotal,
    memberCredit,
    serviceCharge,
    total,
  }
}

export function encodeForm(data: Record<string, string>) {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(data)) {
    params.append(key, value)
  }
  return params
}

export async function stripeApiRequest<T>(
  path: string,
  init: {
    method?: string
    form?: Record<string, string>
  } = {},
) {
  const secretKey = await loadStripeSecretKey()
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    method: init.method ?? "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      ...(init.form ? { "Content-Type": "application/x-www-form-urlencoded" } : {}),
    },
    body: init.form ? encodeForm(init.form) : undefined,
  })

  const data = await response.json().catch(() => ({})) as T & {
    error?: { message?: string }
  }

  if (!response.ok) {
    throw new Error(data?.error?.message || "Stripe request failed")
  }

  return data
}

export async function verifyStripeSignature(
  payload: string,
  signatureHeader: string | null,
  secret: string,
) {
  if (!signatureHeader) return false

  const fragments = signatureHeader.split(",")
  const timestamp = fragments
    .find((part) => part.startsWith("t="))
    ?.slice(2)
  const signatures = fragments
    .filter((part) => part.startsWith("v1="))
    .map((part) => part.slice(3))

  if (!timestamp || signatures.length == 0) return false

  const signedPayload = `${timestamp}.${payload}`
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  )

  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signedPayload),
  )

  const expected = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")

  return signatures.some((candidate) => timingSafeEqual(expected, candidate))
}

function timingSafeEqual(left: string, right: string) {
  if (left.length !== right.length) return false
  let mismatch = 0
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index)
  }
  return mismatch === 0
}

export function generateGiftCardCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  let code = "SAHARA-"
  const values = crypto.getRandomValues(new Uint8Array(8))
  for (const value of values) {
    code += alphabet[value % alphabet.length]
  }
  return code
}

export async function markOrderAsPaid(
  supabase: AdminClient,
  input: {
    orderId: string
    stripeSessionId?: string | null
    stripePaymentIntentId?: string | null
    paymentPayload?: Record<string, unknown>
  },
) {
  const paidAt = new Date().toISOString()
  const { data: orderRow } = await supabase
    .from("orders")
    .select("metadata")
    .eq("id", input.orderId)
    .maybeSingle()

  const { error: orderError } = await supabase
    .from("orders")
    .update({
      status: "paid",
      stripe_session_id: input.stripeSessionId ?? null,
      stripe_payment_intent_id: input.stripePaymentIntentId ?? null,
      paid_at: paidAt,
      metadata: {
        ...((orderRow?.metadata ?? {}) as Record<string, unknown>),
        payment_confirmed_at: paidAt,
      },
    })
    .eq("id", input.orderId)

  if (orderError) throw orderError

  const { data: payment } = await supabase
    .from("payments")
    .select("id")
    .eq("order_id", input.orderId)
    .eq("provider", "stripe")
    .maybeSingle()

  if (payment?.id) {
    const { error: paymentError } = await supabase
      .from("payments")
      .update({
        status: "paid",
        payment_intent_id: input.stripePaymentIntentId ?? null,
        checkout_session_id: input.stripeSessionId ?? null,
        raw_response: input.paymentPayload ?? {},
      })
      .eq("id", payment.id)
    if (paymentError) throw paymentError
  }
}

export async function markOrderWithStatus(
  supabase: AdminClient,
  orderId: string,
  status: string,
  rawPayload: Record<string, unknown> = {},
) {
  const { data: orderRow } = await supabase
    .from("orders")
    .select("metadata")
    .eq("id", orderId)
    .maybeSingle()

  const { error: orderError } = await supabase
    .from("orders")
    .update({
      status,
      metadata: {
        ...((orderRow?.metadata ?? {}) as Record<string, unknown>),
        stripe_last_status: status,
      },
    })
    .eq("id", orderId)

  if (orderError) throw orderError

  const { error: paymentError } = await supabase
    .from("payments")
    .update({
      status,
      raw_response: rawPayload,
    })
    .eq("order_id", orderId)

  if (paymentError) throw paymentError
}

export async function fulfillOrder(
  supabase: AdminClient,
  orderId: string,
) {
  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select(
      "id, customer_id, customer_name, customer_email, customer_phone, paid_at, created_at, " +
        "total, currency, metadata, stripe_session_id, stripe_payment_intent_id",
    )
    .eq("id", orderId)
    .single()

  if (orderError) throw orderError

  const { data: items, error: itemsError } = await supabase
    .from("order_items")
    .select("*")
    .eq("order_id", orderId)

  if (itemsError) throw itemsError

  let requiresScheduling = false
  let pendingPickup = false

  for (const item of items ?? []) {
    const productType = normalizeType(item.product_type)
    const metadata = (item.metadata ?? {}) as Record<string, unknown>

    if (productType === "digital") {
      const { error } = await supabase
        .from("digital_access")
        .upsert({
          order_id: orderId,
          order_item_id: item.id,
          product_id: item.product_id,
          access_status: "granted",
          access_url: String(metadata.digital_file_url ?? ""),
        }, { onConflict: "order_item_id" })
      if (error) throw error
    }

    if (productType === "membership") {
      const requestedDurationDays = Math.max(
        1,
        Number(metadata.membership_duration_days ?? 90),
      )
      const startsAt = new Date()
      const endsAt = new Date(startsAt)
      endsAt.setDate(endsAt.getDate() + requestedDurationDays)

      const { error } = await supabase
        .from("memberships")
        .upsert({
          order_id: orderId,
          order_item_id: item.id,
          customer_id: order.customer_id,
          membership_name: item.product_name,
          status: "active",
          starts_at: startsAt.toISOString(),
          ends_at: endsAt.toISOString(),
        }, { onConflict: "order_item_id" })
      if (error) throw error
    }

    if (productType === "gift_card") {
      await fulfillGiftCardItem(supabase, {
        orderId,
        order: order as Record<string, unknown>,
        item: item as Record<string, unknown>,
      })
      continue
    }

    if (productType === "service") {
      requiresScheduling = true
    }

    if (productType === "physical") {
      pendingPickup = true
    }
  }

  const orderMetadata = {
    ...((order.metadata ?? {}) as Record<string, unknown>),
    requires_scheduling: requiresScheduling,
    pending_pickup: pendingPickup,
    fulfilled_at: new Date().toISOString(),
  }

  const { error: metadataError } = await supabase
    .from("orders")
    .update({ metadata: orderMetadata })
    .eq("id", orderId)

  if (metadataError) throw metadataError
}
