// Sahara Club Spa - Agente recepcionista F2 (read-only, modo piloto)
// Invocado desde whatsapp-webhook cuando llega un message inbound.
// Solo responde a teléfonos en ai_settings.pilot_phones cuando ai_enabled=true.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  corsHeaders,
  DEFAULT_BRANCH_ID,
  loadBusinessSettings,
  normalizePhone,
  callMetaApi,
} from "../_shared/whatsapp_business.ts"

type Settings = {
  ai_enabled: boolean
  ai_mode: "disabled" | "pilot" | "read_only" | "assisted"
  pilot_mode: boolean
  pilot_phones: string[]
  allowed_test_numbers: string[]
  llm_model: string
  active_model: string
  temperature: number
  max_output_tokens: number
  cost_per_million_input_usd: number
  cost_per_million_output_usd: number
  max_msgs_per_phone_24h: number
  max_tokens_per_conversation: number
  ai_pause_all_conversations: boolean
  handoff_human_priority: boolean
  allow_after_hours_responses: boolean
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
)

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

// ---------------------------------------------------------------------------
// Soft closings: cierre cálido sin consumir tokens del LLM.
// Devuelve "soft_closing" | "ignore" | "normal"
// ---------------------------------------------------------------------------
function classifyShortMessage(rawText: string): "soft_closing" | "ignore" | "normal" {
  const text = (rawText || "")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // sin acentos
    .replace(/[¿¡!?.,;:]/g, "")      // sin signos
    .trim()
    .toLowerCase()

  if (text.length === 0) return "ignore"

  // Soft closings: agradecimientos / aceptaciones explícitas
  const softClosings = new Set([
    "gracias", "gracias!", "muchas gracias", "mil gracias",
    "ok gracias", "okay gracias", "sale gracias",
    "ok muchas gracias", "okay muchas gracias", "ok mil gracias", "okay mil gracias",
    "perfecto", "perfecto gracias", "excelente",
    "perfecto muchas gracias", "excelente gracias", "excelente muchas gracias",
    "muy bien", "muy bien gracias", "buenisimo", "buenisimo gracias",
    "entendido", "entendido gracias",
    "listo", "listo gracias",
    "sale", "ok sale",
    "genial", "genial gracias",
    "a la orden", "de nada",
    "todo bien", "todo bien gracias",
  ])

  // Quita emojis y trims múltiples espacios para matchear
  const cleaned = text
    .replace(/[\u{1F300}-\u{1FAFF}\u{1F000}-\u{1F02F}\u{2600}-\u{27BF}✨🌿💆‍♀️]/gu, "")
    .replace(/\s+/g, " ")
    .trim()

  if (softClosings.has(cleaned)) return "soft_closing"

  // Ignorar (no responder)
  // - Solo emojis
  // - "ok" o "okay" pelado (sin gracias)
  // - jajaja / hahaha / lol
  // - Hasta 2 chars
  const onlyEmojis = /^[\s\u{1F300}-\u{1FAFF}\u{1F000}-\u{1F02F}\u{2600}-\u{27BF}✨🌿💆‍♀️👍👌🙏❤️♥️💕😊😀😁]+$/u
    .test(rawText.trim())
  if (onlyEmojis) return "ignore"

  if (cleaned === "ok" || cleaned === "okay" || cleaned === "k") return "ignore"
  if (/^(ja|ha|je)+$/.test(cleaned)) return "ignore"
  if (cleaned === "lol" || cleaned === "lmao") return "ignore"

  return "normal"
}

// Pool de cierres cálidos. Variación por seed (no random puro para auditar).
// Tus dos preferidas primero, el resto como variación.
const SOFT_CLOSING_REPLIES: ReadonlyArray<string> = [
  "Es un placer ayudarte ✨",
  "Estoy aquí para lo que necesites ✨",
  "Con mucho gusto ✨",
  "Cuando gustes, aquí estaré ✨",
  "Que tengas excelente día ✨",
  "Para servirte 🌿",
  "Un placer 🌿",
  "A la orden ✨",
]

function pickSoftClosing(seed: string): string {
  let h = 0
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0
  return SOFT_CLOSING_REPLIES[h % SOFT_CLOSING_REPLIES.length]
}

// ---------------------------------------------------------------------------
// Human backup: alerta a número operativo cuando IA no responde.
// Dedup: una sola alerta por phone cada N min (config en ai_settings).
// ---------------------------------------------------------------------------
async function notifyHumanBackup(
  customerPhone: string,
  customerMessage: string,
  reason: string,
): Promise<{ sent: boolean; reason?: string; recipients?: number }> {
  const { data: s } = await supabase
    .from("ai_settings")
    .select("human_backup_enabled, human_backup_numbers, human_backup_dedup_minutes")
    .eq("id", 1).maybeSingle()
  const enabled = (s as { human_backup_enabled?: boolean })?.human_backup_enabled === true
  const numbers = ((s as { human_backup_numbers?: string[] })?.human_backup_numbers ?? []) as string[]
  const dedupMinutes = (s as { human_backup_dedup_minutes?: number })?.human_backup_dedup_minutes ?? 15

  if (!enabled || numbers.length === 0) {
    return { sent: false, reason: "disabled_or_no_recipients" }
  }

  // Dedup: ¿ya se envió alerta por ESTE phone (cliente) en los últimos N min?
  const since = new Date(Date.now() - dedupMinutes * 60 * 1000).toISOString()
  const { data: recent } = await supabase
    .from("whatsapp_logs")
    .select("id")
    .eq("event_type", "human_backup_alert")
    .ilike("message_rendered", `%${customerPhone}%`)
    .gte("created_at", since)
    .limit(1)
  if ((recent ?? []).length > 0) {
    return { sent: false, reason: "deduped" }
  }

  const businessSettings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)
  if (!businessSettings) return { sent: false, reason: "no_business_settings" }

  const alertText =
    `🚨 Nuevo mensaje sin respuesta IA\n\n` +
    `Cliente: ${customerPhone}\n` +
    `Mensaje:\n"${customerMessage.slice(0, 500)}"\n\n` +
    `Motivo:\n${reason}\n\n` +
    `Responder manualmente desde recepción si es necesario.`

  let okCount = 0
  for (const raw of numbers) {
    const to = normalizePhone(raw)
    if (!to) continue
    try {
      const res = await callMetaApi<Record<string, unknown>>(
        `${businessSettings.row.phone_number_id}/messages`,
        businessSettings.accessToken,
        {
          method: "POST",
          body: JSON.stringify({
            messaging_product: "whatsapp",
            recipient_type: "individual",
            to,
            type: "text",
            text: { body: alertText },
          }),
        },
      )
      const wamid = (res.data as { messages?: Array<{ id?: string }> })?.messages?.[0]?.id ?? null
      const metaErr = !res.ok
        ? ((res.data as { error?: Record<string, unknown> })?.error ?? {}) as { message?: string; code?: number }
        : {}

      await supabase.from("whatsapp_logs").insert({
        phone: to,
        message_rendered: alertText,
        status: res.ok ? "sent" : "failed",
        provider: "meta_cloud_api",
        provider_response: { ...(res.data ?? {}), message_id: wamid },
        meta_error_code: metaErr.code ?? null,
        meta_error_message: metaErr.message ?? null,
        window_type: "free_text_within_24h",
        sent_at: res.ok ? new Date().toISOString() : null,
        created_at: new Date().toISOString(),
        event_type: "human_backup_alert",
        type: "human_backup_alert",
      })
      if (res.ok) okCount += 1
    } catch (e) {
      console.error("notifyHumanBackup send failed", e)
    }
  }
  return { sent: okCount > 0, recipients: okCount }
}

async function loadAnthropicKey(): Promise<string> {
  const { data, error } = await supabase.rpc("get_anthropic_api_key")
  if (error || !data) throw new Error("No se pudo leer anthropic_api_key del Vault")
  return data as string
}

async function loadSettings(): Promise<Settings> {
  const { data, error } = await supabase
    .from("ai_settings").select("*").eq("id", 1).single()
  if (error) throw error
  return data as Settings
}

