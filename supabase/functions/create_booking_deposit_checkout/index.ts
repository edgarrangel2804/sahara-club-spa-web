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
  buildDepositVoucherSuccessUrl,
  createDepositVoucherToken,
  parseVoucherTokenTtl,
  requireVoucherSigningSecret,
} from "../_shared/deposit_receipts.ts"
import { createAdminClient, stripeApiRequest, toMinorUnits } from "../_shared/stripe_checkout.ts"
import {
  checkRateLimit,
  clientIpKey,
  jsonResponseFor,
  preflightResponse,
  sanitizeTechnicalLog,
} from "../_shared/runtime_security.ts"

const DEFAULT_AMOUNT_MXN = 200
const DEFAULT_CURRENCY = "mxn"
// Tras pagar, Stripe redirige al comprobante (voucher) con el id de la sesión.
const DEFAULT_SUCCESS_URL = "https://saharaclubspa.com/comprobante-anticipo.html"
const CANCEL_URL = "https://saharaclubspa.com/anticipo-cancelado"

type StripeSession = {
  id: string
  url: string
  payment_intent?: string | null
  status?: string // open, complete, expired
  payment_status?: string // unpaid, paid
  success_url?: string | null
}

function hasSignedVoucherSuccessUrl(session: StripeSession): boolean {
  return String(session.success_url ?? "").includes("voucher_token=")
}

serve(async (req) => {
  const json = (body: unknown, status = 200) => jsonResponseFor(req, body, status)
  if (req.method === "OPTIONS") return preflightResponse(req)
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405)

  try {
    const rateLimit = checkRateLimit(`booking-deposit-checkout:${clientIpKey(req)}`, {
      maxAttempts: 30,
      windowMs: 10 * 60 * 1000,
    })
    if (!rateLimit.ok) return json({ ok: false, error: rateLimit.error }, rateLimit.status)

    const body = await req.json().catch(() => ({}))
    const bookingId = String(body.booking_id ?? "").trim()
    if (!bookingId) {
      return json({ ok: false, error: "booking_id requerido" }, 400)
    }

    const supabase = createAdminClient()

    // 1. Cargar booking y validar que esté en pending_payment
    const { data: booking, error: bErr } = await supabase
      .from("bookings")
      .select(
        "id, status, stripe_session_id, checkout_url, deposit_amount, deposit_required_cents, " +
          "booking_date, booking_time, service_id, client_record_id",
      )
      .eq("id", bookingId)
      .maybeSingle()
    if (bErr) throw bErr
    if (!booking) return json({ ok: false, error: "booking_not_found" }, 404)
    if (booking.status !== "pending_payment") {
      return json({
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
        if (
          existing.status === "open" &&
          existing.payment_status === "unpaid" &&
          hasSignedVoucherSuccessUrl(existing)
        ) {
          const terms = await resolveDepositTerms(supabase, booking as Record<string, unknown>)
          return json({
            ok: true,
            reused: true,
            checkout_url: existing.url ?? booking.checkout_url,
            stripe_session_id: existing.id,
            amount: terms.amount,
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
    const customerPhone = (client as { phone?: string } | null)?.phone ?? ""
    const paymentTerms = await resolveDepositTerms(supabase, booking as Record<string, unknown>)
    const amount = paymentTerms.amount
    const currency = paymentTerms.currency

    // 4. Crear nueva sesión Stripe
    const description =
      `Anticipo cita: ${serviceName} · ${booking.booking_date} ${booking.booking_time}`
    const voucherSecret = requireVoucherSigningSecret(
      Deno.env.get("DEPOSIT_VOUCHER_SIGNING_SECRET"),
    )
    const voucherTtlSeconds = parseVoucherTokenTtl(
      Deno.env.get("DEPOSIT_VOUCHER_TOKEN_TTL_SECONDS"),
    )
    const { token: voucherToken } = await createDepositVoucherToken({
      bookingId,
      secret: voucherSecret,
      ttlSeconds: voucherTtlSeconds,
    })
    const successUrl = buildDepositVoucherSuccessUrl({
      baseUrl: Deno.env.get("DEPOSIT_VOUCHER_SUCCESS_BASE_URL") ?? DEFAULT_SUCCESS_URL,
      voucherToken,
    })

    const form: Record<string, string> = {
      mode: "payment",
      success_url: successUrl,
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

    return json({
      ok: true,
      reused: false,
      checkout_url: session.url,
      stripe_session_id: session.id,
      amount,
    })
  } catch (e) {
    console.error("create_booking_deposit_checkout error:", sanitizeTechnicalLog(e))
    return json({ ok: false, error: "checkout_unavailable" }, 500)
  }
})

async function resolveDepositTerms(
  supabase: ReturnType<typeof createAdminClient>,
  booking: Record<string, unknown>,
): Promise<{ amount: number; currency: string }> {
  const { data: settings } = await supabase
    .from("ai_settings")
    .select("appointment_deposit_amount, appointment_deposit_currency")
    .eq("id", 1)
    .maybeSingle()

  const fallbackAmount = Number(
    (settings as { appointment_deposit_amount?: number } | null)?.appointment_deposit_amount ??
      DEFAULT_AMOUNT_MXN,
  )
  const amountFromRequiredCents = Number(booking.deposit_required_cents ?? 0) / 100
  const amountFromBooking = Number(booking.deposit_amount ?? 0)
  const amount = amountFromRequiredCents > 0
    ? amountFromRequiredCents
    : amountFromBooking > 0
    ? amountFromBooking
    : fallbackAmount
  const currency = String(
    (settings as { appointment_deposit_currency?: string } | null)?.appointment_deposit_currency ??
      DEFAULT_CURRENCY,
  ).toLowerCase()

  return {
    amount: Number.isFinite(amount) && amount > 0 ? amount : DEFAULT_AMOUNT_MXN,
    currency: currency || DEFAULT_CURRENCY,
  }
}
