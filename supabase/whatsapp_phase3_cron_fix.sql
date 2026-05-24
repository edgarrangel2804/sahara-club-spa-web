-- Fix: invoke_edge_function lee la service_role key desde Vault (no GUC).
-- La URL pública la dejamos hardcoded (es la URL de tu proyecto público).

create or replace function public.invoke_edge_function(
  p_function_name text,
  p_body jsonb default '{}'::jsonb
) returns bigint
language plpgsql
security definer
as $$
declare
  v_url text := 'https://fkbyxhwdcsgrrixalzwf.supabase.co';
  v_key text;
  v_req_id bigint;
begin
  select decrypted_secret into v_key
  from vault.decrypted_secrets
  where name = 'whatsapp_worker_service_role'
  limit 1;

  if v_key is null then
    raise notice 'invoke_edge_function: vault secret whatsapp_worker_service_role no existe';
    return null;
  end if;

  select net.http_post(
    url := v_url || '/functions/v1/' || p_function_name,
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer ' || v_key
    ),
    body := p_body
  ) into v_req_id;

  return v_req_id;
end;
$$;

-- Limpia y re-crea jobs (ahora apuntan a la function refactorizada).
do $$
declare j record;
begin
  for j in select jobid, jobname from cron.job where jobname like 'whatsapp_%'
  loop perform cron.unschedule(j.jobid); end loop;
end;
$$;

select cron.schedule(
  'whatsapp_worker_tick',
  '* * * * *',
  $$ select public.invoke_edge_function('whatsapp-worker', '{"limit":25}'::jsonb); $$
);
select cron.schedule(
  'whatsapp_enqueue_reminders',
  '*/5 * * * *',
  $$ select public.enqueue_due_whatsapp_reminders(now()); $$
);
select cron.schedule(
  'whatsapp_cleanup',
  '30 3 * * *',
  $$ select public.cleanup_whatsapp_data(90, 60, 30); $$
);