// ---------------------------------------------------------------------------
// Tools (todas read-only)
// ---------------------------------------------------------------------------
const TOOLS = [
  {
    name: "list_services",
    description:
      "Lista los servicios activos del spa. Filtra opcionalmente por categoría o por palabras clave en recommended_for (ej 'estrés','facial','relajación').",
    input_schema: {
      type: "object",
      properties: {
        category: { type: "string" },
        recommended_for: { type: "array", items: { type: "string" } },
        limit: { type: "integer", default: 5 },
      },
    },
  },
  {
    name: "get_service_detail",
    description:
      "Devuelve detalle completo de un servicio por id: precio, duración, beneficios, contraindicaciones.",
    input_schema: {
      type: "object",
      properties: { service_id: { type: "string" } },
      required: ["service_id"],
    },
  },
  {
    name: "get_business_hours",
    description:
      "Devuelve horario semanal. Si pasas 'date' (YYYY-MM-DD) devuelve si está abierto ese día específico.",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
    },
  },
  {
    name: "get_faqs",
    description:
      "Devuelve FAQs aprobadas. Filtra por categoría o por una palabra clave de búsqueda.",
    input_schema: {
      type: "object",
      properties: {
        category: { type: "string" },
        query: { type: "string" },
      },
    },
  },
  {
    name: "identify_client",
    description:
      "Busca si el teléfono está registrado como cliente y devuelve nombre + ultima_visita si aplica.",
    input_schema: {
      type: "object",
      properties: { phone: { type: "string" } },
      required: ["phone"],
    },
  },
  {
    name: "check_availability_readonly",
    description:
      "Solo lectura. Devuelve cantidad de citas ya tomadas y horas potencialmente libres para un servicio en un rango. NO reserva nada.",
    input_schema: {
      type: "object",
      properties: {
        service_id: { type: "string" },
        date_from: { type: "string", description: "YYYY-MM-DD" },
        date_to: { type: "string", description: "YYYY-MM-DD" },
      },
      required: ["service_id", "date_from", "date_to"],
    },
  },
  {
    name: "check_availability_for_booking",
    description:
      "OBLIGATORIO antes de create_pending_booking. Verifica disponibilidad real del slot solicitado contra business_hours, días cerrados, schedule_blocks y bookings existentes (incluye pending_reception). Si está libre, available=true. Si NO está libre, devuelve suggested_slots con 3 alternativas reales del mismo día o de los siguientes días. NUNCA crees una pending_reception sin haber llamado primero esta tool y haber recibido available=true.",
    input_schema: {
      type: "object",
      properties: {
        service_id: { type: "string", description: "UUID del servicio (de list_services)" },
        requested_date: { type: "string", description: "YYYY-MM-DD zona Tijuana" },
        requested_time: { type: "string", description: "HH:MM 24h" },
        duration_min: { type: "number", description: "Duración minutos (opcional, default servicio)" },
      },
      required: ["service_id", "requested_date", "requested_time"],
    },
  },
  {
    name: "create_pending_booking",
    description:
      "Crea solicitud en agenda real con status='pending_reception'. SOLO usa esta tool DESPUÉS de check_availability_for_booking con available=true. La recepción valida y confirma después. Idempotente: dedup 10 min por cliente+servicio+fecha+hora.",
    input_schema: {
      type: "object",
      properties: {
        service_id: { type: "string", description: "UUID del servicio (de list_services)" },
        booking_date: { type: "string", description: "YYYY-MM-DD en zona Tijuana" },
        booking_time: { type: "string", description: "HH:MM 24h (ej. 14:00)" },
        duration_min: { type: "number", description: "Duración en minutos (opcional, default 60)" },
        client_name: { type: "string", description: "Nombre del cliente si lo conoces; opcional" },
        notes: { type: "string", description: "Notas opcionales (preferencias, contexto)" },
        confidence: { type: "number", description: "Confianza 0-1 en que la intención es real" },
      },
      required: ["service_id", "booking_date", "booking_time"],
    },
  },
]

type ToolContext = {
  phone?: string
  conversationId?: string
  clientName?: string | null
}

