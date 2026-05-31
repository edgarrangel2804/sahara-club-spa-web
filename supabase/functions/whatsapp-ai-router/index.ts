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

function normalizeSearchText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
}

async function resolveRequestedStaffId(
  input: Record<string, unknown>,
  messageText: string | null | undefined,
): Promise<string | null> {
  const explicit = String(input.staff_id ?? "").trim()
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    .test(explicit)) return explicit

  const haystack = normalizeSearchText(
    `${explicit} ${String(input.staff_name ?? "")} ${messageText ?? ""}`,
  )
  if (!haystack) return null

  const { data, error } = await supabase
    .from("staff")
    .select("id, full_name")
    .eq("role", "therapist")
    .eq("active", true)
  if (error) {
    console.warn("resolveRequestedStaffId failed:", error.message)
    return null
  }

  const matches: string[] = []
  for (const row of (data ?? []) as Array<{ id: string; full_name: string }>) {
    const full = normalizeSearchText(row.full_name ?? "")
    if (!full) continue
    const first = full.split(" ")[0] ?? ""
    if (haystack.includes(full) || (first.length >= 4 && haystack.includes(first))) {
      matches.push(row.id)
    }
  }
  return matches.length === 1 ? matches[0] : null
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

// Envía un texto plano a los números operativos (human_backup + admins) con dedup
// implícito por contenido distinto. Usado para alertas de reagenda/cancelación IA.
async function notifyReceptionRaw(alertText: string): Promise<number> {
  const { data: s } = await supabase
    .from("ai_settings")
    .select("human_backup_enabled, human_backup_numbers, ai_admin_numbers")
    .eq("id", 1).maybeSingle()
  const enabled = (s as { human_backup_enabled?: boolean } | null)?.human_backup_enabled === true
  if (!enabled) return 0
  const backups = ((s as { human_backup_numbers?: string[] } | null)?.human_backup_numbers ?? []) as string[]
  const admins = ((s as { ai_admin_numbers?: string[] } | null)?.ai_admin_numbers ?? []) as string[]
  const seen = new Set<string>()
  let okCount = 0
  for (const list of [backups, admins]) {
    for (const raw of list) {
      const tail = String(raw).replace(/\D/g, "").slice(-10)
      if (tail.length !== 10 || seen.has(tail)) continue
      seen.add(tail)
      try {
        await sendTextToMeta(normalizePhone(String(raw)), alertText)
        okCount += 1
      } catch (e) {
        console.warn("notifyReceptionRaw send failed:", (e as Error).message)
      }
    }
  }
  return okCount
}

async function loadBookingBrief(bookingId: string): Promise<{ service: string; date?: string; time?: string }> {
  try {
    const { data } = await supabase
      .from("bookings")
      .select("booking_date, booking_time, service_id, services(name)")
      .eq("id", bookingId)
      .maybeSingle()
    const row = (data ?? {}) as Record<string, unknown>
    const svc = (row.services as { name?: string } | null)?.name ?? "Servicio"
    return {
      service: svc,
      date: row.booking_date ? String(row.booking_date) : undefined,
      time: row.booking_time ? String(row.booking_time).slice(0, 5) : undefined,
    }
  } catch {
    return { service: "Servicio" }
  }
}

async function notifyReceptionReschedule(
  customerPhone: string, customerName: string | null,
  bookingId: string, newDate: string, newTime: string,
): Promise<number> {
  const brief = await loadBookingBrief(bookingId)
  const alert = [
    "🔄 *Reagenda IA (revalidar)*",
    "",
    `*Cliente:* ${customerName ?? "Cliente WhatsApp"}`,
    `*Teléfono:* ${customerPhone}`,
    `*Servicio:* ${brief.service}`,
    `*Nueva fecha:* ${newDate}`,
    `*Nueva hora:* ${newTime}`,
    "",
    "La cita quedó en revisión (pending_reception). Validar en agenda Sahara.",
  ].join("\n")
  return await notifyReceptionRaw(alert)
}

