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

// Si Meta entrega webhook con metadata.payment_type='appointment_deposit',
// rutea al flujo de booking deposit. Si no, sigue el flujo legacy de orders.
async function handleBookingDepositPayment(
  supabase: ReturnType<typeof createAdminClient>,
  bookingId: string,
  event: { type?: string },
  object: Record<string, unknown> & {
    metadata?: Record<string, unknown>
    payment_intent?: string
    amount_total?: number
  },
) {
  // Stripe IDs según el tipo de event:
  // - checkout.session.* → object es la Session; id de PI está en object.payment_intent
  // - payment_intent.* → object ES el PaymentIntent; id está en object.id
  const isPiEvent = typeof event.type === "string" && event.type.startsWith("payment_intent.")
  const stripeSessionId = isPiEvent ? "" : String(object.id ?? "").trim()
  const paymentIntentId = isPiEvent
    ? String(object.id ?? "").trim()
    : String(object.payment_intent ?? "").trim()
  const amountTotal = typeof object.amount_total === "number"
    ? object.amount_total / 100
    : (typeof (object as { amount?: number }).amount === "number"
        ? ((object as { amount?: number }).amount as number) / 100
        : null)

  if (
    event.type === "checkout.session.completed" ||
    event.type === "checkout.session.async_payment_succeeded" ||
    event.type === "payment_intent.succeeded"
  ) {
    // Idempotente: solo movemos a payment_received si seguimos en pending_payment.
    const { data: booking } = await supabase
      .from("bookings")
      .select("id, status, client_record_id, deposit_amount")
      .eq("id", bookingId)
      .maybeSingle()
    if (!booking) {
      console.warn("booking_deposit: booking not found", bookingId)
      return
    }
    if (booking.status === "payment_received" || booking.status === "confirmed") {
      // ya procesado, no duplicar
      return
    }

    const finalAmount = booking.deposit_amount ?? amountTotal ?? 200
    await supabase
      .from("bookings")
      .update({
        status: "payment_received",
        payment_status: "paid",
        deposit_paid_at: new Date().toISOString(),
        stripe_payment_intent_id: paymentIntentId || null,
        deposit_amount: finalAmount,
      })
      .eq("id", bookingId)
      .eq("status", "pending_payment")

    // Registrar en payments. NOTA: payments.client_id tiene FK a profiles(id),
    // NO a clients(id). booking.client_record_id apunta a clients. Por eso lo
    // dejamos null aquí (la relación con cliente queda via booking_id).
    const { error: payErr } = await supabase.from("payments").insert({
      booking_id: bookingId,
      client_id: null,
      provider: "stripe",
      status: "paid",
      amount: finalAmount,
      currency: "MXN",
      payment_intent_id: paymentIntentId || null,
      checkout_session_id: stripeSessionId || null,
      payment_method: "card",
      raw_response: object,
    })
    if (payErr) {
      console.warn("payments insert failed:", payErr.message)
    }

    // Alerta visible en el panel de recepción (tabla reception_alerts).
    // Capa adicional a la notificación WhatsApp de abajo; nunca debe romper el flujo.
    try {
      await supabase.rpc("log_reception_alert", {
        p_event_type: "deposit_paid",
        p_booking_id: bookingId,
        p_message: "Anticipo pagado. Pendiente de confirmar en agenda.",
        p_amount_mxn: finalAmount,
      })
    } catch (e) {
      console.warn("reception alert (deposit_paid) failed:", (e as Error).message)
    }

    // Notificar a backup humanos + admins IA (los 3 números admin + el backup
    // tablet). Dedup interno: la misma persona no recibe 2 mensajes si está
    // en ambas listas.
    try {
      const { data: settings } = await supabase
        .from("ai_settings")
        .select("human_backup_numbers, human_backup_enabled, ai_admin_numbers")
        .eq("id", 1)
        .maybeSingle()
      const enabled = (settings as { human_backup_enabled?: boolean } | null)?.human_backup_enabled === true
      const backups = ((settings as { human_backup_numbers?: string[] } | null)?.human_backup_numbers ?? []) as string[]
      const admins = ((settings as { ai_admin_numbers?: string[] } | null)?.ai_admin_numbers ?? []) as string[]
      // Dedup por últimos 10 dígitos
      const seen = new Set<string>()
      const targets: string[] = []
      for (const list of [backups, admins]) {
        for (const n of list) {
          const tail = String(n).replace(/\D/g, "").slice(-10)
          if (tail.length === 10 && !seen.has(tail)) {
            seen.add(tail)
            targets.push(n)
          }
        }
      }
      if (enabled && targets.length > 0) {
        // Cargar detalles
        const { data: full } = await supabase
          .from("bookings")
          .select("id, booking_date, booking_time, " +
            "service:services(name), client:clients(full_name, phone)")
          .eq("id", bookingId)
          .maybeSingle()
        const f = full as {
          booking_date: string; booking_time: string;
          service: { name?: string } | null;
          client: { full_name?: string; phone?: string } | null;
        } | null
        const customerName = f?.client?.full_name ?? "Cliente"
        const phone = f?.client?.phone ?? "(sin teléfono)"
        const svc = f?.service?.name ?? "Servicio"
        const message = [
          "💰 *Pago anticipo recibido*",
          "",
          `*Cliente:* ${customerName}`,
          `*Teléfono:* ${phone}`,
          `*Servicio:* ${svc}`,
          `*Fecha:* ${f?.booking_date}`,
          `*Hora:* ${f?.booking_time}`,
          `*Monto:* $${finalAmount} MXN`,
          "",
          "Pendiente de confirmar en agenda Sahara.",
        ].join("\n")
        // Invocamos send_whatsapp_template_message via función shared… o más
        // simple: usamos Meta API directo. Aquí usamos la URL del webhook send.
        // Solo notificación de texto libre porque backup ya tiene ventana 24h.
        for (const t of targets) {
          try {
            await sendBackupText(String(t), message)
          } catch (e) {
            console.warn("backup notify failed for", t, (e as Error).message)
          }
        }
      }
    } catch (e) {
      console.warn("backup notify error:", (e as Error).message)
    }
  }

  if (event.type === "checkout.session.expired") {
    // No cancelamos el booking; recepción lo verá pending_payment y decidirá.
    await supabase
      .from("bookings")
      .update({ payment_status: "expired" })
      .eq("id", bookingId)
      .eq("status", "pending_payment")
  }

  if (
    event.type === "checkout.session.async_payment_failed" ||
    event.type === "payment_intent.payment_failed"
  ) {
    await supabase
      .from("bookings")
      .update({ payment_status: "failed" })
      .eq("id", bookingId)
      .eq("status", "pending_payment")
  }
}

