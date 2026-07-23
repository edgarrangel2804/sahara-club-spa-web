import {
  createAdminClient,
  fulfillOrder,
  markOrderAsPaid,
  markOrderWithStatus,
  stripeApiRequest,
} from "../_shared/stripe_checkout.ts"
import {
  createGiftCardDownloadToken,
  giftCardDownloadSigningSecret,
} from "../_shared/gift_card_fulfillment.ts"
import {
  checkRateLimit,
  clientIpKey,
  jsonResponseFor,
  preflightResponse,
  sanitizeTechnicalLog,
} from "../_shared/runtime_security.ts"

serve(async (req) => {
  const jsonResponse = (body: unknown, status = 200) => jsonResponseFor(req, body, status)
  if (req.method === "OPTIONS") {
    return preflightResponse(req)
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Metodo no permitido." }, 405)
    }

    const rateLimit = checkRateLimit(`confirm-order:${clientIpKey(req)}`, {
      maxAttempts: 40,
      windowMs: 10 * 60 * 1000,
    })
    if (!rateLimit.ok) return jsonResponse({ error: rateLimit.error }, rateLimit.status)

    const body = await req.json().catch(() => ({}))
    const orderId = String(body.order_id ?? "").trim()
    const sessionId = String(body.session_id ?? "").trim()

    if (!orderId && !sessionId) {
      return jsonResponse({ error: "Falta order_id o session_id." }, 400)
    }

    const supabase = createAdminClient()
    let resolvedOrderId = orderId
    let resolvedSessionId = sessionId

    if (!resolvedOrderId && resolvedSessionId) {
      const { data: orderBySession, error } = await supabase
        .from("orders")
        .select("id")
        .eq("stripe_session_id", resolvedSessionId)
        .maybeSingle()
      if (error) throw error
      resolvedOrderId = String(orderBySession?.id ?? "")
    }

    if (!resolvedSessionId && resolvedOrderId) {
      const { data: orderById, error } = await supabase
        .from("orders")
        .select("stripe_session_id")
        .eq("id", resolvedOrderId)
        .single()
      if (error) throw error
      resolvedSessionId = String(orderById.stripe_session_id ?? "")
    }

    if (!resolvedOrderId || !resolvedSessionId) {
      return jsonResponse({ error: "No se encontro la orden de Stripe." }, 404)
    }

    const session = await stripeApiRequest<Record<string, unknown>>(
      `/checkout/sessions/${resolvedSessionId}?expand[]=payment_intent`,
      { method: "GET" },
    )

    const paymentStatus = String(session.payment_status ?? "")
    const paymentIntent = (session.payment_intent as Record<string, unknown> | null | undefined) ??
      {}
    const paymentIntentId = String(paymentIntent.id ?? session.payment_intent ?? "")

    if (paymentStatus == "paid") {
      await markOrderAsPaid(supabase, {
        orderId: resolvedOrderId,
        stripeSessionId: resolvedSessionId,
        stripePaymentIntentId: paymentIntentId || null,
        paymentPayload: session,
      })
      await fulfillOrder(supabase, resolvedOrderId)
      const giftCards = await buildGiftCardDownloadTokens(supabase, resolvedOrderId)
      return jsonResponse({
        order_id: resolvedOrderId,
        status: "paid",
        payment_status: "paid",
        gift_cards: giftCards,
      })
    }

    const normalizedStatus = paymentStatus == "unpaid" ? "pending" : paymentStatus
    await markOrderWithStatus(supabase, resolvedOrderId, normalizedStatus, session)

    return jsonResponse({
      order_id: resolvedOrderId,
      status: normalizedStatus,
      payment_status: paymentStatus,
    })
  } catch (error) {
    console.error("confirm_order_payment", sanitizeTechnicalLog(error))
    return jsonResponse({ error: "No se pudo confirmar el pago con Stripe." }, 400)
  }
})

async function buildGiftCardDownloadTokens(
  supabase: ReturnType<typeof createAdminClient>,
  orderId: string,
) {
  const { data, error } = await supabase
    .from("gift_cards")
    .select(
      "id, order_item_id, recipient_name, service_name, package_name, valid_from, expires_on, " +
        "digital_asset_status, delivery_status, status",
    )
    .eq("order_id", orderId)
  if (error) throw error
  const secret = giftCardDownloadSigningSecret()
  const cards = []
  for (const card of data ?? []) {
    const token = await createGiftCardDownloadToken({
      giftCardId: String(card.id),
      orderItemId: card.order_item_id ? String(card.order_item_id) : null,
      secret,
    })
    cards.push({
      gift_card_id: String(card.id),
      download_token: token.token,
      recipient_name: String(card.recipient_name ?? ""),
      service_name: String(card.service_name ?? card.package_name ?? ""),
      valid_from: String(card.valid_from ?? ""),
      expires_on: String(card.expires_on ?? ""),
      digital_asset_status: String(card.digital_asset_status ?? "pending"),
      delivery_status: String(card.delivery_status ?? "pending"),
      status: String(card.status ?? "active"),
    })
  }
  return cards
}

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
