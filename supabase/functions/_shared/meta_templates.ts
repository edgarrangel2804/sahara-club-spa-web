// Sahara Club Spa - Helpers para Meta WhatsApp Templates oficiales
// Construye payloads "type":"template" válidos para Graph API v21.0,
// valida cantidad/orden de variables y resuelve mapping con la DB.

import {
  callMetaApi,
  META_GRAPH_BASE_URL,
  normalizePhone,
  type AdminClient,
} from "./whatsapp_business.ts"

export type MetaParam =
  | { type: "text"; text: string }
  | { type: "currency"; currency: { fallback_value: string; code: string; amount_1000: number } }
  | { type: "date_time"; date_time: { fallback_value: string } }
  | { type: "image"; image: { link: string } }
  | { type: "document"; document: { link: string; filename?: string } }
  | { type: "video"; video: { link: string } }
  | { type: "payload"; payload: string } // quick reply / button payload

export type MetaComponent =
  | { type: "header"; parameters: MetaParam[] }
  | { type: "body"; parameters: MetaParam[] }
  | { type: "button"; sub_type: "quick_reply" | "url"; index: number; parameters: MetaParam[] }

export type MetaTemplatePayload = {
  messaging_product: "whatsapp"
  to: string
  type: "template"
  template: {
    name: string
    language: { code: string }
    components?: MetaComponent[]
  }
}

export type TemplateRow = {
  id: string
  template_key: string
  template_name: string
  message_body: string
  is_active: boolean
  meta_template_name: string | null
  meta_template_status: string
  meta_language: string
  meta_category: string
  meta_components_schema: Array<Record<string, unknown>> | null
  meta_variables_count: number
  meta_header_format: string | null
}

export type BuildOptions = {
  /** Variables del body en el orden EXACTO esperado por Meta ({{1}}, {{2}}, ...). */
  bodyParams?: Array<string | MetaParam>
  /** Si el template tiene header dinámico. */
  headerParams?: MetaParam[]
  /** Parámetros para botones (quick reply / url). */
  buttons?: Array<{ sub_type: "quick_reply" | "url"; index: number; parameters: MetaParam[] }>
}

function toTextParam(v: string | MetaParam): MetaParam {
  if (typeof v === "string") return { type: "text", text: v }
  return v
}

/**
 * Construye el payload Meta "type":"template" para enviar a Graph API.
 * Lanza Error con mensaje legible si las variables no concuerdan.
 */
export function buildMetaTemplatePayload(
  template: TemplateRow,
  toPhone: string,
  opts: BuildOptions = {},
): MetaTemplatePayload {
  if (!template.meta_template_name) {
    throw new Error(
      `Template "${template.template_key}" sin meta_template_name configurado.`,
    )
  }
  if (template.meta_template_status !== "approved") {
    throw new Error(
      `Template "${template.meta_template_name}" no está APPROVED en Meta (status=${template.meta_template_status}).`,
    )
  }

  const bodyParams = (opts.bodyParams ?? []).map(toTextParam)
  if (bodyParams.length !== template.meta_variables_count) {
    throw new Error(
      `Template "${template.meta_template_name}" espera ${template.meta_variables_count} variables, recibió ${bodyParams.length}.`,
    )
  }

  const components: MetaComponent[] = []

  if (opts.headerParams && opts.headerParams.length > 0) {
    components.push({ type: "header", parameters: opts.headerParams })
  }

  if (bodyParams.length > 0) {
    components.push({ type: "body", parameters: bodyParams })
  }

  if (opts.buttons && opts.buttons.length > 0) {
    for (const b of opts.buttons) {
      components.push({
        type: "button",
        sub_type: b.sub_type,
        index: b.index,
        parameters: b.parameters,
      })
    }
  }

  return {
    messaging_product: "whatsapp",
    to: normalizePhone(toPhone),
    type: "template",
    template: {
      name: template.meta_template_name,
      language: { code: template.meta_language },
      components: components.length > 0 ? components : undefined,
    },
  }
}

/** Helper para llamar a /messages enviando un template ya construido. */
export async function sendMetaTemplate(
  accessToken: string,
  phoneNumberId: string,
  payload: MetaTemplatePayload,
) {
  return callMetaApi<Record<string, unknown>>(
    `${phoneNumberId}/messages`,
    accessToken,
    { method: "POST", body: JSON.stringify(payload) },
  )
}

/**
 * Mapea las variables del contexto (build_whatsapp_context) al orden de Meta,
 * según template_key. La fuente de verdad del ORDEN debe coincidir con el seed.
 */
