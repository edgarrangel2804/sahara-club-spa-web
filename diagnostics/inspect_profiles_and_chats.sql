select id, full_name, role, email, phone
from public.profiles
order by created_at desc nulls last
limit 20;

select *
from public.chats
limit 20;

select *
from public.messages
order by created_at desc
limit 20;
