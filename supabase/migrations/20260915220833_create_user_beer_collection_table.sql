-- Phase 7: user-owned canonical favorite/wishlist state, one row per
-- (user, beer). Distinct from public.user_beer_logs, which is a repeatable
-- historical event (a user may log the same beer many times) -- this is
-- toggleable current-state membership, per CLAUDE.md's Data Model Rule and
-- docs/ARCHITECTURE.md's "Global catalog vs. personal data". See
-- docs/DECISIONS.md for why one table with two booleans was chosen over
-- separate favorites/wishlist tables.

create table public.user_beer_collection (
  id uuid primary key default gen_random_uuid(),
  -- Owner identity FK: cascades like user_beer_logs.user_id, unlike the
  -- catalog tables' RESTRICT convention -- deleting a user's account should
  -- take their collection state with it.
  user_id uuid not null references auth.users (id) on delete cascade,
  -- Shared catalog reference: RESTRICT, matching every other FK onto the
  -- catalog.
  beer_id uuid not null references public.beers (id) on delete restrict,
  is_favorite boolean not null default false,
  is_wishlist boolean not null default false,
  -- Set only on that flag's false->true transition, cleared on true->false.
  -- Deliberately NOT the same as updated_at (bumped by any column change,
  -- so it can't answer "most recently added to this state" on its own --
  -- a Favorites-tab "recent" sort must not resurface an old favorite just
  -- because its wishlist flag changed later).
  favorited_at timestamptz,
  wishlisted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_beer_collection_user_beer_unique unique (user_id, beer_id),
  constraint user_beer_collection_favorited_at_paired check (
    (is_favorite) = (favorited_at is not null)
  ),
  constraint user_beer_collection_wishlisted_at_paired check (
    (is_wishlist) = (wishlisted_at is not null)
  )
  -- Deliberately NO `check (is_favorite or is_wishlist)`. The logical
  -- invariant -- an all-false state is represented by no row, never a
  -- stored row -- still holds, but it is enforced entirely by
  -- CollectionRepository.set_state's single-transaction upsert-then-delete
  -- (backend/app/repositories/collection.py), not by a DB constraint.
  -- Postgres CHECK constraints are not deferrable, so recovering from a
  -- violation would require rolling back to a savepoint -- and that
  -- rollback releases any row lock acquired after the savepoint, reopening
  -- a window where a concurrent transaction could grab the row between the
  -- failed write and a follow-up delete. See docs/DECISIONS.md.
);

-- The unique(user_id, beer_id) constraint's backing index also serves Beer
-- Detail's single-row "what's this beer's state" lookup, the Logged tab's
-- join onto this table, and is the ON CONFLICT target for the atomic
-- upsert in CollectionRepository.set_state -- no separate index needed for
-- any of those.

-- Serves the Favorites tab: WHERE user_id = $1 AND is_favorite ORDER BY
-- favorited_at DESC, id DESC. Partial so wishlist-only rows don't bloat it.
create index user_beer_collection_user_favorite_idx
  on public.user_beer_collection (user_id, favorited_at desc, id desc)
  where is_favorite;

-- Serves the Wishlist tab, same shape.
create index user_beer_collection_user_wishlist_idx
  on public.user_beer_collection (user_id, wishlisted_at desc, id desc)
  where is_wishlist;

create trigger user_beer_collection_set_updated_at
  before update on public.user_beer_collection
  for each row execute function private.set_updated_at();

-- RLS + grants for beerapp_backend live in the next migration, following
-- the same table-then-role split as user_beer_logs/beerapp_backend.
alter table public.user_beer_collection enable row level security;
revoke all on table public.user_beer_collection from anon, authenticated;