export function bodyParamsForTemplateKey(
  templateKey: string,
  ctx: Record<string, unknown>,
): string[] {
  const v = (k: string) => String(ctx[k] ?? "").trim()
  switch (templateKey) {
    case "reservation_confirmed":
      return [v("nombre_cliente"), v("nombre_servicio"), v("fecha_reserva"), v("hora_reserva"), v("nombre_terapeuta")]
    case "cita_agendada_recepcion":
      // Template Meta cita_agendada_recepcion:
      // {{1}} nombre_cliente, {{2}} fecha_reserva, {{3}} hora_reserva
      return [v("nombre_cliente"), v("fecha_reserva"), v("hora_reserva")]
    case "reminder_24h":
      return [v("nombre_cliente"), v("nombre_servicio"), v("fecha_reserva"), v("hora_reserva")]
    case "reminder_3h":
      return [v("nombre_cliente"), v("hora_reserva"), v("nombre_terapeuta")]
    case "reminder_1h":
      return [v("nombre_cliente"), v("nombre_servicio"), v("hora_reserva")]
    case "reservation_cancelled":
      return [v("nombre_cliente"), v("nombre_servicio"), v("fecha_reserva")]
    case "reservation_rescheduled":
      return [v("nombre_cliente"), v("fecha_reserva"), v("hora_reserva"), v("nombre_terapeuta")]
    case "welcome":
      return [v("nombre_cliente")]
    case "payment_pending":
      return [v("nombre_cliente"), v("codigo_reserva"), v("link_pago")]
    default:
      return []
  }
}

/**
 * Resuelve el template Meta para una event_type. Devuelve null si no existe.
 * Se filtra por is_active true para no enviar templates desactivados localmente.
 */
export async function resolveTemplateForEvent(
  supabase: AdminClient,
  eventType: string,
  branchId: string | null,
  templateId?: string | null,
): Promise<TemplateRow | null> {
  const columns =
    "id, template_key, template_name, message_body, is_active, meta_template_name, meta_template_status, meta_language, meta_category, meta_components_schema, meta_variables_count, meta_header_format"

  if (templateId) {
    const { data, error } = await supabase
      .from("whatsapp_templates")
      .select(columns)
      .eq("id", templateId)
      .maybeSingle()
    if (error) throw error
    return (data ?? null) as TemplateRow | null
  }

  // 1) busca por sucursal exacta
  if (branchId) {
    const { data, error } = await supabase
      .from("whatsapp_templates")
      .select(columns)
      .eq("trigger_event", eventType)
      .eq("is_active", true)
      .eq("branch_id", branchId)
      .maybeSingle()
    if (error) throw error
    if (data) return data as TemplateRow
  }

  // 2) fallback: template sin sucursal
  const { data, error } = await supabase
    .from("whatsapp_templates")
    .select(columns)
    .eq("trigger_event", eventType)
    .eq("is_active", true)
    .is("branch_id", null)
    .maybeSingle()
  if (error) throw error
  return (data ?? null) as TemplateRow | null
}

/** ¿El cliente nos escribió en las últimas 24h? */
export async function isWithinCustomerServiceWindow(
  supabase: AdminClient,
  phone: string,
): Promise<boolean> {
  const { data, error } = await supabase.rpc(
    "is_within_customer_service_window",
    { p_phone: phone },
  )
  if (error) {
    console.warn("isWithinCustomerServiceWindow rpc error", error)
    return false
  }
  return Boolean(data)
}

/** Normaliza un código de idioma para comparar (es ≡ es_MX ≡ es_mx). */
function normLang(lang: string): string {
  return (lang || "").trim().toLowerCase().split(/[_-]/)[0]
}
function normName(name: string): string {
  return (name || "").trim().toLowerCase()
}

/**
 * Sincroniza el catálogo de templates desde Meta hacia DB local.
 *
 * Reglas críticas (post-bug 2026-05-25):
 *   - Si Meta devuelve 0 templates o error, ABORTA la sync sin tocar la DB.
 *     Es peligrosísimo marcar todos como deleted por una respuesta vacía.
 *   - El match name+language es case-insensitive y normaliza el idioma
 *     (Meta puede devolver "es" mientras la DB tiene "es_MX" — ambos son el mismo).
 *   - Solo marca deleted los templates que estaban presentes en una sync previa
 *     Y que esta sync confirma como ausentes con catálogo válido.
 */
