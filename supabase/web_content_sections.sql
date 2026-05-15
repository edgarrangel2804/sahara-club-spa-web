create table if not exists public.web_content_sections (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.sucursales(id) on delete set null,
  section_key text not null,
  content_type text not null,
  title text not null default '',
  subtitle text not null default '',
  short_description text not null default '',
  long_description text not null default '',
  price numeric(10,2),
  promo_price numeric(10,2),
  image_url text not null default '',
  video_url text not null default '',
  category text not null default '',
  cta_text text not null default '',
  cta_url text not null default '',
  display_order integer not null default 0,
  is_active boolean not null default true,
  is_featured boolean not null default false,
  start_date timestamptz,
  end_date timestamptz,
  linked_service_id uuid references public.services(id) on delete set null,
  linked_product_id uuid references public.products(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint web_content_sections_type_check check (
    content_type in (
      'facial',
      'massage',
      'membership',
      'digital_product',
      'physical_product',
      'gift_card',
      'promotion',
      'hero',
      'banner',
      'post'
    )
  ),
  constraint web_content_sections_single_link_check check (
    linked_service_id is null or linked_product_id is null
  )
);

create index if not exists idx_web_content_sections_section_key
  on public.web_content_sections(section_key);

create index if not exists idx_web_content_sections_content_type
  on public.web_content_sections(content_type);

create index if not exists idx_web_content_sections_active_order
  on public.web_content_sections(is_active, display_order);

drop trigger if exists trg_web_content_sections_updated_at on public.web_content_sections;
create trigger trg_web_content_sections_updated_at
before update on public.web_content_sections
for each row execute function public.touch_updated_at();

alter table public.web_content_sections enable row level security;

drop policy if exists web_content_public_select on public.web_content_sections;
create policy web_content_public_select
  on public.web_content_sections
  for select
  to anon, authenticated
  using (
    is_active = true
    and (start_date is null or start_date <= now())
    and (end_date is null or end_date >= now())
  );

drop policy if exists web_content_admin_manage on public.web_content_sections;
create policy web_content_admin_manage
  on public.web_content_sections
  for all
  to authenticated
  using (
    public.current_user_role() in ('admin', 'super_admin')
    or public.current_user_has_permission('web_content', 'view')
    or public.current_user_has_permission('web_content', 'edit')
    or public.current_user_has_permission('web_content', 'create')
    or public.current_user_has_permission('web_content', 'delete')
  )
  with check (
    public.current_user_role() in ('admin', 'super_admin')
    or public.current_user_has_permission('web_content', 'edit')
    or public.current_user_has_permission('web_content', 'create')
  );
