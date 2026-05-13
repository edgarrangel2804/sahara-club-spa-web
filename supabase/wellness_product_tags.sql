alter table public.products
  add column if not exists wellness_moods text[] not null default '{}'::text[],
  add column if not exists wellness_benefits text[] not null default '{}'::text[],
  add column if not exists ritual_badge text;

update public.products
set
  wellness_moods = case
    when coalesce(array_length(wellness_moods, 1), 0) > 0 then wellness_moods
    when lower(coalesce(name, '') || ' ' || coalesce(description, '')) ~ '(relaj|calma|descans|soul|noche)'
      then array['relaxation']
    when lower(coalesce(name, '') || ' ' || coalesce(description, '')) ~ '(energ|vital|amazing|transform|sol)'
      then array['energy']
    when lower(coalesce(name, '') || ' ' || coalesce(description, '')) ~ '(equilib|balance|coraz|magia)'
      then array['balance']
    else array['relaxation', 'balance']
  end,
  wellness_benefits = case
    when coalesce(array_length(wellness_benefits, 1), 0) > 0 then wellness_benefits
    when lower(coalesce(category, '')) = 'aceite' then array['Aromaterapia', 'Orgánico']
    when lower(coalesce(category, '')) = 'vela' then array['Hecho a mano', 'Casa Sahara']
    when lower(coalesce(category, '')) = 'crema' then array['Cuidado de la piel', 'Textura nutritiva']
    when lower(coalesce(category, '')) = 'suplemento' then array['Bienestar diario', 'Ritual interior']
    else array['Curado por Sahara', 'Edición boutique']
  end,
  ritual_badge = case
    when nullif(trim(coalesce(ritual_badge, '')), '') is not null then ritual_badge
    when lower(coalesce(name, '')) ~ '(vip|premium)' then 'Selección privada'
    when lower(coalesce(name, '')) ~ '(soul|facial)' then 'Favorito del spa'
    when lower(coalesce(category, '')) in ('vela', 'aceite', 'accesorio') then 'Casa Sahara'
    else 'Curaduría Sahara'
  end;