// Helper interno para mandar texto libre a backup vía Meta API.
async function sendBackupText(phone: string, text: string) {
  const accessToken = Deno.env.get("META_ACCESS_TOKEN")
  const phoneNumberId = Deno.env.get("META_PHONE_NUMBER_ID")
  if (!accessToken || !phoneNumberId) {
    // Caemos a buscar settings de DB si no están en env
    const supabase = createAdminClient()
    const { data } = await supabase
      .from("business_whatsapp_settings")
      .select("access_token, phone_number_id")
      .eq("is_active", true)
      .maybeSingle()
    const t = (data as { access_token?: string; phone_number_id?: string } | null)?.access_token
    const p = (data as { phone_number_id?: string } | null)?.phone_number_id
    if (!t || !p) return
    await fetch(`https://graph.facebook.com/v21.0/${p}/messages`, {
      method: "POST",
      headers: { "content-type": "application/json", Authorization: `Bearer ${t}` },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: phone,
        type: "text",
        text: { body: text },
      }),
    })
    return
  }
  await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
    method: "POST",
    headers: { "content-type": "application/json", Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: phone,
      type: "text",
      text: { body: text },
    }),
  })
}

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

    const supabase = createAdminClient()

    // RUTEO POR payment_type:
    // - 'appointment_deposit' → flujo de booking deposit (NUEVO).
    // - cualquier otro / ausente → flujo legacy de orders (tienda virtual).
    const paymentType = String(object.metadata?.payment_type ?? "").trim()
    if (paymentType === "appointment_deposit") {
      const bookingId = String(
        object.metadata?.booking_id ??
        object.client_reference_id ??
        "",
      ).trim()
      if (!bookingId) {
        console.warn("appointment_deposit webhook without booking_id")
        return jsonResponse({ received: true })
      }
      await handleBookingDepositPayment(supabase, bookingId, event, object)
      return jsonResponse({ received: true, flow: "booking_deposit" })
    }

    // FLUJO LEGACY de orders (tienda virtual, productos físicos/digitales) — sin cambios.
    const orderId = String(
      object.metadata?.order_id ??
      object.client_reference_id ??
      "",
    ).trim()

    if (!orderId) {
      return jsonResponse({ received: true })
    }

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
      // Entrega la(s) gift card(s) al comprador por WhatsApp (best-effort).
      try {
        await deliverGiftCardsWhatsApp(supabase, orderId)
      } catch (e) {
        console.warn("gift card whatsapp delivery failed:", (e as Error).message)
      }
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

    return jsonResponse({ received: true, flow: "order" })
  } catch (error) {
    console.error("stripe_webhook", error)
    return jsonResponse({ error: "No se pudo procesar el webhook de Stripe." }, 400)
  }
})

// Manda la tarjeta de regalo (código + link a la tarjeta con QR) al teléfono del
// comprador por WhatsApp. Best-effort: si el comprador no tiene ventana de 24h
// abierta, Meta puede rechazar el texto libre (futuro: plantilla aprobada).
async function deliverGiftCardsWhatsApp(
  supabase: ReturnType<typeof createAdminClient>,
  orderId: string,
) {
  const { data: order } = await supabase
    .from("orders")
    .select("customer_phone")
    .eq("id", orderId)
    .maybeSingle()
  const phone = (order as { customer_phone?: string } | null)?.customer_phone?.trim()
  if (!phone) return

  const { data: cards } = await supabase
    .from("gift_cards")
    .select("code, service_name, recipient_name, expires_at")
    .eq("order_id", orderId)

  for (
    const c of (cards ?? []) as Array<{
      code?: string; service_name?: string
      recipient_name?: string; expires_at?: string
    }>
  ) {
    if (!c.code) continue
    const link = `https://saharaclubspa.com/tarjeta-regalo?code=${encodeURIComponent(c.code)}`
    const exp = c.expires_at
      ? new Date(c.expires_at).toLocaleDateString("es-MX")
      : ""
    const msg = [
      "🎁 *Tu tarjeta de regalo Sahara Club Spa*",
      "",
      c.service_name ? `*Servicio:* ${c.service_name}` : "",
      c.recipient_name ? `*A nombre de:* ${c.recipient_name}` : "",
      `*Código:* ${c.code}`,
      exp ? `*Vence:* ${exp}` : "",
      "",
      `Ver tu tarjeta con QR: ${link}`,
      "",
      "Preséntala en recepción para agendar tu servicio 🌿",
    ].filter(Boolean).join("\n")
    try {
      await sendBackupText(phone, msg)
    } catch (e) {
      console.warn("gift card send failed:", (e as Error).message)
    }
  }
}

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
