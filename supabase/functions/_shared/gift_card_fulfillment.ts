import * as QRCode from "https://esm.sh/qrcode@1.5.4?target=deno"
import {
  PDFDocument,
  type PDFFont,
  type PDFPage,
  rgb,
  StandardFonts,
} from "https://esm.sh/pdf-lib@1.17.1?target=deno"
import {
  callMetaApi,
  DEFAULT_BRANCH_ID,
  loadBusinessSettings,
  normalizePhone as normalizeWhatsAppPhone,
} from "./whatsapp_business.ts"

export type AdminClient = any

export const GIFT_CARD_VALIDITY_MONTHS = 3
export const GIFT_CARD_BUCKET = "gift-card-assets"
export const GIFT_CARD_DOWNLOAD_PURPOSE = "gift_card_download"
export const GIFT_CARD_DOWNLOAD_TOKEN_VERSION = 1
export const DEFAULT_GIFT_CARD_DOWNLOAD_TTL_SECONDS = 60 * 60 * 24 * 14
export const MAX_DEDICATION_LENGTH = 350

const BASE64URL_RE = /^[A-Za-z0-9_-]+$/
const NONCE_RE = /^[A-Za-z0-9_-]{16,96}$/
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

export type GiftCardDownloadTokenPayload = {
  version: number
  purpose: string
  gift_card_id: string
  order_item_id: string | null
  issued_at: number
  expires_at: number
  nonce: string
}

export type VerifyGiftCardDownloadTokenResult =
  | { ok: true; payload: GiftCardDownloadTokenPayload }
  | { ok: false; error: string; status: number }

export type GiftCardPdfInput = {
  id: string
  code: string
  recipientName: string
  senderName: string
  dedicationMessage: string
  productName: string
  validFrom: string
  expiresOn: string
  amount: number
  currency: string
  folio?: string
}

export type GiftCardFulfillmentDraft = {
  recipientName: string
  recipientPhone: string
  senderName: string
  purchaserName: string
  purchaserPhone: string
  dedicationMessage: string
  validFrom: string
  expiresOn: string
  serviceId: string | null
  serviceName: string
  packageId: string | null
  packageName: string
  deliveryMethod: string
  buyerCopyRequested: boolean
  purchaseChannel: string
  productSnapshot: Record<string, unknown>
}

export type GiftCardRedemptionRow = {
  status?: string | null
  current_balance?: number | string | null
  valid_from?: string | null
  expires_on?: string | null
  expires_at?: string | null
}

export function tijuanaDateFromInstant(date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Tijuana",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date)
  const values: Record<string, string> = {}
  for (const part of parts) {
    if (part.type !== "literal") values[part.type] = part.value
  }
  return `${values.year}-${values.month}-${values.day}`
}

export function parseLocalDate(value: string): { year: number; month: number; day: number } {
  const clean = String(value ?? "").trim()
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(clean)
  if (!match) throw new Error("invalid_local_date")
  const year = Number(match[1])
  const month = Number(match[2])
  const day = Number(match[3])
  if (month < 1 || month > 12) throw new Error("invalid_local_date")
  const maxDay = daysInMonth(year, month)
  if (day < 1 || day > maxDay) throw new Error("invalid_local_date")
  return { year, month, day }
}

export function addCalendarMonths(dateValue: string, months: number): string {
  const date = parseLocalDate(dateValue)
  const monthIndex = date.month - 1 + months
  const targetYear = date.year + Math.floor(monthIndex / 12)
  const targetMonth = ((monthIndex % 12) + 12) % 12 + 1
  const targetDay = Math.min(date.day, daysInMonth(targetYear, targetMonth))
  return `${targetYear}-${pad2(targetMonth)}-${pad2(targetDay)}`
}

export function computeGiftCardValidity(
  requestedValidFrom?: string | null,
  todayTijuana = tijuanaDateFromInstant(),
) {
  const validFrom = String(requestedValidFrom ?? todayTijuana).trim() || todayTijuana
  parseLocalDate(validFrom)
  parseLocalDate(todayTijuana)
  if (validFrom < todayTijuana) throw new Error("gift_card_valid_from_in_past")
  return {
    validFrom,
    expiresOn: addCalendarMonths(validFrom, GIFT_CARD_VALIDITY_MONTHS),
  }
}

