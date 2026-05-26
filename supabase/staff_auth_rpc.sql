-- Sahara Club Spa - RPC helpers para vincular staff con auth.users
-- ----------------------------------------------------------------------------
-- staff_find_auth_user_by_email: busca un user_id en auth.users por email.
--   Solo callable por service_role (Edge Function).

create or replace function public.staff_find_auth_user_by_email(p_email text)
returns uuid
language sql
security definer
set search_path = public, auth
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

revoke all on function public.staff_find_auth_user_by_email(text) from public;
grant execute on function public.staff_find_auth_user_by_email(text) to service_role;
