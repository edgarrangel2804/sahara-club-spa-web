-- Sahara Club Spa - WhatsApp automation architecture
-- Single-branch ready, multi-branch compatible

create extension if not exists pgcrypto;

alter table public.configuracion_sistema
  add column if not exists instagram_url text not null default '',
  add column if not exists facebook_url text not null default '',
  add column if not exists website_url text not null default '';

insert into public.configuracion_sistema (
  whatsapp_enabled,
  enable_multi_branch,
  instagram_url,
  facebook_url,
  website_url
)
select
  false,
  false,
  '',
  '',
  ''
where not exists (
  select 1 from public.configuracion_sistema
);

alter table public.whatsapp_templates
  add column if not exists branch_id uuid references public.sucursales(id) on delete set null,
  add column if not exists template_key text,
  add column if not exists template_name text,
  add column if not exists message_body text,
  add column if not exists is_active boolean not null default true,
  add column if not exists trigger_event text,
  add column if not exists language_code text not null default 'es_MX',
  add column if not exists category text not null default 'general',
  add column if not exists emoji_enabled boolean not null default true,
  add column if not exists markdown_enabled boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

update public.whatsapp_templates
set
  template_name = coalesce(template_name, title),
  message_body = coalesce(message_body, message),
  is_active = coalesce(is_active, active, true),
  template_key = coalesce(template_key, type, 'custom'),
  trigger_event = coalesce(trigger_event, type, 'custom');

alter table public.whatsapp_templates
  drop constraint if exists whatsapp_templates_type_check;

alter table public.whatsapp_templates
  add constraint whatsapp_templates_type_check
  check (
    type = any (
      array[
        'confirmation',
        'reminder_24h',
        'reminder_2h',
        'reminder_3h',
        'reminder_1h',
        'custom',
        'reservation_confirmed',
        'reservation_cancelled',
        'reservation_rescheduled',
        'payment_pending',
        'payment_confirmed',
        'birthday_customer',
        'welcome',
        'first_visit',
        'membership_created',
        'giftcard_created',
        'post_service',
        'promotion'
      ]
    )
  );

alter table public.whatsapp_templates
  alter column template_name set not null,
  alter column message_body set not null,
  alter column template_key set not null,
  alter column trigger_event set not null;

create unique index if not exists idx_whatsapp_templates_template_key_branch
  on public.whatsapp_templates(template_key, coalesce(branch_id, '11111111-1111-1111-1111-111111111111'::uuid));

create index if not exists idx_whatsapp_templates_trigger_event
  on public.whatsapp_templates(trigger_event, is_active);

alter table public.whatsapp_logs
  add column if not exists reservation_id uuid references public.bookings(id) on delete set null,
  add column if not exists customer_id uuid references public.clients(id) on delete set null,
  add column if not exists template_id uuid references public.whatsapp_templates(id) on delete set null,
  add column if not exists queue_id uuid,
  add column if not exists phone text not null default '',
  add column if not exists message_rendered text not null default '',
  add column if not exists status text not null default 'sent',
  add column if not exists provider text not null default 'meta_cloud_api',
  add column if not exists provider_response jsonb not null default '{}'::jsonb,
  add column if not exists delivered_at timestamptz,
  add column if not exists read_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists error_message text,
  add column if not exists event_type text;

update public.whatsapp_logs
set
  reservation_id = coalesce(reservation_id, booking_id),
  event_type = coalesce(event_type, type),
  created_at = coalesce(created_at, sent_at, now()),
  status = coalesce(status, 'sent');

update public.whatsapp_templates
set
  template_key = 'first_visit',
  trigger_event = 'first_visit',
  type = 'first_visit'
where template_key = 'welcome'
  and not exists (
    select 1
    from public.whatsapp_templates existing
    where existing.template_key = 'first_visit'
      and coalesce(existing.branch_id, '11111111-1111-1111-1111-111111111111'::uuid) =
          coalesce(public.whatsapp_templates.branch_id, '11111111-1111-1111-1111-111111111111'::uuid)
  );

update public.whatsapp_templates
set
  is_active = false,
  active = false