export function sanitizeDedicationMessage(value: unknown): string {
  const noControls = String(value ?? "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("")
    .filter((char) => isAllowedDedicationChar(char))
    .join("")
    .replace(/<[^>\n]*>/g, "")
    .replace(/[<>]/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
  return Array.from(noControls).slice(0, MAX_DEDICATION_LENGTH).join("")
}

export function normalizeGiftCardPhone(value: unknown): string | null {
  let digits = String(value ?? "").replace(/\D/g, "")
  if (digits.startsWith("00")) digits = digits.slice(2)
  if (digits.length === 13 && digits.startsWith("521")) {
    digits = `52${digits.slice(-10)}`
  } else if (digits.length === 10) {
    digits = `52${digits}`
  }
  if (!/^[1-9]\d{9,14}$/.test(digits)) return null
  return `+${digits}`
}

export function giftCardPhoneForWhatsApp(value: string): string {
  const e164 = normalizeGiftCardPhone(value)
  if (!e164) return ""
  const digits = e164.replace(/\D/g, "")
  if (digits.length === 12 && digits.startsWith("52")) {
    return normalizeWhatsAppPhone(`521${digits.slice(2)}`)
  }
  return normalizeWhatsAppPhone(digits)
}

export function maskPhone(value: unknown): string {
  const digits = String(value ?? "").replace(/\D/g, "")
  if (digits.length <= 4) return "****"
  return `****${digits.slice(-4)}`
}

export function buildGiftCardProductSnapshot(input: {
  order: Record<string, unknown>
  item: Record<string, unknown>
  metadata: Record<string, unknown>
  serviceName: string
  packageName?: string
}) {
  const quantity = Number(input.item.quantity ?? 1)
  const total = roundCurrency(Number(input.item.total_price ?? input.item.unit_price ?? 0))
  return {
    product_name: String(input.item.product_name ?? input.item.name ?? input.serviceName),
    product_description: String(input.item.product_description ?? input.item.description ?? ""),
    short_description: String(input.metadata.short_description ?? ""),
    service_id: input.metadata.service_id ? String(input.metadata.service_id) : null,
    service_name: input.serviceName,
    package_id: input.metadata.package_id ? String(input.metadata.package_id) : null,
    package_name: input.packageName ?? "",
    sessions_count: Number(input.metadata.sessions_count ?? quantity),
    quantity,
    value_paid: total,
    face_value: total,
    currency: String(input.item.currency ?? input.order.currency ?? "MXN").toUpperCase(),
    purchased_at: String(input.order.paid_at ?? input.order.created_at ?? new Date().toISOString()),
    branding: {
      business_name: "Sahara Club Spa",
      contact_phone: "646 151 9597",
      website: "saharaclubspa.com",
    },
  }
}

export function buildGiftCardFulfillmentDraft(input: {
  order: Record<string, unknown>
  item: Record<string, unknown>
  metadata: Record<string, unknown>
  todayTijuana?: string
}): GiftCardFulfillmentDraft {
  const validity = computeGiftCardValidity(
    String(input.metadata.valid_from ?? ""),
    input.todayTijuana ?? tijuanaDateFromInstant(),
  )
  const serviceName = cleanDisplayName(
    input.metadata.service_name ?? input.item.product_name ?? "Experiencia Sahara",
    "Experiencia Sahara",
  )
  const packageName = cleanDisplayName(input.metadata.package_name ?? "", "")
  const recipientName = cleanDisplayName(input.metadata.recipient_name, "Invitada Sahara")
  const senderName = cleanDisplayName(
    input.metadata.sender_name ?? input.order.customer_name,
    "Cliente Sahara",
  )
  const purchaserName = cleanDisplayName(input.order.customer_name, senderName)
  const recipientPhone = normalizeGiftCardPhone(input.metadata.recipient_phone) ?? ""
  const purchaserPhone = normalizeGiftCardPhone(input.order.customer_phone) ?? ""
  const dedicationMessage = sanitizeDedicationMessage(
    input.metadata.dedication_message ?? input.metadata.message ?? "",
  )

  return {
    recipientName,
    recipientPhone,
    senderName,
    purchaserName,
    purchaserPhone,
    dedicationMessage,
    validFrom: validity.validFrom,
    expiresOn: validity.expiresOn,
    serviceId: input.metadata.service_id ? String(input.metadata.service_id) : null,
    serviceName,
    packageId: input.metadata.package_id ? String(input.metadata.package_id) : null,
    packageName,
    deliveryMethod: String(input.metadata.delivery_method ?? "digital"),
    buyerCopyRequested: input.metadata.buyer_copy_requested === true ||
      input.metadata.send_copy_to_buyer === true,
    purchaseChannel: normalizePurchaseChannel(input.metadata.purchase_channel),
    productSnapshot: buildGiftCardProductSnapshot({
      order: input.order,
      item: input.item,
      metadata: input.metadata,
      serviceName,
      packageName,
    }),
  }
}

export function normalizePurchaseChannel(value: unknown): string {
  const raw = String(value ?? "").trim().toLowerCase()
  if (raw === "web" || raw === "whatsapp" || raw === "reception") return raw
  return "unknown"
}

export function validateGiftCardRedemption(
  row: GiftCardRedemptionRow,
  input: { amount?: number; todayTijuana?: string } = {},
): { ok: true } | { ok: false; error: string } {
  const status = String(row.status ?? "").trim().toLowerCase()
  if (status !== "active") return { ok: false, error: "gift_card_not_active" }

  const today = input.todayTijuana ?? tijuanaDateFromInstant()
  const validFrom = String(row.valid_from ?? "").slice(0, 10)
  if (validFrom && validFrom > today) return { ok: false, error: "gift_card_not_yet_valid" }

  const expiresOn = String(row.expires_on ?? row.expires_at ?? "").slice(0, 10)
  if (expiresOn && expiresOn < today) return { ok: false, error: "gift_card_expired" }

  const amount = Math.max(0, Number(input.amount ?? 0))
  const balance = Number(row.current_balance ?? 0)
  if (!(balance > 0)) return { ok: false, error: "gift_card_empty" }
  if (amount > 0 && balance < amount) {
    return { ok: false, error: "gift_card_insufficient_balance" }
  }

  return { ok: true }
}

export async function fulfillGiftCardItem(
  supabase: AdminClient,
  input: { orderId: string; order: Record<string, unknown>; item: Record<string, unknown> },
) {
  const metadata = (input.item.metadata ?? {}) as Record<string, unknown>
  const draft = buildGiftCardFulfillmentDraft({
    order: input.order,
    item: input.item,
    metadata,
  })

  let card = await findGiftCardByOrderItem(supabase, String(input.item.id))
  if (!card) {
    card = await insertGiftCardWithRetry(supabase, input, draft)
  } else {
    card = await completeMissingGiftCardFields(supabase, card, draft)
  }

  const asset = await ensureGiftCardDigitalAsset(supabase, card)
  card = asset.card
  await deliverGiftCardAfterPayment(supabase, card, asset.signedUrl)
  await createGiftCardReceptionAlert(supabase, {
    order: input.order,
    item: input.item,
    card,
    draft,
  })

  return card
}

export async function ensureGiftCardDigitalAsset(
  supabase: AdminClient,
  card: Record<string, unknown>,
): Promise<{ card: Record<string, unknown>; signedUrl: string }> {
  const path = String(card.digital_asset_path ?? "")
  const status = String(card.digital_asset_status ?? "")

  if (path && status === "generated") {
    return { card, signedUrl: await createGiftCardSignedUrl(supabase, path) }
  }

  try {
    const assetPath = path || giftCardAssetPath(String(card.id))
    const pdfBytes = await buildGiftCardPdf(pdfInputFromCard(card))
    const hash = await sha256Hex(pdfBytes)
    const upload = await supabase.storage
      .from(GIFT_CARD_BUCKET)
      .upload(assetPath, pdfBytes, { contentType: "application/pdf", upsert: true })
    if (upload.error) throw upload.error

    const generatedAt = new Date().toISOString()
    const { data: updated, error } = await supabase
      .from("gift_cards")
      .update({
        digital_asset_path: assetPath,
        digital_asset_status: "generated",
        digital_asset_generated_at: generatedAt,
        digital_asset_sha256: hash,
      })
      .eq("id", card.id)
      .select("*")
      .single()
    if (error) throw error
    const updatedCard = (updated ?? { ...card, digital_asset_path: assetPath }) as Record<
      string,
      unknown
    >
    return { card: updatedCard, signedUrl: await createGiftCardSignedUrl(supabase, assetPath) }
  } catch (error) {
    await markGiftCardAssetFailed(supabase, card, sanitizeTechnicalError(error))
    return { card, signedUrl: "" }
  }
}

export async function buildGiftCardPdf(input: GiftCardPdfInput): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  const page = doc.addPage([420, 680])
  const { width, height } = page.getSize()

  const serif = await doc.embedFont(StandardFonts.TimesRoman)
  const serifBold = await doc.embedFont(StandardFonts.TimesRomanBold)
  const sans = await doc.embedFont(StandardFonts.Helvetica)
  const sansBold = await doc.embedFont(StandardFonts.HelveticaBold)

  const cream = rgb(0.961, 0.941, 0.902)
  const dark = rgb(0.083, 0.078, 0.075)
  const ink = rgb(0.141, 0.126, 0.110)
  const gold = rgb(0.733, 0.600, 0.333)
  const muted = rgb(0.430, 0.382, 0.320)

  page.drawRectangle({ x: 0, y: 0, width, height, color: cream })
  page.drawRectangle({
    x: 18,
    y: 18,
    width: width - 36,
    height: height - 36,
    borderColor: gold,
    borderWidth: 1.2,
  })
  page.drawRectangle({ x: 28, y: 28, width: width - 56, height: height - 56, color: undefined })

  const cx = width / 2
  const center = (text: string, font: typeof serif, size: number) =>
    cx - font.widthOfTextAtSize(text, size) / 2

  let y = height - 72
  page.drawText("SAHARA CLUB SPA", {
    x: center("SAHARA CLUB SPA", serifBold, 22),
    y,
    font: serifBold,
    size: 22,
    color: gold,
  })
  y -= 22
  page.drawText("Gift Card", {
    x: center("Gift Card", serif, 18),
    y,
    font: serif,
    size: 18,
    color: ink,
  })
  y -= 26
  page.drawLine({ start: { x: 58, y }, end: { x: width - 58, y }, thickness: 0.7, color: gold })

  y -= 42
  const recipient = input.recipientName || "Invitada Sahara"
  page.drawText("PARA", { x: 58, y, font: sansBold, size: 8, color: muted })
  y -= 28
  drawCenteredWrapped(page, recipient, serifBold, 26, gold, y, 54, 312, 30)
  y -= recipient.length > 26 ? 58 : 42

  const senderLine = `De parte de ${input.senderName || "Sahara Club Spa"}`
  drawCenteredWrapped(page, senderLine, sans, 12, ink, y, 58, 304, 15)
  y -= 34

  if (input.dedicationMessage) {
    const lines = wrapText(input.dedicationMessage, sans, 11, 310).slice(0, 6)
    page.drawText("DEDICATORIA", { x: 58, y, font: sansBold, size: 8, color: muted })
    y -= 16
    for (const line of lines) {
      page.drawText(line, { x: 58, y, font: sans, size: 11, color: ink })
      y -= 14
    }
    y -= 12
  }

  page.drawRectangle({
    x: 48,
    y: y - 54,
    width: width - 96,
    height: 70,
    color: rgb(0.91, 0.87, 0.78),
  })
  page.drawText("EXPERIENCIA", { x: 66, y: y - 2, font: sansBold, size: 8, color: muted })
  const productLines = wrapText(input.productName || "Experiencia Sahara", serifBold, 17, 248)
    .slice(
      0,
      2,
    )
  let productY = y - 24
  for (const line of productLines) {
    page.drawText(line, { x: 66, y: productY, font: serifBold, size: 17, color: dark })
    productY -= 19
  }
  y -= 92

  const dateLeft = `Valida desde ${formatDateLongEs(input.validFrom)}`
  const dateRight = `Hasta ${formatDateLongEs(input.expiresOn)}`
  page.drawText(dateLeft, { x: 58, y, font: sans, size: 10, color: ink })
  page.drawText(dateRight, {
    x: width - 58 - sans.widthOfTextAtSize(dateRight, 10),
    y,
    font: sans,
    size: 10,
    color: ink,
  })
  y -= 26

  const qrDataUrl = await QRCode.toDataURL(input.code, {
    errorCorrectionLevel: "M",
    margin: 1,
    width: 210,
  })
  const qrBytes = dataUrlToBytes(qrDataUrl)
  const qrImage = await doc.embedPng(qrBytes)
  const qrSize = 156
  page.drawRectangle({
    x: cx - qrSize / 2 - 9,
    y: y - qrSize - 9,
    width: qrSize + 18,
    height: qrSize + 18,
    color: rgb(1, 1, 1),
  })
  page.drawImage(qrImage, { x: cx - qrSize / 2, y: y - qrSize, width: qrSize, height: qrSize })
  y -= qrSize + 28

  const code = input.code
  page.drawText(code, {
    x: center(code, sansBold, 15),
    y,
    font: sansBold,
    size: 15,
    color: gold,
  })
  y -= 18
  const folio = input.folio || folioFromGiftCardId(input.id)
  page.drawText(`Folio ${folio}`, {
    x: center(`Folio ${folio}`, sans, 8),
    y,
    font: sans,
    size: 8,
    color: muted,
  })

  const footerLines = [
    "Valida durante tres meses a partir de la fecha indicada.",
    "Requiere cita previa y esta sujeta a disponibilidad.",
    "Calle Segunda 2226, Ensenada, B.C. | Tel. 646 151 9597 | saharaclubspa.com",
  ]
  let footY = 72
  page.drawLine({
    start: { x: 58, y: footY + 24 },
    end: { x: width - 58, y: footY + 24 },
    thickness: 0.6,
    color: gold,
  })
  for (const line of footerLines) {
    page.drawText(line, {
      x: center(line, sans, 7.5),
      y: footY,
      font: sans,
      size: 7.5,
      color: muted,
    })
    footY -= 11
  }

  return await doc.save()
}

export async function deliverGiftCardAfterPayment(
  supabase: AdminClient,
  card: Record<string, unknown>,
  signedUrl: string,
) {
  const recipientPhone = String(card.recipient_phone ?? "")
  const buyerPhone = String(card.purchaser_phone ?? "")
  await deliverGiftCardToDestination(supabase, {
    card,
    signedUrl,
    phone: recipientPhone,
    deliveryType: "recipient_whatsapp",
  })
  if (card.buyer_copy_requested === true) {
    await deliverGiftCardToDestination(supabase, {
      card,
      signedUrl,
      phone: buyerPhone,
      deliveryType: "buyer_whatsapp_copy",
    })
  }
}

export async function createGiftCardDownloadToken(input: {
  giftCardId: string
  orderItemId?: string | null
  secret: string
  ttlSeconds?: number
  nowSeconds?: number
  nonce?: string
}): Promise<{ token: string; payload: GiftCardDownloadTokenPayload }> {
  const secret = requireGiftCardDownloadSecret(input.secret)
  if (!UUID_RE.test(input.giftCardId)) throw new Error("invalid_gift_card_id")
  const orderItemId = String(input.orderItemId ?? "").trim()
  if (orderItemId && !UUID_RE.test(orderItemId)) throw new Error("invalid_order_item_id")
  const issuedAt = Math.floor(input.nowSeconds ?? Date.now() / 1000)
  const ttlSeconds = input.ttlSeconds ?? DEFAULT_GIFT_CARD_DOWNLOAD_TTL_SECONDS
  if (!Number.isInteger(ttlSeconds) || ttlSeconds < 60 || ttlSeconds > 60 * 60 * 24 * 30) {
    throw new Error("invalid_gift_card_download_ttl")
  }
  const nonce = input.nonce ?? randomNonce()
  if (!NONCE_RE.test(nonce)) throw new Error("invalid_gift_card_download_nonce")
  const payload: GiftCardDownloadTokenPayload = {
    version: GIFT_CARD_DOWNLOAD_TOKEN_VERSION,
    purpose: GIFT_CARD_DOWNLOAD_PURPOSE,
    gift_card_id: input.giftCardId,
    order_item_id: orderItemId || null,
    issued_at: issuedAt,
    expires_at: issuedAt + ttlSeconds,
    nonce,
  }
  const payloadSegment = bytesToBase64Url(
    new TextEncoder().encode(canonicalGiftCardDownloadPayload(payload)),
  )
  const signature = await hmacSha256Base64Url(payloadSegment, secret)
  return { token: `${payloadSegment}.${signature}`, payload }
}

export async function verifyGiftCardDownloadToken(
  token: string,
  secret: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<VerifyGiftCardDownloadTokenResult> {
  const cleanToken = token.trim()
  if (!isValidGiftCardDownloadTokenFormat(cleanToken)) {
    return { ok: false, error: "malformed_token", status: 400 }
  }
  let normalizedSecret = ""
  try {
    normalizedSecret = requireGiftCardDownloadSecret(secret)
  } catch {
    return { ok: false, error: "token_unavailable", status: 500 }
  }
  const [payloadSegment, signature] = cleanToken.split(".")
  const expected = await hmacSha256Base64Url(payloadSegment, normalizedSecret)
  if (!constantTimeEqual(signature, expected)) {
    return { ok: false, error: "invalid_signature", status: 401 }
  }
  const payload = decodeGiftCardDownloadPayload(payloadSegment)
  if (!payload.ok) return payload
  return validateGiftCardDownloadPayload(payload.payload, nowSeconds)
}

export function isValidGiftCardDownloadTokenFormat(value: string): boolean {
  const token = value.trim()
  if (token.length < 80 || token.length > 2200) return false
  const [payload, signature, extra] = token.split(".")
  return extra === undefined &&
    Boolean(payload && signature && BASE64URL_RE.test(payload) && BASE64URL_RE.test(signature))
}

export function requireGiftCardDownloadSecret(value?: string | null): string {
  const secret = String(value ?? "").trim()
  if (!secret) throw new Error("gift_card_download_secret_required")
  if (secret.length < 32) throw new Error("gift_card_download_secret_too_short")
  return secret
}

export function giftCardAssetPath(giftCardId: string, version = 1): string {
  if (!UUID_RE.test(giftCardId)) throw new Error("invalid_gift_card_id")
  return `gift-cards/${giftCardId}/${version}/gift-card.pdf`
}

export function folioFromGiftCardId(giftCardId: string): string {
  return `SAHARA-GC-${String(giftCardId).replace(/-/g, "").slice(0, 8).toUpperCase()}`
}

export function publicGiftCardPayload(input: {
  card: Record<string, unknown>
  signedUrl: string
}) {
  const card = input.card
  const snapshot = (card.product_snapshot && typeof card.product_snapshot === "object")
    ? card.product_snapshot as Record<string, unknown>
    : {}
  return {
    ok: true,
    business_name: "Sahara Club Spa",
    download_url: input.signedUrl,
    asset_status: String(card.digital_asset_status ?? "pending"),
    delivery_status: String(card.delivery_status ?? "pending"),
    card: {
      id: String(card.id ?? ""),
      code: String(card.code ?? ""),
      folio: folioFromGiftCardId(String(card.id ?? "")),
      service_name: String(card.service_name ?? snapshot.service_name ?? ""),
      package_name: String(card.package_name ?? ""),
      recipient_name: String(card.recipient_name ?? ""),
      sender_name: String(card.sender_name ?? ""),
      dedication_message: String(card.dedication_message ?? ""),
      valid_from: String(card.valid_from ?? "").slice(0, 10),
      expires_on: String(card.expires_on ?? card.expires_at ?? "").slice(0, 10),
      status: String(card.status ?? ""),
      currency: String(card.currency ?? "MXN"),
      amount: Number(card.initial_balance ?? 0),
    },
  }
}

export async function giftCardTokenFingerprint(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token))
  return `sha256:${bytesToHex(new Uint8Array(digest)).slice(0, 16)}`
}

