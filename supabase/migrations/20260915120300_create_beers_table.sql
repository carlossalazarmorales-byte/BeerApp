-- Phase 3: global catalog entity for beers -- one row per catalog beer,
-- regardless of how many users log it. Shared, not user-owned; a personal
-- log/review is a separate user-owned entity added in a later phase (see
-- CLAUDE.md's Data Model Rule and docs/DATABASE.md).

create table public.beers (
  id uuid primary key default gen_random_uuid(),
  -- Not unique: beer names are not globally unique.
  official_name text not null,
  brewery_id uuid not null references public.breweries (id),
  -- Nullable: never invent a placeholder style for a beer whose style is
  -- unknown, same convention as profiles.username in the Phase 2 migration.
  style_id uuid references public.beer_styles (id),
  -- A beer's own origin may differ from its brewery's (e.g. a beer brewed
  -- for a specific market) -- independent of country_id/region/city on
  -- breweries, all nullable.
  country_id uuid references public.countries (id),
  region text,
  city text,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  abv numeric(4, 2),
  ibu integer,
  description text,
  image_url text,
  -- Future scanner lookup (Phase 11).
  barcode text,
  verified boolean not null default false,
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint beers_official_name_not_blank check (
    length(trim(official_name)) > 0
  ),
  constraint beers_lat_lng_paired check (
    (latitude is null) = (longitude is null)
  ),
  constraint beers_latitude_range check (
    latitude is null or latitude between -90 and 90
  ),
  constraint beers_longitude_range check (
    longitude is null or longitude between -180 and 180
  ),
  constraint beers_abv_range check (abv is null or abv between 0 and 100),
  -- No upper bound: an invented cap has no documented product rule behind
  -- it. Only a sanity floor at zero.
  constraint beers_ibu_non_negative check (ibu is null or ibu >= 0)
);

-- Search index only, not unique -- beer names are not globally unique.
create index beers_official_name_idx on public.beers (lower(official_name));

create index beers_brewery_id_idx on public.beers (brewery_id);
create index beers_style_id_idx on public.beers (style_id);
create index beers_country_id_idx on public.beers (country_id);

create unique index beers_barcode_unique_idx
  on public.beers (barcode)
  where barcode is not null;

create trigger beers_set_updated_at
  before update on public.beers
  for each row execute function private.set_updated_at();

-- RLS: enabled, zero policies -- same API-only access model as countries.
alter table public.beers enable row level security;

revoke all on table public.beers from anon, authenticated;
