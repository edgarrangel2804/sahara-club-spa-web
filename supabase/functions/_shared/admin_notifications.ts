import {
  type AdminClient,
  DEFAULT_BRANCH_ID,
  loadBusinessSettings,
  normalizePhone,
  sendMetaTextMessage,
} from "./whatsapp_business.ts"

export const ADMIN_GIFT_CARD_PURCHASE_DELIVERY_TYPE = "admin_whatsapp_purchase_alert"

export type PurchaseChannel = "web" | "whatsapp" | "reception" | "manual" | "admin" | "unknown"

export type GiftCardPurchaseAdminNotice = {
  orderId: string
  orderItemId: string
  giftCardId: string
  buyerName: string
  recipientName: string
  productName: string
  amountPaid: number
  currency: string
  validFrom: string
  expiresOn: string
  deliveryStatus: string
  assetStatus: string
  purchaseChannel: PurchaseChannel | string
}

export type AdminNotificationRecipient = {
  phone: string
  destinationHash: string
  recipientMask: string
}

export type AdminNotificationResult = {
  attempted: number
  sent: number
  failed: number
  skipped?: string
}

export function normalizePurchaseChannel(value: unknown): PurchaseChannel {
  const raw = String(value ?? "").trim().toLowerCase()
  if (
    raw === "web" || raw === "whatsapp" || raw === "reception" || raw === "manual" ||
    raw === "admin"
  ) {
    return raw
  }
  return "unknown"
}

export function shouldNotifyGiftCardAdmins(value: unknown): boolean {
  const channel = normalizePurchaseChannel(value)
  return channel !== "reception" && channel !== "manual" && channel !== "admin"
}

export function purchaseChannelLabel(value: unknown): string {
  switch (normalizePurchaseChannel(value)) {
    case "web":
      return "Pagina web"
    case "whatsapp":
      return "WhatsApp"
    case "reception":
      return "Recepcion"
    case "manual":
      return "Venta manual"
    case "admin":
      return "Admin"
    default:
      return "Canal no identificado"
  }
}

export function formatMoney(value: number, currency: string): string {
  return `$${roundCurrency(value).toFixed(2)} ${String(currency || "MXN").toUpperCase()}`
}

export function maskPhone(value: string): string {
  const digits = String(value ?? "").replace(/\D/g, "")
  if (digits.length <= 4) return "****"
  return `****${digits.slice(-4)}`
}

export function buildGiftCardAdminMessage(input: GiftCardPurchaseAdminNotice): string {
  return [
    "Nueva Gift Card pagada en Sahara Club Spa.",
    "",
    `Canal: ${purchaseChannelLabel(input.purchaseChannel)}`,
    `Comprador: ${input.buyerName || "Cliente Sahara"}`,
    `Destinatario: ${input.recipientName || "Invitada Sahara"}`,
    `Experiencia: ${input.productName || "Gift Card Sahara"}`,
    `Monto pagado: ${formatMoney(input.amountPaid, input.currency)}`,
    `Vigencia: ${input.validFrom || "pendiente"} al ${input.expiresOn || "pendiente"}`,
    `Entrega al destinatario: ${deliveryStatusLabel(input.deliveryStatus)}`,
    `Tarjeta digital: ${assetStatusLabel(input.assetStatus)}`,
    "",
    "La venta ya esta disponible en Recepcion.",
  ].join("\n")
}

export async function resolveAdminRecipients(
  settings: { ai_admin_numbers?: string[] | null } | null,
): Promise<AdminNotificationRecipient[]> {
  const recipients: AdminNotificationRecipient[] = []
  const seen = new Set<string>()
  for (const raw of settings?.ai_admin_numbers ?? []) {
    const normalized = normalizePhone(String(raw ?? ""))
    const digits = normalized.replace(/\D/g, "")
    const tail = digits.slice(-10)
    if (tail.length !== 10 || seen.has(tail)) continue
    seen.add(tail)
    recipients.push({
      phone: normalized,
      destinationHash: await sha256Hex(`${ADMIN_GIFT_CARD_PURCHASE_DELIVERY_TYPE}:${normalized}`),
      recipientMask: maskPhone(normalized),
    })
  }
  return recipients
}

