// Sahara Club Spa - create_appointment_deposit_payment_intent
// ---------------------------------------------------------------------------
// Crea (o reutiliza) un Stripe PaymentIntent para el anticipo de cita.
// Diseñado para usar con Stripe Payment Element embebido en
// saharaclubspa.com/pagar-anticipo/{booking_id} — no abre Stripe Checkout.
//
// Body: { booking_id: uuid }
// Response 200: {
//   ok, client_secret, payment_intent_id, amount, currency,
//   publishable_key, booking: { customer_name, service_name, date, time }
// }
//
// verify_jwt=false en config.toml porque lo llama el browser sin auth.
// Validación interna: booking debe existir y estar en pending_payment.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import {
  corsHeaders,
  createAdminClient,
  jsonResponse,
  stripeApiRequest,
  toMinorUnits,
} from "../_shared/stripe_checkout.ts"

type StripePaymentIntent = {
  id: string
  client_secret: string
  status: string
  // requires_payment_method | requires_confirmation | requires_action |
  // processing | requires_capture | canceled | succeeded
  amount: number
  currency: string
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return jsonResponse({ error: "method not allowed" }, 405)

  try {
    const body = await req.json().catch(() => ({}))
    const bookingId = String(body.booking_id ?? "").trim()
    if (!bookingId) {
      return jsonResponse({ ok: false, error: "booking_id requerido" }, 400)
    }

    const supabase = createAdminClient()

    // 1. Cargar booking + validar
    const { data: booking, error: bErr } = await supabase
      .from("bookings")
      .select("id, status, stripe_payment_intent_id, deposit_amount, " +
        "booking_date, booking_time, service_id, client_record_id")
      .eq("id", bookingId)
      .maybeSingle()
    if (bErr) throw bErr
    if (!booking) {
      return jsonResponse({ ok: false, error: "booking_not_found" }, 404)
    }
    if (booking.status === "payment_received" || booking.status === "confirmed") {
      return jsonResponse({
        ok: false,
        error: "already_paid",
        status: booking.status,
      }, 400)
    }
    if (booking.status !== "pending_payment") {
      return jsonResponse({
        ok: false,
        error: "booking_not_in_pending_payment",
        current_status: booking.status,
      }, 400)
    }

    // 2. Cargar ai_settings (monto/currency/price_id) y stripe_settings (publishable)
    const { data: aiSettings } = await supabase
      .from("ai_settings")
      .select("appointment_deposit_amount, appointment_deposit_currency, " +
        "appointment_deposit_enabled, appointment_deposit_product_id, " +
        "appointment_deposit_price_id")
      .eq("id", 1)
      .maybeSingle()
    const settings = (aiSettings ?? {}) as {
      appointment_deposit_enabled?: boolean
      appointment_deposit_amount?: number
      appointment_deposit_currency?: string
      appointment_deposit_product_id?: string
      appointment_deposit_price_id?: string
    }
    const enabled = settings.appointment_deposit_enabled !== false
    if (!enabled) {
      return jsonResponse({ ok: false, error: "deposit_disabled" }, 400)
    }
    const priceId = settings.appointment_deposit_price_id ?? ""
    const productId = settings.appointment_deposit_product_id ?? ""

    // Si hay un Stripe Price configurado, ese es la única fuente de verdad
    // del monto y la moneda. Si no, caemos al monto local.
    let amount = booking.deposit_amount ?? settings.appointment_deposit_amount ?? 200
    let currency = String(settings.appointment_deposit_currency ?? "mxn").toLowerCase()
    if (priceId) {
      try {
        const price = await stripeApiRequest<{
          id: string; unit_amount: number; currency: string; active: boolean;
          product: string;
        }>(`/prices/${priceId}`, { method: "GET" })
        if (price.active && typeof price.unit_amount === "number") {
          amount = price.unit_amount / 100
          currency = String(price.currency).toLowerCase()
        }
      } catch (e) {
        console.warn("price fetch failed, using local amount:", (e as Error).message)
      }
    }

    const { data: stripeRow } = await supabase
      .from("stripe_settings")
      .select("publishable_key")
      .eq("is_active", true)
      .maybeSingle()
    const publishableKey = (stripeRow as { publishable_key?: string } | null)?.publishable_key ?? ""

    // 3. Si ya hay un PaymentIntent en booking, intentar reutilizar
    let pi: StripePaymentIntent | null = null
    if (booking.stripe_payment_intent_id) {
      try {
        const existing = await stripeApiRequest<StripePaymentIntent>(
          `/payment_intents/${booking.stripe_payment_intent_id}`,
          { method: "GET" },
        )
        const reusable = ["requires_payment_method","requires_confirmation","requires_action","processing"]
          .includes(existing.status)
        if (reusable) {
          pi = existing
        }
      } catch (e) {
        console.warn("PI lookup failed:", (e as Error).message)
      }
    }

    // 4. Si no había o no es reutilizable, crear nuevo PaymentIntent
    if (!pi) {
      const { data: client } = await supabase
        .from("clients")
        .select("phone, full_name")
        .eq("id", booking.client_record_id)
        .maybeSingle()
      const phone = (client as { phone?: string } | null)?.phone ?? ""

      const form: Record<string, string> = {
        amount: String(toMinorUnits(Number(amount))),
        currency: currency,
        "automatic_payment_methods[enabled]": "true",
        "metadata[booking_id]": bookingId,
        "metadata[payment_type]": "appointment_deposit",
        "metadata[source]": "whatsapp_ai",
        "metadata[customer_phone]": phone,
        description: `Anticipo cita Sahara · ${booking.booking_date} ${booking.booking_time}`,
      }
      // Si tenemos Stripe Price/Product configurado, lo adjuntamos como metadata
      // para reportes y reconciliación (PaymentIntents NO aceptan price_id directo,
      // pero el monto/currency ya vino del Price arriba).
      if (priceId) form["metadata[stripe_price_id]"] = priceId
      if (productId) form["metadata[stripe_product_id]"] = productId
      const created = await stripeApiRequest<StripePaymentIntent>(
        "/payment_intents",
        { method: "POST", form },
      )
      pi = created

      await supabase
        .from("bookings")
        .update({
          stripe_payment_intent_id: pi.id,
          deposit_amount: Number(amount),
          payment_status: "pending",
        })
        .eq("id", bookingId)
    }

    // 5. Cargar resumen para mostrar en HTML
    const { data: svc } = await supabase
      .from("services")
      .select("name")
      .eq("id", booking.service_id)
      .maybeSingle()
    const { data: cli } = await supabase
      .from("clients")
      .select("full_name")
      .eq("id", booking.client_record_id)
      .maybeSingle()

    return jsonResponse({
      ok: true,
      payment_intent_id: pi.id,
      client_secret: pi.client_secret,
      amount: Number(amount),
      currency,
      publishable_key: publishableKey,
      booking: {
        customer_name: (cli as { full_name?: string } | null)?.full_name ?? "Cliente",
        service_name: (svc as { name?: string } | null)?.name ?? "Servicio",
        booking_date: booking.booking_date,
        booking_time: booking.booking_time,
      },
    })
  } catch (e) {
    console.error("create_appointment_deposit_payment_intent error:", (e as Error).message)
    return jsonResponse({ ok: false, error: (e as Error).message }, 500)
  }
})
