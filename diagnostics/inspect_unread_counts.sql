select
  c.id as chat_id,
  c.participant_1,
  c.participant_2,
  count(*) filter (where m.read_at is null) as unread_total,
  count(*) filter (where m.read_at is not null) as read_total,
  max(m.created_at) as last_message_at
from public.chats c
left join public.messages m on m.chat_id = c.id
group by c.id, c.participant_1, c.participant_2
order by last_message_at desc nulls last
limit 20;

select
  id,
  chat_id,
  sender_id,
  content,
  read_at,
  created_at
from public.messages
where chat_id in (
  select c.id
  from public.chats c
  order by c.created_at desc
  limit 5
)
order by chat_id, created_at desc;