export function giftCardDownloadSigningSecret(): string {
  return Deno.env.get("GIFT_CARD_DOWNLOAD_SIGNING_SECRET") ||
    Deno.env.get("DEPOSIT_VOUCHER_SIGNING_SECRET") ||
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    ""
}

export async function recordGiftCardDownload(
  supabase: AdminClient,
  input: { giftCardId: string; token: string },
) {
  try {
    const destinationHash = await giftCardTokenFingerprint(input.token)
    await supabase.from("gift_card_deliveries").upsert({
      gift_card_id: input.giftCardId,
      destination_hash: destinationHash,
      delivery_type: "download",
      status: "sent",
      delivered_at: new Date().toISOString(),
      attempt_count: 1,
      metadata: { token_hash: destinationHash },
    }, { onConflict: "gift_card_id,destination_hash,delivery_type" })
  } catch {
    // Download auditing is best-effort and must not block a valid signed URL.
  }
}

async function findGiftCardByOrderItem(supabase: AdminClient, orderItemId: string) {
  const { data, error } = await supabase
    .from("gift_cards")
    .select("*")
    .eq("order_item_id", orderItemId)
    .maybeSingle()
  if (error) throw error
  return (data ?? null) as Record<string, unknown> | null
}

async function insertGiftCardWithRetry(
  supabase: AdminClient,
  input: { orderId: string; order: Record<string, unknown>; item: Record<string, unknown> },
  draft: GiftCardFulfillmentDraft,
) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const { data, error } = await supabase
      .from("gift_cards")
      .insert({
        order_id: input.orderId,
        order_item_id: input.item.id,
        code: generateGiftCardCode(),
        initial_balance: roundCurrency(Number(input.item.total_price ?? 0)),
        current_balance: roundCurrency(Number(input.item.total_price ?? 0)),
        currency: String(input.item.currency ?? input.order.currency ?? "MXN").toUpperCase(),
        purchaser_name: draft.purchaserName,
        purchaser_phone: draft.purchaserPhone,
        recipient_name: draft.recipientName,
        recipient_phone: draft.recipientPhone,
        sender_name: draft.senderName,
        dedication_message: draft.dedicationMessage,
        delivery_method: draft.deliveryMethod,
        service_id: draft.serviceId,
        service_name: draft.serviceName,
        package_id: draft.packageId,
        package_name: draft.packageName,
        valid_from: draft.validFrom,
        expires_on: draft.expiresOn,
        status: "active",
        product_snapshot: draft.productSnapshot,
        digital_asset_status: "pending",
        delivery_status: "pending",
        buyer_copy_requested: draft.buyerCopyRequested,
      })
      .select("*")
      .single()
    if (!error && data) return data as Record<string, unknown>
    if ((error as { code?: string } | null)?.code === "23505") {
      const existing = await findGiftCardByOrderItem(supabase, String(input.item.id))
      if (existing) return existing
    } else {
      throw error
    }
  }
  throw new Error("gift_card_insert_race_not_resolved")
}

