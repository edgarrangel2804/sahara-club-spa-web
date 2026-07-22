// Sahara Club Spa - send_deposit_receipt
// ---------------------------------------------------------------------------
// Genera el comprobante PDF del anticipo de una cita, lo guarda en el bucket
// privado `receipts` y se lo envía al cliente por WhatsApp como documento.
//
// Body: { booking_id: uuid, force?: boolean }
// Response 200: { ok, folio, receipt_path, signed_url, whatsapp_sent }
//
// verify_jwt=false: lo invoca el stripe_webhook (server-to-server) y también
// puede llamarlo recepción desde el panel para reenviar el comprobante.
//
// Diseño: best-effort. Si WhatsApp falla (p.ej. ventana de 24h cerrada), el
// PDF igual queda guardado y devolvemos la URL firmada para que recepción lo
// reenvíe a mano. Nunca lanza para no romper el flujo de pago que lo invoca.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { PDFDocument, rgb, StandardFonts } from "https://esm.sh/pdf-lib@1.17.1?target=deno"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  })
}

function createAdminClient(): any {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

// Trazabilidad (auditoría): registra en whatsapp_logs cada mensaje saliente.
// Best-effort: nunca lanza, no debe romper el flujo si el log falla.
async function logOutbound(
  sb: any,
  opts: {
    phone: string
    body: string
    eventType: string
    status?: string
    reservationId?: string | null
    customerId?: string | null
    windowType?: string
  },
): Promise<void> {
  try {
    await sb.from("whatsapp_logs").insert({
      phone: normalizePhone(opts.phone),
      message_rendered: opts.body,
      event_type: opts.eventType,
      type: opts.eventType,
      status: opts.status ?? "sent",
      reservation_id: opts.reservationId ?? null,
      customer_id: opts.customerId ?? null,
      window_type: opts.windowType ?? "free_text",
      provider: "meta",
      sent_at: new Date().toISOString(),
    })
  } catch (e) {
    console.warn("logOutbound failed:", (e as Error).message)
  }
}

// Folio determinista derivado del booking_id. Un reenvío produce el mismo folio.
function folioFromBooking(bookingId: string): string {
  return "SAHARA-" + bookingId.replace(/-/g, "").slice(0, 8).toUpperCase()
}

// Normaliza el teléfono a solo dígitos para el campo `to` de WhatsApp.
// Quita el prefijo de marcación internacional "00" (números del extranjero).
function normalizePhone(raw: string): string {
  let clean = String(raw ?? "").replace(/\D/g, "")
  if (clean.startsWith("00")) clean = clean.slice(2)
  // Número nacional MX de 10 dígitos → anteponer código de país 52.
  if (clean.length === 10) clean = "52" + clean
  return clean
}

function fmtDateLong(dateStr: string): string {
  // dateStr esperado: YYYY-MM-DD
  try {
    const [y, m, d] = dateStr.split("-").map((n) => parseInt(n, 10))
    const meses = [
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
    return `${d} de ${meses[(m - 1) % 12]} de ${y}`
  } catch {
    return dateStr
  }
}

function fmtTime(timeStr: string): string {
  // timeStr esperado: HH:MM:SS o HH:MM
  if (!timeStr) return ""
  const [hStr, min] = timeStr.split(":")
  let h = parseInt(hStr, 10)
  const ampm = h >= 12 ? "PM" : "AM"
  h = h % 12
  if (h === 0) h = 12
  return `${h}:${min} ${ampm}`
}

async function buildReceiptPdf(opts: {
  folio: string
  emittedAt: Date
  customerName: string
  serviceName: string
  bookingDate: string
  bookingTime: string
  amount: number
  currency: string
  paymentIntentId: string
}): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  // Formato tipo recibo vertical (media carta aprox).
  const page = doc.addPage([396, 612])
  const { width, height } = page.getSize()

  const serif = await doc.embedFont(StandardFonts.TimesRoman)
  const serifBold = await doc.embedFont(StandardFonts.TimesRomanBold)
  const sans = await doc.embedFont(StandardFonts.Helvetica)
  const sansBold = await doc.embedFont(StandardFonts.HelveticaBold)

  const cream = rgb(0.957, 0.937, 0.906) // #F4EFE7
  const gold = rgb(0.776, 0.655, 0.416) // #C6A76A
  const dark = rgb(0.118, 0.118, 0.118) // #1E1E1E
  const grayText = rgb(0.42, 0.42, 0.42)

  // Fondo crema
  page.drawRectangle({ x: 0, y: 0, width, height, color: cream })
  // Marco dorado sutil
  page.drawRectangle({
    x: 18,
    y: 18,
    width: width - 36,
    height: height - 36,
    borderColor: gold,
    borderWidth: 1,
    color: undefined,
  })

  const cx = width / 2
  const center = (text: string, font: typeof serif, size: number) =>
    cx - font.widthOfTextAtSize(text, size) / 2

  // Encabezado
  let y = height - 70
  const brand = "SAHARA CLUB SPA"
  page.drawText(brand, {
    x: center(brand, serifBold, 22),
    y,
    font: serifBold,
    size: 22,
    color: gold,
  })
  y -= 22
  const sub = "Comprobante de anticipo"
  page.drawText(sub, { x: center(sub, serif, 12), y, font: serif, size: 12, color: dark })

  // Línea dorada
  y -= 22
  page.drawLine({
    start: { x: 40, y },
    end: { x: width - 40, y },
    thickness: 1,
    color: gold,
  })

  // Sello "PAGADO"
  y -= 34
  const badge = "PAGADO"
  const badgeSize = 13
  const badgeW = sansBold.widthOfTextAtSize(badge, badgeSize) + 24
  page.drawRectangle({
    x: cx - badgeW / 2,
    y: y - 6,
    width: badgeW,
    height: 24,
    color: gold,
  })
  page.drawText(badge, {
    x: cx - sansBold.widthOfTextAtSize(badge, badgeSize) / 2,
    y,
    font: sansBold,
    size: badgeSize,
    color: cream,
  })

  // Campos (etiqueta + valor)
  y -= 44
  const rows: Array<[string, string]> = [
    ["Folio", opts.folio],
    [
      "Fecha de emisión",
      fmtDateLong(
        `${opts.emittedAt.getFullYear()}-${
          String(opts.emittedAt.getMonth() + 1).padStart(2, "0")
        }-${String(opts.emittedAt.getDate()).padStart(2, "0")}`,
      ),
    ],
    ["Cliente", opts.customerName],
    ["Servicio", opts.serviceName],
    ["Fecha de la cita", fmtDateLong(opts.bookingDate)],
    ["Hora", fmtTime(opts.bookingTime)],
    ["Método de pago", "Tarjeta (Stripe)"],
  ]

  const labelX = 44
  const valueX = width - 44
  for (const [label, value] of rows) {
    page.drawText(label.toUpperCase(), {
      x: labelX,
      y,
      font: sansBold,
      size: 8,
      color: grayText,
    })
    page.drawText(value || "—", {
      x: valueX - serif.widthOfTextAtSize(value || "—", 12),
      y: y - 1,
      font: serif,
      size: 12,
      color: dark,
    })
    y -= 14
    page.drawLine({
      start: { x: labelX, y: y + 4 },
      end: { x: valueX, y: y + 4 },
      thickness: 0.4,
      color: rgb(0.85, 0.82, 0.77),
    })
    y -= 14
  }

  // Monto destacado
  y -= 10
  page.drawRectangle({
    x: 40,
    y: y - 30,
    width: width - 80,
    height: 46,
    color: rgb(0.93, 0.90, 0.85),
  })
  page.drawText("ANTICIPO PAGADO", { x: 52, y: y - 2, font: sansBold, size: 9, color: grayText })
  const amountStr = `$${
    opts.amount.toLocaleString("es-MX", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  } ${opts.currency.toUpperCase()}`
  page.drawText(amountStr, {
    x: valueX - serifBold.widthOfTextAtSize(amountStr, 20),
    y: y - 14,
    font: serifBold,
    size: 20,
    color: gold,
  })

  // Nota
  y -= 64
  const note = [
    "Este comprobante ampara el anticipo de tu cita. El monto se",
    "aplica al costo total del servicio. Conserva este documento y",
    "preséntalo en recepción el día de tu cita.",
  ]
  for (const line of note) {
    page.drawText(line, { x: 44, y, font: sans, size: 9, color: grayText })
    y -= 13
  }

  // Pie de página
  const footY = 40
  page.drawLine({
    start: { x: 40, y: footY + 22 },
    end: { x: width - 40, y: footY + 22 },
    thickness: 0.5,
    color: gold,
  })
  const foot1 = "Calle Segunda 2226, 22880 Ensenada, B.C."
  const foot2 = "Tel. 646 151 9597  ·  saharaclubspa.com"
  page.drawText(foot1, {
    x: center(foot1, sans, 8),
    y: footY + 8,
    font: sans,
    size: 8,
    color: grayText,
  })
  page.drawText(foot2, {
    x: center(foot2, sans, 8),
    y: footY - 4,
    font: sans,
    size: 8,
    color: grayText,
  })

  return await doc.save()
}

async function sendWhatsAppDocument(opts: {
  to: string
  link: string
  filename: string
  caption: string
}): Promise<boolean> {
  const token = Deno.env.get("META_ACCESS_TOKEN") ?? ""
  let phoneNumberId = Deno.env.get("META_PHONE_NUMBER_ID") ?? ""

  // Fallback a la configuración en DB si no están en env.
  if (!token || !phoneNumberId) {
    const supabase = createAdminClient()
    const { data } = await supabase
      .from("business_whatsapp_settings")
      .select("phone_number_id")
      .eq("is_active", true)
      .maybeSingle()
    phoneNumberId = (data as { phone_number_id?: string } | null)?.phone_number_id ?? phoneNumberId
  }
  if (!token || !phoneNumberId) {
    console.warn("send_deposit_receipt: faltan credenciales Meta")
    return false
  }

  const res = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
    method: "POST",
    headers: { "content-type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: opts.to,
      type: "document",
      document: { link: opts.link, filename: opts.filename, caption: opts.caption },
    }),
  })
  if (!res.ok) {
    const txt = await res.text().catch(() => "")
    console.warn("send_deposit_receipt: WhatsApp rechazó el documento:", res.status, txt)
    return false
  }
  return true
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405)

  try {
    const body = await req.json().catch(() => ({}))
    const bookingId = String(body.booking_id ?? "").trim()
    if (!bookingId) return json({ ok: false, error: "booking_id_required" }, 400)

    const supabase = createAdminClient()

    // 1. Cargar booking + cliente
    const { data: booking, error: bErr } = await supabase
      .from("bookings")
      .select(
        "id, status, booking_date, booking_time, service_name, service_id, " +
          "deposit_amount, stripe_payment_intent_id, client_record_id",
      )
      .eq("id", bookingId)
      .maybeSingle()
    if (bErr) throw bErr
    if (!booking) return json({ ok: false, error: "booking_not_found" }, 404)

    const { data: client } = await supabase
      .from("clients")
      .select("full_name, phone")
      .eq("id", booking.client_record_id)
      .maybeSingle()
    const customerName = (client as { full_name?: string } | null)?.full_name ?? "Cliente"
    const phone = (client as { phone?: string } | null)?.phone ?? ""

    // Nombre del servicio: usa el de la cita; si falta, lo busca en services.
    let serviceName = booking.service_name ?? ""
    if (!serviceName && booking.service_id) {
      const { data: svc } = await supabase
        .from("services").select("name").eq("id", booking.service_id).maybeSingle()
      serviceName = (svc as { name?: string } | null)?.name ?? "Servicio"
    }

    // Moneda configurada para el anticipo.
    const { data: ai } = await supabase
      .from("ai_settings")
      .select("appointment_deposit_currency")
      .eq("id", 1)
      .maybeSingle()
    const currency = String(
      (ai as { appointment_deposit_currency?: string } | null)?.appointment_deposit_currency ??
        "MXN",
    )

    const folio = folioFromBooking(bookingId)
    const amount = Number(booking.deposit_amount ?? 200)

    // 2. Generar PDF
    const pdfBytes = await buildReceiptPdf({
      folio,
      emittedAt: new Date(),
      customerName,
      serviceName: serviceName || "Servicio",
      bookingDate: String(booking.booking_date ?? ""),
      bookingTime: String(booking.booking_time ?? ""),
      amount,
      currency,
      paymentIntentId: String(booking.stripe_payment_intent_id ?? ""),
    })

    // 3. Subir al bucket privado (overwrite para reenvíos idempotentes)
    const path = `${bookingId}.pdf`
    const { error: upErr } = await supabase.storage
      .from("receipts")
      .upload(path, pdfBytes, { contentType: "application/pdf", upsert: true })
    if (upErr) throw upErr

    // 4. URL firmada (7 días) — Meta descarga el archivo al enviarlo.
    const { data: signed, error: signErr } = await supabase.storage
      .from("receipts")
      .createSignedUrl(path, 60 * 60 * 24 * 7)
    if (signErr) throw signErr
    const signedUrl = signed?.signedUrl ?? ""

    // 5. Enviar al cliente por WhatsApp como documento (best-effort)
    let whatsappSent = false
    const to = normalizePhone(phone)
    if (to && signedUrl) {
      const caption = [
        "🌿 *Sahara Club Spa*",
        `Comprobante de tu anticipo · Folio ${folio}`,
        `${serviceName || "Servicio"} · ${fmtDateLong(String(booking.booking_date ?? ""))} ${
          fmtTime(String(booking.booking_time ?? ""))
        }`,
        "",
        "¡Gracias! Te esperamos. Tu cita está pendiente de confirmación por recepción.",
      ].join("\n")
      try {
        whatsappSent = await sendWhatsAppDocument({
          to,
          link: signedUrl,
          filename: `Comprobante-anticipo-${folio}.pdf`,
          caption,
        })
      } catch (e) {
        console.warn("send_deposit_receipt: error enviando documento:", (e as Error).message)
      }
      // Trazabilidad (auditoría): registra el envío del comprobante en whatsapp_logs.
      await logOutbound(supabase, {
        phone: to,
        body: caption,
        eventType: "deposit_receipt",
        windowType: "document",
        reservationId: bookingId,
        customerId: booking.client_record_id ?? null,
        status: whatsappSent ? "sent" : "failed",
      })
    }

    return json({
      ok: true,
      folio,
      receipt_path: path,
      signed_url: signedUrl,
      whatsapp_sent: whatsappSent,
    })
  } catch (e) {
    console.error("send_deposit_receipt error:", (e as Error).message)
    return json({ ok: false, error: (e as Error).message }, 500)
  }
})
