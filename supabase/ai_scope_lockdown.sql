-- Sahara Club Spa - Lock down scope para FAQs y reglas de recomendación
-- ----------------------------------------------------------------------------
-- Regla: el agente IA solo puede usar conocimiento de Sahara Club Spa
-- (servicios, horarios, terapeutas, políticas, ubicación, reservas).
-- Esto añade gating estructural a nivel de DB para que aunque la UI deje
-- entrar contenido fuera de scope, las tools del router lo filtren.

-- 1. faqs.scope_category --------------------------------------------------
alter table public.faqs
  add column if not exists scope_category text not null default 'sahara';

alter table public.faqs
  drop constraint if exists faqs_scope_category_check;
alter table public.faqs
  add constraint faqs_scope_category_check
  check (scope_category in ('sahara','out_of_scope'));

-- Backfill: todas las filas existentes asumen scope sahara (curadas hasta hoy).
update public.faqs
set scope_category = 'sahara'
where scope_category is null or scope_category = '';

-- Índice para el path caliente del router (get_faqs filtra is_active + scope).
create index if not exists idx_faqs_active_scope
  on public.faqs(is_active, scope_category)
  where is_active = true and scope_category = 'sahara';

-- 2. service_recommendation_rules: detectar reglas que apunten a servicios
--    inexistentes/inactivos y desactivarlas (no las borramos para auditoría).
with stale as (
  select r.id
  from public.service_recommendation_rules r
  where r.is_active = true
    and exists (
      select 1
      from unnest(r.recommended_service_ids) sid
      where not exists (
        select 1 from public.services s
        where s.id = sid and s.is_active = true
      )
    )
)
update public.service_recommendation_rules r
set is_active = false,
    notes = coalesce(notes, '') ||
            case when notes is null or notes = '' then '' else E'\n' end ||
            '[auto-deactivated ' || now()::date ||
            ' — apuntaba a service_id inexistente o inactivo]'
from stale
where r.id = stale.id;

-- 3. Verificación
select
  (select count(*) from public.faqs where scope_category = 'sahara' and is_active = true) as faqs_sahara_active,
  (select count(*) from public.faqs where scope_category = 'out_of_scope') as faqs_out_of_scope,
  (select count(*) from public.faqs where is_active = false) as faqs_inactive_total,
  (select count(*) from public.service_recommendation_rules where is_active = true) as rules_active,
  (select count(*) from public.service_recommendation_rules where is_active = false) as rules_inactive;
