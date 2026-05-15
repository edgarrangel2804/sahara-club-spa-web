insert into storage.buckets (id, name, public)
values ('digital-products', 'digital-products', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists digital_products_public_read on storage.objects;
create policy digital_products_public_read
on storage.objects for select
to public
using (bucket_id = 'digital-products');

drop policy if exists digital_products_authenticated_upload on storage.objects;
create policy digital_products_authenticated_upload
on storage.objects for insert
to authenticated
with check (bucket_id = 'digital-products');

drop policy if exists digital_products_authenticated_update on storage.objects;
create policy digital_products_authenticated_update
on storage.objects for update
to authenticated
using (bucket_id = 'digital-products')
with check (bucket_id = 'digital-products');