async function completeMissingGiftCardFields(
  supabase: AdminClient,
  card: Record<string, unknown>,
  draft: GiftCardFulfillmentDraft,
) {
  const patch: Record<string, unknown> = {}
  assignIfMissing(patch, card, "purchaser_name", draft.purchaserName)
  assignIfMissing(patch, card, "purchaser_phone", draft.purchaserPhone)
  assignIfMissing(patch, card, "recipient_phone", draft.recipientPhone)
  assignIfMissing(patch, card, "dedication_message", draft.dedicationMessage)
  assignIfMissing(patch, card, "valid_from", draft.validFrom)
  assignIfMissing(patch, card, "expires_on", draft.expiresOn)
  assignIfMissing(patch, card, "service_name", draft.serviceName)
  assignIfMissing(patch, card, "package_name", draft.packageName)
  assignIfMissing(patch, card, "product_snapshot", draft.productSnapshot)
  if (card.buyer_copy_requested !== true && draft.buyerCopyRequested) {
    patch.buyer_copy_requested = true
  }
  if (Object.keys(patch).length === 0) return card
  const { data, error } = await supabase
    .from("gift_cards")
    .update(patch)
    .eq("id", card.id)
    .select("*")
    .single()
  if (error) throw error
  return (data ?? { ...card, ...patch }) as Record<string, unknown>
}