async function notifyReceptionCancel(
  customerPhone: string, customerName: string | null,
  bookingId: string, reason: string,
): Promise<number> {
  const brief = await loadBookingBrief(bookingId)
  const alert = [
    "❌ *Cancelación IA*",
    "",
    `*Cliente:* ${customerName ?? "Cliente WhatsApp"}`,
    `*Teléfono:* ${customerPhone}`,
    `*Servicio:* ${brief.service}`,
    brief.date ? `*Fecha:* ${brief.date}${brief.time ? ` ${brief.time}` : ""}` : "",
    reason ? `*Motivo:* ${reason}` : "",
    "",
    "El cliente canceló su cita desde WhatsApp.",
  ].filter(Boolean).join("\n")
  return await notifyReceptionRaw(alert)
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
      "OBLIGATORIO antes de create_pending_booking. Verifica disponibilidad real del slot solicitado contra business_hours, días cerrados, schedule_blocks y bookings existentes (incluye scheduled / pending_reception). Si está libre, available=true. Si NO está libre, devuelve suggested_slots con 3 alternativas reales del mismo día o de los siguientes días. NUNCA crees una cita sin haber llamado primero esta tool y haber recibido available=true.",
    input_schema: {
      type: "object",
      properties: {
        service_id: { type: "string", description: "UUID del servicio (de list_services)" },
        requested_date: { type: "string", description: "YYYY-MM-DD zona Tijuana" },
        requested_time: { type: "string", description: "HH:MM 24h" },
        duration_min: { type: "number", description: "Duración minutos (opcional, default servicio)" },
        staff_id: { type: "string", description: "UUID del terapeuta si el cliente pidio uno especifico" },
        staff_name: { type: "string", description: "Nombre del terapeuta si el cliente pidio uno especifico" },
      },
      required: ["service_id", "requested_date", "requested_time"],
    },
  },
  {
    name: "get_staff_day_status",
    description:
      "Devuelve el estado de cada terapeuta para una fecha: working / off / time_off / lunch / busy / available. Úsalo SOLO si el cliente pregunta explícitamente por una terapeuta (\"¿está Victoria?\", \"¿quién atiende hoy?\", \"¿Anita trabaja mañana?\"). NO la uses para chequear si un slot está libre — para eso usa check_availability_for_booking. Solo lectura, no reserva nada. Devuelve también start_time/end_time/lunch_start/lunch_end por si necesitas narrar horarios.",
    input_schema: {
      type: "object",
      properties: {
        date: { type: "string", description: "YYYY-MM-DD en zona Tijuana. Si se omite, usa hoy." },
      },
    },
  },
  {
    name: "create_pending_booking",
    description:
      "Crea solicitud en agenda real con status='scheduled' (Agendada). SOLO usa esta tool DESPUÉS de check_availability_for_booking con available=true. Recepción/admin la marca como 'confirmed' después. Idempotente: dedup 10 min por cliente+servicio+fecha+hora.",
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
  {
    name: "consult_my_appointments",
    description:
      "Devuelve las próximas citas del cliente que escribe (se identifica por su propio teléfono, no pidas el número). Úsala cuando pregunte '¿qué citas tengo?', '¿cuándo es mi cita?', '¿a qué hora quedé?', '¿ya tengo algo agendado?'. Solo lectura. Cada cita trae booking_id, service_name, date, time, status_label y ai_manageable (true si tú puedes reagendarla/cancelarla, false si la maneja recepción).",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "reschedule_my_booking",
    description:
      "Mueve una cita EXISTENTE del cliente a nueva fecha/hora. Úsala solo cuando el cliente pida cambiar/mover una cita suya. PRIMERO obtén el booking_id con consult_my_appointments y confirma cuál cita quiere mover. Solo funciona si ai_manageable=true (citas no confirmadas). Valida disponibilidad: si available=false devuelve suggested_slots para ofrecer. Si available=true, deja la cita en revisión de recepción con la nueva fecha/hora.",
    input_schema: {
      type: "object",
      properties: {
        booking_id: { type: "string", description: "UUID de la cita a mover (de consult_my_appointments)" },
        new_date: { type: "string", description: "YYYY-MM-DD zona Tijuana" },
        new_time: { type: "string", description: "HH:MM 24h (ej. 16:00)" },
      },
      required: ["booking_id", "new_date", "new_time"],
    },
  },
  {
    name: "cancel_my_booking",
    description:
      "Cancela una cita EXISTENTE del cliente. Úsala solo cuando el cliente pida explícitamente cancelar una cita suya, y DESPUÉS de confirmar con él cuál (obtén el booking_id con consult_my_appointments). Solo funciona si ai_manageable=true. Si devuelve error 'requires_reception', informa que recepción le ayudará con esa cita.",
    input_schema: {
      type: "object",
      properties: {
        booking_id: { type: "string", description: "UUID de la cita a cancelar (de consult_my_appointments)" },
        reason: { type: "string", description: "Motivo breve si el cliente lo da (opcional)" },
      },
      required: ["booking_id"],
    },
  },
]

type ToolContext = {
  phone?: string
  conversationId?: string
  clientName?: string | null
  messageText?: string | null
}

// "Ahora" en zona Tijuana, como wall-clock (mismo truco que buildSystemPrompt).
// En un server UTC (Deno Deploy) toISOString/toTimeString devuelven la hora de
// pared de Tijuana, no UTC. Las usamos solo para comparar contra fecha/hora pedida.
function tjNowParts(): { date: string; time: string } {
  const tjNow = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
  return {
    date: tjNow.toISOString().slice(0, 10),
    time: tjNow.toTimeString().slice(0, 5),
  }
}

