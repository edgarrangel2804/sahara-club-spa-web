export type AiBookingChannel = "web_concierge" | "whatsapp_ai"

export type CreatePendingBookingRpcArgsInput = {
  channel: AiBookingChannel
  phone: string
  clientName: string
  email?: string | null
  serviceId: string
  bookingDate: string
  bookingTime: string
  durationMin?: number | null
  notes?: string | null
  conversationId?: string | null
  confidenceScore?: number | null
  therapistId?: string | null
  externalMessageId?: string | null
}

export type CreatePendingBookingRpcArgs = {
  p_phone: string
  p_client_name: string
  p_email: string | null
  p_service_id: string
  p_booking_date: string
  p_booking_time: string
  p_duration_min: number | null
  p_notes: string | null
  p_ai_conversation_id: string | null
  p_ai_confidence_score: number | null
  p_therapist_id: string | null
  p_request_id: string
}

const encoder = new TextEncoder()

export function normalizeAiBookingTime(value: string): string {
  const clean = String(value ?? "").trim()
  return /^\d{2}:\d{2}$/.test(clean) ? `${clean}:00` : clean
}

function normalizeOptionalText(value: string | null | undefined): string | null {
  const clean = String(value ?? "").replace(/\s+/g, " ").trim()
  return clean.length > 0 ? clean : null
}

function stableJson(value: Record<string, unknown>): string {
  return JSON.stringify(
    Object.keys(value).sort().reduce<Record<string, unknown>>((acc, key) => {
      acc[key] = value[key]
      return acc
    }, {}),
  )
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value))
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
}

export async function buildAiBookingRequestId(
  input: CreatePendingBookingRpcArgsInput,
): Promise<string> {
  const normalized = {
    bookingDate: input.bookingDate.trim(),
    bookingTime: normalizeAiBookingTime(input.bookingTime),
    channel: input.channel,
    clientName: normalizeOptionalText(input.clientName)?.toLowerCase() ?? "",
    conversationId: normalizeOptionalText(input.conversationId) ?? "",
    durationMin: input.durationMin ?? null,
    email: normalizeOptionalText(input.email)?.toLowerCase() ?? "",
    externalMessageId: normalizeOptionalText(input.externalMessageId) ?? "",
    phoneDigits: input.phone.replace(/\D/g, ""),
    serviceId: input.serviceId.trim().toLowerCase(),
    therapistId: normalizeOptionalText(input.therapistId)?.toLowerCase() ?? "",
  }
  const digest = await sha256Hex(stableJson(normalized))
  return `ai-booking:${input.channel}:${digest}`
}

export async function buildCreatePendingBookingRpcArgs(
  input: CreatePendingBookingRpcArgsInput,
): Promise<CreatePendingBookingRpcArgs> {
  return {
    p_phone: input.phone,
    p_client_name: normalizeOptionalText(input.clientName) ?? "",
    p_email: normalizeOptionalText(input.email),
    p_service_id: input.serviceId,
    p_booking_date: input.bookingDate,
    p_booking_time: normalizeAiBookingTime(input.bookingTime),
    p_duration_min: input.durationMin ?? null,
    p_notes: normalizeOptionalText(input.notes),
    p_ai_conversation_id: normalizeOptionalText(input.conversationId),
    p_ai_confidence_score: input.confidenceScore ?? null,
    p_therapist_id: normalizeOptionalText(input.therapistId),
    p_request_id: await buildAiBookingRequestId(input),
  }
}