export async function syncMetaTemplates(
  supabase: AdminClient,
  accessToken: string,
  wabaId: string,
) {
  if (!accessToken || !wabaId) {
    throw new Error("syncMetaTemplates: accessToken y wabaId requeridos")
  }

  const all: Array<Record<string, unknown>> = []
  let url = `${META_GRAPH_BASE_URL}/${wabaId}/message_templates?fields=id,name,language,status,category,components,quality_score&limit=200`

  // Pagina hasta agotar
  while (true) {
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    })
    const json = (await res.json().catch(() => ({}))) as {
      data?: Array<Record<string, unknown>>
      paging?: { next?: string }
      error?: { message?: string }
    }
    if (!res.ok) {
      throw new Error(`Meta GET message_templates falló: ${json?.error?.message ?? res.status}`)
    }
    all.push(...(json.data ?? []))
    const next = json.paging?.next
    if (!next) break
    url = next
  }

  // ⚠️ SAFETY: si Meta devolvió catálogo vacío, ABORTA sin tocar nada.
  if (all.length === 0) {
    return {
      fetched: 0,
      updated: 0,
      skipped_no_match: 0,
      marked_deleted: 0,
      aborted: true,
      reason: "empty_catalog_from_meta",
      synced_at: new Date().toISOString(),
    }
  }

  const nowIso = new Date().toISOString()
  let updated = 0
  let skipped = 0
  const seen: Array<{ nameKey: string; langKey: string }> = []
  const allowedStatus = new Set([
    "approved","pending","rejected","disabled","paused","deleted",
  ])

  // Cargamos todas las filas locales para matchear in-memory (case/lang insensitive)
  const { data: localRows, error: localErr } = await supabase
    .from("whatsapp_templates")
    .select("id, meta_template_name, meta_language")
    .not("meta_template_name", "is", null)
  if (localErr) throw localErr
  const localList = (localRows ?? []) as Array<{
    id: string; meta_template_name: string; meta_language: string
  }>

  for (const tmpl of all) {
    const name = String(tmpl.name ?? "")
    const lang = String(tmpl.language ?? "es")
    const nameKey = normName(name)
    const langKey = normLang(lang)
    if (!nameKey) continue
    seen.push({ nameKey, langKey })

    const status = String(tmpl.status ?? "UNKNOWN").toLowerCase()
    const category = String(tmpl.category ?? "UTILITY").toUpperCase()
    const components = (tmpl.components ?? []) as Array<Record<string, unknown>>
    const id = tmpl.id ? String(tmpl.id) : null

    const bodyComp = components.find((c) => String(c.type ?? "").toUpperCase() === "BODY")
    const bodyText = String((bodyComp as { text?: string } | undefined)?.text ?? "")
    const varCount = (bodyText.match(/\{\{\d+\}\}/g) ?? []).length
    const headerComp = components.find((c) => String(c.type ?? "").toUpperCase() === "HEADER")
    const headerFormat = headerComp ? String((headerComp as { format?: string }).format ?? "") : null

    const dbStatus = allowedStatus.has(status) ? status : "unknown"

    // Match in-memory case + language insensitive
    const matching = localList.filter(
      (r) => normName(r.meta_template_name) === nameKey &&
             normLang(r.meta_language) === langKey,
    )

    if (matching.length === 0) {
      skipped += 1
      continue
    }

    for (const row of matching) {
      const { error: updErr } = await supabase
        .from("whatsapp_templates")
        .update({
          meta_template_status: dbStatus,
          meta_language: lang,
          meta_category: category,
          meta_components_schema: components,
          meta_variables_count: varCount,
          meta_template_id: id,
          meta_header_format: headerFormat,
          approved_at: dbStatus === "approved" ? nowIso : null,
          rejected_reason: dbStatus === "rejected"
            ? String((tmpl as { rejected_reason?: string }).rejected_reason ?? "")
            : null,
          last_sync_at: nowIso,
        })
        .eq("id", row.id)

      if (updErr) {
        console.error("sync update failed", updErr)
      } else {
        updated += 1
      }
    }
  }

  // Marca deleted SOLO si:
  //   1. La respuesta de Meta fue válida (lo confirmamos arriba: all.length>0)
  //   2. El template local NO aparece en el catálogo de Meta (comparación normalizada)
  //   3. Y NO está ya marcado como deleted
  const seenKeys = new Set(seen.map((s) => `${s.nameKey}::${s.langKey}`))
  const { data: dbRowsForDelete } = await supabase
    .from("whatsapp_templates")
    .select("id, meta_template_name, meta_language, meta_template_status")
    .not("meta_template_name", "is", null)
  let markedDeleted = 0
  for (const row of (dbRowsForDelete ?? []) as Array<{
    id: string; meta_template_name: string; meta_language: string; meta_template_status: string
  }>) {
    const key = `${normName(row.meta_template_name)}::${normLang(row.meta_language)}`
    if (!seenKeys.has(key) && row.meta_template_status !== "deleted") {
      const { error } = await supabase
        .from("whatsapp_templates")
        .update({ meta_template_status: "deleted", last_sync_at: nowIso })
        .eq("id", row.id)
      if (!error) markedDeleted += 1
    }
  }

  return {
    fetched: all.length,
    updated,
    skipped_no_match: skipped,
    marked_deleted: markedDeleted,
    aborted: false,
    synced_at: nowIso,
  }
}
