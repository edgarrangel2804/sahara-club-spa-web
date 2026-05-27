// Sahara Club Spa - create_booking_deposit_checkout
// ---------------------------------------------------------------------------
// Crea (o reutiliza) una sesión de Stripe Checkout para el anticipo de $200 MXN
// de una cita creada por la IA. Idempotente: si el booking ya tiene una sesión
// activa, devuelve la misma URL.
//
// Body: { booking_id: uuid, amount?: number, currency?: string }
// Response 200: { ok: true, checkout_url, stripe_session_id, reused: bool }
//
// Llamado por: whatsapp-ai-router después de crear booking pending_payment.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import {
  corsHeaders,
  createAdminClient,
  jsonResponse,
  stripeApiRequest,
  toMinorUnits,
} from "../_shared/stripe_checkout.ts"

const DEFAULT_AMOUNT_MXN = 200
const DEFAULT_CURRENCY = "mxn"
const SUCCESS_URL = "https://saharaclubspa.com/anticipo-ok"
const CANCEL_URL = "https://saharaclubspa.com/anticipo-cancelado"

type StripeSession = {
  id: string
  url: string
  payment_intent?: string | null
  status?: string  // open, complete, expired
  payment_status?: string  // unpaid, paid
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
    const amount = Number(body.amount ?? DEFAULT_AMOUNT_MXN)
    const currency = String(body.currency ?? DEFAULT_CURRENCY).toLowerCase()

    const supabase = createAdminClient()

    // 1. Cargar booking y validar que esté en pending_payment
    const { data: booking, error: bErr } = await supabase
      .from("bookings")
      .select("id, status, stripe_session_id, checkout_url, deposit_amount, " +
        "booking_date, booking_time, service_id, client_record_id")
      .eq("id", bookingId)
      .maybeSingle()
    if (bErr) throw bErr
    if (!booking) return jsonResponse({ ok: false, error: "booking_not_found" }, 404)
    if (booking.status !== "pending_payment") {
      return jsonResponse({
        ok: false,
        error: "booking_not_in_pending_payment",
        current_status: booking.status,
      }, 400)
    }

    // 2. Si ya tiene session_id, verificar en Stripe si sigue activa (open + unpaid)
    if (booking.stripe_session_id) {
      try {
        const existing = await stripeApiRequest<StripeSession>(
          `/checkout/sessions/${booking.stripe_session_id}`,
          { method: "GET" },
        )
        if (existing.status === "open" && existing.payment_status === "unpaid") {
          return jsonResponse({
            ok: true,
            reused: true,
            checkout_url: existing.url ?? booking.checkout_url,
            stripe_session_id: existing.id,
            amount: booking.deposit_amount ?? amount,
          })
        }
        // Si está expirada o ya pagada, seguimos al flujo de crear nueva.
      } catch (e) {
        console.warn("stripe session lookup failed:", (e as Error).message)
        // Seguimos al flujo de crear nueva.
      }
    }

    // 3. Cargar datos para metadata + descripción
    const { data: service } = await supabase
      .from("services")
      .select("name")
      .eq("id", booking.service_id)
      .maybeSingle()
    const { data: client } = await supabase
      .from("clients")
      .select("full_name, phone")
      .eq("id", booking.client_record_id)
      .maybeSingle()

    const serviceName = (service as { name?: string } | null)?.name ?? "Servicio Sahara"
    const customerName = (client as { full_name?: string } | null)?.full_name ?? "Cliente Sahara"
    const customerPhone = (client as { phone?: string } | null)?.phone ?? ""

    // 4. Crear nueva sesión Stripe
    const description = `Anticipo cita: ${serviceName} · ${booking.booking_date} ${booking.booking_time}`
    const form: Record<string, string> = {
      mode: "payment",
      success_url: SUCCESS_URL,
      cancel_url: CANCEL_URL,
      "metadata[booking_id]": bookingId,
      "metadata[payment_type]": "appointment_deposit",
      "metadata[source]": "whatsapp_ai",
      "metadata[customer_phone]": customerPhone,
      "client_reference_id": bookingId,
      "payment_intent_data[metadata][booking_id]": bookingId,
      "payment_intent_data[metadata][payment_type]": "appointment_deposit",
      "line_items[0][price_data][currency]": currency,
      "line_items[0][price_data][unit_amount]": String(toMinorUnits(amount)),
      "line_items[0][price_data][product_data][name]": "Anticipo de cita Sahara Club Spa",
      "line_items[0][price_data][product_data][description]": description.slice(0, 240),
      "line_items[0][quantity]": "1",
    }

    const session = await stripeApiRequest<StripeSession>("/checkout/sessions", {
      method: "POST",
      form,
    })

    // 5. Persistir en booking
    const { error: updErr } = await supabase
      .from("bookings")
      .update({
        stripe_session_id: session.id,
        checkout_url: session.url,
        deposit_amount: amount,
        payment_status: "pending",
      })
      .eq("id", bookingId)
    if (updErr) throw updErr

    return jsonResponse({
      ok: true,
      reused: false,
      checkout_url: session.url,
      stripe_session_id: session.id,
      amount,
    })
  } catch (e) {
    console.error("create_booking_deposit_checkout error:", (e as Error).message)
    return jsonResponse({ ok: false, error: (e as Error).message }, 500)
  }
})
