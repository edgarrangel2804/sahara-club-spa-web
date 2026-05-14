select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'staff'
order by ordinal_position;

select *
from public.staff
limit 5;

select
  c.id,
  c.conversation_type,
  c.customer_id,
  c.receptionist_id,
  c.professional_id,
  c.admin_id,
  c.reservation_id,
  c.subject,
  c.last_message_preview,
  c.last_message_at
from public.chat_conversations c
order by c.updated_at desc
limit 15;

select
  m.id,
  m.conversation_id,
  m.sender_id,
  m.sender_role,
  m.message_text,
  m.message_type,
  m.is_read,
  m.created_at
from public.chat_messages m
order by m.created_at desc
limit 20;
