// Sahara Club Spa — Concierge web (chat embebido en la landing).
// Hermano del bot de WhatsApp pero por chat web: informa servicios/precios,
// responde dudas, crea la reserva PENDIENTE y devuelve el link de anticipo ($200).
// Reutiliza las MISMAS RPCs que el bot de WhatsApp (check_availability_for_booking_from_ai,
// create_pending_booking_from_ai, check_booking_payment_requirement).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  checkRateLimit,
  clientIpKey,
  jsonResponseFor,
  preflightResponse,
  sanitizeTechnicalLog,
} from "../_shared/runtime_security.ts"

const BRANCH = "11111111-1111-1111-1111-111111111111"
const MAX_BODY_BYTES = 32_000
const MAX_MESSAGES = 16
const MAX_MESSAGE_CHARS = 1200

const DAYS = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
const MONTHS = [
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

function tjNow(): Date {
  return new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
}

// Tabla de los próximos 45 días, marcando domingos cerrados.
function fechasTable(): string {
  const now = tjNow()
  const out: string[] = []
  for (let i = 0; i < 45; i++) {
    const d = new Date(now.getTime() + i * 86400000)
    const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${
      String(d.getDate()).padStart(2, "0")
    }`
    const tag = i === 0 ? " (HOY)" : i === 1 ? " (mañana)" : ""
    const closed = d.getDay() === 0 ? "  ❌ CERRADO (domingo)" : ""
    out.push(
      `  ${DAYS[d.getDay()]} ${d.getDate()} de ${MONTHS[d.getMonth()]} → ${iso}${tag}${closed}`,
    )
  }
  return out.join("\n")
}

Deno.serve(async (req: Request) => {
  const json = (body: unknown, status = 200) => jsonResponseFor(req, body, status)
  if (req.method === "OPTIONS") return preflightResponse(req)
  if (req.method !== "POST") return json({ reply: "Metodo no permitido." }, 405)

  try {
    const contentLength = Number(req.headers.get("content-length") ?? 0)
    if (contentLength > MAX_BODY_BYTES) {
      return json({
        reply: "El mensaje es demasiado largo. Escríbenos por WhatsApp y te ayudamos.",
      }, 413)
    }
    const rateLimit = checkRateLimit(`web-concierge:${clientIpKey(req)}`, {
      maxAttempts: 20,
      windowMs: 10 * 60 * 1000,
    })
    if (!rateLimit.ok) {
      return json({
        reply: "Recibimos muchas solicitudes seguidas. Intenta de nuevo en unos minutos.",
      }, 429)
    }

    const body = await req.json().catch(() => ({}))
    const messages = normalizeMessages(Array.isArray(body.messages) ? body.messages : [])

    const sb: any = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    const { data: settings } = await sb.from("ai_settings").select("*").eq("id", 1).maybeSingle()
    if (
      !settings || settings.ai_enabled === false || settings.ai_mode === "disabled" ||
      settings.ai_pause_all_conversations === true
    ) {
      return json({
        reply:
          "Por ahora el asistente está en pausa. Escríbenos por WhatsApp y con gusto te ayudamos. 🤍",
      })
    }

    // API key de Anthropic desde el Vault (mismo método que el bot de WhatsApp).
    let apiKey = ""
    try {
      const { data: k } = await sb.rpc("get_anthropic_api_key")
      apiKey = String(k || "")
    } catch (_) { /* noop */ }
    if (!apiKey) {
      return json({
        reply: "El asistente con IA se está conectando. Escríbenos por WhatsApp y te ayudamos. ✨",
      })
    }

    const depositAmount = Number(settings.appointment_deposit_amount ?? 200)
    const depositEnabled = settings.appointment_deposit_enabled !== false

    const [{ data: services }, { data: faqs }, { data: hours }] = await Promise.all([
      sb.from("services").select("id,name,duration_min,price,price_on_quote,category").eq(
        "is_active",
        true,
      ).order("category").order("name").limit(120),
      sb.from("faqs").select("question,answer").eq("is_active", true).eq("scope_category", "sahara")
        .limit(40),
      sb.from("business_hours").select("weekday,opens_at,closes_at,is_closed").eq(
        "branch_id",
        BRANCH,
      ).order("weekday"),
    ])

    const catalogo = (services || []).map((s: any) => {
      const precio = s.price_on_quote ? "precio a cotizar" : `$${Number(s.price ?? 0)} MXN`
      return `- ${s.name} · ${s.duration_min ?? 60} min · ${precio} · id:${s.id}`
    }).join("\n")

    const dn = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    const horario = (hours || []).map((h: any) =>
      `${dn[h.weekday]}: ${
        h.is_closed
          ? "Cerrado"
          : `${String(h.opens_at).slice(0, 5)}–${String(h.closes_at).slice(0, 5)}`
      }`
    ).join("\n")
    const faqStr = (faqs || []).map((f: any) => `P: ${f.question}\nR: ${f.answer}`).join("\n\n")

    const system = [
      "Eres el concierge de Sahara Club Spa (spa de bienestar en Ensenada, BC). Asesoras al cliente y captas su intención de reserva con calidez y brevedad (2-4 frases). Recepción confirma toda cita.",
      "\n⛔ HORARIO: abrimos de LUNES a SÁBADO. Los DOMINGOS está CERRADO. NUNCA ofrezcas ni agendes en domingo.",
      "\n=== HORARIOS ===\n" + horario,
      "\n=== FECHAS (próximos 45 días, no calcules, usa esta tabla) ===\n" + fechasTable(),
      "\n=== SERVICIOS (única fuente de precios; NUNCA inventes precios) ===\n" + catalogo,
      "\n=== PREGUNTAS FRECUENTES ===\n" + faqStr,
      "\nReglas: responde en español, cálido y breve. No inventes servicios, precios ni horarios. No des consejo médico. Las cancelaciones y reembolsos los maneja recepción (no tú).",
      `\n=== AGENDAR (importante) ===\nPara reservar requieres: servicio (de la lista), fecha, hora, NOMBRE COMPLETO del cliente, un TELÉFONO de contacto y un EMAIL (para enviarle el comprobante del anticipo). Cuando tengas TODO, confirma con calidez que dejas su cita en estado PENDIENTE y que para apartarla se requiere un anticipo de $${depositAmount} MXN. En ESE mismo mensaje agrega al FINAL una última línea EXACTAMENTE con este formato (sin explicarla ni mencionar el id al cliente):\n[[RESERVA]]{"service_id":"UUID","fecha":"YYYY-MM-DD","hora":"HH:MM","nombre":"","telefono":"","email":""}\nUsa el id exacto del servicio de la lista. Inclúyela SOLO la primera vez que confirmas; no la repitas. Si falta algún dato, pídelo; no emitas la línea hasta tener servicio, fecha, hora, nombre completo, teléfono y email.`,
      `\n=== CONTACTO / RECEPCIÓN ===\nTeléfono y WhatsApp de recepción: 646 151 9597 (lunes a sábado, 10:00 a 19:00). Si el cliente pide el número, dáselo SIEMPRE.`,
      `\n=== CONSULTAR / CAMBIAR / CANCELAR UNA CITA (importante) ===\nTú NO puedes ver, consultar, cambiar, reagendar ni cancelar citas ya agendadas. NUNCA pidas datos con la promesa de "buscar" la cita (no la puedes buscar). Si el cliente quiere consultar, cambiar, reagendar o cancelar su cita —o dice que olvidó su cita— NO prometas buscarla: deriva de inmediato y con calidez a WhatsApp, donde el equipo sí lo atiende: "Para consultar o cambiar tu cita te ayudamos por WhatsApp al 646 151 9597 (lun a sáb, 10:00 a 19:00) 🌿, ahí la revisamos al momento." Tu única función aquí es AGENDAR citas nuevas e informar (servicios, precios, horarios).`,
    ].join("\n")

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: settings.active_model || settings.llm_model || "claude-haiku-4-5",
        max_tokens: 700,
        system,
        messages: messages.map((m: any) => ({
          role: m.role === "assistant" ? "assistant" : "user",
          content: String(m.content || ""),
        })),
      }),
    })
    if (!resp.ok) {
      console.error("Anthropic", resp.status, sanitizeTechnicalLog(await resp.text()))
      return json({
        reply: "Tuve un problema para responder. Escríbenos por WhatsApp y te ayudamos. 🤍",
      })
    }
    const data = await resp.json()
    let reply = data?.content?.find((c: any) => c.type === "text")?.text ||
      "Lo siento, no pude responder. Escríbenos por WhatsApp."

    // ¿Solicitud de reserva?
    const tag = "[[RESERVA]]"
    const idx = reply.indexOf(tag)
    if (idx >= 0) {
      const after = reply.slice(idx + tag.length)
      reply = reply.slice(0, idx).trim()
      let r: any = {}
      try {
        const m = after.match(/\{[\s\S]*\}/)
        r = m ? JSON.parse(m[0]) : {}
      } catch (_) { /* noop */ }

      const serviceId = String(r.service_id || "").trim()
      const fecha = String(r.fecha || "").trim()
      const hora = String(r.hora || "").trim()
      const nombre = String(r.nombre || "").trim().replace(/\s+/g, " ")
      const telefono = String(r.telefono || "").trim()
      const email = String(r.email || "").trim()

      // 🪪 Nombre real obligatorio (nombre + apellido, no genérico): el voucher y
      // la agenda deben salir con el nombre del cliente, no "Cliente".
      const nombreOk = nombre.length >= 3 &&
        !/^(cliente(\s+whats?app|\s+web)?|whats?app|sin\s+nombre|invitad[oa]|test|prueba)$/i.test(
          nombre,
        ) &&
        nombre.split(" ").filter((w) => /[a-zA-ZÀ-ÿ]{2,}/.test(w)).length >= 2

      let done = false
      // Falta el nombre completo: lo pedimos antes de intentar reservar.
      if (serviceId && fecha && hora && telefono && !nombreOk) {
        reply +=
          `\n\nPara dejar lista tu reserva, ¿me confirmas tu *nombre completo* (nombre y apellido) y un *correo* para enviarte el comprobante? 🌿`
        done = true
      }
      if (!done && serviceId && fecha && hora && telefono && nombreOk) {
        try {
          const timeNorm = hora.length === 5 ? `${hora}:00` : hora
          const { data: avail } = await sb.rpc("check_availability_for_booking_from_ai", {
            p_service_id: serviceId,
            p_requested_date: fecha,
            p_requested_time: timeNorm,
            p_duration_min: null,
            p_branch_id: BRANCH,
            p_staff_id: null,
          })
          if ((avail as any)?.available === true) {
            const { data: created } = await sb.rpc("create_pending_booking_from_ai", {
              p_phone: telefono,
              p_client_name: nombre,
              p_email: email || null,
              p_service_id: serviceId,
              p_booking_date: fecha,
              p_booking_time: timeNorm,
              p_duration_min: null,
              p_notes: "Solicitud creada por concierge web.",
              p_ai_conversation_id: null,
              p_ai_confidence_score: 0.9,
              p_therapist_id: null,
            })
            const bookingId = (created as any)?.booking_id
            if (bookingId) {
              // 🌐 Origen real: esta cita nació en el CONCIERGE WEB, no en el bot
              // de WhatsApp. El RPC compartido la marca como 'whatsapp_ai', así
              // que la corregimos para que la agenda muestre "Página web".
              await sb.from("bookings").update({
                booking_source: "web_concierge",
                source_platform: "web",
              }).eq("id", bookingId)
              // ¿Aplica waiver (gift card/membresía) o requiere anticipo?
              const { data: req } = await sb.rpc("check_booking_payment_requirement", {
                p_phone: telefono,
                p_service_id: serviceId,
                p_requested_date: fecha,
                p_requested_time: timeNorm,
                p_customer_name: nombre,
              })
              const requiresDeposit = (req as any)?.requires_deposit !== false
              if (requiresDeposit && depositEnabled) {
                const cents = Number((req as any)?.deposit_required_cents ?? depositAmount * 100)
                await sb.from("bookings").update({
                  status: "pending_payment",
                  payment_requirement: "deposit_required",
                  deposit_required_cents: cents,
                  deposit_amount: cents / 100,
                  payment_status: "pending",
                }).eq("id", bookingId)
                // La página /pagar-anticipo no existe en el front (regresaba a
                // la home). Generamos la sesión de Stripe Checkout y entregamos
                // el link DIRECTO a la pasarela segura ($200, con la cita).
                // Al pagar, el webhook confirma la cita y envía el comprobante.
                let payUrl = ""
                try {
                  const { data: co } = await sb.functions.invoke(
                    "create_booking_deposit_checkout",
                    {
                      body: { booking_id: bookingId, amount: cents / 100 },
                    },
                  )
                  payUrl = String((co as any)?.checkout_url ?? "")
                } catch (e) {
                  console.error("checkout web", sanitizeTechnicalLog(e))
                }
                if (payUrl) {
                  reply += `\n\nPara apartar tu cita realiza el anticipo de $${
                    cents / 100
                  } MXN aquí:\n${payUrl}\nAl completar el pago tu cita queda confirmada y te enviamos tu comprobante. 🌿`
                } else {
                  reply += `\n\nPara apartar tu cita se requiere un anticipo de $${
                    cents / 100
                  } MXN. Recepción te enviará el link de pago en breve. 🌿`
                }
              } else {
                reply +=
                  `\n\n¡Listo! Tu solicitud quedó registrada. Recepción la valida y te confirma en breve. 🌿`
              }
              done = true
            }
          } else {
            reply +=
              `\n\nEse horario no está disponible. Recepción te ayudará a encontrar el más cercano. 🌿`
            done = true
          }
        } catch (e) {
          console.error("reserva web", sanitizeTechnicalLog(e))
        }
      }
      if (!done) {
        reply += `\n\nTomamos tu interés; recepción te contactará para afinar los detalles. 🌿`
      }
    }

    return json({ reply })
  } catch (e) {
    console.error(sanitizeTechnicalLog(e))
    return json({ reply: "Ocurrió un error. Escríbenos por WhatsApp y te ayudamos." })
  }
})

function normalizeMessages(
  rawMessages: unknown[],
): Array<{ role: "assistant" | "user"; content: string }> {
  return rawMessages
    .slice(-MAX_MESSAGES)
    .map((m: any) => ({
      role: m?.role === "assistant" ? "assistant" as const : "user" as const,
      content: String(m?.content ?? "").replace(/\s+/g, " ").trim().slice(0, MAX_MESSAGE_CHARS),
    }))
    .filter((message) => message.content.length > 0)
}
