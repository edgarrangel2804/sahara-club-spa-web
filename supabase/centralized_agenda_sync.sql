alter type public.booking_status add value if not exists 'pending' after 'scheduled';
alter type public.booking_status add value if not exists 'checked_in' after 'confirmed';
alter type public.booking_status add value if not exists 'in_progress' after 'checked_in';
alter type public.booking_status add value if not exists 'rescheduled' after 'cancelled';

alter table public.bookings
  add column if not exists source_platform text not null default 'web',
  add column if not exists updated_by uuid references public.profiles(id) on delete set null;

update public.bookings
set
  source_platform = coalesce(nullif(source_platform, ''), 'web'),
  sucursal_id = coalesce(sucursal_id, '11111111-1111-1111-1111-111111111111'::uuid);

create table if not exists public.appointment_status_history (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  old_status text,
  new_status text not null,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now(),
  source_platform text not null default 'web',
  old_booking_date date,
  new_booking_date date,
  old_booking_time time without time zone,
  new_booking_time time without time zone,
  old_therapist_id uuid references public.staff(id) on delete set null,
  new_therapist_id uuid references public.staff(id) on delete set null,
  notes text,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_appointment_status_history_booking
  on public.appointment_status_history(booking_id, changed_at desc);

create or replace function public.capture_booking_history()
returns trigger
language plpgsql
security definer
as $$
declare
  actor_id uuid := coalesce(new.updated_by, new.created_by, auth.uid());
begin
  if tg_op = 'INSERT' then
    insert into public.appointment_status_history (
      booking_id,
      old_status,
      new_status,
      changed_by,
      source_platform,
      new_booking_date,
      new_booking_time,
      new_therapist_id,
      notes,
      metadata
    ) values (
      new.id,
      null,
      coalesce(new.status::text, 'pending'),
      actor_id,
      coalesce(new.source_platform, 'web'),
      new.booking_date,
      new.booking_time,
      new.therapist_id,
      new.client_notes,
      jsonb_build_object('event', 'created')
    );
    return new;
  end if;

  if old.status is distinct from new.status
     or old.booking_date is distinct from new.booking_date
     or old.booking_time is distinct from new.booking_time
     or old.therapist_id is distinct from new.therapist_id then
    insert into public.appointment_status_history (
      booking_id,
      old_status,
      new_status,
      changed_by,
      source_platform,
      old_booking_date,
      new_booking_date,
      old_booking_time,
      new_booking_time,
      old_therapist_id,
      new_therapist_id,
      notes,
      metadata
    ) values (
      new.id,
      old.status::text,
      new.status::text,
      actor_id,
      coalesce(new.source_platform, old.source_platform, 'web'),
      old.booking_date,
      new.booking_date,
      old.booking_time,
      new.booking_time,
      old.therapist_id,
      new.therapist_id,
      new.client_notes,
      jsonb_build_object(
        'event',
        case
          when old.status is distinct from new.status then 'status_changed'
          else 'rescheduled'
        end
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_capture_history on public.bookings;
create trigger bookings_capture_history
after insert or update on public.bookings
for each row execute function public.capture_booking_history();

insert into public.appointment_status_history (
  booking_id,
  old_status,
  new_status,
  changed_by,
  source_platform,
  new_booking_date,
  new_booking_time,
  new_therapist_id,
  notes,
  metadata
)
select
  b.id,
  null,
  coalesce(b.status::text, 'pending'),
  coalesce(b.updated_by, b.created_by),
  coalesce(nullif(b.source_platform, ''), 'web'),
  b.booking_date,
  b.booking_time,
  b.therapist_id,
  b.client_notes,
  jsonb_build_object('event', 'backfill')
from public.bookings b
where not exists (
  select 1
  from public.appointment_status_history h
  where h.booking_id = b.id
);

alter table public.appointment_status_history enable row level security;

drop policy if exists appointment_status_history_select_by_role on public.appointment_status_history;
create policy appointment_status_history_select_by_role
  on public.appointment_status_history
  for select
  to authenticated
  using (
    current_user_role() = any (array['admin', 'reception', 'receptionist'])
    or exists (
      select 1
      from public.bookings b
      where b.id = booking_id
        and (b.client_id = auth.uid() or b.therapist_id = auth.uid())
    )
  );

drop policy if exists appointment_status_history_insert_by_system on public.appointment_status_history;
create policy appointment_status_history_insert_by_system
  on public.appointment_status_history
  for insert
  to authenticated
  with check (
    current_user_role() = any (array['admin', 'reception', 'receptionist'])
  );
