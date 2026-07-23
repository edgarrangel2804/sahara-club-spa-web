import {
  CheckoutItem,
  createAdminClient,
  normalizeCurrency,
  normalizeType,
  roundCurrency,
  stripeApiRequest,
  toMinorUnits,
} from "../_shared/stripe_checkout.ts"
import {
  computeGiftCardValidity,
  normalizeGiftCardPhone,
  sanitizeDedicationMessage,
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

    const rateLimit = checkRateLimit(`checkout:${clientIpKey(req)}`, {
      maxAttempts: 20,
      windowMs: 10 * 60 * 1000,
    })
    if (!rateLimit.ok) {
      return jsonResponse({ error: "Demasiados intentos. Intenta de nuevo en unos minutos." }, 429)
    }

    const body = await req.json().catch(() => ({})) as Record<string, unknown>
    const customerName = String(body.customer_name ?? "").trim()
    const customerEmail = String(body.customer_email ?? "").trim()
    const customerPhone = String(body.customer_phone ?? "").trim()
    const notes = String(body.notes ?? "").trim()
    const successUrl = String(body.success_url ?? "").trim()
    const cancelUrl = String(body.cancel_url ?? "").trim()
    let items: CheckoutItem[] = Array.isArray(body.items)
      ? body.items.map((item: unknown) => normalizeItem(item as Record<string, unknown>))
      : []

    if (!customerName || !customerEmail || !customerPhone) {
      return jsonResponse({ error: "Faltan datos del cliente." }, 400)
    }

    if (!successUrl || !cancelUrl) {
      return jsonResponse({ error: "Faltan las URLs de retorno de Stripe." }, 400)
    }

    if (!isAllowedCheckoutReturnUrl(successUrl) || !isAllowedCheckoutReturnUrl(cancelUrl)) {
      return jsonResponse({ error: "URL de retorno no autorizada." }, 400)
    }

    if (items.length === 0) {
      return jsonResponse({ error: "El carrito esta vacio." }, 400)
    }

    if (items.some((item) => !item.name || item.quantity <= 0)) {
      return jsonResponse({ error: "Hay productos invalidos en el carrito." }, 400)
    }

    const supabase = createAdminClient()
    items = await validateCheckoutItems(supabase, items)
    const pricing = buildServerPricing(items)
    const checkoutCurrency = items[0]?.currency ?? "mxn"

    const { data: authUser } = await supabase.auth.getUser(
      req.headers.get("Authorization")?.replace("Bearer ", "") ?? "",
    ).catch(() => ({ data: { user: null } }))

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert({
        customer_id: authUser?.user?.id ?? null,
        customer_name: customerName,
        customer_email: customerEmail,
        customer_phone: customerPhone,
        notes,
        status: "pending",
        subtotal: pricing.subtotal,
        member_credit: pricing.memberCredit,
        service_charge: pricing.serviceCharge,
        total: pricing.total,
        currency: checkoutCurrency.toUpperCase(),
        metadata: {
          checkout_origin: req.headers.get("origin"),
          items_count: items.length,
        },
      })
      .select("id")
      .single()

    if (orderError || !order) {
      throw orderError ?? new Error("No se pudo crear la orden.")
    }

    const itemRows = items.map((item) => ({
      order_id: order.id,
      product_id: item.product_id,
      product_name: item.name,
      product_description: item.description ?? item.short_description ?? "",
      image_url: item.image_url ?? "",
      quantity: item.quantity,
      unit_price: roundCurrency(item.unit_price),
      total_price: roundCurrency(item.unit_price * item.quantity),
      currency: (item.currency ?? checkoutCurrency).toUpperCase(),
      product_type: item.product_type,
      category_key: item.category_key ?? "",
      duration_minutes: item.duration_minutes ?? null,
      metadata: {
        ...(item.metadata ?? {}),
        base_product_id: item.base_product_id ?? null,
        short_description: item.short_description ?? "",
        category_label: item.category_label ?? "",
      },
    }))

    const { error: itemsError } = await supabase.from("order_items").insert(itemRows)
    if (itemsError) throw itemsError

    const sessionPayload: Record<string, string> = {
      mode: "payment",
      success_url: successUrl,
      cancel_url: cancelUrl,
      "metadata[order_id]": order.id,
      "metadata[customer_email]": customerEmail,
      "client_reference_id": order.id,
      "customer_email": customerEmail,
      "payment_intent_data[metadata][order_id]": order.id,
      "payment_intent_data[metadata][customer_email]": customerEmail,
      "line_items[0][price_data][currency]": checkoutCurrency,
      "line_items[0][price_data][unit_amount]": String(
        toMinorUnits(pricing.total),
      ),
      "line_items[0][price_data][product_data][name]": "Tienda Sahara Club Spa",
      "line_items[0][price_data][product_data][description]": items
        .map((item) => `${item.name} x${item.quantity}`)
        .join(" | ")
        .slice(0, 240),
      "line_items[0][quantity]": "1",
    }

    const session = await stripeApiRequest<{
      id: string
      url: string
      payment_intent?: string | null
      payment_status?: string
    }>("/checkout/sessions", {
      method: "POST",
      form: sessionPayload,
    })

    const { error: updateOrderError } = await supabase
      .from("orders")
      .update({
        stripe_session_id: session.id,
        stripe_payment_intent_id: session.payment_intent ?? null,
        checkout_url: session.url,
        metadata: {
          stripe_payment_status: session.payment_status ?? "unpaid",
        },
      })
      .eq("id", order.id)

    if (updateOrderError) throw updateOrderError

    const { error: paymentError } = await supabase.from("payments").insert({
      order_id: order.id,
      provider: "stripe",
      status: "pending",
      amount: pricing.total,
      currency: checkoutCurrency.toUpperCase(),
      payment_intent_id: session.payment_intent ?? null,
      checkout_session_id: session.id,
      raw_response: session,
    })

    if (paymentError) throw paymentError

    return jsonResponse({
      order_id: order.id,
      session_id: session.id,
      checkout_url: session.url,
    })
  } catch (error) {
    console.error("create_checkout_session", sanitizeTechnicalLog(error))
    return jsonResponse(
      { error: "No se pudo crear la sesion de Stripe." },
      400,
    )
  }
})

