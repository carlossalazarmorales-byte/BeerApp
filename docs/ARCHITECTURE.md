# Architecture

High-level structure only; it describes what exists in the repository today and is
updated as features land.

## Mobile (`/mobile`)

Flutter app, feature-oriented per `CLAUDE.md`:

```
mobile/lib/
  app/            # app-level setup: launch/startup guard, router, theming glue
  core/           # cross-cutting: auth, bootstrap (global error handlers), config
                  #   (env + validation, legal links), links, locale, logging,
                  #   network (API client), onboarding (age gate)
  design_system/  # tokens (colors, gradients, typography, spacing, radii, shadows),
                  #   theme, and components (buttons, cards, chips, inputs,
                  #   navigation, states)
  features/       # one folder per feature: achievements, auth, catalog, collection,
                  #   contributions, discover, logging, map, profile, scan,
                  #   statistics -- each split into data/domain/presentation as needed
  l10n/           # ARB sources (EN, ES) and the generated localizations
  shared/         # widgets/utilities used by more than one feature
```

Folders are created when they are actually populated, not scaffolded empty ahead of
time.

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
  db.py           # asyncpg connection pool (bounded: connect/acquire/command timeouts)
  errors.py       # exception -> JSON error envelope mapping (incl. 413/503/500)
  middleware.py   # pure-ASGI body-size limit and request logging (Phase 14)
  logging_config.py  # stdlib logging setup (Phase 14)
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

**A third kind of data: contributions (Phase 13).** Users can *propose*
missing beers and breweries, and a proposal is neither catalog data nor
personal consumption data: it lives in its own user-owned tables
(`beer_contributions`, `brewery_contributions`), private to its author, on the
same API-only/`app.user_id` model as the tables above. The invariant that
matters: **a contribution never becomes a catalog row by itself** — no code
path in this phase writes `beers`/`breweries`/`beer_styles`/`countries`, the
backend role has no privilege to, and the mobile app has no route to. A
suggestion reaches the canonical catalog only through a future, privileged,
moderator-only approval step that does not exist yet (there is no admin
identity to authorize it — see `docs/DECISIONS.md`). Creating a contribution
also never creates a log, favorite, wishlist entry or achievement.

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

## World map (Phase 8, revised QA Round 1 Block 2)

`features/map/` follows the same repository/controller pattern as every
other feature — no new state-management framework:

```
features/map/
  domain/          # MapRepository interface, MapMode/BeerMapState, MapBeer/MapCountry/MapResult
  data/            # ApiMapRepository (GET /map/beers, /map/countries), MapConfig, CountryBoundaries
  presentation/    # MapController, MapScreen, mode selector, beer preview card, MapLegend
```

**QA Round 1 Block 2** turned the map into a primarily beer-**origin** map
and removed the earlier brewery map mode: `MapMode` no longer has a
`breweries` value, `MapRepository`/`ApiMapRepository` no longer expose
`getMapBreweries`, and `MapBrewery`/`BreweryPreviewCard` were deleted as
dead code. The backend's brewery endpoints (`GET /map/breweries`,
`GET /breweries*`) are untouched and still used elsewhere (contributions,
catalog filtering by `brewery_id`) — only this feature's UI path to them
was removed.

`MapController` reuses `CollectionRefreshSignal` (see above) exactly as
`CollectionController` does: it listens for the same beer-log/favorite/
wishlist mutation notifications, since the Tried/Not tried/Favorites/
Wishlist map modes — and the country-fill layer's per-country tried counts
— depend on the identical personal-state tables Collection does. No new
signal was introduced for this.

`GET /map/beers` reads `user_beer_logs`/`user_beer_collection` the same way
`/collection/*` does: inside `scoped_connection` (see "Global catalog vs.
personal data" above), never a plain pooled query, since those tables are
RLS-protected on the transaction-local `app.user_id` setting.

**Country-fill layer.** `GET /map/countries` (`MapRepository.list_country_coverage`,
backend) aggregates `public.beers` joined to `public.countries` (via the
same `coalesce(b.country_id, br.country_id)` fallback `GET /map/beers`
uses, so a beer is never counted under a different country than it's
displayed under) with a `user_beer_logs` `EXISTS` for the tried count —
RLS-scoped like `GET /map/beers`. Only countries with at least one catalog
beer are returned; a country's absence from the response *is* the "zero
catalog" state, never a stored flag or a zero-count row. On the client,
`CountryBoundaries` (`data/country_boundaries.dart`) loads a bundled
Natural Earth 1:50m world-boundaries GeoJSON asset, simplified with
mapshaper's topology-preserving `keep-shapes` mode (`assets/map/`, see its
`NOTICE.txt` for the exact release/license, the simplification pipeline,
and known ISO-code gaps — revised from an initial 1:110m release after
on-device manual QA found it too coarse: several small island nations were
entirely absent, not merely simplified) and resolves each polygon's
ISO-3166-1 alpha-2 code (preferring Natural
Earth's `ISO_A2_EH` column over the plain `ISO_A2`, which is `"-99"` for
several sovereign/disputed entities in this release); a polygon with no
clean code, or whose code has no matching coverage row, always renders in
the "zero catalog" state — never a fabricated ISO mapping. `MapDataSynchronizer`
joins boundaries × coverage into exactly **three flat fill states**
(`CountryFillState`: zero catalog / zero history / has history) — this is
a closed, non-gradient enum by design: CLAUDE.md's Responsible Product
Design section forbids a completion/reward framing, so there is no
continuous ratio, no 4th "full coverage" tier, and no percentage shown
anywhere in the UI, even though the backend does return both counts (kept
as legitimate derived data for possible future neutral analytics).
`MapLegend` (`presentation/map_legend.dart`) gives these states — and the
beer-point tried/untried states — a text label, since color alone must not
carry all the meaning.

