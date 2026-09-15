-- Phase 3: global catalog reference table. Countries are shared, not
-- user-owned -- see docs/DATABASE.md and CLAUDE.md's Data Model Rule.

create table public.countries (
  id uuid primary key default gen_random_uuid(),
  -- ISO 3166-1 alpha-2. `text` (not `char(2)`) to avoid CHAR blank-padding
  -- semantics; the CHECK below enforces the actual shape.
  iso_code text not null,
  name text not null,
  -- Fixed vocabulary for map-style grouping (mapa_interactivo mockup's
  -- "Across Europe" sidebar grouping). This is still a migration-gated
  -- vocabulary, not a free-form field -- adding/renaming a continent value
  -- requires a new migration, same as it would with a real enum type.
  continent text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint countries_iso_code_format check (iso_code ~ '^[A-Z]{2}$'),
  constraint countries_name_not_blank check (length(trim(name)) > 0),
  constraint countries_continent_allowed check (
    continent in (
      'Africa', 'Antarctica', 'Asia', 'Europe',
      'North America', 'Oceania', 'South America'
    )
  )
);

create unique index countries_iso_code_unique_idx
  on public.countries (iso_code);

create unique index countries_name_unique_idx
  on public.countries (lower(name));

create trigger countries_set_updated_at
  before update on public.countries
  for each row execute function private.set_updated_at();

-- RLS: enabled, deliberately zero policies here. This denies anon and
-- authenticated by default -- catalog access is API-only via FastAPI
-- (see backend/app), which connects as the least-privilege
-- `beerapp_backend` role created in a later migration. See docs/DATABASE.md
-- for the full access-model rationale.
alter table public.countries enable row level security;

revoke all on table public.countries from anon, authenticated;