export async function notifyGiftCardPurchaseAdmins(
  supabase: AdminClient,
  notices: GiftCardPurchaseAdminNotice[],
): Promise<AdminNotificationResult> {
  const eligible = notices.filter((notice) => shouldNotifyGiftCardAdmins(notice.purchaseChannel))
  if (eligible.length === 0) {
    return { attempted: 0, sent: 0, failed: 0, skipped: "channel_not_admin_notifiable" }
  }

  const { data: settings, error: settingsError } = await supabase
    .from("ai_settings")
    .select("ai_admin_numbers")
    .eq("id", 1)
    .maybeSingle()
  if (settingsError) throw settingsError

  const recipients = await resolveAdminRecipients(
    settings as { ai_admin_numbers?: string[] | null } | null,
  )
  if (recipients.length === 0) {
    return { attempted: 0, sent: 0, failed: 0, skipped: "no_admin_recipients" }
  }

  const businessSettings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)
  let attempted = 0
  let sent = 0
  let failed = 0

  for (const notice of eligible) {
    const message = buildGiftCardAdminMessage(notice)
    for (const recipient of recipients) {
      const claim = await claimGiftCardDelivery(supabase, notice, recipient)
      if (!claim.claimed) continue
      attempted += 1

      if (!businessSettings?.accessToken || !businessSettings.row.phone_number_id) {
        const providerResponse = { error: "missing_meta_config" }
        const whatsappLogId = await insertWhatsappLog(supabase, {
          recipient,
          notice,
          message,
          ok: false,
          providerResponse,
          payloadSent: null,
          errorMessage: "missing_meta_config",
        })
        await completeGiftCardDelivery(supabase, {
          deliveryId: claim.deliveryId,
          status: "failed",
          whatsappLogId,
          error: "missing_meta_config",
          providerResponse,
        })
        failed += 1
        continue
      }

      let ok = false
      let providerResponse: Record<string, unknown> = {}
      let errorMessage: string | null = null
      const payloadSent = {
        messaging_product: "whatsapp",
        to: recipient.recipientMask,
        type: "text",
        text: { preview_url: false, body: message },
      }
      try {
        const response = await sendMetaTextMessage(
          businessSettings.accessToken,
          businessSettings.row.phone_number_id,
          recipient.phone,
          message,
        )
        ok = response.ok
        providerResponse = { ...(response.data ?? {}), http_status: response.status }
        if (!ok) errorMessage = metaErrorMessage(response.data)
      } catch (error) {
        ok = false
        errorMessage = error instanceof Error ? error.message : String(error)
        providerResponse = { error: errorMessage }
      }

      const safeProviderResponse = sanitizeProviderResponse(
        providerResponse,
        recipient.recipientMask,
      )
      const whatsappLogId = await insertWhatsappLog(supabase, {
        recipient,
        notice,
        message,
        ok,
        providerResponse: safeProviderResponse,
        payloadSent,
        errorMessage,
      })
      await completeGiftCardDelivery(supabase, {
        deliveryId: claim.deliveryId,
        status: ok ? "sent" : "failed",
        whatsappLogId,
        error: ok ? null : errorMessage,
        providerResponse: safeProviderResponse,
      })
      if (ok) sent += 1
      else failed += 1
    }
  }

  return { attempted, sent, failed }
}

async function claimGiftCardDelivery(
  supabase: AdminClient,
  notice: GiftCardPurchaseAdminNotice,
  recipient: AdminNotificationRecipient,
): Promise<{ deliveryId: string; claimed: boolean }> {
  const { data, error } = await supabase.rpc("claim_gift_card_delivery", {
    p_gift_card_id: notice.giftCardId,
    p_destination_hash: recipient.destinationHash,
    p_delivery_type: ADMIN_GIFT_CARD_PURCHASE_DELIVERY_TYPE,
  })
  if (error) throw error
  const row = Array.isArray(data) ? data[0] : data
  return {
    deliveryId: String(row?.delivery_id ?? ""),
    claimed: row?.claimed === true,
  }
}