**`MapConfig`** (`features/map/data/map_config.dart`) is the single place
that knows the tile/style provider is MapTiler — `MapController`/`MapScreen`
depend only on its narrow `isConfigured`/`styleUrl` interface, so changing
providers later doesn't touch them. It is deliberately **not** part of
`core/config/env.dart`'s `Env.validate()`: an unconfigured or invalid map
key must never block Auth/Discover/Collection/Profile from opening, since
the map is one feature among several, not core app infrastructure like
Supabase or the API base URL. `MapScreen` checks `MapConfig.isConfigured`
itself and renders a localized "unavailable" state instead of building a
`MapLibreMap` when it's false — see `docs/DECISIONS.md` for why the
MapTiler key is a client-visible, quota-limited credential, not a
`service_role`-style secret.

**Map data synchronization (Phase 14, simplified in QA Round 1 Block 2).**
`MapScreen` no longer pushes data to the map itself. `MapDataSynchronizer`
(`presentation/map_data_synchronizer.dart`) talks to a one-method
`MapSurface` interface (`setGeoJsonSource`; `MapScreen` supplies a thin
MapLibre adapter), so the logic is testable without a platform view. It
uploads a source only when that source's content fingerprint changed
(beer ids/coordinates/tried-state for the beers source; boundary count and
per-country tried-state for the countries source), coalesces overlapping
syncs (re-reading the latest state), never throws, and leaves a failed
piece unsynced so the next notification retries it. The style-load path
calls `invalidate()` because the sources are recreated empty. Brewery
mode's layer-visibility toggling (`setLayerVisibility`, a second source, a
second layer group) was removed along with brewery mode itself — every
layer the map has left is always visible, so there is nothing left to
toggle. See `docs/DECISIONS.md` (performance review) for the Phase 14
measurement this synchronizer was originally built to address.

Beer-marker clustering is client-side only, via `maplibre_gl`'s built-in
GeoJSON-source `cluster` support — no backend aggregation/viewport query
exists for it. See `docs/DECISIONS.md` for why, and Phase 14 as the place
real geo-scale work (if it's ever needed) belongs. This is distinct from
the country-fill layer's `GET /map/countries` aggregation above, which is a
plain `GROUP BY` over the country/beer catalog, not a clustering/viewport
concern, and needs no comparable scale caveat at any realistic country
count (~250 max).

## Production hardening (Phase 14)

**Backend request path.** `app/main.py` builds the app from settings that need no
secrets (`RuntimeSettings`), so it can be imported by tests and tooling without a
populated `.env`. Two pure-ASGI middlewares wrap every request, outermost first:
`RequestLogMiddleware` (request id, one log line per request with the route
template and no query string, `X-Request-ID` on every response) and
`BodySizeLimitMiddleware` (413 from `Content-Length` and from the streamed bytes).
Because request logging is the outer layer, a rejected oversized request is logged
too. `errors.py` maps failures to the standard envelope: a narrow set of temporary
database/network errors to a sanitized 503, and everything else to a fixed 500.
`services/db_errors.py` translates a foreign-key violation by *constraint name*
(beer key -> 404, user key -> 401). The docs/OpenAPI routes exist only for
`ENVIRONMENT` in `local`/`dev`; `Settings` validates deployment values at startup
(https `SUPABASE_URL` outside local/dev; pool min <= max).

**Mobile startup.** `main.dart` calls `launchApp` (`app/launch_app.dart`), which
runs the app builder inside a guard: an invalid build configuration
(`core/config/env_validator.dart` - pure rules, value-free problem names) shows a
non-retryable localized `StartupFailureApp`, and any other startup error shows a
retryable one. `core/bootstrap/global_error_handlers.dart` installs
`FlutterError.onError` and `PlatformDispatcher.onError`; diagnostics go only
through `core/logging/debug_log.dart`, which writes nothing outside debug builds.
There is no crash-reporting or analytics vendor. Legal links are read from
build-time configuration (`core/config/legal_config.dart`) and opened by
`core/links/external_link_opener.dart` in the external browser.

**Shared UI added for accessibility and performance (Phase 14).** `design_system/components/states/inline_progress.dart` (`InlineSpinner`,
`InlineProgressBar`, labelled "Loading..."); `shared/widgets/beer_image.dart`
(`BeerImage`: display-size decode, stable placeholder, icon fallback, used by both
list tiles and the detail hero). `PrimaryButton`/`SecondaryButton` and the other
design-system components now carry the semantics described in `docs/DECISIONS.md`.

**Test support.** `backend/tests/integration/support/` (a minimal Supabase-like
scaffold and the helper that applies it plus every migration) and
`tests/integration/disposable_db.py` (the guard that keeps the integration suite off
any shared database) are documented in `docs/DATABASE.md`.