// Guard determinista: ¿la fecha/hora solicitada ya pasó en Tijuana?
// No dependemos de que el modelo razone bien las fechas; bloqueamos a nivel código.
// Comparación lexicográfica de "YYYY-MM-DDTHH:MM" (ambos en hora de pared Tijuana).
function isPastTjDateTime(date: string, time: string): boolean {
  if (!date) return false
  const t = (time && time.length >= 5) ? time.slice(0, 5) : (time || "00:00")
  const { date: nowDate, time: nowTime } = tjNowParts()
  return `${date}T${t}` < `${nowDate}T${nowTime}`
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
    case "get_staff_day_status": {
      const date = String(input.date ?? "").trim()
      const args: Record<string, unknown> = {}
      if (date) args.p_date = date
      const { data, error } = await supabase.rpc("get_staff_day_status", args)
      if (error) return { error: error.message }
      return data ?? { staff: [] }
    }
    case "check_availability_for_booking": {
      const serviceId = String(input.service_id ?? "").trim()
      const date = String(input.requested_date ?? "").trim()
      const time = String(input.requested_time ?? "").trim()
      if (!serviceId || !date || !time) {
        return { error: "missing_service_or_datetime" }
      }
      // 🛡️ Nunca agendar en el pasado. Si la fecha/hora ya pasó en Tijuana,
      // no consultamos disponibilidad ni creamos booking: pedimos otra hora.
      if (isPastTjDateTime(date, time)) {
        const tjNow = tjNowParts()
        return {
          error: "past_datetime",
          available: false,
          requested_date: date,
          requested_time: time,
          server_now_date: tjNow.date,
          server_now_time: tjNow.time,
          note: "La fecha/hora solicitada ya pasó en zona Tijuana. Pide al cliente un día/hora futuros.",
        }
      }
      const timeNorm = time.length === 5 ? `${time}:00` : time
      const requestedStaffId = await resolveRequestedStaffId(input, ctx.messageText)
      const { data, error } = await supabase.rpc("check_availability_for_booking_from_ai", {
        p_service_id: serviceId,
        p_requested_date: date,
        p_requested_time: timeNorm,
        p_duration_min: input.duration_min ? Number(input.duration_min) : null,
        p_staff_id: requestedStaffId,
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
            // Política: solo asignamos terapeuta si el cliente lo pidió por
            // nombre. Si la elección la hizo el RPC automáticamente,
            // dejamos therapist_id=null para que recepción asigne.
            p_therapist_id: requestedStaffId
              ? String(requestedStaffId)
              : null,
          })
          if (!createErr && created) {
            const createdResult = created as Record<string, unknown>
            result.booking_id = createdResult.booking_id
            result.booking_created = createdResult.created
            result.duplicate_prevented = createdResult.duplicate_prevented
            result.status = createdResult.status

            // Si el booking fue creado por primera vez:
            //  0) Consultar check_booking_payment_requirement (gift_card / membresía)
            //  1a) Si waiver aplica → marcar booking waived + alerta a recepción
            //  1b) Si requiere anticipo → flip a pending_payment + URL Stripe
            if (createdResult.created === true && createdResult.booking_id) {
              const bookingId = String(createdResult.booking_id)
              try {
                // ¿Aplica waiver?
                const { data: req } = await supabase.rpc(
                  "check_booking_payment_requirement",
                  {
                    p_phone: phone,
                    p_service_id: serviceId,
                    p_requested_date: date,
                    p_requested_time: timeNorm,
                    p_customer_name: ctx.clientName ?? null,
                  },
                )
                const reqResult = (req ?? {}) as Record<string, unknown>
                const requiresDeposit = reqResult.requires_deposit !== false
                const waiverReason = String(reqResult.reason ?? "deposit_required")
                const depositCents = Number(reqResult.deposit_required_cents ?? 20000)
                const depositAmount = depositCents / 100

                // Cargar monto/enabled de ai_settings
                const { data: aiCfg } = await supabase
                  .from("ai_settings")
                  .select("appointment_deposit_amount, appointment_deposit_enabled")
                  .eq("id", 1)
                  .maybeSingle()
                const depositEnabled = (aiCfg as { appointment_deposit_enabled?: boolean } | null)
                  ?.appointment_deposit_enabled !== false

                if (!requiresDeposit && depositEnabled) {
                  // === WAIVER APPLIES ===
                  const giftCardId = reqResult.gift_card_id as string | null
                  const membershipId = reqResult.membership_id as string | null
                  await supabase
                    .from("bookings")
                    .update({
                      status: "pending_reception",
                      payment_requirement: "waived",
                      waiver_reason: waiverReason,
                      gift_card_id: giftCardId,
                      membership_id: membershipId,
                      deposit_required_cents: depositCents,
                    })
                    .eq("id", bookingId)

                  result.status = "pending_reception"
                  result.payment_requirement = "waived"
                  result.waiver_reason = waiverReason
                  result.checkout_url = null
                  result.deposit_amount = 0

                  // Alerta a recepción / human_backup
                  try {
                    const { data: svc } = await supabase.from("services")
                      .select("name").eq("id", serviceId).maybeSingle()
                    const serviceName = (svc as { name?: string } | null)?.name ?? "Servicio"
                    const reasonLabel = waiverReason === "gift_card"
                      ? "Gift card activa con saldo"
                      : waiverReason === "membership"
                        ? "Membresía activa con sesiones"
                        : "Override admin"
                    const alert = [
                      "📅 *Nueva solicitud IA (sin anticipo)*",
                      "",
                      `*Cliente:* ${ctx.clientName ?? "Cliente WhatsApp"}`,
                      `*Teléfono:* ${phone}`,
                      `*Servicio:* ${serviceName}`,
                      `*Fecha:* ${date}`,
                      `*Hora:* ${time}`,
                      `*Beneficio:* ${reasonLabel}`,
                      "",
                      "Pendiente de validar en agenda Sahara.",
                    ].join("\n")
                    const { data: settingsRow } = await supabase.from("ai_settings")
                      .select("human_backup_numbers, human_backup_enabled, ai_admin_numbers")
                      .eq("id", 1).maybeSingle()
                    const enabled = (settingsRow as { human_backup_enabled?: boolean } | null)
                      ?.human_backup_enabled === true
                    const backups = ((settingsRow as { human_backup_numbers?: string[] } | null)
                      ?.human_backup_numbers ?? []) as string[]
                    const admins = ((settingsRow as { ai_admin_numbers?: string[] } | null)
                      ?.ai_admin_numbers ?? []) as string[]
                    const seen = new Set<string>()
                    if (enabled) {
                      for (const list of [backups, admins]) {
                        for (const t of list) {
                          const tail = String(t).replace(/\D/g, "").slice(-10)
                          if (tail.length === 10 && !seen.has(tail)) {
                            seen.add(tail)
                            try { await sendTextToMeta(normalizePhone(String(t)), alert) } catch {
                              /* swallow */
                            }
                          }
                        }
                      }
                    }
                  } catch (e) {
                    console.warn("waiver alert failed:", (e as Error).message)
                  }
                } else if (depositEnabled) {
                  // === REQUIRES DEPOSIT ===
                  await supabase
                    .from("bookings")
                    .update({
                      status: "pending_payment",
                      payment_requirement: "deposit_required",
                      deposit_required_cents: depositCents,
                      deposit_amount: depositAmount,
                      payment_status: "pending",
                    })
                    .eq("id", bookingId)
                  result.checkout_url = `https://saharaclubspa.com/pagar-anticipo/${bookingId}`
                  result.deposit_amount = depositAmount
                  result.status = "pending_payment"
                  result.payment_requirement = "deposit_required"
                } else {
                  // anticipo deshabilitado globalmente
                  result.deposit_disabled = true
                }
              } catch (e) {
                console.warn("auto-flip with waiver check failed:", (e as Error).message)
                result.checkout_error = (e as Error).message
              }
            }
          } else {
            // available=true pero el insert del booking falló (createErr) o
            // devolvió null. NO podemos dejar que la IA diga "registramos tu
            // solicitud": sería mentira (recepción no ve nada en agenda).
            // Marcamos fallo explícito y alertamos a recepción.
            result.booking_failed = true
            result.booking_created = false
            result.checkout_error = createErr?.message ?? "create_pending_booking_returned_null"
            try {
              await notifyHumanBackup(phone, ctx.messageText ?? "(intento de reserva)", "ai_booking_create_failed")
            } catch { /* swallow */ }
          }
        } catch (e) {
          console.warn("auto-create after available=true failed:", (e as Error).message)
          // Excepción dura en el flujo de creación → mismo blindaje: la IA NO
          // debe confirmar una reserva que no se persistió.
          result.booking_failed = true
          result.booking_created = false
          result.checkout_error = (e as Error).message
          try {
            await notifyHumanBackup(phone, ctx.messageText ?? "(intento de reserva)", "ai_booking_create_exception")
          } catch { /* swallow */ }
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
      // 🛡️ Defensa en profundidad: jamás crear una cita en el pasado (Tijuana).
      if (isPastTjDateTime(date, time)) {
        const tjNow = tjNowParts()
        return {
          ok: false,
          error: "past_datetime",
          server_now_date: tjNow.date,
          server_now_time: tjNow.time,
          note: "La fecha/hora ya pasó en zona Tijuana. Pide al cliente un día/hora futuros antes de crear la cita.",
        }
      }
      // Normalizar HH:MM → HH:MM:00 para tipo time
      const timeNorm = time.length === 5 ? `${time}:00` : time
      const requestedStaffId = await resolveRequestedStaffId(input, ctx.messageText)
      // Safety net: re-verificar disponibilidad. La IA debió llamar
      // check_availability_for_booking antes, pero validamos por si acaso.
      const { data: availCheck } = await supabase.rpc("check_availability_for_booking_from_ai", {
        p_service_id: serviceId,
        p_requested_date: date,
        p_requested_time: timeNorm,
        p_duration_min: input.duration_min ? Number(input.duration_min) : null,
        p_staff_id: requestedStaffId,
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
        // Política: respetar terapeuta SOLO si el cliente lo nombró.
        // Si no, dejar NULL para que recepción asigne.
        p_therapist_id: requestedStaffId
          ? String(requestedStaffId)
          : null,
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
    case "consult_my_appointments": {
      const phone = String(ctx.phone ?? "").trim()
      if (!phone) return { error: "phone_missing_from_context" }
      const { data, error } = await supabase.rpc("consult_my_appointments_from_ai", {
        p_phone: phone,
      })
      if (error) return { error: error.message }
      return (data as Record<string, unknown> | null) ?? { ok: false, error: "rpc_returned_null" }
    }
    case "reschedule_my_booking": {
      const phone = String(ctx.phone ?? "").trim()
      if (!phone) return { error: "phone_missing_from_context" }
      const bookingId = String(input.booking_id ?? "").trim()
      const newDate = String(input.new_date ?? "").trim()
      const newTime = String(input.new_time ?? "").trim()
      if (!bookingId || !newDate || !newTime) return { error: "missing_params" }
      const timeNorm = newTime.length === 5 ? `${newTime}:00` : newTime
      const { data, error } = await supabase.rpc("reschedule_my_booking_from_ai", {
        p_phone: phone,
        p_booking_id: bookingId,
        p_new_date: newDate,
        p_new_time: timeNorm,
      })
      if (error) return { error: error.message }
      const result = (data as Record<string, unknown> | null) ?? { ok: false, error: "rpc_returned_null" }
      // Si se reagendó con éxito, alerta a recepción (re-validación de slot nuevo).
      if (result.ok === true && result.rescheduled === true) {
        try {
          await notifyReceptionReschedule(phone, ctx.clientName ?? null, bookingId, newDate, newTime)
        } catch (e) {
          console.warn("reschedule reception alert failed:", (e as Error).message)
        }
      }
      return result
    }
    case "cancel_my_booking": {
      const phone = String(ctx.phone ?? "").trim()
      if (!phone) return { error: "phone_missing_from_context" }
      const bookingId = String(input.booking_id ?? "").trim()
      if (!bookingId) return { error: "missing_booking_id" }
      const { data, error } = await supabase.rpc("cancel_my_booking_from_ai", {
        p_phone: phone,
        p_booking_id: bookingId,
        p_reason: input.reason ? String(input.reason) : null,
      })
      if (error) return { error: error.message }
      const result = (data as Record<string, unknown> | null) ?? { ok: false, error: "rpc_returned_null" }
      if (result.ok === true && result.cancelled === true) {
        try {
          await notifyReceptionCancel(phone, ctx.clientName ?? null, bookingId, String(input.reason ?? ""))
        } catch (e) {
          console.warn("cancel reception alert failed:", (e as Error).message)
        }
      }
      return result
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
    description: "Lista citas próximas 7 días que están en estado pending, scheduled o pending_reception (creadas por IA), todas esperando confirmar.",
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
  // --- Suite director: finanzas, nómina, clientes, prospectos ---
  {
    name: "get_financial_summary",
    description: "Estado de resultados de un rango (default: mes en curso, Tijuana): ingresos pagados, gastos variables, gastos a proveedores, gastos fijos mensuales, nómina y UTILIDAD neta. Si una sección no tiene datos cargados lo indica con has_data=false. Úsalo para 'cómo vamos este mes', 'utilidad', 'ganancias', 'cuánto llevamos'.",
    input_schema: {
      type: "object",
      properties: {
        date_from: { type: "string", description: "YYYY-MM-DD inicio (opcional)" },
        date_to: { type: "string", description: "YYYY-MM-DD fin (opcional)" },
      },
    },
  },
  {
    name: "get_fixed_expenses",
    description: "Lista los gastos fijos del negocio (renta, servicios, etc.) con monto, frecuencia y día de pago, más el total mensual activo.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "get_payroll_summary",
    description: "Nómina por periodo (default: mes en curso): detalle por empleado (sueldo base, comisiones, bonos, propinas, deducciones, total) y gran total. Para 'cuánto pagamos de nómina', 'sueldos'.",
    input_schema: {
      type: "object",
      properties: {
        date_from: { type: "string" },
        date_to: { type: "string" },
      },
    },
  },
  {
    name: "get_recurring_clients",
    description: "Clientes recurrentes: quienes tienen 2+ citas. Devuelve nombre, teléfono, total de citas, visitas completadas y última visita. Para 'clientes recurrentes', 'clientes frecuentes', 'quiénes regresan'.",
    input_schema: {
      type: "object",
      properties: {
        min_visits: { type: "integer", description: "mínimo de citas para contar como recurrente (default 2)" },
        limit: { type: "integer", description: "máximo de clientes a devolver (default 20)" },
      },
    },
  },
  {
    name: "get_client_lookup",
    description: "Busca un cliente por NOMBRE o TELÉFONO y devuelve su ficha completa: contacto, historial reciente de citas, próxima cita, total de visitas y membresía. Para 'dame los datos de X', 'historial de X', 'cuándo vino X'.",
    input_schema: {
      type: "object",
      properties: { query: { type: "string", description: "nombre o teléfono" } },
      required: ["query"],
    },
  },
  {
    name: "get_memberships_summary",
    description: "Membresías activas: total, cuántas vencen en 30 días, cuántas con auto-renovación, y el detalle (cliente, vencimiento, sesiones usadas/totales). Para 'membresías', 'quién está por vencer'.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "get_prospects",
    description: "Clientes nuevos / prospectos de un rango (default: mes en curso): total de altas, cuántos son leads sin cita aún, y el detalle. Para 'prospectos', 'clientes nuevos', 'leads'.",
    input_schema: {
      type: "object",
      properties: {
        date_from: { type: "string" },
        date_to: { type: "string" },
      },
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
      // Derivado: "pendientes por confirmar" = pending + scheduled + pending_reception (IA) + rescheduled
      const pendingToConfirm =
        (counts["pending"] ?? 0) +
        (counts["scheduled"] ?? 0) +
        (counts["pending_reception"] ?? 0) +
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
        .in("status", ["pending", "scheduled", "pending_reception"])
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
    // --- Suite director: finanzas, nómina, clientes, prospectos ---
    case "get_financial_summary": {
      const { data, error } = await supabase.rpc("admin_financial_summary_from_ai", {
        p_from: input.date_from ? String(input.date_from) : null,
        p_to: input.date_to ? String(input.date_to) : null,
      })
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    case "get_fixed_expenses": {
      const { data, error } = await supabase.rpc("admin_fixed_expenses_from_ai")
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    case "get_payroll_summary": {
      const { data, error } = await supabase.rpc("admin_payroll_summary_from_ai", {
        p_from: input.date_from ? String(input.date_from) : null,
        p_to: input.date_to ? String(input.date_to) : null,
      })
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    case "get_recurring_clients": {
      const { data, error } = await supabase.rpc("admin_recurring_clients_from_ai", {
        p_min_visits: typeof input.min_visits === "number" ? input.min_visits : 2,
        p_limit: typeof input.limit === "number" ? input.limit : 20,
      })
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    case "get_client_lookup": {
      const { data, error } = await supabase.rpc("admin_client_lookup_from_ai", {
        p_query: String(input.query ?? ""),
      })
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    case "get_memberships_summary": {
      const { data, error } = await supabase.rpc("admin_memberships_summary_from_ai")
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    case "get_prospects": {
      const { data, error } = await supabase.rpc("admin_prospects_from_ai", {
        p_from: input.date_from ? String(input.date_from) : null,
        p_to: input.date_to ? String(input.date_to) : null,
      })
      if (error) return { error: error.message }
      return data ?? { error: "sin datos" }
    }
    default:
      return { error: `admin tool desconocida: ${name}` }
  }
}

function buildAdminSystemPrompt(): { stable: string; dynamic: string } {
  const days = ["domingo","lunes","martes","miércoles","jueves","viernes","sábado"]
  const tjNow = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
  const tjDate = tjNow.toISOString().slice(0, 10)
  const tjTime = tjNow.toTimeString().slice(0, 5)
  const tjWeekday = days[tjNow.getDay()]
  const tjTomorrowDate = new Date(tjNow.getTime() + 86400000).toISOString().slice(0, 10)
  const tjTomorrowName = days[(tjNow.getDay() + 1) % 7]

  const stable = `Eres Sahara, el ANALISTA DE NEGOCIO y mano derecha del dueño/administrador de Sahara Club Spa.
Este usuario es admin autorizado (dueño/arquitecto). Tiene acceso TOTAL a la información del negocio por WhatsApp: operación, finanzas, nómina, gastos, clientes (con nombres y contacto), membresías y prospectos. Tu trabajo es darle datos REALES, claros y accionables, y ACONSEJARLO cuando lo pida o cuando los datos lo ameriten.

REGLAS DURAS (admin):
1. Solo LECTURA. Nunca creas, modificas, cancelas ni editas nada. Si te piden una
   acción de escritura ("cancela", "modifica", "elimina", "cambia pago", "edita"):
   "Por seguridad solo consulto, no ejecuto cambios. Eso se hace desde el panel en saharaclubspa.com."
2. DATOS DE CLIENTES PERMITIDOS: este admin SÍ puede ver nombres completos, teléfono,
   email e historial de clientes. Úsalos cuando los pida (ej. get_client_lookup,
   get_recurring_clients). Estás hablando con el dueño, no con un cliente.
3. NUNCA inventes números, nombres ni datos. Si una tool devuelve has_data=false o
   vacío, DILO con claridad: ej. "Aún no hay gastos/nómina cargados en el sistema para ese periodo."
   Nunca rellenes con suposiciones ni con conocimiento general.
4. Fechas SIEMPRE en America/Tijuana, usando las tools (no calcules de memoria).
5. ALCANCE EXCLUSIVO SAHARA (regla más importante): toda respuesta se basa SOLO en
   datos devueltos por las tools de la DB de Sahara Club Spa. PROHIBIDO usar
   conocimiento general, datos de otros negocios, promedios de la industria, noticias,
   o temas ajenos (tecnología, traducciones, código, consejos médicos, etc.).
   Si preguntan algo fuera de Sahara: "Solo manejo información de Sahara Club Spa."
6. CONSEJOS PERMITIDOS pero ATERRIZADOS EN DATOS DE SAHARA: puedes interpretar,
   sugerir y recomendar SIEMPRE Y CUANDO te apoyes en los números reales que
   devolvieron las tools (ej. "12 de tus 16 altas del mes son leads sin cita →
   conviene una campaña de primera cita"). Nada de teoría genérica sin datos detrás.

CÓMO ELEGIR HERRAMIENTAS:
- Operación del día / citas / cancelaciones / no-shows → tools operativas (get_today_summary, etc.).
- "Cómo vamos", utilidad, ganancias, ingresos vs gastos del mes → get_financial_summary.
- Gastos fijos → get_fixed_expenses. Nómina/sueldos → get_payroll_summary.
- Clientes recurrentes/frecuentes → get_recurring_clients.
- Datos/historial de un cliente concreto → get_client_lookup (por nombre o teléfono).
- Membresías / por vencer → get_memberships_summary.
- Prospectos / clientes nuevos / leads → get_prospects.
- Para análisis amplios, llama varias tools y sintetiza.

FORMATO:
- Tono ejecutivo y directo, bullets para WhatsApp. Máximo 1 emoji sutil por bullet/título: 📊 📅 💰 ⏰ ⚠️ 🤖 👥 🔝 📈 📉 🧾
- Resúmenes operativos: breves (≈6 líneas). Reportes financieros, de clientes o
  análisis con consejo: usa lo que necesites pero sé conciso (idealmente ≤ 14 líneas).
- Montos en MXN. Si net_profit es negativo, dilo claro (pérdida) y sugiere dónde mirar.
- Si una sección viene en cero por falta de captura, acláralo para que no se lea como $0 real.

NOTA: en el resumen del día, "Pendientes por confirmar" ya viene en pending_to_confirm
(pending + scheduled + pending_reception + rescheduled). NO sumes manualmente.

EJEMPLOS:
P: "¿Cómo vamos este mes?" → get_financial_summary; reporta ingresos, gastos, nómina y
   utilidad; si faltan datos cargados, dilo; cierra con 1 recomendación basada en los números.
P: "¿Cuántos clientes recurrentes tenemos?" → get_recurring_clients; da el conteo y el top.
P: "Dame los datos de Rodrigo" → get_client_lookup con query "Rodrigo"; entrega ficha completa.
P: "Cancela la cita de las 4pm" → "Por seguridad solo consulto, no ejecuto cambios. Eso se hace desde el panel."
`

  const dynamic = `CONTEXTO TEMPORAL:
- Zona horaria: America/Tijuana
- Hoy es: ${tjWeekday} ${tjDate} (hora actual: ${tjTime})
- Mañana es: ${tjTomorrowName} ${tjTomorrowDate}
`

  return { stable, dynamic }
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

// Bloque de contenido para el system prompt con soporte de prompt caching.
type SystemBlock = { type: "text"; text: string; cache_control?: { type: "ephemeral" } }

// Devuelve el system como array de bloques cacheables (orden: estable → dinámico).
// El bloque estable (reglas) no cambia entre mensajes → cache hit por 5 min.
// El bloque dinámico (fechas, catálogo, cliente) cambia poco → también cacheable
// dentro del loop de tool_use de un mismo mensaje y entre mensajes del mismo día.
function buildSystemBlocks(stable: string, dynamic: string): SystemBlock[] {
  return [
    { type: "text", text: stable, cache_control: { type: "ephemeral" } },
    { type: "text", text: dynamic, cache_control: { type: "ephemeral" } },
  ]
}

function buildSystemPrompt(clientKnown: string | null, serviceCatalog: string = ""): { stable: string; dynamic: string } {
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

  const stable = `Eres Sahara, asistente concierge de Sahara Club Spa (spa de bienestar en Ensenada, BC).
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
10. CONTACTO DIRECTO cuando la conversación se alarga:
   - Si el cliente hace MUCHAS preguntas seguidas, pide detalles que no tienes en tus tools,
     o la charla se extiende sin avanzar a una reserva, ofrécele AMABLEMENTE el teléfono directo
     del spa para que lo atiendan en persona y resuelvan todas sus dudas.
   - Frase sugerida: "Para resolver todas tus dudas con calma, también puedes comunicarte directo
     con nuestro equipo al 646 151 9597 ✨ Con gusto te atienden."
   - NO lo ofrezcas en el primer mensaje ni para deshacerte del cliente. Solo cuando de verdad notes
     que la conversación es larga o que no estás resolviendo. Sigue cálida y dispuesta a ayudar.

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
✅ "Tu cita fue agendada para [servicio] el [día] a las [hora]. Nuestro equipo
   la revisará y te confirmará en breve ✨"
   (porque SÍ se creó un row real en la agenda con status pending_reception,
    aunque no esté confirmada por recepción).
   NO digas "tu cita está confirmada" — la confirmación viene cuando recepción
   o admin la marca como confirmed en el sistema.

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

  🚨 ANTES DE CASO A — verifica que el booking SÍ se creó:
    Si el output trae booking_failed=true (o booking_created NO es true aunque
    available=true), NO digas "registramos tu solicitud" ni "fue agendada".
    Significa que falló el guardado y recepción no ve nada. Responde:
    "Tuvimos un problema registrando tu solicitud. Recepción se pondrá en
    contacto contigo en breve para confirmar 🌿" y NADA más. NO inventes
    confirmación. Solo si booking_created=true (o duplicate_prevented=true)
    procede con el wording de CASO A.

  CASO A — available=true Y booking_created=true (booking creado automáticamente):
    El tool puede regresar uno de DOS sub-casos según los beneficios del cliente:

    SUB-CASO A1 — payment_requirement='waived' (cliente con gift card o membresía):
      El cliente NO necesita pagar anticipo. checkout_url será null y el waiver_reason
      indica el motivo ('gift_card' o 'membership'). Responde EXACTAMENTE así:

      "Perfecto ✨

      Registramos tu solicitud para [Servicio] ([N] minutos),
      [día de la semana] [N] de [mes], a las [HH] horas.

      Recepción validará disponibilidad y te confirmará por aquí en breve 🌿"

      NO menciones el motivo del waiver al cliente — recepción ya lo ve en agenda.

    SUB-CASO A2 — payment_requirement='deposit_required' (cliente regular):
      checkout_url contiene el link a pagar el anticipo $200 MXN. Responde:

      "Perfecto ✨

      Registramos tu solicitud para [Servicio] ([N] minutos),
      [día de la semana] [N] de [mes], a las [HH] horas.

      Para continuar con la validación de tu cita, realiza un anticipo de
      $200 MXN aquí:
      [checkout_url]

      Una vez recibido el pago, recepción validará disponibilidad y agendará
      tu cita por este medio 🌿"

    Si la tool devuelve duplicate_prevented=true, NO repitas el mensaje
    largo: di "Ya registramos tu solicitud hace un momento ✨ Recepción
    validará y te confirmará por aquí en breve 🌿"
    (Si hay checkout_url disponible y la solicitud aún no se pagó, agrega:
    "Si aún no realizas el anticipo, aquí está el link nuevamente: [checkout_url]")

    Si checkout_error está presente (falló generar link Stripe): di
    "Tu solicitud quedó registrada pero hubo un problema generando el
    link de anticipo. Recepción te contactará en breve para confirmar."

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

GESTIÓN DE CITAS EXISTENTES (consultar, reagendar, cancelar):

CONSULTAR — cliente pregunta "¿qué citas tengo?", "¿cuándo es mi cita?",
  "¿a qué hora quedé?":
  • Llama consult_my_appointments (NO pidas su teléfono, ya lo tenemos).
  • Si appointments viene vacío: "No encuentro citas próximas a tu nombre 🌿
    ¿Te ayudo a agendar una?"
  • Si hay citas, lístalas con servicio, día y hora usando status_label.
    Ej: "Tienes: • Masaje relajante · jueves 5 jun · 16:00 · En revisión por recepción"

REAGENDAR — cliente pide cambiar/mover una cita:
  PASO A: si no sabes cuál cita, llama consult_my_appointments y pregunta
    cuál quiere mover (o cuál es si solo tiene una).
  PASO B: cuando tengas el booking_id y la nueva fecha/hora, llama
    reschedule_my_booking con booking_id, new_date (YYYY-MM-DD de la tabla
    autoritativa), new_time (HH:MM 24h).
  RESULTADOS:
    • rescheduled=true → "Listo, movimos tu solicitud a [día] [hora].
      Recepción la validará y te confirmará por aquí ✨"
    • available=false → ofrece los suggested_slots como en CASO B de reservas.
    • error='requires_reception' → "Esa cita ya está confirmada, así que
      recepción te ayudará a moverla. Les aviso 🌿" (NO la muevas tú).
    • error='not_your_booking' / 'booking_not_found' → "No encuentro esa cita
      a tu nombre. ¿Te muestro tus citas?" + consult_my_appointments.

CANCELAR — cliente pide cancelar una cita:
  • SIEMPRE confirma primero CUÁL cita (usa consult_my_appointments si hay
    duda). Nunca canceles sin que el cliente lo haya pedido explícitamente.
  • Llama cancel_my_booking con booking_id (y reason si lo dio).
  RESULTADOS:
    • cancelled=true → "Listo, cancelamos tu cita de [servicio]. Si quieres
      reagendar más adelante, aquí estoy 🌿"
    • error='requires_reception' → "Esa cita ya está confirmada; recepción
      te ayudará a cancelarla. Les aviso." (NO la canceles tú).
    • error='not_your_booking' / 'booking_not_found' → "No encuentro esa cita
      a tu nombre. ¿Te muestro tus citas?"

🚨 SEGURIDAD: solo gestionas citas del PROPIO cliente que escribe. NUNCA
  consultes, muevas ni canceles citas de otra persona aunque te den otro
  nombre o teléfono. Si piden gestionar la cita de alguien más: "Por
  privacidad solo puedo ver y mover tus propias citas 🌿".

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
- 🚫 NUNCA agendes en el PASADO. Una cita siempre es a FUTURO.
- DÍA DE LA SEMANA AMBIGUO: si HOY es el mismo día que pide el cliente
  (ej. hoy es sábado y dice "el sábado"), NO asumas que es hoy. Si el
  cliente dio también un número/fecha (ej. "sábado 6 de junio"), usa esa
  fecha exacta de la tabla. Si solo dijo el nombre del día sin número y la
  hora de hoy para ese día ya pasó, entiéndelo como el PRÓXIMO [día] (la
  siguiente ocurrencia en la tabla), o PREGUNTA: "¿Te refieres a hoy [fecha]
  o al próximo [día] [fecha]?". Nunca lo agendes hoy si la hora ya pasó.
- HORA YA PASADA HOY: si el cliente pide una hora de HOY que ya pasó según
  "Hora actual Tijuana", NO la agendes. Ofrece una hora más tarde de hoy o
  el siguiente día disponible.
- Si check_availability_for_booking devuelve error="past_datetime", NO
  insistas: discúlpate brevemente y pide al cliente una fecha/hora futura.
- Zona horaria oficial: America/Tijuana.

FLUJO TÍPICO:
- Saluda en primer mensaje, ofrece ayuda.
- Usa tools para responder con DATOS REALES.
- No prometas disponibilidad final. Nunca confirmes.
- Cierra con apertura suave ("¿algo más?" o "¿te puedo ayudar con algo más?").
`

  const dynamic = `CONTEXTO TEMPORAL — TABLA AUTORITATIVA (próximos 14 días):
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
`

  return { stable, dynamic }
}

// ---------------------------------------------------------------------------
// Anthropic API call con tool-use loop
// ---------------------------------------------------------------------------
type AnthropicMessage = {
  role: "user" | "assistant"
  content: string | Array<Record<string, unknown>>
}

// Marca la última tool con cache_control para cachear todo el bloque de tools.
// El array de tools es idéntico en cada request → prefijo cacheado por 5 min.
function withToolCache(tools: unknown[]): unknown[] {
  if (tools.length === 0) return tools
  const copy = tools.map((t) => ({ ...(t as Record<string, unknown>) }))
  const lastIdx = copy.length - 1
  copy[lastIdx] = { ...copy[lastIdx], cache_control: { type: "ephemeral" } }
  return copy
}

async function callAnthropic(
  apiKey: string, model: string, system: string | SystemBlock[],
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
    usage: {
      input_tokens: number; output_tokens: number
      cache_creation_input_tokens?: number
      cache_read_input_tokens?: number
    }
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  // Capturados en scope externo para el blindaje del catch global.
  let phoneForError = ""
  let messageForError = ""

  try {
    const body = await req.json().catch(() => ({}))
    const phoneRaw = String(body.phone ?? "").trim()
    const messageText = String(body.message_text ?? "").trim()
    const wamid = body.wamid ? String(body.wamid) : null
    const phone = normalizePhone(phoneRaw)
    phoneForError = phone
    messageForError = messageText

    if (!phone || !messageText) {
      return jsonResponse({ error: "phone y message_text requeridos" }, 400)
    }

    const settings = await loadSettings()

    // Resolver o crear conversación.
    // ROTACIÓN POR SESIÓN / DÍA. Una conversación NO vive para siempre; cuando se
    // renueva se CIERRA la vieja y se abre una NUEVA con todos los contadores en 0
    // (message_count, tokens y rate-limit de 24 h). Así ningún cliente queda mudo de
    // forma permanente (incidente 2026-05-30: ambas conversaciones piloto se atascaron
    // en 30 msgs y el gate las bloqueó con 'msg_cap_reached' indefinidamente).
    // Se renueva si:
    //   - DIARIA  : nació hace > 24 h  → "todos empiezan en cero" cada día.
    //   - INACTIVA: > 6 h sin actividad → sesión nueva tras una pausa larga.
    //   - TOPE    : alcanzó max_messages_per_conversation → rota en vez de BLOQUEAR.
    const SESSION_IDLE_MS = 6 * 60 * 60 * 1000
    const SESSION_MAX_AGE_MS = 24 * 60 * 60 * 1000
    let { data: existing } = await supabase
      .from("ai_conversations")
      .select("id, total_tokens_in, total_tokens_out, message_count, total_cost_usd, last_message_at, created_at")
      .eq("customer_phone", phone)
      .eq("status", "active")
      .order("last_message_at", { ascending: false })
      .limit(1)
      .maybeSingle()

    if (existing) {
      const capMsgs = Number(
        (settings as { max_messages_per_conversation?: number }).max_messages_per_conversation ?? 60,
      )
      const nowMs = Date.now()
      const lastMs = existing.last_message_at
        ? new Date(existing.last_message_at as string).getTime()
        : 0
      const bornMs = existing.created_at
        ? new Date(existing.created_at as string).getTime()
        : nowMs
      const ageRotate = nowMs - bornMs > SESSION_MAX_AGE_MS
      const idleRotate = nowMs - lastMs > SESSION_IDLE_MS
      const capRotate = Number(existing.message_count ?? 0) >= capMsgs
      if (ageRotate || idleRotate || capRotate) {
        await supabase.from("ai_conversations")
          .update({
            status: "closed",
            escalation_reason: ageRotate
              ? "daily_rotated_24h"
              : capRotate
              ? "msg_cap_rotated"
              : "session_idle_rotated",
          })
          .eq("id", existing.id as string)
        // Forzar creación de una conversación nueva y limpia (contadores en 0).
        existing = null
      }
    }

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
    const { stable: sysStable, dynamic: sysDynamic } = isAdmin
      ? buildAdminSystemPrompt()
      : buildSystemPrompt(client?.full_name ?? null, serviceCatalog)
    const system = buildSystemBlocks(sysStable, sysDynamic)
    // Tools con cache_control en la última → prefijo de tools cacheado.
    const cachedTools = withToolCache(activeTools)

    // Cargar historia últimos mensajes (solo texto user/assistant).
    const { data: history } = await supabase
      .from("ai_messages")
      .select("role, content, created_at")
      .eq("conversation_id", convId)
      .order("created_at", { ascending: true })
      .limit(40)

    // Convertir historia a formato Anthropic: SOLO texto user/assistant.
    // No reconstruimos tool_use/tool_result de turnos previos (ai_messages no
    // guarda tool_use_id, así que sería inválido). El catálogo con UUIDs vive
    // en el system prompt y los suggested_slots quedan en el propio texto del
    // assistant, por lo que el modelo conserva el contexto necesario.
    // Se colapsan roles consecutivos iguales y se garantiza que el primer
    // mensaje sea 'user' (requisito de la Messages API).
    const messages: AnthropicMessage[] = []
    for (const m of (history ?? []) as Array<Record<string, unknown>>) {
      let role: "user" | "assistant" | null = null
      if (m.role === "user") role = "user"
      else if (m.role === "assistant" && m.content) role = "assistant"
      else continue // descarta filas tool/system
      const text = String(m.content ?? "").trim()
      if (!text) continue
      const prev = messages[messages.length - 1]
      if (prev && prev.role === role && typeof prev.content === "string") {
        prev.content = `${prev.content}\n\n${text}`
      } else {
        messages.push({ role, content: text })
      }
    }
    while (messages.length > 0 && messages[0].role !== "user") messages.shift()

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
        // Intención de GESTIÓN (reagendar/cancelar/consultar) sobre cita existente.
        // Si aparece, NO forzamos check_availability_for_booking aunque haya
        // fecha+hora: forzarlo crearía una cita NUEVA en lugar de mover/cancelar
        // la existente. Dejamos que el modelo elija reschedule_my_booking, etc.
        const manageIntent = /\b(reagend|reprogram|cambiar?|mover|recorrer|pasar|cancelar?|anular|elimina|quitar?\s+(mi|la)\s+cita|mis?\s+citas?|qu[eé]\s+citas|cu[aá]ndo\s+(es|tengo)\s+mi)\b/.test(lower)
        if (hasDateTime && !manageIntent) {
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
    let totalCacheRead = 0, totalCacheCreate = 0
    let finalText = ""
    let stopReason = ""

    for (let i = 0; i < 5; i++) {  // máx 5 iteraciones tool_use
      const resp = await callAnthropic(
        apiKey, (settings.active_model || settings.llm_model), system, messages,
        settings.temperature, settings.max_output_tokens,
        cachedTools,
        // Solo forzamos en la PRIMERA iteración; después dejamos al modelo libre
        i === 0 ? forceToolChoice : undefined,
      )
      totalIn += resp.usage.input_tokens
      totalOut += resp.usage.output_tokens
      totalCacheRead += resp.usage.cache_read_input_tokens ?? 0
      totalCacheCreate += resp.usage.cache_creation_input_tokens ?? 0
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
                messageText,
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
    // input_tokens NO incluye los tokens cacheados; se cobran aparte:
    // cache write ≈ 1.25x input, cache read ≈ 0.1x input.
    const costUsd =
      (totalIn / 1_000_000) * settings.cost_per_million_input_usd +
      (totalCacheCreate / 1_000_000) * settings.cost_per_million_input_usd * 1.25 +
      (totalCacheRead / 1_000_000) * settings.cost_per_million_input_usd * 0.1 +
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
        cache_read_tokens: totalCacheRead,
        cache_creation_tokens: totalCacheCreate,
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
      cache_read_tokens: totalCacheRead, cache_creation_tokens: totalCacheCreate,
      cost_usd: Number(costUsd.toFixed(6)), elapsed_ms: elapsed,
      stop_reason: stopReason,
    })
  } catch (e) {
    console.error("whatsapp-ai-router", e)
    // Blindaje: ante un fallo duro (Anthropic caído, Vault, RPC crítica), el
    // cliente NO debe quedarse sin respuesta. Mandamos un mensaje suave y
    // alertamos a recepción para que dé seguimiento humano.
    if (phoneForError) {
      try {
        await sendTextToMeta(
          phoneForError,
          "Estamos teniendo un detalle técnico de nuestro lado 🌿 Recepción te contactará en breve para ayudarte.",
        )
      } catch (sendErr) {
        console.warn("fallback client message failed:", (sendErr as Error).message)
      }
      try {
        await notifyHumanBackup(phoneForError, messageForError || "(sin texto)", "ai_router_hard_error")
      } catch { /* swallow */ }
    }
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
