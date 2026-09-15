-- Phase 3: global catalog entity for breweries. Shared, not user-owned --
-- see docs/DATABASE.md and CLAUDE.md's Data Model Rule.

create table public.breweries (
  id uuid primary key default gen_random_uuid(),
  -- Not unique: different breweries in different places can legitimately
  -- share a name. Duplicate detection is a Phase 13 (Beer Contributions)
  -- concern, not a schema-level constraint.
  name text not null,
  country_id uuid not null references public.countries (id),
  region text,
  city text,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  description text,
  website text,
  logo_url text,
  verified boolean not null default false,
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint breweries_name_not_blank check (length(trim(name)) > 0),
  constraint breweries_lat_lng_paired check (
    (latitude is null) = (longitude is null)
  ),
  constraint breweries_latitude_range check (
    latitude is null or latitude between -90 and 90
  ),
  constraint breweries_longitude_range check (
    longitude is null or longitude between -180 and 180
  )
);

-- Search index only, not unique -- see the name-uniqueness note above.
create index breweries_name_idx on public.breweries (lower(name));

create index breweries_country_id_idx on public.breweries (country_id);

create trigger breweries_set_updated_at
  before update on public.breweries
  for each row execute function private.set_updated_at();

-- RLS: enabled, zero policies -- same API-only access model as countries.
alter table public.breweries enable row level security;

revoke all on table public.breweries from anon, authenticated;