where template_key = 'confirmation'
  and exists (
    select 1
    from public.whatsapp_templates existing
    where existing.template_key = 'reservation_confirmed'
      and coalesce(existing.branch_id, '11111111-1111-1111-1111-111111111111'::uuid) =
          coalesce(public.whatsapp_templates.branch_id, '11111111-1111-1111-1111-111111111111'::uuid)
  );

create index if not exists idx_whatsapp_logs_reservation_event
  on public.whatsapp_logs(reservation_id, event_type, sent_at desc);

create table if not exists public.whatsapp_queue (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete set null,
  event_type text not null,
  reservation_id uuid references public.bookings(id) on delete cascade,
  customer_id uuid references public.clients(id) on delete set null,
  template_id uuid references public.whatsapp_templates(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  retry_count integer not null default 0,
  max_retries integer not null default 5,
  scheduled_at timestamptz not null default now(),
  processed_at timestamptz,
  error_message text,
  provider_response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_whatsapp_queue_status_schedule
  on public.whatsapp_queue(status, scheduled_at);

create index if not exists idx_whatsapp_queue_reservation_event
  on public.whatsapp_queue(reservation_id, event_type);

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_whatsapp_templates_updated on public.whatsapp_templates;
create trigger on_whatsapp_templates_updated
before update on public.whatsapp_templates
for each row execute function public.handle_updated_at();

drop trigger if exists on_whatsapp_queue_updated on public.whatsapp_queue;
create trigger on_whatsapp_queue_updated
before update on public.whatsapp_queue
for each row execute function public.handle_updated_at();

create or replace function public.get_default_branch_id()
returns uuid
language sql
stable
as $$
  select '11111111-1111-1111-1111-111111111111'::uuid
$$;

create or replace function public.first_name_from_full_name(full_name text)
returns text
language sql
immutable
as $$
  select coalesce(nullif(split_part(trim(coalesce(full_name, '')), ' ', 1), ''), 'Cliente')
$$;

create or replace function public.last_name_from_full_name(full_name text)
returns text
language sql
immutable
as $$
  select trim(replace(trim(coalesce(full_name, '')), split_part(trim(coalesce(full_name, '')), ' ', 1), ''))
$$;

create or replace function public.render_whatsapp_template(body text, vars jsonb)
returns text
language plpgsql
stable
as $$
declare
  result text := coalesce(body, '');
  pair record;
  legacy_key text;
begin
  for pair in
    select key, coalesce(value #>> '{}', '') as value
    from jsonb_each(coalesce(vars, '{}'::jsonb))
  loop
    result := replace(result, '[[' || pair.key || ']]', pair.value);

    legacy_key := upper(pair.key);
    legacy_key := replace(legacy_key, 'NOMBRE_CLIENTE', 'CLIENTE');
    legacy_key := replace(legacy_key, 'NOMBRE_SERVICIO', 'SERVICIO');
    legacy_key := replace(legacy_key, 'FECHA_RESERVA', 'FECHA');
    legacy_key := replace(legacy_key, 'HORA_RESERVA', 'HORA');
    legacy_key := replace(legacy_key, 'NOMBRE_LOCAL', 'LOCAL');
    result := replace(result, '[' || legacy_key || ']', pair.value);
  end loop;

  return result;
end;
$$;

create or replace function public.build_whatsapp_context(
  p_reservation_id uuid,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
stable
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'nombre_cliente', public.first_name_from_full_name(coalesce(c.full_name, 'Cliente')),
    'apellido_cliente', public.last_name_from_full_name(coalesce(c.full_name, '')),
    'telefono', coalesce(c.phone, ''),
    'nombre_servicio', coalesce(sv.name, b.service_name, 'Servicio'),
    'duracion', coalesce(b.duration_min, 0)::text,
    'fecha_reserva', to_char(b.booking_date, 'DD/MM/YYYY'),
    'hora_reserva', to_char(b.booking_time, 'HH24:MI'),
    'nombre_terapeuta', coalesce(st.full_name, 'Equipo Sahara'),
    'nombre_local', coalesce(br.nombre, 'Sahara Club Spa'),
    'direccion_local', coalesce(br.direccion_completa, ''),
    'telefono_local', coalesce(br.telefono_contacto, ''),
    'instagram', coalesce(cfg.instagram_url, ''),
    'facebook', coalesce(cfg.facebook_url, ''),
    'pagina_web', coalesce(cfg.website_url, ''),
    'link_pago', coalesce(p_payload->>'link_pago', ''),
    'codigo_reserva', left(b.id::text, 8),
    'emoji_confirmacion', '✨',
    'emoji_recordatorio', '⏰',
    'emoji_pago', '💳'
  )
  into result
  from public.bookings b
  -- Resuelve el cliente por client_record_id (web/landing/recepcion/IA) y, si
  -- viene NULL (citas creadas desde la app movil, que solo setean client_id =
  -- auth uid), cae al fallback por profile_id. Aditivo: las filas con
  -- client_record_id conservan su resolucion original.
  left join public.clients c
    on c.id = b.client_record_id
    or (b.client_record_id is null and c.profile_id = b.client_id)
  left join public.staff st on st.id = b.therapist_id
  left join public.services sv on sv.id = b.service_id
  left join public.sucursales br on br.id = coalesce(b.sucursal_id, public.get_default_branch_id())
  left join public.configuracion_sistema cfg on true
  where b.id = p_reservation_id
  limit 1;

  return coalesce(result, '{}'::jsonb) || coalesce(p_payload, '{}'::jsonb);
end;
$$;

create or replace function public.enqueue_whatsapp_event(
  p_event_type text,
  p_reservation_id uuid default null,
  p_customer_id uuid default null,
  p_payload jsonb default '{}'::jsonb,
  p_scheduled_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
as $$
declare
  queue_id uuid;
  resolved_branch_id uuid;
  resolved_customer_id uuid;
begin
  if p_reservation_id is not null then
    select coalesce(sucursal_id, public.get_default_branch_id()), client_record_id
    into resolved_branch_id, resolved_customer_id
    from public.bookings
    where id = p_reservation_id;
  end if;

  insert into public.whatsapp_queue (
    branch_id,
    event_type,
    reservation_id,
    customer_id,
    payload,
    status,
    scheduled_at
  ) values (
    coalesce(resolved_branch_id, public.get_default_branch_id()),
    p_event_type,
    p_reservation_id,
    coalesce(p_customer_id, resolved_customer_id),
    coalesce(p_payload, '{}'::jsonb),
    'pending',
    coalesce(p_scheduled_at, now())
  )
  returning id into queue_id;

  return queue_id;
end;
$$;

create or replace function public.handle_booking_whatsapp_events()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'INSERT' then
    perform public.enqueue_whatsapp_event('reservation_created', new.id, new.client_record_id, '{}'::jsonb, now());
    if new.status = 'confirmed' then
      perform public.enqueue_whatsapp_event('reservation_confirmed', new.id, new.client_record_id, '{}'::jsonb, now());
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event('reservation_cancelled', new.id, new.client_record_id, '{}'::jsonb, now());
    end if;
    return new;
  end if;

  if old.status is distinct from new.status then
    if new.status = 'confirmed' then
      perform public.enqueue_whatsapp_event('reservation_confirmed', new.id, new.client_record_id, '{}'::jsonb, now());
    elsif new.status = 'cancelled' then
      perform public.enqueue_whatsapp_event('reservation_cancelled', new.id, new.client_record_id, '{}'::jsonb, now());
    elsif new.status = 'pending' then
      perform public.enqueue_whatsapp_event('payment_pending', new.id, new.client_record_id, '{}'::jsonb, now());
    end if;
  end if;

  if old.booking_date is distinct from new.booking_date
     or old.booking_time is distinct from new.booking_time
     or old.therapist_id is distinct from new.therapist_id then
    perform public.enqueue_whatsapp_event('reservation_rescheduled', new.id, new.client_record_id, '{}'::jsonb, now());
  end if;

  return new;
end;
$$;

drop trigger if exists booking_whatsapp_events on public.bookings;
create trigger booking_whatsapp_events
after insert or update on public.bookings
for each row execute function public.handle_booking_whatsapp_events();

create or replace function public.enqueue_due_whatsapp_reminders(p_now timestamptz default now())
returns integer
language plpgsql
security definer
as $$
declare
  booking_row record;
  total_count integer := 0;
  booking_ts timestamptz;
begin
  for booking_row in
    select b.id, b.client_record_id
    from public.bookings b
    where b.status = 'confirmed'
  loop
    booking_ts := ((select booking_date from public.bookings where id = booking_row.id)::text || ' ' ||
      (select booking_time from public.bookings where id = booking_row.id)::text)::timestamp;

    if booking_ts - interval '24 hours' <= p_now
       and booking_ts - interval '24 hours' > p_now - interval '30 minutes'
       and not exists (
         select 1 from public.whatsapp_logs l
         where l.reservation_id = booking_row.id and l.event_type = 'reminder_24h'
       ) then
      perform public.enqueue_whatsapp_event('reminder_24h', booking_row.id, booking_row.client_record_id, '{}'::jsonb, p_now);
      total_count := total_count + 1;
    end if;

    if booking_ts - interval '3 hours' <= p_now
       and booking_ts - interval '3 hours' > p_now - interval '30 minutes'
       and not exists (
         select 1 from public.whatsapp_logs l
         where l.reservation_id = booking_row.id and l.event_type = 'reminder_3h'
       ) then
      perform public.enqueue_whatsapp_event('reminder_3h', booking_row.id, booking_row.client_record_id, '{}'::jsonb, p_now);
      total_count := total_count + 1;
    end if;

    if booking_ts - interval '1 hour' <= p_now
       and booking_ts - interval '1 hour' > p_now - interval '20 minutes'
       and not exists (
         select 1 from public.whatsapp_logs l
         where l.reservation_id = booking_row.id and l.event_type = 'reminder_1h'
       ) then
      perform public.enqueue_whatsapp_event('reminder_1h', booking_row.id, booking_row.client_record_id, '{}'::jsonb, p_now);
      total_count := total_count + 1;
    end if;
  end loop;

  return total_count;
end;
$$;

insert into public.whatsapp_templates (
  branch_id,
  template_key,
  template_name,
  message_body,
  is_active,
  trigger_event,
  language_code,
  category,
  emoji_enabled,
  markdown_enabled,
  title,
  message,
  type,
  active
)
select
  public.get_default_branch_id(),
  seed.template_key,
  seed.template_name,
  seed.message_body,
  true,
  seed.template_key,
  'es_MX',
  seed.category,
  true,
  true,
  seed.template_name,
  seed.message_body,
  seed.template_key,
  true
from (
  values
    ('reservation_confirmed', 'Confirmación de cita', '[[emoji_confirmacion]] Hola [[nombre_cliente]], tu cita de [[nombre_servicio]] quedó confirmada para el [[fecha_reserva]] a las [[hora_reserva]] con [[nombre_terapeuta]]. Te esperamos en [[nombre_local]]. [[direccion_local]]', 'booking'),
    ('reminder_24h', 'Recordatorio 24 horas', '⏰ Hola [[nombre_cliente]], te recordamos tu cita de [[nombre_servicio]] mañana [[fecha_reserva]] a las [[hora_reserva]]. Si necesitas ayuda responde a este mensaje.', 'reminder'),
    ('reminder_3h', 'Recordatorio 3 horas', '⏰ Tu cita en [[nombre_local]] es hoy a las [[hora_reserva]] con [[nombre_terapeuta]]. ¡Te esperamos!', 'reminder'),
    ('reminder_1h', 'Recordatorio 1 hora', '⏰ Estamos por recibirte en [[nombre_local]]. Tu cita de [[nombre_servicio]] inicia a las [[hora_reserva]].', 'reminder'),
    ('reservation_rescheduled', 'Cita reagendada', '📅 Hola [[nombre_cliente]], tu cita fue reagendada. Nueva fecha: [[fecha_reserva]] a las [[hora_reserva]] con [[nombre_terapeuta]].', 'booking'),
    ('reservation_cancelled', 'Cita cancelada', 'Lo sentimos, [[nombre_cliente]]. Tu cita de [[nombre_servicio]] programada para [[fecha_reserva]] fue cancelada. Si deseas reagendar, estamos para ayudarte.', 'booking'),
    ('payment_pending', 'Pago pendiente', '💳 Hola [[nombre_cliente]], tu reserva [[codigo_reserva]] tiene un pago pendiente. Puedes completarlo aquí: [[link_pago]]', 'payment'),
    ('payment_confirmed', 'Pago confirmado', '✅ Recibimos tu pago para la reserva [[codigo_reserva]]. Gracias por elegir [[nombre_local]].', 'payment'),
    ('welcome', 'Bienvenida', '✨ Bienvenida a [[nombre_local]], [[nombre_cliente]]. Estamos felices de acompañarte en tu camino de bienestar.', 'customer'),
    ('birthday_customer', 'Cumpleaños', '🎂 Feliz cumpleaños, [[nombre_cliente]]. Te enviamos un abrazo y una invitación especial para consentirte en [[nombre_local]].', 'customer'),
    ('membership_created', 'Membresía', '🌟 Tu membresía en [[nombre_local]] fue activada correctamente. Muy pronto recibirás más detalles.', 'membership'),
    ('giftcard_created', 'Gift card', '🎁 Tu gift card de [[nombre_local]] está lista. Si necesitas apoyo para usarla, estamos para ayudarte.', 'giftcard'),
    ('post_service', 'Post servicio', '💆 Gracias por visitarnos, [[nombre_cliente]]. Si disfrutaste tu experiencia, nos encantará leerte o verte en redes: [[instagram]]', 'followup'),
    ('promotion', 'Promoción', '✨ [[nombre_cliente]], tenemos una promoción especial para ti en [[nombre_local]]. Escríbenos para conocer más.', 'marketing')
) as seed(template_key, template_name, message_body, category)
where not exists (
  select 1
  from public.whatsapp_templates t
  where t.template_key = seed.template_key
    and coalesce(t.branch_id, public.get_default_branch_id()) = public.get_default_branch_id()
);

alter table public.whatsapp_templates enable row level security;
alter table public.whatsapp_logs enable row level security;
alter table public.whatsapp_queue enable row level security;

drop policy if exists whatsapp_templates_select_staff on public.whatsapp_templates;
create policy whatsapp_templates_select_staff
  on public.whatsapp_templates for select to authenticated
  using (public.current_user_role() in ('admin', 'reception', 'receptionist'));

drop policy if exists whatsapp_templates_manage_staff on public.whatsapp_templates;
create policy whatsapp_templates_manage_staff
  on public.whatsapp_templates for all to authenticated
  using (public.current_user_role() in ('admin', 'reception', 'receptionist'))
  with check (public.current_user_role() in ('admin', 'reception', 'receptionist'));

drop policy if exists whatsapp_logs_select_staff on public.whatsapp_logs;
create policy whatsapp_logs_select_staff
  on public.whatsapp_logs for select to authenticated
  using (public.current_user_role() in ('admin', 'reception', 'receptionist'));

drop policy if exists whatsapp_logs_manage_staff on public.whatsapp_logs;
create policy whatsapp_logs_manage_staff
  on public.whatsapp_logs for all to authenticated
  using (public.current_user_role() in ('admin', 'reception', 'receptionist'))
  with check (public.current_user_role() in ('admin', 'reception', 'receptionist'));

drop policy if exists whatsapp_queue_select_staff on public.whatsapp_queue;
create policy whatsapp_queue_select_staff
  on public.whatsapp_queue for select to authenticated
  using (public.current_user_role() in ('admin', 'reception', 'receptionist'));

drop policy if exists whatsapp_queue_manage_staff on public.whatsapp_queue;
create policy whatsapp_queue_manage_staff
  on public.whatsapp_queue for all to authenticated
  using (public.current_user_role() in ('admin', 'reception', 'receptionist'))
  with check (public.current_user_role() in ('admin', 'reception', 'receptionist'));
