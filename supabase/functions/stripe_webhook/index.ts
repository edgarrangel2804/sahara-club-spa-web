import {
  corsHeaders,
  createAdminClient,
  fulfillOrder,
  jsonResponse,
  loadStripeWebhookSecret,
  markOrderAsPaid,
  markOrderWithStatus,
  verifyStripeSignature,
} from "../_shared/stripe_checkout.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Metodo no permitido." }, 405)
    }

    const signature = req.headers.get("stripe-signature")
    const payload = await req.text()
    const webhookSecret = await loadStripeWebhookSecret()
    const validSignature = await verifyStripeSignature(payload, signature, webhookSecret)

    if (!validSignature) {
      return jsonResponse({ error: "Firma de Stripe invalida." }, 400)
    }

    const event = JSON.parse(payload) as {
      type?: string
      data?: { object?: Record<string, unknown> }
    }

    const object = (event.data?.object ?? {}) as Record<string, unknown> & {
      metadata?: Record<string, unknown>
      client_reference_id?: string
      payment_intent?: string
    }
    const orderId = String(
      object.metadata?.order_id ??
      object.client_reference_id ??
      "",
    ).trim()

    if (!orderId) {
      return jsonResponse({ received: true })
    }

    const supabase = createAdminClient()
    const stripeSessionId = String(object.id ?? "").trim()
    const paymentIntentId = String(object.payment_intent ?? "").trim()

    if (
      event.type === "checkout.session.completed" ||
      event.type === "checkout.session.async_payment_succeeded" ||
      event.type === "payment_intent.succeeded"
    ) {
      await markOrderAsPaid(supabase, {
        orderId,
        stripeSessionId: stripeSessionId || null,
        stripePaymentIntentId: paymentIntentId || null,
        paymentPayload: object,
      })
      await fulfillOrder(supabase, orderId)
    }

    if (event.type === "checkout.session.expired") {
      await markOrderWithStatus(supabase, orderId, "expired", object)
    }

    if (
      event.type === "checkout.session.async_payment_failed" ||
      event.type === "payment_intent.payment_failed"
    ) {
      await markOrderWithStatus(supabase, orderId, "failed", object)
    }

    return jsonResponse({ received: true })
  } catch (error) {
    console.error("stripe_webhook", error)
    return jsonResponse({ error: "No se pudo procesar el webhook de Stripe." }, 400)
  }
})

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
