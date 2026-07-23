import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts"
import {
  buildAiBookingRequestId,
  buildCreatePendingBookingRpcArgs,
  normalizeAiBookingTime,
} from "./ai_booking_contracts.ts"

Deno.test("AI booking time normalization preserves PostgreSQL time contract", () => {
  assertEquals(normalizeAiBookingTime("10:30"), "10:30:00")
  assertEquals(normalizeAiBookingTime("10:30:00"), "10:30:00")
  assertEquals(normalizeAiBookingTime(" 10:30 "), "10:30:00")
})

Deno.test("AI booking request id is stable, scoped and does not expose PII", async () => {
  const base = {
    channel: "web_concierge" as const,
    phone: "+52 646 151 9597",
    clientName: "Ana Maria Lopez",
    email: "ana@example.com",
    serviceId: "00000000-0000-4000-8000-000000000101",
    bookingDate: "2026-08-10",
    bookingTime: "10:30",
    durationMin: 60,
    notes: "Solicitud creada por concierge web.",
  }

  const first = await buildAiBookingRequestId(base)
  const second = await buildAiBookingRequestId({ ...base, bookingTime: "10:30:00" })
  const changed = await buildAiBookingRequestId({ ...base, bookingTime: "11:00" })

  assertEquals(first, second)
  assert(first !== changed)
  assertStringIncludes(first, "ai-booking:web_concierge:")
  assert(!first.includes("6461519597"))
  assert(!first.includes("ana@example.com"))
  assert(!first.includes("Ana"))
})

Deno.test("web and WhatsApp create_pending_booking RPC args include idempotency key", async () => {
  const webArgs = await buildCreatePendingBookingRpcArgs({
    channel: "web_concierge",
    phone: "6461519597",
    clientName: "Ana Maria Lopez",
    email: "ana@example.com",
    serviceId: "00000000-0000-4000-8000-000000000101",
    bookingDate: "2026-08-10",
    bookingTime: "10:30",
    durationMin: null,
    notes: "Solicitud creada por concierge web.",
    confidenceScore: 0.9,
  })

  const whatsappArgs = await buildCreatePendingBookingRpcArgs({
    channel: "whatsapp_ai",
    phone: "5216461519597",
    clientName: "Ana Maria Lopez",
    email: null,
    serviceId: "00000000-0000-4000-8000-000000000101",
    bookingDate: "2026-08-10",
    bookingTime: "10:30",
    durationMin: 60,
    notes: "Solicitud creada por IA WhatsApp.",
    conversationId: "00000000-0000-4000-8000-000000000201",
    confidenceScore: 0.9,
    externalMessageId: "wamid.test-message",
  })

  assertEquals(webArgs.p_email, "ana@example.com")
  assertEquals(webArgs.p_booking_time, "10:30:00")
  assertEquals(webArgs.p_therapist_id, null)
  assertStringIncludes(webArgs.p_request_id, "ai-booking:web_concierge:")
  assertEquals(whatsappArgs.p_ai_conversation_id, "00000000-0000-4000-8000-000000000201")
  assertStringIncludes(whatsappArgs.p_request_id, "ai-booking:whatsapp_ai:")
  assert(whatsappArgs.p_request_id !== webArgs.p_request_id)
})