async function markGiftCardAssetFailed(
  supabase: AdminClient,
  card: Record<string, unknown>,
  errorMessage: string,
) {
  try {
    await supabase
      .from("gift_cards")
      .update({
        digital_asset_status: "failed",
        last_delivery_error: errorMessage,
      })
      .eq("id", card.id)
  } catch {
    // Best-effort: the paid gift card remains created even if status update fails.
  }
}

export async function deliverGiftCardToDestination(
  supabase: AdminClient,
  input: {
    card: Record<string, unknown>
    signedUrl: string
    phone: string
    deliveryType: "recipient_whatsapp" | "buyer_whatsapp_copy" | "reception_resend"
  },
) {
  const normalizedPhone = normalizeGiftCardPhone(input.phone)
  if (!normalizedPhone) {
    await completeAggregateDeliveryStatus(supabase, input.card, "failed", "invalid_phone")
    return
  }
  if (!input.signedUrl) {
    await completeAggregateDeliveryStatus(supabase, input.card, "failed", "asset_unavailable")
    return
  }

  const destinationHash = await sha256Hex(
    new TextEncoder().encode(`${input.deliveryType}:${normalizedPhone}`),
  )
  const claim = await claimDelivery(supabase, {
    giftCardId: String(input.card.id),
    destinationHash,
    deliveryType: input.deliveryType,
  })
  if (!claim.claimed) return

  const caption = buildGiftCardWhatsAppCaption(input.card)
  const send = await sendGiftCardWhatsAppDocument(supabase, {
    to: giftCardPhoneForWhatsApp(normalizedPhone),
    link: input.signedUrl,
    filename: `${folioFromGiftCardId(String(input.card.id))}.pdf`,
    caption,
  })

  await completeDelivery(supabase, {
    deliveryId: claim.deliveryId,
    status: send.ok ? "sent" : "failed",
    error: send.ok ? null : send.error,
    providerResponse: send.providerResponse,
  })
  await completeAggregateDeliveryStatus(
    supabase,
    input.card,
    send.ok ? "sent" : "failed",
    send.ok ? null : send.error,
  )
}