function normalizeItem(raw: Record<string, unknown>): CheckoutItem {
  const requestedQuantity = Math.floor(Number(raw.quantity ?? 1))
  return {
    product_id: String(raw.product_id ?? "").trim(),
    base_product_id: raw.base_product_id ? String(raw.base_product_id).trim() : null,
    name: String(raw.name ?? "").trim(),
    description: String(raw.description ?? "").trim(),
    short_description: String(raw.short_description ?? "").trim(),
    unit_price: Number(raw.unit_price ?? 0),
    currency: normalizeCurrency(String(raw.currency ?? "MXN")),
    quantity: Math.min(10, Math.max(1, Number.isFinite(requestedQuantity) ? requestedQuantity : 1)),
    product_type: normalizeType(String(raw.product_type ?? "physical")),
    image_url: String(raw.image_url ?? "").trim(),
    duration_minutes: raw.duration_minutes ? Number(raw.duration_minutes) : null,
    category_key: String(raw.category_key ?? "").trim(),
    category_label: String(raw.category_label ?? "").trim(),
    metadata: raw.metadata && typeof raw.metadata === "object"
      ? raw.metadata as Record<string, unknown>
      : {},
  }
}

function isAllowedCheckoutReturnUrl(raw: string): boolean {
  if (!raw || raw.length > 2048) return false
  let url: URL
  try {
    url = new URL(raw)
  } catch {
    return false
  }
  if (url.username || url.password) return false
  const host = url.hostname.toLowerCase()
  const isLocalhost = host === "localhost" || host === "127.0.0.1"
  if (isLocalhost) return url.protocol === "http:" || url.protocol === "https:"
  return url.protocol === "https:" &&
    (host === "saharaclubspa.com" || host === "www.saharaclubspa.com")
}

function buildServerPricing(items: CheckoutItem[]) {
  const subtotal = roundCurrency(
    items.reduce(
      (sum, item) => sum + roundCurrency(item.unit_price * item.quantity),
      0,
    ),
  )
  return {
    subtotal,
    memberCredit: 0,
    serviceCharge: 0,
    total: subtotal,
  }
}

