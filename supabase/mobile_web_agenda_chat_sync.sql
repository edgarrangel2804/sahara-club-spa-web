alter type public.booking_status add value if not exists 'awaiting_payment' after 'completed';
alter type public.booking_status add value if not exists 'paid' after 'awaiting_payment';
alter type public.booking_status add value if not exists 'no_show' after 'cancelled';

alter table public.bookings
  add column if not exists source_platform text not null default 'web',
  add column if not exists updated_by uuid references public.profiles(id) on delete set null;

drop policy if exists bookings_insert_by_client_pending on public.bookings;
create policy bookings_insert_by_client_pending
  on public.bookings
  for insert
  to authenticated
  with check (
    public.current_user_role() = 'client'
    and client_id = auth.uid()
    and coalesce(status::text, 'pending') = 'pending'
  );

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null default '11111111-1111-1111-1111-111111111111'::uuid,
  conversation_type text not null default 'customer_support',
  customer_id uuid references public.profiles(id) on delete set null,
  receptionist_id uuid references public.profiles(id) on delete set null,
  professional_id uuid references public.staff(id) on delete set null,
  admin_id uuid references public.profiles(id) on delete set null,
  reservation_id uuid references public.bookings(id) on delete set null,
  subject text not null default '',
  last_message_preview text not null default '',
  last_message_at timestamptz,
  last_message_sender_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_chat_conversations_branch
  on public.chat_conversations(branch_id, updated_at desc);

create index if not exists idx_chat_conversations_customer
  on public.chat_conversations(customer_id, updated_at desc);

create index if not exists idx_chat_conversations_professional
  on public.chat_conversations(professional_id, updated_at desc);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  sender_role text not null,
  message_text text not null,
  message_type text not null default 'text',
  is_read boolean not null default false,
  read_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_messages_conversation
  on public.chat_messages(conversation_id, created_at asc);

create index if not exists idx_chat_messages_unread
  on public.chat_messages(conversation_id, is_read, created_at desc);

create or replace function public.can_access_chat_conversation(
  p_conversation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_conversations c
    where c.id = p_conversation_id
      and (
        public.current_user_role() in ('admin', 'super_admin', 'reception', 'receptionist')
        or (public.current_user_role() = 'client' and c.customer_id = auth.uid())
        or (public.current_user_role() = 'therapist' and c.professional_id = auth.uid())
      )
  );
$$;

create or replace function public.touch_chat_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_conversations
  set
    last_message_preview = left(coalesce(new.message_text, ''), 200),
    last_message_at = new.created_at,
    last_message_sender_id = new.sender_id,
    updated_at = now()
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists chat_messages_touch_conversation on public.chat_messages;
create trigger chat_messages_touch_conversation
after insert on public.chat_messages
for each row execute function public.touch_chat_conversation();

do $$
begin
  if exists (
    select 1
    from pg_proc
    where proname = 'set_updated_at'
      and pg_function_is_visible(oid)
  ) then
    execute 'drop trigger if exists chat_conversations_set_updated_at on public.chat_conversations';
    execute '
      create trigger chat_conversations_set_updated_at
      before update on public.chat_conversations
      for each row execute function public.set_updated_at()
    ';
  end if;
end $$;

alter table public.chat_conversations enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists chat_conversations_select_by_access on public.chat_conversations;
create policy chat_conversations_select_by_access
  on public.chat_conversations
  for select
  to authenticated
  using (public.can_access_chat_conversation(id));

drop policy if exists chat_conversations_insert_by_role on public.chat_conversations;
create policy chat_conversations_insert_by_role
  on public.chat_conversations
  for insert
  to authenticated
  with check (
    public.current_user_role() in ('admin', 'super_admin', 'reception', 'receptionist')
    or (
      public.current_user_role() = 'client'
      and customer_id = auth.uid()
      and professional_id is null
    )
    or (
      public.current_user_role() = 'therapist'
      and professional_id = auth.uid()
      and customer_id is null
    )
  );

drop policy if exists chat_conversations_update_by_access on public.chat_conversations;
create policy chat_conversations_update_by_access
  on public.chat_conversations
  for update
  to authenticated
  using (public.can_access_chat_conversation(id))
  with check (public.can_access_chat_conversation(id));

drop policy if exists chat_conversations_delete_admin on public.chat_conversations;
create policy chat_conversations_delete_admin
  on public.chat_conversations
  for delete
  to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'));

drop policy if exists chat_messages_select_by_access on public.chat_messages;
create policy chat_messages_select_by_access
  on public.chat_messages
  for select
  to authenticated
  using (public.can_access_chat_conversation(conversation_id));

drop policy if exists chat_messages_insert_by_access on public.chat_messages;
create policy chat_messages_insert_by_access
  on public.chat_messages
  for insert
  to authenticated
  with check (
    public.can_access_chat_conversation(conversation_id)
    and sender_id = auth.uid()
  );

drop policy if exists chat_messages_update_by_access on public.chat_messages;
create policy chat_messages_update_by_access
  on public.chat_messages
  for update
  to authenticated
  using (public.can_access_chat_conversation(conversation_id))
  with check (public.can_access_chat_conversation(conversation_id));

drop policy if exists chat_messages_delete_admin on public.chat_messages;
create policy chat_messages_delete_admin
  on public.chat_messages
  for delete
  to authenticated
  using (public.current_user_role() in ('admin', 'super_admin'));
