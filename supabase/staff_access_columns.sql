-- Sahara Club Spa - Completar columnas faltantes en staff para acceso al sistema
-- ----------------------------------------------------------------------------
-- El formulario admin intenta escribir auth_user_id, can_login, can_access_*,
-- y campos de contacto/horario que NO existían en la tabla → el helper de
-- retry silenciosamente descartaba todo. Esto crea las columnas faltantes.

-- 1. Columnas de acceso al sistema
alter table public.staff
  add column if not exists auth_user_id uuid references auth.users(id) on delete set null,
  add column if not exists can_login boolean not null default false,
  add column if not exists can_access_web boolean not null default false,
  add column if not exists can_access_mobile boolean not null default false;

create unique index if not exists staff_auth_user_id_uidx
  on public.staff(auth_user_id) where auth_user_id is not null;

-- 2. Columnas de contacto extendido
alter table public.staff
  add column if not exists whatsapp text,
  add column if not exists address text,
  add column if not exists city text,
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_phone text;

-- 3. Columnas de horario / agenda
alter table public.staff
  add column if not exists work_days text[],
  add column if not exists work_start_time text,
  add column if not exists work_end_time text,
  add column if not exists break_time text,
  add column if not exists show_in_calendar boolean not null default false;

-- 4. Columnas de pago
alter table public.staff
  add column if not exists fixed_salary numeric,
  add column if not exists commission_percentage numeric,
  add column if not exists payment_notes text;

-- 5. Normalizar y asegurar check de rol
-- El form Flutter ofrece: admin, reception, therapist, cleaning, sales, other.
-- Hay un row legado con role='receptionist' que normalizamos a 'reception'.
update public.staff set role = 'reception' where role = 'receptionist';

alter table public.staff drop constraint if exists staff_role_check;
alter table public.staff add constraint staff_role_check
  check (role in ('admin','reception','therapist','cleaning','sales','other'));

-- 6. RLS: solo admins pueden leer/modificar columnas sensibles desde el cliente.
-- (no se cambian las policies existentes; si no hay, queda como estaba).

-- 7. Verificación
select column_name, data_type
from information_schema.columns
where table_schema='public' and table_name='staff'
  and column_name in (
    'auth_user_id','can_login','can_access_web','can_access_mobile',
    'whatsapp','address','city','emergency_contact_name','emergency_contact_phone',
    'work_days','work_start_time','work_end_time','break_time','show_in_calendar',
    'fixed_salary','commission_percentage','payment_notes'
  )
order by column_name;
