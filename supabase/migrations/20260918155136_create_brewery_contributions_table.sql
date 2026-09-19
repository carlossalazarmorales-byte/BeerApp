-- Phase 13: user-owned proposal for a brewery missing from the catalog.
-- A contribution is NOT a catalog row: nothing here is ever readable through
-- Discover/Map/Statistics/Achievements, and nothing in this phase writes
-- public.breweries (see CLAUDE.md's Data Model Rule and docs/DECISIONS.md).
--
-- The moderation lifecycle (status/reviewed_at/review_note/resolved_brewery_id)
-- is defined now so a future moderator workflow needs no schema change, but
-- only 'pending' is reachable today: no role in this phase can UPDATE this
-- table, and the INSERT policy (next migration group) pins status = 'pending'.
--
-- Write-once by design (no updated_at, no trigger), same rationale as
-- public.user_achievements: submissions are immutable this phase.

create table public.brewery_contributions (
  id uuid primary key default gen_random_uuid(),
  -- Owner identity FK: cascades so DELETE /account (Phase 12) stays complete.
  user_id uuid not null,
  name text not null,
  -- Canonical country when picked from the catalog, or a free-text proposal
  -- when the country isn't listed -- exactly one of the two. A proposal never
  -- creates a public.countries row.
  country_id uuid,
  proposed_country_name text,
  region text,
  city text,
  status text not null default 'pending',
  reviewed_at timestamptz,
  review_note text,
  -- Set by a future moderator on approval: the canonical row this
  -- contribution resolved to. RESTRICT matches every FK onto the catalog.
  resolved_brewery_id uuid,
  created_at timestamptz not null default now(),
  constraint brewery_contributions_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete cascade,
  constraint brewery_contributions_country_id_fkey
    foreign key (country_id) references public.countries (id) on delete restrict,
  constraint brewery_contributions_resolved_brewery_id_fkey
    foreign key (resolved_brewery_id) references public.breweries (id) on delete restrict,
  constraint brewery_contributions_name_length check (
    length(btrim(name)) between 1 and 200
  ),
  constraint brewery_contributions_country_xor_proposed check (
    num_nonnulls(country_id, proposed_country_name) = 1
  ),
  constraint brewery_contributions_proposed_country_length check (
    proposed_country_name is null
    or length(btrim(proposed_country_name)) between 1 and 100
  ),
  constraint brewery_contributions_region_length check (
    region is null or length(btrim(region)) between 1 and 100
  ),
  constraint brewery_contributions_city_length check (
    city is null or length(btrim(city)) between 1 and 100
  ),
  constraint brewery_contributions_status_valid check (
    status in ('pending', 'approved', 'rejected')
  ),
  constraint brewery_contributions_reviewed_at_matches_status check (
    (status = 'pending') = (reviewed_at is null)
  ),
  constraint brewery_contributions_review_note_only_when_reviewed check (
    status <> 'pending' or review_note is null
  ),
  constraint brewery_contributions_review_note_length check (
    review_note is null or length(review_note) <= 500
  ),
  constraint brewery_contributions_resolved_matches_approved check (
    (status = 'approved') = (resolved_brewery_id is not null)
  )
);

-- Serves "my contributions" history: WHERE user_id = $1 ORDER BY created_at
-- DESC, id DESC (id is the stable pagination tie-breaker).
create index brewery_contributions_user_created_idx
  on public.brewery_contributions (user_id, created_at desc, id desc);

-- Own-duplicate guards: one user cannot have two equivalent PENDING
-- suggestions (a retry/double-tap must not create two rows). Two partial
-- indexes rather than one coalesce(country_id::text, ...) expression index,
-- which avoids any cast-immutability question. Deliberately per-user: other
-- users' rows are private, so cross-user name duplicates are the future
-- moderator's concern, not a constraint.
create unique index brewery_contributions_own_pending_country_uidx
  on public.brewery_contributions (user_id, lower(btrim(name)), country_id)
  where status = 'pending' and country_id is not null;

create unique index brewery_contributions_own_pending_proposed_country_uidx
  on public.brewery_contributions (
    user_id, lower(btrim(name)), lower(btrim(proposed_country_name))
  )
  where status = 'pending' and proposed_country_name is not null;

-- RLS + grants for beerapp_backend live in the grants migration, following
-- the same table-then-role split as user_achievements.
alter table public.brewery_contributions enable row level security;
revoke all on table public.brewery_contributions from anon, authenticated;
