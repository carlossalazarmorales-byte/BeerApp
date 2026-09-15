-- Phase 3: global catalog reference table for beer styles. Shared, not
-- user-owned -- see docs/DATABASE.md and CLAUDE.md's Data Model Rule.

create table public.beer_styles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- Free text, no fixed taxonomy -- the product does not define one yet.
  category text,
  description text,
  origin_country_id uuid references public.countries (id),
  typical_abv_min numeric(4, 2),
  typical_abv_max numeric(4, 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint beer_styles_name_not_blank check (length(trim(name)) > 0),
  constraint beer_styles_abv_min_non_negative check (
    typical_abv_min is null or typical_abv_min >= 0
  ),
  constraint beer_styles_abv_max_non_negative check (
    typical_abv_max is null or typical_abv_max >= 0
  ),
  constraint beer_styles_abv_range_order check (
    typical_abv_min is null
    or typical_abv_max is null
    or typical_abv_max >= typical_abv_min
  )
);

create unique index beer_styles_name_unique_idx
  on public.beer_styles (lower(name));

create index beer_styles_origin_country_id_idx
  on public.beer_styles (origin_country_id);

create trigger beer_styles_set_updated_at
  before update on public.beer_styles
  for each row execute function private.set_updated_at();

-- RLS: enabled, zero policies -- same API-only access model as countries.
alter table public.beer_styles enable row level security;

revoke all on table public.beer_styles from anon, authenticated;
