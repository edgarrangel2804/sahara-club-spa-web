-- Normalize product categories to the set supported by the current UI.
-- Supported values:
-- general, aceite, vela, crema, suplemento, accesorio

alter table public.products
  alter column category set default 'general';

update public.products
set category = case lower(coalesce(category, ''))
  when 'general' then 'general'
  when 'aceite' then 'aceite'
  when 'vela' then 'vela'
  when 'crema' then 'crema'
  when 'suplemento' then 'suplemento'
  when 'accesorio' then 'accesorio'
  when 'aceites' then 'aceite'
  when 'velas' then 'vela'
  when 'cremas' then 'crema'
  when 'suplementos' then 'suplemento'
  when 'accesorios' then 'accesorio'
  else 'general'
end
where category is null
   or lower(category) not in (
     'general',
     'aceite',
     'vela',
     'crema',
     'suplemento',
     'accesorio'
   );
