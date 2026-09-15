-- Phase 6: user-owned personal log of having tried/reviewed a catalog beer.
-- Distinct from the global public.beers catalog entity -- see CLAUDE.md's
-- Data Model Rule and docs/ARCHITECTURE.md's "Global catalog vs. personal
-- data" section. A user may log the same beer multiple times (PRODUCT.md
-- §7 / ROADMAP.md Phase 6 exit criteria), so there is deliberately no
-- unique(user_id, beer_id) constraint here.
--
-- No quantity/streak/leaderboard/reward field of any kind. serving_volume_ml
-- is the one deliberate, scoped exception to "no volume": an optional,
-- never-inferred, neutral data point for a future descriptive statistic
-- ("recorded volume", never "consumption") -- see docs/DECISIONS.md.

create table public.user_beer_logs (
  id uuid primary key default gen_random_uuid(),
  -- Owner identity FK: cascades like profiles.id, unlike the catalog
  -- tables' RESTRICT convention -- deleting a user's account should take
  -- their personal logs with it.
  user_id uuid not null references auth.users (id) on delete cascade,
  -- Shared catalog reference: RESTRICT, matching every other FK onto the
  -- catalog -- a future beer-delete flow must not silently destroy a
  -- user's personal review data.
  beer_id uuid not null references public.beers (id) on delete restrict,
  rating smallint,
  review text,
  consumed_at timestamptz not null default now(),
  serving_note text,
  price numeric(10, 2),
  currency text,
  venue_name text,
  -- Canonical unit is milliliters so a future SUM() is deterministic
  -- regardless of what unit the UI displays. Nullable and never populated
  -- automatically -- a log with no serving_volume_ml is a log with unknown
  -- volume, not zero volume. No invented upper bound, only a sanity floor.
  serving_volume_ml integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_beer_logs_rating_range check (rating is null or rating between 1 and 5),
  constraint user_beer_logs_price_non_negative check (price is null or price >= 0),
  constraint user_beer_logs_price_currency_paired check ((price is null) = (currency is null)),
  constraint user_beer_logs_currency_format check (currency is null or currency ~ '^[A-Z]{3}$'),
  constraint user_beer_logs_serving_volume_positive check (
    serving_volume_ml is null or serving_volume_ml > 0
  )
);

-- Serves the caller's general log history (Phase 7): WHERE user_id = $1
-- ORDER BY consumed_at DESC, id DESC. id is the stable tie-breaker so
-- pagination stays deterministic when two logs share a consumed_at.
create index user_beer_logs_user_id_consumed_at_id_idx
  on public.user_beer_logs (user_id, consumed_at desc, id desc);

-- Serves Beer Detail's per-beer history: WHERE user_id = $1 AND beer_id = $2
-- ORDER BY consumed_at DESC, id DESC. Also satisfies a plain (user_id,
-- beer_id) lookup via its leftmost columns, so no separate index is needed
-- for that narrower case.
create index user_beer_logs_user_id_beer_id_consumed_at_id_idx
  on public.user_beer_logs (user_id, beer_id, consumed_at desc, id desc);

create trigger user_beer_logs_set_updated_at
  before update on public.user_beer_logs
  for each row execute function private.set_updated_at();

-- RLS + grants for beerapp_backend live in the next migration, following
-- the same table-then-role split as beers/beerapp_backend.
alter table public.user_beer_logs enable row level security;
revoke all on table public.user_beer_logs from anon, authenticated;
