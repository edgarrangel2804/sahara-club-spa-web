-- Sahara Club Spa - protect signed PDF assets in private Storage buckets.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gift-card-assets', 'gift-card-assets', false, 10485760, array['application/pdf'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 10485760, array['application/pdf'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists gift_card_assets_service_role_all on storage.objects;
create policy gift_card_assets_service_role_all
  on storage.objects
  for all
  to service_role
  using (bucket_id = 'gift-card-assets')
  with check (bucket_id = 'gift-card-assets');

drop policy if exists receipts_service_role_all on storage.objects;
create policy receipts_service_role_all
  on storage.objects
  for all
  to service_role
  using (bucket_id = 'receipts')
  with check (bucket_id = 'receipts');
