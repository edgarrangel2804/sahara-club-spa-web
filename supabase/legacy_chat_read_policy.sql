alter table if exists public.messages enable row level security;

drop policy if exists "Chat participants can mark messages as read" on public.messages;
create policy "Chat participants can mark messages as read"
  on public.messages
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.chats
      where chats.id = messages.chat_id
        and (
          chats.participant_1 = auth.uid()
          or chats.participant_2 = auth.uid()
        )
    )
  )
  with check (
    exists (
      select 1
      from public.chats
      where chats.id = messages.chat_id
        and (
          chats.participant_1 = auth.uid()
          or chats.participant_2 = auth.uid()
        )
    )
  );
