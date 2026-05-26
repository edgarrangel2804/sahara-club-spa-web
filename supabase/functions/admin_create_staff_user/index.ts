// Sahara Club Spa - admin_create_staff_user
// ---------------------------------------------------------------------------
// Crea (o vincula) un usuario en auth.users a partir de un registro staff.
// - Auth: el caller debe estar autenticado y tener role='admin' en public.staff.
// - Si el email ya existe en auth.users → vincula (no duplica, no resetea pass).
// - Devuelve { auth_user_id, linked, created } y actualiza staff.auth_user_id +
//   can_login = true + email confirmado.
//
// Body: { staff_id: uuid, email: string, password?: string, full_name?: string, role?: string }
// Response 200: { ok: true, auth_user_id, linked, created }
// Response 4xx: { ok: false, error, code }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function j(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors })
  if (req.method !== "POST") return j(405, { ok: false, error: "method not allowed" })

  // 1. Verificar caller autenticado y que sea admin en staff
  const authHeader = req.headers.get("Authorization") || ""
  const token = authHeader.replace(/^Bearer\s+/i, "")
  if (!token) return j(401, { ok: false, error: "missing bearer token" })

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  })
  const { data: userData, error: userErr } = await userClient.auth.getUser()
  if (userErr || !userData?.user) {
    return j(401, { ok: false, error: "invalid token", details: userErr?.message })
  }
  const callerId = userData.user.id

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

  const { data: callerStaff, error: callerStaffErr } = await admin
    .from("staff")
    .select("id, role, active")
    .eq("auth_user_id", callerId)
    .maybeSingle()

  if (callerStaffErr) {
    return j(500, { ok: false, error: "staff lookup failed", details: callerStaffErr.message })
  }
  if (!callerStaff || callerStaff.role !== "admin" || callerStaff.active === false) {
    return j(403, { ok: false, error: "caller is not an active admin" })
  }

  // 2. Parse body
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return j(400, { ok: false, error: "invalid json body" })
  }

  const staff_id = String(body.staff_id ?? "").trim()
  const email = String(body.email ?? "").trim().toLowerCase()
  const password = body.password ? String(body.password) : ""
  const full_name = body.full_name ? String(body.full_name) : ""
  const role = body.role ? String(body.role) : ""

  if (!staff_id) return j(400, { ok: false, error: "staff_id required" })
  if (!email || !email.includes("@")) return j(400, { ok: false, error: "valid email required" })

  // 3. Verificar que staff_id existe
  const { data: staffRow, error: staffErr } = await admin
    .from("staff")
    .select("id, full_name, role, auth_user_id, email")
    .eq("id", staff_id)
    .maybeSingle()
  if (staffErr) return j(500, { ok: false, error: "staff lookup failed", details: staffErr.message })
  if (!staffRow) return j(404, { ok: false, error: "staff not found" })

  // 4. Buscar si el email ya existe en auth.users
  // (la API admin.listUsers pagina; con un filtro de email)
  let existingUserId: string | null = null
  try {
    // Buscamos por email directo a la tabla via service role.
    // Auth schema no es queryable directo con supabase-js; usamos un RPC simple:
    const { data: dup, error: dupErr } = await admin
      .rpc("staff_find_auth_user_by_email", { p_email: email })
    if (dupErr) {
      // Si el RPC no existe, intentamos crear y manejamos el conflicto.
      console.warn("RPC staff_find_auth_user_by_email missing:", dupErr.message)
    } else if (dup) {
      existingUserId = dup as string
    }
  } catch (e) {
    console.warn("dup check threw:", (e as Error).message)
  }

  let authUserId: string
  let linked = false
  let created = false

  if (existingUserId) {
    authUserId = existingUserId
    linked = true
  } else {
    if (!password || password.length < 6) {
      return j(400, { ok: false, error: "password (min 6 chars) required for new user" })
    }
    const { data: createRes, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name,
        role,
        staff_id,
      },
    })
    if (createErr || !createRes?.user) {
      // Posible: email ya existe pero el RPC no lo detectó. Damos error útil.
      const msg = createErr?.message ?? "unknown create error"
      if (msg.toLowerCase().includes("already")) {
        return j(409, {
          ok: false,
          error: "El correo ya está registrado. Usa otro o vincula manualmente al usuario existente.",
          code: "email_exists",
        })
      }
      return j(500, { ok: false, error: "auth.admin.createUser failed", details: msg })
    }
    authUserId = createRes.user.id
    created = true
  }

  // 5. Actualizar staff: auth_user_id, can_login=true, email sync, role sync
  const updatePayload: Record<string, unknown> = {
    auth_user_id: authUserId,
    can_login: true,
  }
  if (email && email !== staffRow.email) updatePayload.email = email
  if (role && role !== staffRow.role) updatePayload.role = role

  const { error: updErr } = await admin
    .from("staff")
    .update(updatePayload)
    .eq("id", staff_id)
  if (updErr) {
    return j(500, { ok: false, error: "staff update failed", details: updErr.message })
  }

  // Sincronizar public.profiles.role con el role del staff. Esto es CRÍTICO:
  // el portal lee profiles.role para mostrar menús, y un auth user nuevo nace
  // con profiles.role='client' por default → quedaría sin acceso admin.
  if (role) {
    const { error: profErr } = await admin
      .from("profiles")
      .upsert({ id: authUserId, role }, { onConflict: "id" })
    if (profErr) {
      console.warn("profiles upsert failed:", profErr.message)
      // No fallamos el endpoint — staff ya está vinculado. Devolvemos warning.
      return j(200, {
        ok: true,
        auth_user_id: authUserId,
        linked,
        created,
        warning: `staff vinculado, pero no se pudo sincronizar profiles.role: ${profErr.message}`,
      })
    }
  }

  return j(200, {
    ok: true,
    auth_user_id: authUserId,
    linked,
    created,
    message: linked
      ? "Correo ya existía en Auth. Se vinculó al staff sin cambiar el password."
      : "Usuario creado y vinculado correctamente.",
  })
})
