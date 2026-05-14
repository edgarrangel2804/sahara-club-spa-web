select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name in ('chats', 'messages')
order by table_name, ordinal_position;

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename in ('chats', 'messages')
order by tablename, policyname;
