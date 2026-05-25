-- Sahara Club Spa - Base de conocimiento (Fase 0/1 - parte 2)
-- Complementa ai_foundation.sql: agrega faqs, recommendation rules, staff AI fields.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. FAQs públicas / operativas
-- ---------------------------------------------------------------------------
create table if not exists public.faqs (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete cascade,
  question text not null,
  answer text not null,
  category text not null default 'general',  -- general | pagos | citas | servicios | politicas | ubicacion
  tags text[] not null default '{}',         -- ["estacionamiento","tarjetas"]
  is_active boolean not null default true,
  display_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_faqs_active_category
  on public.faqs (is_active, category, display_order);
create index if not exists idx_faqs_tags
  on public.faqs using gin (tags);

drop trigger if exists on_faqs_updated on public.faqs;
create trigger on_faqs_updated
before update on public.faqs
for each row execute function public.handle_updated_at();

-- Seed con plantilla mínima editable
insert into public.faqs (branch_id, question, answer, category, display_order)
select public.get_default_branch_id(), q, a, c, ord
from (values
  ('¿Tienen estacionamiento?',
   'Sí, contamos con estacionamiento. Por favor avísanos al llegar.',
   'ubicacion', 10),
  ('¿Aceptan tarjeta?',
   'Sí, aceptamos pagos con tarjeta de crédito, débito y efectivo.',
   'pagos', 20),
  ('¿Cuál es la política de cancelación?',
   'Te pedimos cancelar con al menos 24 horas de anticipación. Cancelaciones tardías pueden generar un cargo.',
   'politicas', 30),
  ('¿Puedo llevar acompañante?',
   'El servicio es personal en la cabina. Tu acompañante puede esperar en recepción.',
   'politicas', 40),
  ('¿Cuánto tiempo antes debo llegar?',
   'Te sugerimos llegar 10 minutos antes de tu cita para una experiencia tranquila.',
   'citas', 50)
) as t(q, a, c, ord)
where not exists (select 1 from public.faqs where question = t.q);

-- ---------------------------------------------------------------------------
-- 2. Reglas de recomendación de servicios (sin UI todavía, alimentará al agente)
-- ---------------------------------------------------------------------------
create table if not exists public.service_recommendation_rules (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete cascade,
  trigger_tags text[] not null default '{}',         -- ["estrés","relajación"]
  recommended_service_ids uuid[] not null default '{}',
  priority smallint not null default 100,
  is_active boolean not null default true,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_service_recom_active
  on public.service_recommendation_rules (is_active, priority);
create index if not exists idx_service_recom_tags
  on public.service_recommendation_rules using gin (trigger_tags);

drop trigger if exists on_service_recom_updated on public.service_recommendation_rules;
create trigger on_service_recom_updated
before update on public.service_recommendation_rules
for each row execute function public.handle_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Extender staff con campos para el agente
-- ---------------------------------------------------------------------------
alter table public.staff
  add column if not exists specialties text[] not null default '{}',           -- ["facial","masaje tejido profundo"]
  add column if not exists certifications text[] not null default '{}',         -- ["Cosmetología certificada CDMX"]
  add column if not exists bio text not null default '',                        -- descripción pública corta
  add column if not exists recommended_services uuid[] not null default '{}',   -- servicios donde es referente
  add column if not exists active_for_ai boolean not null default true,         -- el agente puede recomendarl@?
  add column if not exists years_experience smallint;

create index if not exists idx_staff_active_for_ai on public.staff(active_for_ai) where active_for_ai = true;
create index if not exists idx_staff_specialties on public.staff using gin (specialties);

-- ---------------------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------------------
alter table public.faqs enable row level security;
alter table public.service_recommendation_rules enable row level security;

-- FAQs: lectura pública (web puede mostrarlas), edición admin
drop policy if exists faqs_public_read on public.faqs;
create policy faqs_public_read
  on public.faqs for select to anon, authenticated using (is_active = true);

drop policy if exists faqs_staff_read on public.faqs;
create policy faqs_staff_read
  on public.faqs for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));

drop policy if exists faqs_admin_write on public.faqs;
create policy faqs_admin_write
  on public.faqs for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- Recommendation rules: NO públicas (lógica interna), staff puede leer, admin escribe
drop policy if exists service_recom_staff_read on public.service_recommendation_rules;
create policy service_recom_staff_read
  on public.service_recommendation_rules for select to authenticated
  using (public.current_user_role() in ('admin','reception','receptionist'));

drop policy if exists service_recom_admin_write on public.service_recommendation_rules;
create policy service_recom_admin_write
  on public.service_recommendation_rules for all to authenticated
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- Nota: staff ya tiene RLS heredada de la tabla base; los nuevos campos
-- entran en las políticas existentes sin ajustes adicionales.
