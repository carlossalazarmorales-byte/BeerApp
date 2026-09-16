# Architecture

High-level structure only. This will grow as features land; it does not describe
features that don't exist yet.

## Mobile (`/mobile`)

Flutter app, feature-oriented per `CLAUDE.md`:

```
mobile/lib/
  app/            # app-level setup: entrypoint, routing, theming glue
  core/           # cross-cutting concerns: env config, networking, error handling
  design_system/  # shared tokens/components (colors, typography, spacing, radii)
  features/       # one folder per feature, each optionally split into data/domain/presentation
  shared/         # widgets/utilities used by more than one feature
```

None of these folders exist yet beyond `main.dart` — they will be introduced in
Phase 1 (Design System & App Shell) as they're actually populated, rather than
scaffolded empty ahead of time.

## Backend (`/backend`)

FastAPI app. Layering per `CLAUDE.md`, built out in Phase 3:

```
backend/app/
  routes/         # thin HTTP layer — request/response only
  schemas/        # Pydantic request/response models
  services/       # business logic
  repositories/   # persistence access, hand-written parameterized SQL
  auth/           # JWKS fetch/cache, JWT verification, get_current_user dependency
  dependencies.py # pool -> repository -> service wiring, overridable per layer in tests
  db.py           # asyncpg connection pool
  errors.py       # exception -> JSON error envelope mapping
  config.py       # environment-driven settings (pydantic-settings)
```

No `models/` (ORM) layer: the backend talks to Postgres directly via `asyncpg`
and hand-written SQL in `repositories/`, not an ORM — see `docs/DECISIONS.md`.
Pydantic models in `schemas/` are the only "model" layer, and describe API
shapes, not persistence.

## Data flow

Mobile → FastAPI (REST) → PostgreSQL (via Supabase). Supabase Auth issues the
session token the mobile app attaches to API requests; the backend verifies it
locally (JWKS-based JWT verification, `app/auth/`) and enforces authorization
server-side (see `PRODUCT.md` §27). The mobile app never queries Postgres/
PostgREST directly for catalog data — FastAPI is the only read path, per
`docs/DATABASE.md`. Supabase Storage holds images referenced by URL from
catalog/user records.

The backend's own Postgres connection (`DATABASE_URL`) is a dedicated,
least-privilege role (`beerapp_backend`, `SELECT`-only on the catalog tables)
rather than the project's admin credentials — see `docs/DATABASE.md` for the
full role model and `docs/DECISIONS.md` for the rationale.

## Discover vs. catalog (Phase 5)

`features/catalog/` stays generic: `CatalogRepository`/`ApiCatalogRepository`
(now including a paginated `getBeers(... q:)` search parameter and a
`getBreweries()` listing method), plus UI pieces reused elsewhere
(`BeerListTile`, the shared catalog error/debug helpers). Discover-specific
orchestration — the search query, style/country/brewery filter selection,
debouncing, stale-request protection, and pagination against that
query/filter state — lives entirely in `features/discover/`
(`DiscoverController`/`DiscoverScreen`), which is the only consumer of the
search/filter parameters. This keeps the catalog feature reusable by any
future consumer (e.g. the map phase) without carrying Discover's UI state.

## Global catalog vs. personal data

Per `CLAUDE.md` and `PRODUCT.md` §7: `Beer`, `Brewery`, and `Beer Style` are
global catalog entities, shared across all users. A user's rating, review,
favorite, wishlist, or drinking history is never stored on those records — it
lives in a separate user-owned `User Beer Log` entity referencing the catalog
beer by id. This separation must hold at the database, API, and mobile-model
level.

`public.user_beer_logs` (Phase 6) is the first concrete instance of this:
it's the first user-owned table, and it follows the catalog's **API-only**
model, not `profiles`'s direct-Supabase model — mobile never queries it via
Supabase/PostgREST, only through FastAPI's `/beer-logs` endpoints, using the
`beerapp_backend` role (`docs/DATABASE.md`, `docs/DECISIONS.md`). This was a
deliberate choice, not the only option: `profiles` (Phase 2) is also
user-owned but *is* read/written directly from the mobile app via
`supabase_flutter`, under `auth.uid()`-scoped RLS — that pattern works
because a PostgREST request genuinely carries the end user's own session.
FastAPI's connection to Postgres does not; it's one fixed role
(`beerapp_backend`) for the life of the pool, with no per-request identity
Postgres can see on its own. So per-user isolation on `user_beer_logs` is
enforced by **two** layers instead: the repository's explicit
`WHERE user_id = $1` filtering, and a transaction-scoped RLS policy keyed on
`app.user_id` (a Postgres setting the backend sets from the verified JWT's
`sub` claim at the start of each transaction) — never `auth.uid()`, and
never a blanket `USING (true)` policy. See `docs/DATABASE.md`'s
`user_beer_logs` section for the exact mechanism.

`public.user_beer_collection` (Phase 7) is the second table on this pattern
— favorite/wishlist state, distinct from `user_beer_logs`'s repeatable
historical events. Since a second repository now needed the identical
transaction-scoped-identity mechanism, it was extracted out of
`BeerLogRepository._scoped` into a small shared helper,
`scoped_connection()` (`backend/app/repositories/scoped_connection.py`) —
the same "wait for a second real consumer before generalizing" bar CLAUDE.md
asks for elsewhere. Both repositories still filter `WHERE user_id = $N`
explicitly on every query in addition to it; the helper only centralizes the
"open a transaction and set `app.user_id`" plumbing, not the query logic
itself.

## Collection freshness (Phase 7)

The Collection screen (unique beers tried, favorites, wishlist) must reflect
mutations that happen elsewhere — logging a beer or favoriting/wishlisting it
from Beer Detail — without a manual refresh. The obvious navigation-driven
approach (a `RouteObserver`/`RouteAware` hook firing when Beer Detail pops)
was rejected: `BeerDetailScreen` is a top-level route on the root navigator
while `CollectionScreen` lives inside its own `StatefulShellBranch` navigator,
so that hook would only fire on an actual push/pop — missing the common case
of returning to a *different* tab first and switching to Collection later via
the bottom nav.

Instead, `CollectionRefreshSignal` (`mobile/lib/shared/collection_refresh_signal.dart`)
is a tiny mutation-driven `ChangeNotifier`: any controller that successfully
mutates data Collection cares about (`BeerLogController`,
`CollectionStateController`) calls `notifyChanged()` on it, and
`CollectionController` listens and calls `refresh()`. This works with no
visibility check at all, because `StatefulShellRoute.indexedStack` keeps
every branch's widget subtree — including `CollectionController` — mounted
and responsive even while a different tab is showing, so a hidden
`CollectionController` still processes the notification and has fresh data
ready by the time the user switches to that tab. See `docs/DECISIONS.md`.