async function claimDelivery(
  supabase: AdminClient,
  input: { giftCardId: string; destinationHash: string; deliveryType: string },
): Promise<{ claimed: boolean; deliveryId: string }> {
  const { data, error } = await supabase.rpc("claim_gift_card_delivery", {
    p_gift_card_id: input.giftCardId,
    p_destination_hash: input.destinationHash,
    p_delivery_type: input.deliveryType,
  })
  if (error) throw error
  const row = Array.isArray(data) ? data[0] : data
  return {
    claimed: row?.claimed === true,
    deliveryId: String(row?.delivery_id ?? ""),
  }
}

async function completeDelivery(
  supabase: AdminClient,
  input: {
    deliveryId: string
    status: "sent" | "failed" | "skipped"
    error?: string | null
    providerResponse?: Record<string, unknown>
  },
) {
  if (!input.deliveryId) return
  await supabase.rpc("complete_gift_card_delivery", {
    p_delivery_id: input.deliveryId,
    p_status: input.status,
    p_last_error: input.error ?? null,
    p_metadata: input.providerResponse ?? {},
  })
}

async function completeAggregateDeliveryStatus(
  supabase: AdminClient,
  card: Record<string, unknown>,
  status: "sent" | "failed" | "skipped",
  error: string | null,
) {
  const patch: Record<string, unknown> = {
    delivery_status: status,
    last_delivery_error: error,
    delivery_attempts: Number(card.delivery_attempts ?? 0) + 1,
  }
  if (status === "sent") {
    patch.delivered_at = new Date().toISOString()
  }
  await supabase.from("gift_cards").update(patch).eq("id", card.id)
}

async function sendGiftCardWhatsAppDocument(
  supabase: AdminClient,
  input: { to: string; link: string; filename: string; caption: string },
): Promise<{ ok: boolean; error: string | null; providerResponse: Record<string, unknown> }> {
  const envToken = Deno.env.get("META_ACCESS_TOKEN") ?? ""
  const envPhoneNumberId = Deno.env.get("META_PHONE_NUMBER_ID") ?? ""
  const settings = (!envToken || !envPhoneNumberId)
    ? await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID).catch(() => null)
    : null
  const accessToken = envToken || settings?.accessToken || ""
  const phoneNumberId = envPhoneNumberId || settings?.row.phone_number_id || ""
  if (!accessToken || !phoneNumberId) {
    return {
      ok: false,
      error: "missing_meta_config",
      providerResponse: { error: "missing_meta_config" },
    }
  }

  const response = await callMetaApi<Record<string, unknown>>(
    `${phoneNumberId}/messages`,
    accessToken,
    {
      method: "POST",
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: input.to,
        type: "document",
        document: {
          link: input.link,
          filename: input.filename,
          caption: input.caption,
        },
      }),
    },
  )
  return {
    ok: response.ok,
    error: response.ok ? null : metaErrorMessage(response.data),
    providerResponse: { ...(response.data ?? {}), http_status: response.status },
  }
}

function buildGiftCardWhatsAppCaption(card: Record<string, unknown>): string {
  return [
    `Hola, ${String(card.recipient_name ?? "te compartimos tu regalo")}.`,
    `${
      String(card.sender_name ?? "Alguien especial")
    } te ha enviado una Gift Card de Sahara Club Spa.`,
    "",
    `Experiencia: ${String(card.service_name ?? card.package_name ?? "Experiencia Sahara")}`,
    `Valida del ${formatDateLongEs(String(card.valid_from ?? "").slice(0, 10))} al ${
      formatDateLongEs(String(card.expires_on ?? "").slice(0, 10))
    }`,
    "",
    "Te compartimos tu tarjeta digital. Para reservar, responde a este mensaje.",
  ].join("\n")
}