async function validateCheckoutItems(
  supabase: ReturnType<typeof createAdminClient>,
  items: CheckoutItem[],
): Promise<CheckoutItem[]> {
  const validated: CheckoutItem[] = []
  for (const item of items) {
    const productType = normalizeType(item.product_type)
    if (productType === "service") {
      validated.push(await validateServiceItem(supabase, item))
      continue
    }

    if (productType !== "gift_card") {
      throw new Error(`unsupported_product_type:${productType}`)
    }

    const metadata = item.metadata ?? {}
    const recipientName = String(metadata.recipient_name ?? "").trim()
    const senderName = String(metadata.sender_name ?? "").trim()
    const recipientPhone = normalizeGiftCardPhone(metadata.recipient_phone)
    const termsAccepted = metadata.terms_accepted === true
    if (!recipientName || !senderName || !recipientPhone) {
      throw new Error("gift_card_required_fields")
    }
    if (!termsAccepted) {
      throw new Error("gift_card_terms_required")
    }

    const validity = computeGiftCardValidity(String(metadata.valid_from ?? ""))
    const serviceId = String(metadata.service_id ?? "").trim()
    if (!serviceId) throw new Error("gift_card_service_required")

    const serviceRow = await loadActivePricedService(supabase, { serviceId })
    const price = Number(serviceRow.price ?? 0)

    const serviceName = String(serviceRow.name ?? item.name).trim() || item.name
    const dedicationMessage = sanitizeDedicationMessage(
      metadata.dedication_message ?? metadata.message ?? "",
    )

    validated.push({
      ...item,
      name: `Gift card - ${serviceName}`,
      description: `Gift card para 1 sesion de ${serviceName}`,
      short_description: String(serviceRow.description ?? item.short_description ?? "").slice(
        0,
        240,
      ),
      unit_price: price,
      quantity: 1,
      product_type: "gift_card",
      category_key: "gift_cards",
      category_label: item.category_label || "Tarjetas de regalo",
      metadata: {
        base_product_id: metadata.base_product_id ?? item.base_product_id ?? null,
        product_type: "gift_card",
        gift_card_kind: "service",
        service_id: serviceId,
        service_name: serviceName,
        sessions_count: Number(serviceRow.sessions_count ?? 1) || 1,
        recipient_name: recipientName,
        recipient_phone: recipientPhone,
        sender_name: senderName,
        dedication_message: dedicationMessage,
        message: dedicationMessage,
        valid_from: validity.validFrom,
        buyer_copy_requested: metadata.buyer_copy_requested === true ||
          metadata.send_copy_to_buyer === true,
        delivery_method: String(metadata.delivery_method ?? "digital"),
        purchase_channel: String(metadata.purchase_channel ?? "web"),
        terms_accepted: true,
      },
    })
  }
  return validated
}

async function validateServiceItem(
  supabase: ReturnType<typeof createAdminClient>,
  item: CheckoutItem,
): Promise<CheckoutItem> {
  const serviceRow = await loadActivePricedService(supabase, {
    serviceId: firstUuid(
      item.product_id,
      item.base_product_id ?? "",
      String(item.metadata?.service_id ?? ""),
      String(item.metadata?.base_product_id ?? ""),
    ),
    serviceName: item.name,
  })
  const serviceName = String(serviceRow.name ?? item.name).trim() || item.name
  const price = Number(serviceRow.price ?? 0)
  const duration = Number(serviceRow.duration_min ?? serviceRow.duration ?? item.duration_minutes)
  return {
    ...item,
    product_id: String(serviceRow.id),
    name: serviceName,
    description: String(serviceRow.description ?? item.description ?? ""),
    short_description: String(serviceRow.description ?? item.short_description ?? "").slice(0, 240),
    unit_price: price,
    currency: "mxn",
    product_type: "service",
    category_key: String(serviceRow.category ?? item.category_key ?? "services"),
    duration_minutes: Number.isFinite(duration) && duration > 0 ? duration : null,
    metadata: {
      ...(item.metadata ?? {}),
      server_priced: true,
      source_table: "services",
      service_id: String(serviceRow.id),
    },
  }
}

async function loadActivePricedService(
  supabase: ReturnType<typeof createAdminClient>,
  input: { serviceId?: string; serviceName?: string },
): Promise<Record<string, unknown>> {
  const columns =
    "id, name, description, category, duration_min, duration, price, is_active, active, price_on_quote, is_package, sessions_count"

  let service: Record<string, unknown> | null = null
  if (input.serviceId) {
    const { data, error } = await supabase
      .from("services")
      .select(columns)
      .eq("id", input.serviceId)
      .maybeSingle()
    if (error) throw error
    service = data as Record<string, unknown> | null
  }

  if (!service && input.serviceName) {
    const { data, error } = await supabase
      .from("services")
      .select(columns)
      .eq("name", input.serviceName)
      .limit(2)
    if (error) throw error
    const rows = (data ?? []) as Array<Record<string, unknown>>
    if (rows.length === 1) service = rows[0]
  }

  if (!service) throw new Error("service_not_found")
  const serviceActive = service.is_active !== false && service.active !== false
  if (!serviceActive) throw new Error("service_inactive")
  if (service.price_on_quote === true) throw new Error("service_price_on_quote")
  const price = Number(service.price ?? 0)
  if (!(price > 0)) throw new Error("service_no_price")
  return service
}

function firstUuid(...values: string[]): string | undefined {
  return values.find((value) => isUuid(value.trim()))?.trim()
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value)
}

function serve(handler: (req: Request) => Promise<Response>) {
  return Deno.serve(handler)
}