async function execTool(
  name: string,
  input: Record<string, unknown>,
  ctx: ToolContext = {},
) {
  switch (name) {
    case "list_services": {
      const limit = Math.min(Number(input.limit ?? 5), 10)
      let q = supabase
        .from("services")
        .select("id, name, category, duration_min, price, tagline, recommended_for")
        .eq("is_active", true)
        .limit(limit)
      if (input.category) q = q.eq("category", String(input.category))
      if (Array.isArray(input.recommended_for) && input.recommended_for.length > 0) {
        q = q.overlaps("recommended_for", input.recommended_for as string[])
      }
      const { data, error } = await q
      if (error) return { error: error.message }
      return { services: data ?? [] }
    }
    case "get_service_detail": {
      const { data, error } = await supabase
        .from("services")
        .select("id, name, description, category, duration_min, price, tagline, benefits, contraindications, recommended_for")
        .eq("id", String(input.service_id))
        .maybeSingle()
      if (error) return { error: error.message }
      if (!data) return { error: "no encontrado" }
      return data
    }
    case "get_business_hours": {
      const days = ["domingo","lunes","martes","miércoles","jueves","viernes","sábado"]
      // Calculamos today/tomorrow SIEMPRE en America/Tijuana (timezone del negocio)
      const tjNow = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
      const tjToday = tjNow.toISOString().slice(0, 10)
      const tjTomorrow = new Date(tjNow.getTime() + 86400000).toISOString().slice(0, 10)
      const todayName = days[tjNow.getDay()]
      const tomorrowName = days[(tjNow.getDay() + 1) % 7]

      if (input.date) {
        const at = `${input.date}T12:00:00-07:00`
        const { data, error } = await supabase.rpc("is_business_open", {
          p_at: at, p_branch_id: DEFAULT_BRANCH_ID,
        })
        if (error) return { error: error.message }
        return {
          date: input.date,
          ...((data?.[0]) ?? {}),
          timezone: "America/Tijuana",
          server_today_date: tjToday,
          server_today_name: todayName,
          server_tomorrow_date: tjTomorrow,
          server_tomorrow_name: tomorrowName,
        }
      }
      const { data, error } = await supabase
        .from("business_hours")
        .select("weekday, opens_at, closes_at, is_closed")
        .order("weekday")
      if (error) return { error: error.message }
      return {
        timezone: "America/Tijuana",
        today_date: tjToday,
        today_name: todayName,
        tomorrow_date: tjTomorrow,
        tomorrow_name: tomorrowName,
        weekly: (data ?? []).map((r: Record<string, unknown>) => ({
          day: days[r.weekday as number],
          ...r,
        })),
      }
    }
    case "get_faqs": {
      // Scope lock: solo FAQs activas Y curadas como 'sahara'.
      // Cualquier FAQ marcada out_of_scope (otro spa, clima, recetas, etc.)
      // queda invisible para el router aunque alguien la haya creado en admin.
      let q = supabase
        .from("faqs")
        .select("question, answer, category, tags, scope_category")
        .eq("is_active", true)
        .eq("scope_category", "sahara")
        .limit(10)
      if (input.category) q = q.eq("category", String(input.category))
      const { data, error } = await q
      if (error) return { error: error.message }
      let rows = (data ?? []) as Array<Record<string, unknown>>
      if (input.query) {
        const term = String(input.query).toLowerCase()
        rows = rows.filter((r) =>
          `${r.question} ${r.answer}`.toLowerCase().includes(term),
        )
      }
      // Defensa en profundidad: aunque vengan con scope='sahara', revalidamos
      // por si futuras filas tienen un valor inesperado.
      rows = rows.filter((r) => (r.scope_category ?? "sahara") === "sahara")
      return { faqs: rows.slice(0, 6).map((r) => ({
        question: r.question, answer: r.answer, category: r.category, tags: r.tags,
      })) }
    }
    case "identify_client": {
      const phone = normalizePhone(String(input.phone ?? ""))
      const last10 = phone.replace(/\D/g, "").slice(-10)
      const { data, error } = await supabase
        .from("clients")
        .select("id, full_name, phone, created_at")
        .ilike("phone", `%${last10}%`)
        .limit(1)
        .maybeSingle()
      if (error) return { error: error.message }
      return { client: data ?? null, is_known: !!data }
    }
    case "check_availability_readonly": {
      const sid = String(input.service_id)
      const from = String(input.date_from)
      const to = String(input.date_to)
      const { data: bookings, error } = await supabase
        .from("bookings")
        .select("booking_date, booking_time, therapist_id, duration_min")
        .eq("service_id", sid)
        .gte("booking_date", from)
        .lte("booking_date", to)
        .in("status", ["confirmed","rescheduled","checked_in","in_progress"])
      if (error) return { error: error.message }
      const { data: hours } = await supabase
        .from("business_hours").select("weekday, opens_at, closes_at, is_closed")
      return {
        existing_bookings: (bookings ?? []).length,
        bookings_summary: bookings ?? [],
        weekly_hours: hours ?? [],
        note: "Read-only. Recepción confirma la disponibilidad final.",
      }
    }
    case "check_availability_for_booking": {
      const serviceId = String(input.service_id ?? "").trim()
      const date = String(input.requested_date ?? "").trim()
      const time = String(input.requested_time ?? "").trim()
      if (!serviceId || !date || !time) {
        return { error: "missing_service_or_datetime" }
      }
      const timeNorm = time.length === 5 ? `${time}:00` : time
      const { data, error } = await supabase.rpc("check_availability_for_booking_from_ai", {
        p_service_id: serviceId,
        p_requested_date: date,
        p_requested_time: timeNorm,
        p_duration_min: input.duration_min ? Number(input.duration_min) : null,
      })
      if (error) return { error: error.message }
      const result = (data ?? {}) as Record<string, unknown>
      // 🔒 Si está disponible, encadenamos AUTOMÁTICAMENTE la creación del
      // booking. Esto garantiza que si el cliente eligió fecha/hora libres,
      // se crea sí o sí, aunque el modelo olvide llamar create_pending_booking.
      // La idempotencia del RPC evita duplicados.
      const phone = String(ctx.phone ?? "").trim()
      if (result.available === true && phone) {
        try {
          const { data: created, error: createErr } = await supabase.rpc("create_pending_booking_from_ai", {
            p_phone: phone,
            p_client_name: String(ctx.clientName ?? ""),
            p_service_id: serviceId,
            p_booking_date: date,
            p_booking_time: timeNorm,
            p_duration_min: input.duration_min ? Number(input.duration_min) : null,
            p_notes: "Solicitud creada por IA WhatsApp.",
            p_ai_conversation_id: ctx.conversationId ?? null,
            p_ai_confidence_score: 0.9,
          })
          if (!createErr && created) {
            const createdResult = created as Record<string, unknown>
            result.booking_id = createdResult.booking_id
            result.booking_created = createdResult.created
            result.duplicate_prevented = createdResult.duplicate_prevented
            result.status = createdResult.status
            // Alerta interna a recepción solo si fue creado por primera vez
            if (createdResult.created === true && createdResult.booking_id) {
              try {
                const { data: svc } = await supabase
                  .from("services")
                  .select("name")
                  .eq("id", serviceId)
                  .maybeSingle()
                const serviceName = (svc as { name?: string } | null)?.name ?? "Servicio"
                const customerName = String(ctx.clientName ?? "Cliente WhatsApp")
                const alert = [
                  "📅 *Nueva solicitud IA*",
                  "",
                  `*Cliente:* ${customerName}`,
                  `*Teléfono:* ${phone}`,
                  `*Servicio:* ${serviceName}`,
                  `*Fecha:* ${date}`,
                  `*Hora:* ${time}`,
                  "",
                  "Pendiente de validación en agenda Sahara.",
                ].join("\n")
                const { data: settingsRow } = await supabase
                  .from("ai_settings")
                  .select("human_backup_numbers, human_backup_enabled")
                  .eq("id", 1)
                  .maybeSingle()
                const enabled = (settingsRow as { human_backup_enabled?: boolean } | null)?.human_backup_enabled === true
                const targets = ((settingsRow as { human_backup_numbers?: string[] } | null)?.human_backup_numbers ?? []) as string[]
                if (enabled && Array.isArray(targets)) {
                  for (const target of targets) {
                    try {
                      await sendTextToMeta(normalizePhone(String(target)), alert)
                    } catch (e) {
                      console.warn("reception alert failed for", target, (e as Error).message)
                    }
                  }
                }
              } catch (e) {
                console.warn("auto-create alert build failed:", (e as Error).message)
              }
            }
          }
        } catch (e) {
          console.warn("auto-create after available=true failed:", (e as Error).message)
        }
      }
      return result
    }
    case "create_pending_booking": {
      const phone = String(ctx.phone ?? "").trim()
      if (!phone) return { error: "phone_missing_from_context" }
      const serviceId = String(input.service_id ?? "").trim()
      const date = String(input.booking_date ?? "").trim()
      const time = String(input.booking_time ?? "").trim()
      if (!serviceId || !date || !time) {
        return { error: "missing_service_or_datetime" }
      }
      // Normalizar HH:MM → HH:MM:00 para tipo time
      const timeNorm = time.length === 5 ? `${time}:00` : time
      // Safety net: re-verificar disponibilidad. La IA debió llamar
      // check_availability_for_booking antes, pero validamos por si acaso.
      const { data: availCheck } = await supabase.rpc("check_availability_for_booking_from_ai", {
        p_service_id: serviceId,
        p_requested_date: date,
        p_requested_time: timeNorm,
        p_duration_min: input.duration_min ? Number(input.duration_min) : null,
      })
      if (availCheck && (availCheck as { available?: boolean }).available !== true) {
        return {
          ok: false,
          error: "slot_not_available",
          reason: (availCheck as { reason?: string }).reason,
          suggested_slots: (availCheck as { suggested_slots?: unknown[] }).suggested_slots ?? [],
          note: "Slot ocupado o fuera de horario. Sugiere las alternativas al cliente.",
        }
      }
      const { data, error } = await supabase.rpc("create_pending_booking_from_ai", {
        p_phone: phone,
        p_client_name: String(input.client_name ?? ctx.clientName ?? ""),
        p_service_id: serviceId,
        p_booking_date: date,
        p_booking_time: timeNorm,
        p_duration_min: input.duration_min ? Number(input.duration_min) : null,
        p_notes: String(input.notes ?? ""),
        p_ai_conversation_id: ctx.conversationId ?? null,
        p_ai_confidence_score: input.confidence != null ? Number(input.confidence) : null,
      })
      if (error) return { error: error.message }
      const result = data as Record<string, unknown> | null
      // Alerta interna a recepción solo si REALMENTE se creó (no en dup)
      if (result?.created === true && result?.booking_id) {
        try {
          // Construir mensaje con datos del booking (servicio, etc.)
          const { data: svc } = await supabase
            .from("services")
            .select("name")
            .eq("id", serviceId)
            .maybeSingle()
          const serviceName = (svc as { name?: string } | null)?.name ?? "Servicio"
          const customerName = String(input.client_name ?? ctx.clientName ?? "Cliente WhatsApp")
          const alert = [
            "📅 *Nueva solicitud IA*",
            "",
            `*Cliente:* ${customerName}`,
            `*Teléfono:* ${phone}`,
            `*Servicio:* ${serviceName}`,
            `*Fecha:* ${date}`,
            `*Hora:* ${time}`,
            "",
            "Pendiente de validación en agenda Sahara.",
          ].join("\n")
          // Cargamos human_backup_numbers de ai_settings
          const { data: settingsRow } = await supabase
            .from("ai_settings")
            .select("human_backup_numbers, human_backup_enabled")
            .eq("id", 1)
            .maybeSingle()
          const enabled = (settingsRow as { human_backup_enabled?: boolean } | null)?.human_backup_enabled === true
          const targets = ((settingsRow as { human_backup_numbers?: string[] } | null)?.human_backup_numbers ?? []) as string[]
          if (enabled && Array.isArray(targets)) {
            for (const target of targets) {
              try {
                await sendTextToMeta(normalizePhone(String(target)), alert)
              } catch (e) {
                console.warn("reception alert failed for", target, (e as Error).message)
              }
            }
          }
        } catch (e) {
          console.warn("pending_booking alert build failed:", (e as Error).message)
        }
      }
      return result ?? { ok: false, error: "rpc_returned_null" }
    }
    default:
      return { error: `tool desconocida: ${name}` }
  }
}

// ---------------------------------------------------------------------------
// Admin tools (READ-ONLY) - solo accesibles para números en ai_admin_numbers
// ---------------------------------------------------------------------------
const ADMIN_TOOLS = [
  {
    name: "get_today_summary",
    description: "Resumen operativo de HOY (zona Tijuana): total citas, confirmadas, canceladas, pendientes, completadas, ingresos pagados.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "get_appointments_summary",
    description: "Conteo de citas por status para una fecha específica (YYYY-MM-DD, hora Tijuana).",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
      required: ["date"],
    },
  },
  {
    name: "get_tomorrow_appointments",
    description: "Lista compacta de las citas de MAÑANA (Tijuana): hora, servicio, terapeuta, status. NO devuelve nombre completo del cliente, solo inicial.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "get_pending_confirmations",
    description: "Lista citas próximas 7 días que están en estado pending o scheduled (esperando confirmar).",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "get_revenue_summary",
    description: "Ingresos pagados de una fecha específica: total y desglose por método de pago.",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
      required: ["date"],
    },
  },
  {
    name: "get_cancellations_summary",
    description: "Cancelaciones de una fecha + porcentaje sobre el total de citas del día.",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
      required: ["date"],
    },
  },
  {
    name: "get_top_services",
    description: "Top 5 servicios más reservados en un rango de fechas (date_from, date_to en YYYY-MM-DD).",
    input_schema: {
      type: "object",
      properties: {
        date_from: { type: "string" },
        date_to: { type: "string" },
      },
      required: ["date_from", "date_to"],
    },
  },
  {
    name: "get_staff_schedule_summary",
    description: "Citas por terapeuta para una fecha específica.",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
      required: ["date"],
    },
  },
  {
    name: "get_whatsapp_status_summary",
    description: "Estado del canal WhatsApp últimas 24h: enviados, entregados, fallidos, en cola, dead-letter, latencia.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "get_ai_usage_summary",
    description: "Métricas IA: conversaciones activas hoy, mensajes, costo USD, latencia promedio, escaladas a recepción.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "get_first_visit_clients_count",
    description: "Cuántos clientes nuevos (primera visita) tuvimos en una fecha.",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
      required: ["date"],
    },
  },
  {
    name: "get_no_shows_summary",
    description: "Citas que no se presentaron (no_show) en una fecha específica.",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
      required: ["date"],
    },
  },
  {
    name: "get_daily_operations_summary",
    description: "Resumen extendido del día: citas + cancelaciones + ingresos + WhatsApp + IA en una sola llamada.",
    input_schema: {
      type: "object",
      properties: { date: { type: "string" } },
    },
  },
]

