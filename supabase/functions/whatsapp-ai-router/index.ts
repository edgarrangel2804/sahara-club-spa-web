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
]

async function execTool(name: string, input: Record<string, unknown>) {
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
      let q = supabase
        .from("faqs")
        .select("question, answer, category, tags")
        .eq("is_active", true)
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
      return { faqs: rows.slice(0, 6) }
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
    default:
      return { error: `tool desconocida: ${name}` }
  }
}

// ---------------------------------------------------------------------------
// System prompt
// ---------------------------------------------------------------------------
function buildSystemPrompt(clientKnown: string | null) {
  // SIEMPRE en zona horaria del negocio
  const days = ["domingo","lunes","martes","miércoles","jueves","viernes","sábado"]
  const tjNow = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Tijuana" }))
  const tjDate = tjNow.toISOString().slice(0, 10)
  const tjTime = tjNow.toTimeString().slice(0, 5)
  const tjWeekday = days[tjNow.getDay()]
  const tjTomorrowDate = new Date(tjNow.getTime() + 86400000).toISOString().slice(0, 10)
  const tjTomorrowName = days[(tjNow.getDay() + 1) % 7]

  return `Eres Sahara, asistente virtual de Sahara Club Spa (spa de bienestar en Ensenada, BC).
Tu rol: asesorar al cliente con información real del spa. Recepción confirma toda cita.

REGLAS DURAS (no negociables):
1. NUNCA confirmas, agendas, cancelas ni reagendas citas. Solo das información.
2. NUNCA inventes servicios, precios, horarios, beneficios ni terapeutas. Si no aparece en tools, di "déjame verificar con recepción".
3. NUNCA des consejo médico ni diagnóstico. Si mencionan condición médica, sugiere consultar con su médico y con recepción.
4. NO ofrezcas descuentos. Si los piden: "déjame consultar con recepción".
5. Si el cliente quiere agendar/reservar, responde EXACTAMENTE: "Con gusto te puedo orientar. Recepción confirmará disponibilidad y te avisará por aquí." (puedes adaptar tono pero ese sentido).
6. Tono cálido, profesional, breve. MÁXIMO 4 LÍNEAS por mensaje.
7. Responde en español MX. Si el cliente escribe en inglés, responde en inglés.
8. Si no puedes ayudar con datos disponibles: "Recepción te atenderá pronto por aquí mismo."

REGLAS DE FECHAS (CRÍTICO):
9. NUNCA calcules fechas manualmente. Usa EXCLUSIVAMENTE las fechas devueltas por las tools (campos today_date, today_name, tomorrow_date, tomorrow_name).
10. Si el cliente dice "mañana", "hoy", "el lunes", etc → llama get_business_hours() PRIMERO y usa los campos server_today/tomorrow para resolver.
11. Zona horaria oficial del negocio: America/Tijuana. Nunca uses otra.

CONTEXTO TEMPORAL (provisto por el sistema, NO calcules, solo cita):
- Zona horaria: America/Tijuana
- Hoy es: ${tjWeekday} ${tjDate} (hora actual Tijuana: ${tjTime})
- Mañana es: ${tjTomorrowName} ${tjTomorrowDate}

CONTEXTO NEGOCIO:
- Sahara Club Spa, Ensenada
- Cliente conocido en sistema: ${clientKnown ?? "(desconocido, primera interacción)"}

FLUJO TÍPICO:
- Saluda en primer mensaje, ofrece ayuda.
- Usa tools para responder con DATOS REALES.
- No prometas disponibilidad final.
- Si terminas de informar, cierra con "¿te puedo ayudar con algo más?".
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
) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model, max_tokens: maxTokens, temperature, system,
      tools: TOOLS, messages,
    }),
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

    // Persistir mensaje user SIEMPRE (auditoría)
    await supabase.from("ai_messages").insert({
      conversation_id: convId,
      role: "user",
      content: messageText,
      wamid,
    })

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
      return jsonResponse({
        skipped: true,
        reason: denyReason,
        conversation_id: convId,
        phone,
        gate,
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
      const cap = "Esta conversación se atenderá ahora por recepción para darte mejor seguimiento."
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

    // Identificar cliente (para system prompt)
    const last10 = phone.replace(/\D/g, "").slice(-10)
    const { data: client } = await supabase
      .from("clients").select("full_name")
      .ilike("phone", `%${last10}%`).limit(1).maybeSingle()
    const system = buildSystemPrompt(client?.full_name ?? null)

    // Cargar historia últimos 20 mensajes (excluyendo system)
    const { data: history } = await supabase
      .from("ai_messages")
      .select("role, content, tool_name, tool_input, tool_output")
      .eq("conversation_id", convId)
      .order("created_at", { ascending: true })
      .limit(40)

    // Convertir historia a formato Anthropic
    const messages: AnthropicMessage[] = []
    for (const m of (history ?? []) as Array<Record<string, unknown>>) {
      if (m.role === "user") {
        messages.push({ role: "user", content: String(m.content ?? "") })
      } else if (m.role === "assistant" && m.content) {
        messages.push({ role: "assistant", content: String(m.content) })
      }
      // Las llamadas de tool no se reconstruyen del historial: el LLM las verá si necesita
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
      const results: Array<Record<string, unknown>> = []
      for (const t of toolCalls) {
        const out = await execTool(t.name, t.input)
        await supabase.from("ai_messages").insert({
          conversation_id: convId, role: "tool",
          tool_name: t.name, tool_input: t.input, tool_output: out,
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
      tool_output: {
        server_now_utc: new Date().toISOString(),
        server_now_tijuana: tjNowIso,
        timezone: "America/Tijuana",
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
