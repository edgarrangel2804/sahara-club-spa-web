-- Single-branch mode bootstrap for Sahara Club Spa
-- Note: current production schema uses UUID ids for sucursales.
-- We keep a fixed UUID for the default branch instead of literal id=1.

insert into public.sucursales (
  id,
  nombre,
  direccion_completa,
  telefono_contacto,
  link_maps,
  whatsapp,
  email
)
values (
  '11111111-1111-1111-1111-111111111111',
  'Sahara Club Spa',
  '',
  '',
  '',
  '',
  ''
)
on conflict (id) do update
set nombre = excluded.nombre;

alter table public.bookings
  alter column sucursal_id set default '11111111-1111-1111-1111-111111111111'::uuid;

update public.bookings
set sucursal_id = '11111111-1111-1111-1111-111111111111'::uuid
where sucursal_id is null;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'configuracion_sistema'
      and column_name = 'enable_multi_branch'
  ) then
    update public.configuracion_sistema
    set enable_multi_branch = false;
  elsif exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'configuracion_sistema'
  ) then
    alter table public.configuracion_sistema
      add column if not exists enable_multi_branch boolean not null default false;

    update public.configuracion_sistema
    set enable_multi_branch = false;
  end if;
end $$;
