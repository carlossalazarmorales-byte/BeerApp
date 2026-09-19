-- Phase 13: user-owned proposal for a beer missing from the catalog.
-- Same model as public.brewery_contributions: a contribution is NOT a catalog
-- row and nothing in this phase writes public.beers. Catalog reads do not
-- filter on `verified`, which is why a proposal must never be stored as an
-- unverified public.beers row -- it would appear in Discover immediately.
--
-- Deliberately narrow: only what identifies a beer for a moderator. No ibu,
-- description, origin fields, image or notes (each can be added later without
-- reshaping this table).

create table public.beer_contributions (
  id uuid primary key default gen_random_uuid(),
  -- Owner identity FK: cascades so DELETE /account (Phase 12) stays complete.
  user_id uuid not null,
  official_name text not null,
  -- The brewery is either a canonical catalog brewery or a free-text
  -- proposal -- exactly one. There is intentionally NO reference to
  -- public.brewery_contributions: a beer suggestion never depends on a
  -- separate brewery suggestion.
  brewery_id uuid,
  proposed_brewery_name text,
  -- Style stays optional: at most one of the canonical id / a proposal.
  style_id uuid,
  proposed_style_name text,
  abv numeric(4, 2),
  -- Canonical GTIN only (see backend/app/services/barcode.py). The GS1
  -- check digit is validated once, in Python; the DB only pins the shape.
  barcode text,
  status text not null default 'pending',
  reviewed_at timestamptz,
  review_note text,
  -- Set by a future moderator on approval: the canonical beer this
  -- contribution resolved to.
  resolved_beer_id uuid,
  created_at timestamptz not null default now(),
  constraint beer_contributions_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete cascade,
  constraint beer_contributions_brewery_id_fkey
    foreign key (brewery_id) references public.breweries (id) on delete restrict,
  constraint beer_contributions_style_id_fkey
    foreign key (style_id) references public.beer_styles (id) on delete restrict,
  constraint beer_contributions_resolved_beer_id_fkey
    foreign key (resolved_beer_id) references public.beers (id) on delete restrict,
  constraint beer_contributions_name_length check (
    length(btrim(official_name)) between 1 and 200
  ),
  constraint beer_contributions_brewery_xor_proposed check (
    num_nonnulls(brewery_id, proposed_brewery_name) = 1
  ),
  constraint beer_contributions_proposed_brewery_length check (
    proposed_brewery_name is null
    or length(btrim(proposed_brewery_name)) between 1 and 200
  ),
  constraint beer_contributions_style_not_both check (
    num_nonnulls(style_id, proposed_style_name) <= 1
  ),
  constraint beer_contributions_proposed_style_length check (
    proposed_style_name is null
    or length(btrim(proposed_style_name)) between 1 and 100
  ),
  constraint beer_contributions_abv_range check (
    abv is null or abv between 0 and 100
  ),
  constraint beer_contributions_barcode_format check (
    barcode is null or barcode ~ '^([0-9]{8}|[0-9]{13})$'
  ),
  constraint beer_contributions_status_valid check (
    status in ('pending', 'approved', 'rejected')
  ),
  constraint beer_contributions_reviewed_at_matches_status check (
    (status = 'pending') = (reviewed_at is null)
  ),
  constraint beer_contributions_review_note_only_when_reviewed check (
    status <> 'pending' or review_note is null
  ),
  constraint beer_contributions_review_note_length check (
    review_note is null or length(review_note) <= 500
  ),
  constraint beer_contributions_resolved_matches_approved check (
    (status = 'approved') = (resolved_beer_id is not null)
  )
);

-- Serves "my contributions" history: WHERE user_id = $1 ORDER BY created_at
-- DESC, id DESC (id is the stable pagination tie-breaker).
create index beer_contributions_user_created_idx
  on public.beer_contributions (user_id, created_at desc, id desc);

-- Own-duplicate guards (pending only, per user): a retry/double-tap cannot
-- create two equivalent suggestions. Two partial indexes, one per brewery
-- form, so no expression has to coalesce a uuid into text.
create unique index beer_contributions_own_pending_brewery_uidx
  on public.beer_contributions (user_id, lower(btrim(official_name)), brewery_id)
  where status = 'pending' and brewery_id is not null;

create unique index beer_contributions_own_pending_proposed_brewery_uidx
  on public.beer_contributions (
    user_id, lower(btrim(official_name)), lower(btrim(proposed_brewery_name))
  )
  where status = 'pending' and proposed_brewery_name is not null;

-- Deliberately NOT unique: two users may legitimately submit the same barcode
-- (the submitter is flagged, not blocked -- docs/DECISIONS.md). This index
-- serves both the cross-user existence check
-- (private.other_user_pending_beer_barcode_exists) and a future moderator's
-- duplicate lookup.
create index beer_contributions_pending_barcode_idx
  on public.beer_contributions (barcode)
  where barcode is not null and status = 'pending';

-- RLS + grants for beerapp_backend live in the grants migration, following
-- the same table-then-role split as user_achievements.
alter table public.beer_contributions enable row level security;
revoke all on table public.beer_contributions from anon, authenticated;