function todayTjDate(): string {
  return new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
    .toISOString().slice(0, 10)
}

async function execAdminTool(name: string, input: Record<string, unknown>) {
  switch (name) {
    case "get_today_summary": {
      const { data, error } = await supabase
        .from("admin_today_summary").select().maybeSingle()
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    case "get_appointments_summary": {
      const date = String(input.date ?? todayTjDate())
      const { data, error } = await supabase
        .from("bookings").select("status").eq("booking_date", date)
      if (error) return { error: error.message }
      const counts: Record<string, number> = {}
      for (const r of (data ?? []) as Array<{ status: string }>) {
        counts[r.status] = (counts[r.status] ?? 0) + 1
      }
      // Derivado: "pendientes por confirmar" = pending + scheduled + rescheduled
      const pendingToConfirm =
        (counts["pending"] ?? 0) +
        (counts["scheduled"] ?? 0) +
        (counts["rescheduled"] ?? 0)
      return {
        date,
        total: data?.length ?? 0,
        by_status: counts,
        pending_to_confirm: pendingToConfirm,
        confirmed: counts["confirmed"] ?? 0,
        cancelled: counts["cancelled"] ?? 0,
        completed: counts["completed"] ?? 0,
      }
    }
    case "get_tomorrow_appointments": {
      const { data, error } = await supabase
        .from("admin_tomorrow_appointments").select()
      if (error) return { error: error.message }
      return { count: data?.length ?? 0, appointments: data ?? [] }
    }
    case "get_pending_confirmations": {
      const from = todayTjDate()
      const toDate = new Date(new Date(from).getTime() + 7 * 86400000).toISOString().slice(0, 10)
      const { data, error } = await supabase
        .from("bookings")
        .select("booking_date, booking_time, service_name, status")
        .in("status", ["pending", "scheduled"])
        .gte("booking_date", from)
        .lte("booking_date", toDate)
        .order("booking_date").order("booking_time")
      if (error) return { error: error.message }
      return { count: data?.length ?? 0, items: data ?? [], range: { from, to: toDate } }
    }
    case "get_revenue_summary": {
      const date = String(input.date ?? todayTjDate())
      const { data, error } = await supabase
        .from("sales").select("total, payment_method, payment_status")
        .gte("created_at", `${date}T00:00:00-07:00`)
        .lt("created_at", `${date}T23:59:59-07:00`)
        .eq("payment_status", "paid")
      if (error) return { error: error.message }
      const byMethod: Record<string, number> = {}
      let total = 0
      for (const r of (data ?? []) as Array<{ total: number; payment_method?: string }>) {
        total += Number(r.total ?? 0)
        const m = r.payment_method ?? "otro"
        byMethod[m] = (byMethod[m] ?? 0) + Number(r.total ?? 0)
      }
      return { date, total_paid_mxn: total, by_method: byMethod, transactions: data?.length ?? 0 }
    }
    case "get_cancellations_summary": {
      const date = String(input.date ?? todayTjDate())
      const { data, error } = await supabase
        .from("bookings").select("status").eq("booking_date", date)
      if (error) return { error: error.message }
      const total = data?.length ?? 0
      const cancelled = (data ?? []).filter((r: { status: string }) => r.status === "cancelled").length
      return {
        date, total, cancelled,
        cancellation_rate_pct: total > 0 ? Math.round((cancelled / total) * 1000) / 10 : 0,
      }
    }
    case "get_top_services": {
      const from = String(input.date_from ?? todayTjDate())
      const to = String(input.date_to ?? todayTjDate())
      const { data, error } = await supabase
        .from("bookings").select("service_id, service_name")
        .gte("booking_date", from).lte("booking_date", to)
        .in("status", ["confirmed", "completed", "paid", "checked_in"])
      if (error) return { error: error.message }
      const counts: Record<string, { name: string; count: number }> = {}
      for (const r of (data ?? []) as Array<{ service_id: string; service_name: string }>) {
        const k = r.service_id ?? r.service_name ?? "desconocido"
        if (!counts[k]) counts[k] = { name: r.service_name ?? "sin nombre", count: 0 }
        counts[k].count += 1
      }
      const top5 = Object.values(counts).sort((a, b) => b.count - a.count).slice(0, 5)
      return { range: { from, to }, top: top5 }
    }
    case "get_staff_schedule_summary": {
      const date = String(input.date ?? todayTjDate())
      const { data, error } = await supabase
        .from("bookings").select("therapist_id")
        .eq("booking_date", date)
        .not("therapist_id", "is", null)
      if (error) return { error: error.message }
      const counts: Record<string, number> = {}
      for (const r of (data ?? []) as Array<{ therapist_id: string }>) {
        counts[r.therapist_id] = (counts[r.therapist_id] ?? 0) + 1
      }
      // Resolver nombres staff
      const ids = Object.keys(counts)
      if (ids.length === 0) return { date, by_therapist: [] }
      const { data: staff } = await supabase
        .from("staff").select("id, full_name").in("id", ids)
      const result = (staff ?? []).map((s: { id: string; full_name: string }) => ({
        therapist: s.full_name, count: counts[s.id] ?? 0,
      })).sort((a, b) => b.count - a.count)
      return { date, by_therapist: result }
    }
    case "get_whatsapp_status_summary": {
      const { data, error } = await supabase
        .from("whatsapp_metrics_24h").select().maybeSingle()
      if (error) return { error: error.message }
      return data ?? { error: "sin métricas" }
    }
    case "get_ai_usage_summary": {
      const { data, error } = await supabase
        .from("ai_metrics_dashboard").select().maybeSingle()
      if (error) return { error: error.message }
      return data ?? { error: "sin métricas" }
    }
    case "get_first_visit_clients_count": {
      const date = String(input.date ?? todayTjDate())
      const { data, error } = await supabase
        .from("clients").select("id, created_at")
        .gte("created_at", `${date}T00:00:00-07:00`)
        .lt("created_at", `${date}T23:59:59-07:00`)
      if (error) return { error: error.message }
      return { date, new_clients: data?.length ?? 0 }
    }
    case "get_no_shows_summary": {
      const date = String(input.date ?? todayTjDate())
      const { data, error } = await supabase
        .from("bookings").select("status").eq("booking_date", date)
      if (error) return { error: error.message }
      const noShows = (data ?? []).filter((r: { status: string }) => r.status === "no_show").length
      return { date, no_shows: noShows, total: data?.length ?? 0 }
    }
    case "get_daily_operations_summary": {
      // Composición de varias vistas para un overview completo
      const date = String(input.date ?? todayTjDate())
      const [today, wa, ai] = await Promise.all([
        supabase.from("admin_today_summary").select().maybeSingle(),
        supabase.from("whatsapp_metrics_24h").select().maybeSingle(),
        supabase.from("ai_metrics_dashboard").select().maybeSingle(),
      ])
      return {
        date,
        bookings: today.data ?? {},
        whatsapp: wa.data ?? {},
        ai: ai.data ?? {},
      }
    }
    default:
      return { error: `admin tool desconocida: ${name}` }
  }
}

function buildAdminSystemPrompt() {
  const days = ["domingo","lunes","martes","miércoles","jueves","viernes","sábado"]
  const tjNow = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
  const tjDate = tjNow.toISOString().slice(0, 10)
  const tjTime = tjNow.toTimeString().slice(0, 5)
  const tjWeekday = days[tjNow.getDay()]
  const tjTomorrowDate = new Date(tjNow.getTime() + 86400000).toISOString().slice(0, 10)
  const tjTomorrowName = days[(tjNow.getDay() + 1) % 7]

  return `Eres Sahara, asistente del ADMINISTRADOR de Sahara Club Spa.
Este usuario es admin autorizado y puede consultarte resúmenes operativos por WhatsApp.

REGLAS DURAS (admin):
1. Solo LECTURA. Nunca creas, modificas ni cancelas nada.
2. NUNCA reveles nombres completos, teléfonos, emails ni detalles personales
   de clientes. Solo conteos, agregados, iniciales.
3. Si admin pide "cancela X", "modifica X", "elimina X", "cambia pago", "edita",
   responde: "Por seguridad, solo lecturas por WhatsApp. Acciones en el panel admin."
4. Si admin pide datos personales (teléfono, email, dirección, notas privadas):
   "Por seguridad, solo puedo darte un resumen general. Revisa el panel admin para detalles."
5. NUNCA inventes números. Si una tool falla o devuelve vacío, dilo: "No hay datos para esa consulta."
6. Tono ejecutivo, conciso, formato bullet list para WhatsApp.
7. Máximo 6 líneas por respuesta.
8. Fechas SIEMPRE en America/Tijuana usando tools.
9. ALCANCE EXCLUSIVO — SOLO datos operativos de Sahara Club Spa (REGLA MÁS IMPORTANTE):
   - Toda respuesta DEBE basarse en datos devueltos por tools de la DB de Sahara Club Spa.
   - PROHIBIDO usar conocimiento general, comparaciones con otros negocios o información externa.
   - PROHIBIDO responder temas ajenos: noticias, finanzas personales, tecnología, traducciones, código, consejos médicos, etc.
   - Si preguntan algo fuera del scope: "Solo manejo datos operativos de Sahara Club Spa. Revisa el panel admin para análisis adicionales."

FORMATO RECOMENDADO PARA RESUMEN DE DÍA:
"📊 Resumen de hoy:
• Citas totales: N
• Confirmadas: N
• Canceladas: N
• Completadas: N
• Pendientes por confirmar: N
• Ingresos registrados: $N MXN"

NOTA: "Pendientes por confirmar" se toma del campo pending_to_confirm que ya
incluye status pending + scheduled + rescheduled. NO sumes manualmente.

Usa máximo 1 emoji sutil por bullet o título: 📊 📅 💰 ⏰ ⚠️ 🤖 👥 🔝

CONTEXTO TEMPORAL:
- Zona horaria: America/Tijuana
- Hoy es: ${tjWeekday} ${tjDate} (hora actual: ${tjTime})
- Mañana es: ${tjTomorrowName} ${tjTomorrowDate}

EJEMPLOS DE RESPUESTA:
Pregunta: "Resumen de hoy"
→ Llama get_today_summary, formatea como bullets, máximo 6 líneas.

Pregunta: "Cancela la cita de las 4pm"
→ "Por seguridad, solo lecturas por WhatsApp. Las cancelaciones se hacen desde la agenda en saharaclubspa.com."

Pregunta: "Dame el teléfono de Rodrigo"
→ "Por seguridad, solo puedo darte un resumen general. Revisa el panel admin para detalles."
`
}

// ---------------------------------------------------------------------------
// System prompt (customer)
// ---------------------------------------------------------------------------
// Carga el catálogo completo de servicios activos para inyectarlo en el
// system prompt como única fuente de verdad. Evita que el modelo invente
// precios o diga "no existe" un servicio que sí está en DB.
async function buildServiceCatalog(): Promise<string> {
  try {
    const { data, error } = await supabase
      .from("services")
      .select("id, name, category, duration_min, price, tagline")
      .eq("is_active", true)
      .order("category", { ascending: true })
      .order("name", { ascending: true })
      .order("duration_min", { ascending: true })
    if (error) {
      console.warn("buildServiceCatalog error:", error.message)
      return "(catálogo no disponible — usa list_services como fallback)"
    }
    const rows = (data ?? []) as Array<{
      id: string; name: string; category: string | null;
      duration_min: number | null; price: number | string | null;
      tagline: string | null
    }>
    if (rows.length === 0) return "(sin servicios activos)"
    const byCat = new Map<string, typeof rows>()
    for (const r of rows) {
      const c = r.category ?? "Otros"
      if (!byCat.has(c)) byCat.set(c, [])
      byCat.get(c)!.push(r)
    }
    const lines: string[] = []
    for (const [cat, items] of byCat) {
      lines.push(`[${cat}]`)
      for (const s of items) {
        const price = s.price != null ? `$${Number(s.price).toFixed(0)}` : "precio sin definir"
        const dur = s.duration_min != null ? `${s.duration_min} min` : "duración sin definir"
        const tag = s.tagline ? ` · ${s.tagline}` : ""
        lines.push(`  • ${s.name} · ${dur} · ${price} · id:${s.id}${tag}`)
      }
      lines.push("")
    }
    return lines.join("\n").trim()
  } catch (e) {
    console.warn("buildServiceCatalog threw:", (e as Error).message)
    return "(catálogo no disponible — usa list_services como fallback)"
  }
}

function buildSystemPrompt(clientKnown: string | null, serviceCatalog: string = "") {
  // SIEMPRE en zona horaria del negocio
  const days = ["domingo","lunes","martes","miércoles","jueves","viernes","sábado"]
  const monthsEs = ["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"]
  const tjNow = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
  const tjDate = tjNow.toISOString().slice(0, 10)
  const tjTime = tjNow.toTimeString().slice(0, 5)
  const tjWeekday = days[tjNow.getDay()]
  const tjTomorrowDate = new Date(tjNow.getTime() + 86400000).toISOString().slice(0, 10)
  const tjTomorrowName = days[(tjNow.getDay() + 1) % 7]

  // Tabla autoritativa de los próximos 14 días: nombre + fecha exacta.
  // El modelo NUNCA debe calcular; solo hacer lookup en esta tabla.
  const upcomingLines: string[] = []
  for (let i = 0; i < 14; i++) {
    const d = new Date(tjNow.getTime() + i * 86400000)
    const dateStr = d.toISOString().slice(0, 10)
    const wname = days[d.getDay()]
    const dd = d.getDate()
    const mname = monthsEs[d.getMonth()]
    const tag = i === 0 ? " (HOY)" : i === 1 ? " (mañana)" : ""
    upcomingLines.push(`  ${wname} ${dd} de ${mname} → ${dateStr}${tag}`)
  }
  const upcomingTable = upcomingLines.join("\n")

  return `Eres Sahara, asistente concierge de Sahara Club Spa (spa de bienestar en Ensenada, BC).
Tu rol: asesorar al cliente y CAPTAR su intención de reserva. Recepción confirma toda cita oficialmente.

ROL EXACTO:
- Eres un CONCIERGE de PRE-RESERVA.
- NO eres sistema de booking automático.
- NO eres confirmador de citas.
- Capturas interés, sugieres opciones, registras solicitud. Recepción decide y confirma.

REGLAS DURAS (no negociables):
1. NUNCA digas "tu cita confirmada", "reserva confirmada", "tu cita quedó confirmada", "ya quedó tu cita",
   "tu cita está agendada", "queda apartado", "te aparto", "está reservado".
   PROHIBIDO totalmente. Esa palabra solo la usa recepción.
2. Never claim an appointment is confirmed unless reception or the booking system explicitly confirms it.
3. NUNCA inventes servicios, precios, horarios, beneficios ni terapeutas. Si no aparece en tools, di "déjame verificar con recepción".
3a. PRECIOS: usa SIEMPRE el campo "price" exacto del row de list_services que el cliente eligió. NUNCA copies un precio de otro servicio ni mezcles entre variantes de duración. Si tienes el UUID de un servicio y no recuerdas el precio, llama get_service_detail con ese UUID. PROHIBIDO inventar precios.
3b. COHERENCIA: si en ESTA conversación dijiste que un servicio existe (lo ofreciste por nombre y precio), NUNCA digas después que "no aparece en el sistema". Si dudas, llama list_services de nuevo, pero NO te contradigas.
4. NUNCA des consejo médico ni diagnóstico. Si mencionan condición médica, sugiere consultar con su médico y con recepción.
5. NO ofrezcas descuentos. Si los piden: "déjame consultar con recepción".
6. NUNCA digas "entra a la landing", "agenda en línea", "ve a la web a finalizar". El flujo es WhatsApp → recepción → confirmación.
7. Tono cálido, profesional, breve. MÁXIMO 4 LÍNEAS por mensaje (5 si registras solicitud con bullets).
8. Responde en español MX. Si el cliente escribe en inglés, responde en inglés.
9. ALCANCE EXCLUSIVO — SOLO Sahara Club Spa (REGLA MÁS IMPORTANTE):
   - SOLO puedes dar información que esté EN LA BASE DE DATOS de Sahara Club Spa (devuelta por tools: list_services, get_business_hours, get_therapists, etc.).
   - PROHIBIDO usar conocimiento general, entrenamiento previo, internet, suposiciones o memoria de modelos.
   - PROHIBIDO recomendar otros spas, salones, clínicas, marcas, hoteles, restaurantes, gimnasios o cualquier negocio que no sea Sahara Club Spa.
   - PROHIBIDO responder temas ajenos al spa: clima, recetas, rutinas genéricas de skincare/maquillaje, consejos médicos/nutricionales, política, deportes, noticias, viajes, finanzas, tecnología, entretenimiento, traducciones generales, tareas, código, etc.
   - Si te preguntan algo fuera de Sahara responde EXACTAMENTE en este espíritu:
     "Solo puedo orientarte con experiencias y servicios de Sahara Club Spa ✨ ¿Te ayudo con algún ritual, facial o reserva?"
   - Si preguntan por algo de spa que NO existe en nuestra DB: "Ese servicio no lo ofrecemos en Sahara. Déjame mostrarte lo que sí tenemos 🌿" + sugiere alternativas reales con list_services.
   - Ante CUALQUIER duda sobre un dato: "déjame verificar con recepción" antes que inventar.

VOCABULARIO PERMITIDO (úsalo activamente):
✅ "solicitud registrada", "registramos tu solicitud", "registramos tu interés"
✅ "pre-reserva", "intención de reserva"
✅ "recepción validará disponibilidad", "recepción confirmará"
✅ "pendiente de confirmación", "sujeto a validación"
✅ "te confirmará por aquí en breve"

VOCABULARIO PROHIBIDO:
❌ "confirmada", "confirmado", "quedó confirmada", "apartado", "reservado"
❌ "ya tienes tu cita confirmada", "listo, está confirmada"
❌ "entra a", "ve a la landing", "agenda en línea"

VOCABULARIO PERMITIDO solo cuando create_pending_booking devuelve created=true:
✅ "Registramos tu solicitud y ha sido agendada para [servicio]..."
   (porque SÍ se creó un row real en la agenda con status pending_reception,
    aunque no esté confirmada por recepción).
   NO digas "tu cita está agendada y confirmada" — la confirmación es de recepción.

EMOJIS PERMITIDOS:
✅ ✨  🌿  (úsalos con moderación, máximo 1 por mensaje)
❌ 🎯  (NO usar)

FLUJO CUANDO EL CLIENTE QUIERE RESERVAR:

PASO 1 — Cliente pregunta por servicio o expresa interés:
  • Recomienda 2-3 opciones reales (usa list_services).
  • Sugiere días/horarios aproximados (sin prometer).
  • Pregunta su preferencia.

PASO 2 — Cliente elige día/hora específico (ej. "jueves 4pm") O elige
  una de las alternativas que tú sugeriste antes:

  🚨 PROHIBIDO ABSOLUTAMENTE en este punto:
  - Preguntar trivia personal como "¿es tu primer masaje?", "¿ya nos has visitado?",
    "¿prefieres terapeuta hombre o mujer?", "¿cómo te enteraste de nosotros?".
    Esas preguntas DISTRAEN del cierre. Después de la reserva, recepción puede
    preguntar lo que falte. Tu única tarea ahora es CERRAR LA RESERVA.
  - Decir "déjame verificar con recepción" sin antes haber llamado la tool.
    Narrar la verificación NO ES verificar. La verificación es llamar la tool.

  OBLIGATORIO: llama check_availability_for_booking con:
    service_id = UUID del servicio elegido (de list_services)
    requested_date = YYYY-MM-DD (zona Tijuana, usa server_today/tomorrow)
    requested_time = HH:MM 24h (ej. 16:00 para 4pm)
    duration_min = duración del servicio si la conoces

  ESTA TOOL: si available=true, AUTOMÁTICAMENTE crea el booking y manda
  alerta a recepción. NO necesitas llamar create_pending_booking aparte
  (la tool ya lo hace internamente). Verás en el output: booking_created=true,
  booking_id=<uuid>, status='pending_reception'.

  CASO A — available=true (booking creado automáticamente):
    Responde EXACTAMENTE así (adapta servicio/duración/fecha/hora):

    "Perfecto ✨

    Registramos tu solicitud y ha sido agendada para [Servicio] ([N] minutos),
    [día de la semana] [N] de [mes], a las [HH] horas.

    Recepción validará disponibilidad y te confirmará por aquí en breve 🌿"

    Si la tool devuelve duplicate_prevented=true, NO repitas el mensaje
    largo: di "Ya registramos tu solicitud hace un momento ✨
    Recepción validará y te confirmará por aquí en breve 🌿".

  CASO B — available=false:
    NO LLAMES create_pending_booking. Sugiere los suggested_slots devueltos
    por check_availability_for_booking. Formato:

    "Ese horario ya no está disponible 🌿

    Tengo estas opciones cercanas:
    • [día] [hora]
    • [día] [hora]
    • [día] [hora]

    ¿Cuál te gustaría que enviemos a recepción?"

    Si reason='closed_day': "Ese día estamos cerrados. Tengo opciones para [día]:..."
    Si reason='outside_business_hours': "Ese horario está fuera de nuestro
    servicio (abrimos [opens_at] a [closes_at]). Te sugiero:..."
    Si suggested_slots viene vacío: "No tengo horarios libres por ahora
    en esa fecha. Recepción te ayudará a encontrar el mejor día 🌿"

    🚨 REGLA ABSOLUTA — NO NEGOCIABLE:
    Cuando el cliente elija una de las opciones que sugeriste (ej.
    "mejor a las 11am", "la primera", "sí esa") DEBES en ese mismo turno:
      (1) llamar check_availability_for_booking con la nueva hora
      (2) llamar create_pending_booking con la nueva hora
      (3) DESPUÉS responder al cliente con el wording "Registramos tu
          solicitud y ha sido agendada para..."

    PROHIBIDO ABSOLUTAMENTE escribir "Registramos tu solicitud" o "ha
    sido agendada" en tu respuesta de texto SIN haber recibido un
    tool_result de create_pending_booking con created=true en el MISMO
    turno actual. Si lo haces, mientes al cliente: él cree que tiene
    reserva pero recepción NO ve nada en la agenda real.

    El historial NO cuenta. Si en un turno anterior llamaste la tool,
    no significa que esta nueva elección ya esté creada. Cada nueva
    elección requiere su propia llamada a create_pending_booking.

  Si create_pending_booking devuelve error="slot_not_available" (significa
  que cambió entre check y create), trata el suggested_slots devuelto como
  CASO B y sugiere alternativas.

  Si cualquier tool devuelve error inesperado: "Tuvimos un problema
  registrando tu solicitud. Recepción se pondrá en contacto contigo en breve."

PASO 3 — Cliente pregunta "¿ya quedó?", "¿ya está confirmada?", "¿ya está pagada?":
  Responde con calma:
  "Aún no. Recepción validará disponibilidad y te confirmará por aquí en breve ✨"
  o:
  "Aún no se ha pagado. Recepción te apoyará con los siguientes pasos 🌿"

REGLAS DE FECHAS (CRÍTICO):
- NUNCA calcules fechas manualmente. Usa SIEMPRE la TABLA AUTORITATIVA de abajo.
- Cuando el cliente dice un día ("jueves", "el sábado", "mañana"), haz lookup
  en la tabla y usa la fecha exacta que aparece junto al día. Esa es la
  ÚNICA fuente de verdad.
- Si el cliente dice un número de día sin nombre (ej. "el 30"), busca en la
  tabla qué día de la semana es el 30 y úsalo. Si dice "jueves 30" pero
  jueves NO es 30 según la tabla, PREGUNTA al cliente: "¿Te refieres al
  jueves [fecha real] o al sábado [fecha real, si el 30 es sábado]?".
  NUNCA inventes una fecha donde día y número no coincidan.
- Zona horaria oficial: America/Tijuana.

CONTEXTO TEMPORAL — TABLA AUTORITATIVA (próximos 14 días):
${upcomingTable}

Hora actual Tijuana: ${tjTime}.

CONTEXTO NEGOCIO:
- Sahara Club Spa, Ensenada
- Cliente conocido en sistema: ${clientKnown ?? "(desconocido, primera interacción)"}

CATÁLOGO COMPLETO DE SERVICIOS (ÚNICA FUENTE DE VERDAD):
Cada línea tiene formato: nombre · duración · precio · id:UUID · tagline.
NUNCA inventes precios; copia el exacto de la línea correspondiente.
NUNCA digas que un servicio "no existe" si está listado aquí.
NUNCA mezcles el precio de una variante de duración con otra.
Cuando el cliente diga el nombre de un servicio (parcial o completo),
busca aquí PRIMERO antes de usar list_services. El UUID que necesitas
para check_availability_for_booking está justo en cada línea.

${serviceCatalog}

Si el cliente nombra algo que NO está en el catálogo, di: "Ese servicio
no lo ofrecemos. Te muestro lo que sí tenemos:" y sugiere 2-3 opciones
reales del catálogo de arriba.

FLUJO TÍPICO:
- Saluda en primer mensaje, ofrece ayuda.
- Usa tools para responder con DATOS REALES.
- No prometas disponibilidad final. Nunca confirmes.
- Cierra con apertura suave ("¿algo más?" o "¿te puedo ayudar con algo más?").
`
}

// ---------------------------------------------------------------------------
// Anthropic API call con tool-use loop
// ---------------------------------------------------------------------------
type AnthropicMessage = {
  role: "user" | "assistant"
  content: string | Array<Record<string, unknown>>
}

async function callAnthropic(
  apiKey: string, model: string, system: string,
  messages: AnthropicMessage[], temperature: number, maxTokens: number,
  tools: unknown[],
  toolChoice?: Record<string, unknown>,
) {
  const payload: Record<string, unknown> = {
    model, max_tokens: maxTokens, temperature, system,
    tools, messages,
  }
  if (toolChoice) payload.tool_choice = toolChoice
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  })
  const json = await res.json()
  if (!res.ok) throw new Error(`Anthropic ${res.status}: ${JSON.stringify(json)}`)
  return json as {
    id: string
    content: Array<Record<string, unknown>>
    stop_reason: string
    usage: { input_tokens: number; output_tokens: number }
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const body = await req.json().catch(() => ({}))
    const phoneRaw = String(body.phone ?? "").trim()
    const messageText = String(body.message_text ?? "").trim()
    const wamid = body.wamid ? String(body.wamid) : null
    const phone = normalizePhone(phoneRaw)

    if (!phone || !messageText) {
      return jsonResponse({ error: "phone y message_text requeridos" }, 400)
    }

    const settings = await loadSettings()

    // Resolver o crear conversación
    const { data: existing } = await supabase
      .from("ai_conversations")
      .select("id, total_tokens_in, total_tokens_out, message_count, total_cost_usd")
      .eq("customer_phone", phone)
      .eq("status", "active")
      .order("last_message_at", { ascending: false })
      .limit(1)
      .maybeSingle()

    let convId: string
    if (existing) {
      convId = existing.id as string
    } else {
      const { data: created, error: cErr } = await supabase
        .from("ai_conversations")
        .insert({
          customer_phone: phone,
          branch_id: DEFAULT_BRANCH_ID,
          llm_model: (settings as { active_model?: string; llm_model: string }).active_model
            ?? (settings.active_model || settings.llm_model),
        })
        .select("id").single()
      if (cErr) throw cErr
      convId = created.id as string
    }

    // Detectar modo admin temprano para marcar correctamente el mensaje user
    const { data: isAdminEarly } = await supabase.rpc("is_ai_admin", { p_phone: phone })
    const isAdminUser = Boolean(isAdminEarly)

    // Persistir mensaje user SIEMPRE (auditoría)
    await supabase.from("ai_messages").insert({
      conversation_id: convId,
      role: "user",
      content: messageText,
      wamid,
      is_admin_query: isAdminUser,
    })

    // Clasificación de mensaje corto (antes de gastar tokens en Anthropic)
    const shortMsgKind = classifyShortMessage(messageText)

    if (shortMsgKind === "ignore") {
      await supabase.from("ai_conversations")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", convId)
      return jsonResponse({
        ok: true, conversation_id: convId,
        skipped_short: true, kind: "ignore",
        reason: "emoji_or_filler_no_reply",
      })
    }

    if (shortMsgKind === "soft_closing") {
      // Verifica que can_ai_respond no esté en pausa/disabled (admin bypass aplica igual)
      const { data: gateSc } = await supabase.rpc("can_ai_respond", {
        p_phone: phone, p_conversation_id: convId,
      })
      const allowedSc = (gateSc as { allowed?: boolean })?.allowed === true
      if (!allowedSc) {
        return jsonResponse({ skipped: true, reason: "soft_closing_gated", gate: gateSc })
      }

      const reply = pickSoftClosing(`${phone}:${new Date().toISOString().slice(0,10)}:${messageText}`)

      // Insertar assistant directo, sin tokens LLM
      await supabase.from("ai_messages").insert({
        conversation_id: convId, role: "assistant",
        content: reply,
        tokens_in: 0, tokens_out: 0, latency_ms: 0,
        llm_model: null,
        stop_reason: "soft_closing",
        is_admin_query: isAdminUser,
        tool_output: { soft_closing_sent: true, mode: isAdminUser ? "admin" : "customer" },
      })

      await supabase.from("ai_conversations")
        .update({
          last_message_at: new Date().toISOString(),
          message_count: (existing?.message_count ?? 0) + 2,
        })
        .eq("id", convId)

      await sendTextToMeta(phone, reply)

      return jsonResponse({
        ok: true, conversation_id: convId,
        reply, soft_closing_sent: true, tokens_in: 0, tokens_out: 0, cost_usd: 0,
      })
    }

    // Guardrail centralizado vía can_ai_respond (revisa modo, piloto, pausa, horario,
    // cap costo diario, recepción tiene control, cap msgs por conversación)
    const { data: gate } = await supabase.rpc("can_ai_respond", {
      p_phone: phone,
      p_conversation_id: convId,
    })
    const allowed = (gate as { allowed?: boolean })?.allowed === true
    const denyReason = (gate as { reason?: string })?.reason ?? "unknown"

    if (!allowed) {
      await supabase.from("ai_conversations")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", convId)

      // Si el gate trae un auto_reply (after_hours_blocked, etc.), enviarlo
      // al cliente para que sepa cuándo le respondemos. Solo aplica a clientes
      // (admin no entra a esta rama). Persistimos como mensaje assistant.
      const autoReply = (gate as { auto_reply?: string })?.auto_reply
      let autoReplySent = false
      if (autoReply && typeof autoReply === "string" && autoReply.trim().length > 0) {
        try {
          await sendTextToMeta(phone, autoReply)
          await supabase.from("ai_messages").insert({
            conversation_id: convId, role: "assistant", content: autoReply,
            tokens_in: 0, tokens_out: 0, latency_ms: 0,
            llm_model: null,
            stop_reason: denyReason,
            is_admin_query: false,
            tool_output: { auto_reply: true, reason: denyReason },
          })
          autoReplySent = true
        } catch (e) {
          console.warn("after-hours auto_reply send failed:", (e as Error).message)
        }
      }

      // Notificar al número humano de respaldo (con dedup 15 min).
      // NO se dispara para soft closings (esos no llegan aquí porque retornan antes).
      // NO se dispara para mensajes admin con acceso (no entran a esta rama).
      const backup = await notifyHumanBackup(phone, messageText, denyReason)

      return jsonResponse({
        skipped: true,
        reason: denyReason,
        conversation_id: convId,
        phone,
        gate,
        auto_reply_sent: autoReplySent,
        human_backup: backup,
      })
    }

    // Rate limit por número (últimas 24h)
    const sinceIso = new Date(Date.now() - 24 * 3600 * 1000).toISOString()
    const { count: msg24h } = await supabase
      .from("ai_messages")
      .select("id", { count: "exact", head: true })
      .eq("role", "user")
      .gte("created_at", sinceIso)
      .in("conversation_id", [convId])
    if ((msg24h ?? 0) > settings.max_msgs_per_phone_24h) {
      const overflow = "Recibimos tu mensaje. Para no saturarte, recepción te contactará directamente."
      await sendTextToMeta(phone, overflow)
      await supabase.from("ai_messages").insert({
        conversation_id: convId, role: "assistant", content: overflow,
        stop_reason: "rate_limit_local",
      })
      return jsonResponse({ ok: true, rate_limited: true })
    }

    // Cap de tokens por conversación
    if ((existing?.total_tokens_in ?? 0) + (existing?.total_tokens_out ?? 0)
        > settings.max_tokens_per_conversation) {
      const cap = "Recepción te dará seguimiento personal en breve ✨ Cualquier duda urgente, escríbenos directo. ¡Gracias por elegir Sahara! 🌿"
      await sendTextToMeta(phone, cap)
      await supabase.from("ai_messages").insert({
        conversation_id: convId, role: "assistant", content: cap,
        stop_reason: "tokens_cap_local",
      })
      await supabase.from("ai_conversations")
        .update({ status: "escalated_to_human", escalation_reason: "tokens_cap" })
        .eq("id", convId)
      return jsonResponse({ ok: true, escalated: true })
    }

    // Cargar API key Anthropic desde Vault
    const apiKey = await loadAnthropicKey()

    // Modo admin ya resuelto al insertar user message
    const isAdmin = isAdminUser
    const activeTools = isAdmin ? [...TOOLS, ...ADMIN_TOOLS] : TOOLS

    // Identificar cliente (para system prompt customer)
    const last10 = phone.replace(/\D/g, "").slice(-10)
    const { data: client } = isAdmin
      ? { data: null }
      : await supabase.from("clients").select("full_name")
          .ilike("phone", `%${last10}%`).limit(1).maybeSingle()
    // Cargar catálogo completo solo si NO es admin (admin tiene otro contexto)
    const serviceCatalog = isAdmin ? "" : await buildServiceCatalog()
    const system = isAdmin
      ? buildAdminSystemPrompt()
      : buildSystemPrompt(client?.full_name ?? null, serviceCatalog)

    // Cargar historia últimos 20 mensajes (excluyendo system)
    const { data: history } = await supabase
      .from("ai_messages")
      .select("role, content, tool_name, tool_input, tool_output, id")
      .eq("conversation_id", convId)
      .order("created_at", { ascending: true })
      .limit(40)

    // Convertir historia a formato Anthropic. Inyectamos como CONTEXTO TEXTUAL
    // los últimos tool_outputs relevantes (servicios, disponibilidad) en un
    // pseudo-mensaje user, para que el modelo recuerde UUIDs y suggested_slots
    // al volver al turno actual.
    const messages: AnthropicMessage[] = []
    let lastToolContext = ""
    for (const m of (history ?? []) as Array<Record<string, unknown>>) {
      if (m.role === "tool" && m.tool_output) {
        const toolName = String(m.tool_name ?? "")
        if (toolName === "list_services" || toolName === "check_availability_for_booking") {
          try {
            const snippet = JSON.stringify(m.tool_output).slice(0, 1500)
            lastToolContext += `\n[Tool ${toolName} output: ${snippet}]`
          } catch { /* skip */ }
        }
        continue
      }
      if (m.role === "user") {
        messages.push({ role: "user", content: String(m.content ?? "") })
      } else if (m.role === "assistant" && m.content) {
        messages.push({ role: "assistant", content: String(m.content) })
      }
    }
    // Agrega el contexto de tool como referencia al final si existe
    if (lastToolContext && messages.length > 0) {
      const lastIdx = messages.length - 1
      const last = messages[lastIdx]
      if (last.role === "user" && typeof last.content === "string") {
        messages[lastIdx] = {
          role: "user",
          content: `${last.content}\n\n---\nCONTEXTO DE TOOLS PREVIOS (datos reales que ya consultaste, úsalos si aplica):${lastToolContext}`,
        }
      }
    }

    // Detección de intención de reserva con fecha+hora en el mensaje del cliente.
    // Si el cliente menciona un día (hoy/mañana/lunes...domingo o un número de día)
    // junto con una hora (\d{1,2} con am/pm/horas/:), entonces es señal clara de
    // que quiere reservar → forzamos check_availability_for_booking.
    // También se activa si el último tool_output fue suggested_slots
    // (cliente eligiendo alternativa).
    let forceToolChoice: Record<string, unknown> | undefined = undefined
    if (!isAdmin) {
      try {
        const lower = messageText.toLowerCase()
        const dayWord = /\b(hoy|mañana|manana|lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)\b/.test(lower)
        const dayNum = /\b\d{1,2}\s+de\s+\w+\b/.test(lower) // "29 de mayo"
        const timeWord = /\b(\d{1,2}(:\d{2})?\s*(am|pm|a\.?m\.?|p\.?m\.?|hrs?|horas?))\b|\b(a\s+las?\s+\d{1,2})/.test(lower)
        const hasDateTime = (dayWord || dayNum) && timeWord
        if (hasDateTime) {
          forceToolChoice = { type: "tool", name: "check_availability_for_booking" }
        }
        if (!forceToolChoice) {
          const { data: lastTool } = await supabase
            .from("ai_messages")
            .select("tool_name, tool_output, created_at")
            .eq("conversation_id", convId)
            .eq("role", "tool")
            .eq("tool_name", "check_availability_for_booking")
            .order("created_at", { ascending: false })
            .limit(1)
          const recent = (lastTool ?? []) as Array<{ tool_output: Record<string, unknown> | null; created_at: string }>
          if (recent.length > 0) {
            const out = recent[0].tool_output as Record<string, unknown> | null
            const slots = out && Array.isArray(out.suggested_slots) ? out.suggested_slots : []
            if (out && out.available === false && slots.length > 0) {
              forceToolChoice = { type: "tool", name: "check_availability_for_booking" }
            }
          }
        }
      } catch (e) {
        console.warn("force tool detection failed:", (e as Error).message)
      }
    }

    // Loop tool_use
    const startedAt = Date.now()
    let totalIn = 0, totalOut = 0
    let finalText = ""
    let stopReason = ""

    for (let i = 0; i < 5; i++) {  // máx 5 iteraciones tool_use
      const resp = await callAnthropic(
        apiKey, (settings.active_model || settings.llm_model), system, messages,
        settings.temperature, settings.max_output_tokens,
        activeTools,
        // Solo forzamos en la PRIMERA iteración; después dejamos al modelo libre
        i === 0 ? forceToolChoice : undefined,
      )
      totalIn += resp.usage.input_tokens
      totalOut += resp.usage.output_tokens
      stopReason = resp.stop_reason

      // Buscar texto y tool_use en content
      const textParts: string[] = []
      const toolCalls: Array<{ id: string; name: string; input: Record<string, unknown> }> = []
      for (const part of resp.content) {
        if (part.type === "text") textParts.push(String(part.text ?? ""))
        if (part.type === "tool_use") {
          toolCalls.push({
            id: String(part.id), name: String(part.name),
            input: (part.input ?? {}) as Record<string, unknown>,
          })
        }
      }

      finalText = textParts.join("\n").trim()

      if (toolCalls.length === 0 || resp.stop_reason !== "tool_use") {
        break
      }

      // Push assistant turn con tool_use
      messages.push({ role: "assistant", content: resp.content })

      // Ejecutar tools y push tool_result
      const adminToolNames = new Set(ADMIN_TOOLS.map((t) => t.name))
      const results: Array<Record<string, unknown>> = []
      for (const t of toolCalls) {
        const isAdminCall = adminToolNames.has(t.name)
        // Hard block: si un número NO admin llama una admin tool (por seguridad belt-and-suspenders)
        const out = isAdminCall && !isAdmin
          ? { error: "tool_restricted_to_admin" }
          : isAdminCall
            ? await execAdminTool(t.name, t.input)
            : await execTool(t.name, t.input, {
                phone,
                conversationId: convId,
                clientName: client?.full_name ?? null,
              })
        await supabase.from("ai_messages").insert({
          conversation_id: convId, role: "tool",
          tool_name: t.name, tool_input: t.input, tool_output: out,
          is_admin_query: isAdmin,
        })
        results.push({
          type: "tool_result", tool_use_id: t.id,
          content: JSON.stringify(out).slice(0, 8000),
        })
      }
      messages.push({ role: "user", content: results })
    }

    const elapsed = Date.now() - startedAt
    const costUsd =
      (totalIn / 1_000_000) * settings.cost_per_million_input_usd +
      (totalOut / 1_000_000) * settings.cost_per_million_output_usd

    // Insertar respuesta del assistant + observabilidad fechas
    const tjNowIso = new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" })
    await supabase.from("ai_messages").insert({
      conversation_id: convId, role: "assistant",
      content: finalText || "(sin respuesta)",
      tokens_in: totalIn, tokens_out: totalOut,
      latency_ms: elapsed, llm_model: (settings.active_model || settings.llm_model),
      stop_reason: stopReason,
      is_admin_query: isAdmin,
      tool_output: {
        server_now_utc: new Date().toISOString(),
        server_now_tijuana: tjNowIso,
        timezone: "America/Tijuana",
        mode: isAdmin ? "admin" : "customer",
      },
    })

    // Actualizar totales conversación
    await supabase.from("ai_conversations").update({
      last_message_at: new Date().toISOString(),
      total_tokens_in: (existing?.total_tokens_in ?? 0) + totalIn,
      total_tokens_out: (existing?.total_tokens_out ?? 0) + totalOut,
      total_cost_usd: ((existing as { total_cost_usd?: number })?.total_cost_usd ?? 0) + costUsd,
      message_count: ((existing?.message_count ?? 0) as number) + 2,
    }).eq("id", convId)

    // Enviar a Meta (texto libre dentro de ventana 24h)
    if (finalText) {
      await sendTextToMeta(phone, finalText.slice(0, 1500))
    }

    return jsonResponse({
      ok: true, conversation_id: convId,
      reply: finalText, tokens_in: totalIn, tokens_out: totalOut,
      cost_usd: Number(costUsd.toFixed(6)), elapsed_ms: elapsed,
      stop_reason: stopReason,
    })
  } catch (e) {
    console.error("whatsapp-ai-router", e)
    return jsonResponse({ error: (e as Error).message }, 500)
  }
})

async function sendTextToMeta(phone: string, text: string) {
  const settings = await loadBusinessSettings(supabase, DEFAULT_BRANCH_ID)
  if (!settings) return
  await callMetaApi(
    `${settings.row.phone_number_id}/messages`,
    settings.accessToken,
    {
      method: "POST",
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: phone,
        type: "text",
        text: { body: text },
      }),
    },
  )
}
