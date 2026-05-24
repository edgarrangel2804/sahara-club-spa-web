-- Sahara Club Spa - WhatsApp Meta Templates (Fase 2)
-- Extiende whatsapp_templates con campos oficiales de Meta,
-- crea logs ricos, y la función de ventana 24h.

create extension if not exists pgcrypto;

-- 1. Extender whatsapp_templates con campos Meta -----------------------------
alter table public.whatsapp_templates
  add column if not exists meta_template_name text,
  add column if not exists meta_template_status text not null default 'pending',
  add column if not exists meta_language text not null default 'es_MX',
  add column if not exists meta_category text not null default 'UTILITY',
  add column if not exists meta_components_schema jsonb not null default '[]'::jsonb,
  add column if not exists meta_header_format text,            -- TEXT | IMAGE | DOCUMENT | VIDEO | LOCATION
  add column if not exists meta_variables_count integer not null default 0,
  add column if not exists meta_template_id text,              -- id que devuelve Graph API
  add column if not exists approved_at timestamptz,
  add column if not exists rejected_reason text,
  add column if not exists last_sync_at timestamptz;

alter table public.whatsapp_templates
  drop constraint if exists whatsapp_templates_meta_status_check;
alter table public.whatsapp_templates
  add constraint whatsapp_templates_meta_status_check
  check (meta_template_status in (
    'pending','approved','rejected','disabled','paused','deleted','unknown'
  ));

alter table public.whatsapp_templates
  drop constraint if exists whatsapp_templates_meta_category_check;
alter table public.whatsapp_templates
  add constraint whatsapp_templates_meta_category_check
  check (meta_category in ('UTILITY','MARKETING','AUTHENTICATION'));

create unique index if not exists idx_whatsapp_templates_meta_name_lang
  on public.whatsapp_templates (meta_template_name, meta_language)
  where meta_template_name is not null;

create index if not exists idx_whatsapp_templates_meta_status
  on public.whatsapp_templates (meta_template_status);

-- 2. Extender whatsapp_logs con metadatos Meta -------------------------------
alter table public.whatsapp_logs
  add column if not exists meta_template_name text,
  add column if not exists meta_template_status text,
  add column if not exists meta_language text,
  add column if not exists payload_sent jsonb,
  add column if not exists meta_error_code integer,
  add column if not exists meta_error_message text,
  add column if not exists meta_error_subcode integer,
  add column if not exists window_type text;  -- 'template' | 'free_text_within_24h'

-- 3. Función ventana 24h: ¿hay mensaje entrante del cliente <24h? -----------
create or replace function public.is_within_customer_service_window(
  p_phone text,
  p_now timestamptz default now()
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.whatsapp_webhook_events e
    where e.event_kind = 'message'
      and e.from_phone is not null
      and (
        -- Normalizamos quitando todo lo que no es dígito y comparando últimos 10
        right(regexp_replace(coalesce(e.from_phone,''), '\D', '', 'g'), 10)
        = right(regexp_replace(coalesce(p_phone,''), '\D', '', 'g'), 10)
      )
      and e.received_at >= p_now - interval '24 hours'
  );
$$;

-- 4. Seeds de templates oficiales --------------------------------------------
-- meta_template_name debe coincidir EXACTAMENTE con el template aprobado en Meta.
-- Variables Meta son posicionales {{1}}, {{2}}, ... — preservamos su orden.

with seeds(template_key, meta_template_name, meta_language, meta_category, meta_components_schema, meta_variables_count) as (
  values
    (
      'reservation_confirmed',
      'confirmacion_cita',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Hola {{1}}, tu cita de {{2}} quedó confirmada para el {{3}} a las {{4}} con {{5}}. Te esperamos en Sahara Club Spa.","example":{"body_text":[["María","Masaje relajante","12/06/2026","16:00","Ana"]]}}
      ]'::jsonb,
      5
    ),
    (
      'reminder_24h',
      'recordatorio_24h',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Hola {{1}}, te recordamos tu cita de {{2}} mañana {{3}} a las {{4}}. Si necesitas reagendar responde a este mensaje.","example":{"body_text":[["María","Masaje","13/06/2026","16:00"]]}}
      ]'::jsonb,
      4
    ),
    (
      'reminder_3h',
      'recordatorio_3h',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Hola {{1}}, tu cita en Sahara Club Spa es hoy a las {{2}} con {{3}}. ¡Te esperamos!","example":{"body_text":[["María","16:00","Ana"]]}}
      ]'::jsonb,
      3
    ),
    (
      'reminder_1h',
      'recordatorio_1h',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Hola {{1}}, estamos por recibirte. Tu cita de {{2}} inicia a las {{3}}.","example":{"body_text":[["María","Masaje","16:00"]]}}
      ]'::jsonb,
      3
    ),
    (
      'reservation_cancelled',
      'cancelacion_cita',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Hola {{1}}, tu cita de {{2}} programada para {{3}} fue cancelada. Si deseas reagendar estamos para ayudarte.","example":{"body_text":[["María","Masaje","13/06/2026"]]}}
      ]'::jsonb,
      3
    ),
    (
      'reservation_rescheduled',
      'reagendado_cita',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Hola {{1}}, tu cita fue reagendada. Nueva fecha: {{2}} a las {{3}} con {{4}}.","example":{"body_text":[["María","14/06/2026","17:00","Ana"]]}}
      ]'::jsonb,
      4
    ),
    (
      'welcome',
      'bienvenida_cliente',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Bienvenida a Sahara Club Spa, {{1}}. Estamos felices de acompañarte en tu camino de bienestar.","example":{"body_text":[["María"]]}}
      ]'::jsonb,
      1
    ),
    (
      'payment_pending',
      'pago_pendiente',
      'es_MX',
      'UTILITY',
      '[
        {"type":"BODY","text":"Hola {{1}}, tu reserva {{2}} tiene un pago pendiente. Puedes completarlo aquí: {{3}}","example":{"body_text":[["María","abc12345","https://pago.example/x"]]}}
      ]'::jsonb,
      3
    )
)
update public.whatsapp_templates t
set
  meta_template_name = s.meta_template_name,
  meta_language = s.meta_language,
  meta_category = s.meta_category,
  meta_components_schema = s.meta_components_schema,
  meta_variables_count = s.meta_variables_count,
  meta_template_status = coalesce(t.meta_template_status, 'pending'),
  last_sync_at = coalesce(t.last_sync_at, null)
from seeds s
where t.template_key = s.template_key
  and coalesce(t.branch_id, public.get_default_branch_id()) = public.get_default_branch_id();

-- 5. Vista cómoda para la UI -------------------------------------------------
create or replace view public.whatsapp_meta_templates_view as
select
  id,
  branch_id,
  template_key,
  template_name,
  meta_template_name,
  meta_template_status,
  meta_language,
  meta_category,
  meta_variables_count,
  meta_components_schema,
  meta_header_format,
  meta_template_id,
  message_body,
  is_active,
  approved_at,
  rejected_reason,
  last_sync_at,
  updated_at
from public.whatsapp_templates;