async function createGiftCardReceptionAlert(
  supabase: AdminClient,
  input: {
    order: Record<string, unknown>
    item: Record<string, unknown>
    card: Record<string, unknown>
    draft: GiftCardFulfillmentDraft
  },
) {
  try {
    const message = [
      `Gift Card adquirida por ${purchaseChannelLabel(input.draft.purchaseChannel)}.`,
      `Comprador: ${input.draft.purchaserName || "Cliente Sahara"}.`,
      `Destinatario: ${input.draft.recipientName || "Invitada Sahara"}.`,
      `WhatsApp destinatario: ${maskPhone(input.draft.recipientPhone)}.`,
      `Experiencia: ${input.draft.serviceName || input.draft.packageName || "Gift Card Sahara"}.`,
      `Monto pagado: $${roundCurrency(Number(input.item.total_price ?? 0)).toFixed(2)} ${
        String(input.item.currency ?? "MXN").toUpperCase()
      }.`,
      `Vigencia: ${input.draft.validFrom} a ${input.draft.expiresOn}.`,
      `Entrega: ${String(input.card.delivery_status ?? "pending")}.`,
    ].join("\n")

    const { error } = await supabase.from("reception_alerts").insert({
      event_type: "gift_card_purchased",
      booking_id: null,
      client_record_id: null,
      client_name: input.draft.recipientName,
      client_phone: maskPhone(input.draft.recipientPhone),
      service_name: input.draft.serviceName || input.draft.packageName || "Gift Card Sahara",
      channel: input.draft.purchaseChannel,
      message,
      amount_mxn: roundCurrency(Number(input.item.total_price ?? 0)),
      order_id: input.order.id,
      order_item_id: input.item.id,
      gift_card_id: input.card.id,
      buyer_name: input.draft.purchaserName,
      buyer_email: maskEmail(String(input.order.customer_email ?? "")),
      buyer_phone: maskPhone(input.draft.purchaserPhone),
      product_name: String(input.item.product_name ?? input.draft.serviceName),
      face_value: roundCurrency(Number(input.item.total_price ?? 0)),
      amount_paid: roundCurrency(Number(input.item.total_price ?? 0)),
      currency: String(input.item.currency ?? "MXN").toUpperCase(),
      purchase_channel: input.draft.purchaseChannel,
      occurred_at: new Date().toISOString(),
      metadata: {
        recipient_phone_mask: maskPhone(input.draft.recipientPhone),
        gift_card_code_last4: String(input.card.code ?? "").slice(-4),
        valid_from: input.draft.validFrom,
        expires_on: input.draft.expiresOn,
        delivery_status: String(input.card.delivery_status ?? "pending"),
        digital_asset_status: String(input.card.digital_asset_status ?? "pending"),
      },
    })
    if (error && (error as { code?: string } | null)?.code !== "23505") throw error
  } catch (error) {
    console.warn("gift card reception alert failed:", sanitizeTechnicalError(error))
  }
}

export async function createGiftCardSignedUrl(
  supabase: AdminClient,
  path: string,
  ttlSeconds = 60 * 60 * 24 * 7,
): Promise<string> {
  const { data, error } = await supabase.storage.from(GIFT_CARD_BUCKET).createSignedUrl(
    path,
    ttlSeconds,
  )
  if (error) throw error
  return String(data?.signedUrl ?? "")
}

function pdfInputFromCard(card: Record<string, unknown>): GiftCardPdfInput {
  return {
    id: String(card.id ?? ""),
    code: String(card.code ?? ""),
    recipientName: String(card.recipient_name ?? ""),
    senderName: String(card.sender_name ?? ""),
    dedicationMessage: String(card.dedication_message ?? ""),
    productName: String(card.service_name ?? card.package_name ?? "Experiencia Sahara"),
    validFrom: String(card.valid_from ?? "").slice(0, 10),
    expiresOn: String(card.expires_on ?? card.expires_at ?? "").slice(0, 10),
    amount: Number(card.initial_balance ?? 0),
    currency: String(card.currency ?? "MXN"),
  }
}

function canonicalGiftCardDownloadPayload(payload: GiftCardDownloadTokenPayload): string {
  return JSON.stringify({
    version: payload.version,
    purpose: payload.purpose,
    gift_card_id: payload.gift_card_id,
    order_item_id: payload.order_item_id ?? null,
    issued_at: payload.issued_at,
    expires_at: payload.expires_at,
    nonce: payload.nonce,
  })
}

function decodeGiftCardDownloadPayload(
  payloadSegment: string,
): VerifyGiftCardDownloadTokenResult {
  const bytes = base64UrlToBytes(payloadSegment)
  if (!bytes) return { ok: false, error: "malformed_token", status: 400 }
  let parsed: unknown
  try {
    parsed = JSON.parse(new TextDecoder().decode(bytes))
  } catch {
    return { ok: false, error: "malformed_token", status: 400 }
  }
  if (!parsed || typeof parsed !== "object") {
    return { ok: false, error: "malformed_token", status: 400 }
  }
  const row = parsed as Record<string, unknown>
  return {
    ok: true,
    payload: {
      version: Number(row.version),
      purpose: String(row.purpose ?? ""),
      gift_card_id: String(row.gift_card_id ?? ""),
      order_item_id: row.order_item_id === null || row.order_item_id === undefined
        ? null
        : String(row.order_item_id),
      issued_at: Number(row.issued_at),
      expires_at: Number(row.expires_at),
      nonce: String(row.nonce ?? ""),
    },
  }
}

