import {
  corsHeaders,
  createAdminClient,
  fulfillOrder,
  jsonResponse,
  markOrderAsPaid,
  markOrderWithStatus,
  stripeApiRequest,
} from "../_shared/stripe_checkout.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Metodo no permitido." }, 405)
    }

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
    const paymentIntent = session.payment_intent as Record<string, unknown>? ?? {}
    const paymentIntentId = String(paymentIntent.id ?? session.payment_intent ?? "")

    if (paymentStatus == "paid") {
      await markOrderAsPaid(supabase, {
        orderId: resolvedOrderId,
        stripeSessionId: resolvedSessionId,
        stripePaymentIntentId: paymentIntentId || null,
        paymentPayload: session,
      })
      await fulfillOrder(supabase, resolvedOrderId)
      return jsonResponse({
        order_id: resolvedOrderId,
        status: "paid",
        payment_status: "paid",
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
    console.error("confirm_order_payment", error)
    return jsonResponse({ error: "No se pudo confirmar el pago con Stripe." }, 400)
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