async function completeGiftCardDelivery(
  supabase: AdminClient,
  input: {
    deliveryId: string
    status: "sent" | "failed" | "skipped"
    whatsappLogId: string | null
    error?: string | null
    providerResponse?: Record<string, unknown>
  },
) {
  if (!input.deliveryId) return
  await supabase.rpc("complete_gift_card_delivery", {
    p_delivery_id: input.deliveryId,
    p_status: input.status,
    p_last_error: input.error ?? null,
    p_metadata: {
      notification_kind: ADMIN_GIFT_CARD_PURCHASE_DELIVERY_TYPE,
      whatsapp_log_id: input.whatsappLogId,
      provider_response: input.providerResponse ?? {},
    },
  })
}

async function insertWhatsappLog(
  supabase: AdminClient,
  input: {
    recipient: AdminNotificationRecipient
    notice: GiftCardPurchaseAdminNotice
    message: string
    ok: boolean
    providerResponse: Record<string, unknown>
    payloadSent: Record<string, unknown> | null
    errorMessage?: string | null
  },
): Promise<string | null> {
  const wamid =
    (input.providerResponse as { messages?: Array<{ id?: string }> })?.messages?.[0]?.id ?? null
  const { data, error } = await supabase
    .from("whatsapp_logs")
    .insert({
      phone: input.recipient.recipientMask,
      message_rendered: input.message,
      status: input.ok ? "sent" : "failed",
      provider: "meta_cloud_api",
      provider_response: {
        ...sanitizeProviderResponse(input.providerResponse, input.recipient.recipientMask),
        message_id: wamid,
      },
      payload_sent: sanitizePayloadSent(input.payloadSent, input.recipient.recipientMask),
      window_type: "free_text",
      sent_at: input.ok ? new Date().toISOString() : null,
      created_at: new Date().toISOString(),
      error_message: input.ok ? null : input.errorMessage ?? "admin_notification_failed",
      event_type: ADMIN_GIFT_CARD_PURCHASE_DELIVERY_TYPE,
      type: ADMIN_GIFT_CARD_PURCHASE_DELIVERY_TYPE,
    })
    .select("id")
    .maybeSingle()

  if (error) {
    console.warn("admin notification whatsapp log failed:", sanitizeTechnicalError(error.message))
    return null
  }
  return String((data as { id?: string } | null)?.id ?? "")
}

function sanitizePayloadSent(
  payload: Record<string, unknown> | null,
  recipientMask: string,
): Record<string, unknown> | null {
  if (!payload) return null
  return { ...payload, to: recipientMask }
}

function sanitizeProviderResponse(
  response: Record<string, unknown>,
  recipientMask: string,
): Record<string, unknown> {
  const sanitized = { ...response }
  const contacts = sanitized.contacts
  if (Array.isArray(contacts)) {
    sanitized.contacts = contacts.map((contact) => {
      if (!contact || typeof contact !== "object") return contact
      return {
        ...(contact as Record<string, unknown>),
        input: recipientMask,
        wa_id: recipientMask,
      }
    })
  }
  return sanitized
}

function metaErrorMessage(data: unknown): string {
  const message = ((data as { error?: { message?: string } })?.error ?? {}).message
  return message ?? JSON.stringify(data)
}

function assetStatusLabel(status: string): string {
  switch (String(status || "").trim().toLowerCase()) {
    case "generated":
      return "generada"
    case "failed":
      return "fallida"
    default:
      return "pendiente"
  }
}

function deliveryStatusLabel(status: string): string {
  switch (String(status || "").trim().toLowerCase()) {
    case "sent":
      return "enviada"
    case "failed":
      return "fallida"
    case "skipped":
      return "omitida"
    default:
      return "pendiente"
  }
}

function sanitizeTechnicalError(value: unknown): string {
  return String(value ?? "")
    .replace(/\+?\d[\d\s().-]{7,}\d/g, "[redacted-phone]")
    .replace(/[A-Za-z0-9_-]{40,1800}\.[A-Za-z0-9_-]{32,220}/g, "[redacted-token]")
    .slice(0, 300)
}

function roundCurrency(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

async function sha256Hex(value: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))
  return Array.from(new Uint8Array(hash))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
}