function validateGiftCardDownloadPayload(
  payload: GiftCardDownloadTokenPayload,
  nowSeconds: number,
): VerifyGiftCardDownloadTokenResult {
  if (payload.version !== GIFT_CARD_DOWNLOAD_TOKEN_VERSION) {
    return { ok: false, error: "unsupported_token_version", status: 403 }
  }
  if (payload.purpose !== GIFT_CARD_DOWNLOAD_PURPOSE) {
    return { ok: false, error: "invalid_token_purpose", status: 403 }
  }
  if (!UUID_RE.test(payload.gift_card_id)) {
    return { ok: false, error: "invalid_gift_card_id", status: 400 }
  }
  if (payload.order_item_id && !UUID_RE.test(payload.order_item_id)) {
    return { ok: false, error: "invalid_order_item_id", status: 400 }
  }
  if (!Number.isInteger(payload.issued_at) || !Number.isInteger(payload.expires_at)) {
    return { ok: false, error: "invalid_token_time", status: 400 }
  }
  if (payload.expires_at <= payload.issued_at) {
    return { ok: false, error: "invalid_token_expiration", status: 400 }
  }
  if (payload.expires_at < nowSeconds) {
    return { ok: false, error: "token_expired", status: 403 }
  }
  if (!NONCE_RE.test(payload.nonce)) {
    return { ok: false, error: "invalid_token_nonce", status: 400 }
  }
  return { ok: true, payload }
}

function randomNonce(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24))
  return bytesToBase64Url(bytes)
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}

function base64UrlToBytes(value: string): Uint8Array | null {
  if (!BASE64URL_RE.test(value)) return null
  const padded = value.replace(/-/g, "+").replace(/_/g, "/") +
    "=".repeat((4 - (value.length % 4)) % 4)
  try {
    const binary = atob(padded)
    return Uint8Array.from(binary, (char) => char.charCodeAt(0))
  } catch {
    return null
  }
}

async function hmacSha256Base64Url(value: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value))
  return bytesToBase64Url(new Uint8Array(digest))
}

export function constantTimeEqual(a: string, b: string): boolean {
  let diff = a.length ^ b.length
  const maxLength = Math.max(a.length, b.length)
  for (let index = 0; index < maxLength; index += 1) {
    const left = index < a.length ? a.charCodeAt(index) : 0
    const right = index < b.length ? b.charCodeAt(index) : 0
    diff |= left ^ right
  }
  return diff === 0
}

export async function sha256Hex(value: Uint8Array | string): Promise<string> {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value
  const digest = await crypto.subtle.digest("SHA-256", copyBytesToArrayBuffer(bytes))
  return bytesToHex(new Uint8Array(digest))
}

function copyBytesToArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength)
  copy.set(bytes)
  return copy.buffer
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0")).join("")
}

function dataUrlToBytes(dataUrl: string): Uint8Array {
  const [, payload = ""] = dataUrl.split(",")
  const binary = atob(payload)
  return Uint8Array.from(binary, (char) => char.charCodeAt(0))
}

function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate()
}

function pad2(value: number): string {
  return String(value).padStart(2, "0")
}

function roundCurrency(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

function cleanDisplayName(value: unknown, fallback: string): string {
  const clean = String(value ?? "").replace(/\s+/g, " ").trim()
  return clean || fallback
}

function assignIfMissing(
  patch: Record<string, unknown>,
  card: Record<string, unknown>,
  key: string,
  value: unknown,
) {
  const current = card[key]
  const missing = current === null || current === undefined ||
    (typeof current === "string" && current.trim() === "") ||
    (typeof current === "object" && Object.keys(current as Record<string, unknown>).length === 0)
  if (missing && value !== null && value !== undefined && String(value).trim() !== "") {
    patch[key] = value
  }
}

function wrapText(text: string, font: PDFFont, size: number, maxWidth: number) {
  const output: string[] = []
  for (const paragraph of String(text ?? "").split("\n")) {
    let line = ""
    for (const word of paragraph.split(/\s+/).filter(Boolean)) {
      const candidate = line ? `${line} ${word}` : word
      if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
        line = candidate
      } else {
        if (line) output.push(line)
        line = word
      }
    }
    if (line) output.push(line)
  }
  return output
}

function drawCenteredWrapped(
  page: PDFPage,
  text: string,
  font: PDFFont,
  size: number,
  color: ReturnType<typeof rgb>,
  startY: number,
  x: number,
  maxWidth: number,
  lineHeight: number,
) {
  let y = startY
  for (const line of wrapText(text, font, size, maxWidth).slice(0, 3)) {
    const lineX = x + (maxWidth - font.widthOfTextAtSize(line, size)) / 2
    page.drawText(line, { x: lineX, y, font, size, color })
    y -= lineHeight
  }
}

function formatDateLongEs(value: string): string {
  try {
    const { year, month, day } = parseLocalDate(value)
    const months = [
      "enero",
      "febrero",
      "marzo",
      "abril",
      "mayo",
      "junio",
      "julio",
      "agosto",
      "septiembre",
      "octubre",
      "noviembre",
      "diciembre",
    ]
    return `${day} de ${months[month - 1]} de ${year}`
  } catch {
    return value || "fecha pendiente"
  }
}

function purchaseChannelLabel(value: string): string {
  switch (value) {
    case "web":
      return "pagina web"
    case "whatsapp":
      return "WhatsApp"
    case "reception":
      return "recepcion"
    default:
      return "canal no identificado"
  }
}

function maskEmail(value: string): string {
  const [name, domain] = String(value ?? "").split("@")
  if (!name || !domain) return ""
  return `${name.slice(0, 2)}***@${domain}`
}

function metaErrorMessage(data: Record<string, unknown>): string {
  const error = data.error as Record<string, unknown> | undefined
  return String(error?.message ?? data.message ?? "meta_delivery_failed").slice(0, 240)
}

function sanitizeTechnicalError(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error ?? "")
  return message.replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "[email]")
    .replace(/\+?\d[\d\s().-]{8,}\d/g, "[phone]")
    .slice(0, 240)
}

function generateGiftCardCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  let code = "SAHARA-"
  const values = crypto.getRandomValues(new Uint8Array(8))
  for (const value of values) code += alphabet[value % alphabet.length]
  return code
}

function isAllowedDedicationChar(char: string): boolean {
  const code = char.charCodeAt(0)
  if (code === 9 || code === 10) return true
  if (code < 32 || code === 127) return false
  return true
}
