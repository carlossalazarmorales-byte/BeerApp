# BeerApp — Development Roadmap

This roadmap defines the recommended order of implementation.

The objective is to build BeerApp incrementally, keeping every phase functional before moving to the next.

Do not attempt to build the entire application at once.

---

# Phase 0 — Project Foundation

Goal: create a professional project structure before feature development.

Tasks:

- [ ] Initialize Git repository
- [ ] Create GitHub repository
- [ ] Create Flutter application under `/mobile`
- [ ] Create FastAPI application under `/backend`
- [ ] Create `/docs`
- [ ] Preserve `/stitch` unchanged
- [ ] Add `.gitignore`
- [ ] Add `.env.example`
- [ ] Create root `README.md`
- [ ] Create initial architecture documentation
- [ ] Create initial database documentation
- [ ] Create design system documentation
- [ ] Configure linting
- [ ] Configure formatting
- [ ] Configure basic tests
- [ ] Verify Flutter project runs
- [ ] Verify backend health endpoint runs
- [ ] Make first clean Git commit

Exit criteria:

- Mobile app launches
- Backend launches
- Repository structure is clean
- No feature logic yet

---

# Phase 1 — Design System and App Shell

Goal: create the visual and navigation foundation.

Tasks:

- [ ] Analyze Stitch visual references
- [ ] Define colors
- [ ] Define typography
- [ ] Define spacing scale
- [ ] Define border radii
- [ ] Define shadows
- [ ] Define button styles
- [ ] Define card styles
- [ ] Define form styles
- [ ] Create reusable loading states
- [ ] Create reusable error states
- [ ] Create bottom navigation
- [ ] Create base app routing
- [ ] Create placeholder screens
- [ ] Add localization structure
- [ ] Add responsive layout rules

Initial navigation:

- Map
- Discover
- Scan
- Collection
- Profile

Exit criteria:

- Navigation works
- Visual identity resembles Stitch
- Reusable design components exist
- No duplicated styling

---

# Phase 2 — Supabase and Authentication

Goal: establish secure user accounts.

Tasks:

- [ ] Create Supabase project
- [ ] Configure local environment variables
- [ ] Integrate Supabase client
- [ ] Create profile table
- [ ] Configure Row Level Security
- [ ] Email registration
- [ ] Email login
- [ ] Email verification
- [ ] Password recovery
- [ ] Persistent login
- [ ] Logout
- [ ] Google login
- [ ] Apple login
- [ ] Authentication error states
- [ ] Authentication loading states
- [ ] Protected app routes

Exit criteria:

- User can register
- User can sign in
- Session persists
- User cannot access private app without authentication

---

# Phase 3 — Core Database

Goal: create the core beer catalog data model.

> **Scope note (2026-09-15, see `docs/DECISIONS.md`)**: `user_beer_logs`,
> `favorites`, and `wishlist` below are **deferred to Phase 6 (Logging a
> Beer) / Phase 7 (Personal Collection)** — they're user-owned entities that
> belong with the features that create them, not built speculatively ahead
> of those phases. Phase 3 delivered `users/profiles` (Phase 2),
> `countries`, `beer_styles`, `breweries`, `beers`, the protected backend
> foundation (config, JWT verification, DB access, repository/service
> layers), and — moved forward from Phase 4 as allowed foundational work —
> the six catalog read endpoints listed there.

Tables/entities:

- [x] users / profiles (Phase 2)
- [x] countries
- [x] beer_styles
- [x] breweries
- [x] beers
- [x] user_beer_logs — built in Phase 6, see that phase's entry
- [x] favorites — built in Phase 7 as part of `user_beer_collection`, see that phase's entry
- [x] wishlist — built in Phase 7 as part of `user_beer_collection`, see that phase's entry

Tasks:

- [x] Define database schema
- [x] Add constraints
- [x] Add indexes
- [x] Add foreign keys
- [x] Add migrations
- [x] Add seed data (run against the dev project and confirmed idempotent —
      see `docs/DECISIONS.md`)
- [x] Document entity relationships
- [x] Create backend repository layer
- [x] Create backend service layer
- [x] Create initial API schemas

Exit criteria:

- Database can represent the core product correctly
- No duplicate business logic exists in controllers/routes

---

# Phase 4 — Beer Catalog and Beer Detail

Goal: allow users to browse real catalog data.

> **Scope note (2026-09-15, see `docs/DECISIONS.md`)**: the API tasks below
> were already built in Phase 3 as part of proving the protected backend
> end-to-end (`GET /countries`, `/beer-styles`, `/breweries[/{id}]`,
> `/beers[/{id}]` — see `docs/API.md`). Phase 4 consumes and polishes them
> in the Flutter UI rather than rebuilding them.

Tasks:

- [x] Beer list API (built in Phase 3)
- [x] Pagination (built in Phase 3)
- [x] Beer detail API (built in Phase 3)
- [x] Brewery relation (built in Phase 3)
- [x] Style relation (built in Phase 3)
- [x] Country relation (built in Phase 3)
- [x] Beer cards
- [x] Beer detail screen
- [x] Loading states
- [x] Empty states
- [x] Error states
- [x] Beer imagery fallback

> **Scope note (2026-09-15, see `docs/DECISIONS.md`)**: `Favorite action` and
> `Wishlist action` are deferred to Phase 7 (`Personal Collection`), which
> already tracks the underlying `Favorites`/`Wishlist` tasks — there is no
> `favorites`/`wishlist` table or endpoint yet (Phase 3's scope note above).
> Phase 4 does not add favorites, wishlist, ratings, reviews, logging,
> achievements, the scanner, the map, recommendations, or social features.
> **Completion note (2026-09-16)**: the favorite/wishlist buttons landed in
> Phase 7, on Beer Detail's AppBar — see that phase's entry.

Exit criteria:

- User can browse beers
- User can open a beer
- Beer details are loaded from backend/database

> **Completion note (2026-09-15, see `docs/DECISIONS.md`)**: Phase 4 is
> complete, verified via a live run on the Android emulator against a local
> FastAPI backend and a real Supabase project — sign-in, the Discover tab
> loading all seeded beers through FastAPI (style/country resolved),
> opening a beer detail screen (brewery/style/country/ABV/IBU rendering,
> bottom nav hidden), back restoring the Discover list's prior state, and
> pull-to-refresh, all working with no raw backend error ever shown. This
> run also completes Phase 3's previously-pending live authenticated
> smoke test (Supabase Auth → JWT → FastAPI JWKS verification → Postgres →
> JSON → Flutter render, end-to-end).

---

# Phase 5 — Search and Discover

Goal: make catalog exploration easy.

> **Scope note (2026-09-15, see `docs/DECISIONS.md`)**: "Search history" is
> **deferred** for scope/UX reasons — a nice-to-have not required by this
> phase's exit criteria, not deferred for a technical/dependency reason
> (`shared_preferences`, the obvious storage for it, is already a direct
> mobile dependency). "Country browsing"/"Style browsing"/"Brewery browsing"
> are satisfied by the style/country/brewery filters below rather than
> separate curated Discover sections/shelves, which would risk exactly the
> section/recommendation-engine overbuild `PRODUCT.md` warns against this
> early.

Tasks:

- [x] Search endpoint (`GET /beers?q=`, see `docs/API.md`)
- [x] Search by beer name
- [x] Search by brewery
- [x] Search by country
- [x] Search by style
- [x] Search screen (Discover's search field, debounced)
- [ ] Search history — deferred, see scope note above
- [x] Filters (style/country/brewery, single-select per category, AND
      semantics, transactional filters bottom sheet)
- [ ] Discover sections — deferred, see scope note above
- [x] Country browsing — via country filter
- [x] Style browsing — via style filter
- [x] Brewery browsing — via brewery filter

Exit criteria:

- [x] User can reliably find a known beer
- [x] Discover presents useful catalog entry points

> **Completion note (2026-09-15, see `docs/DECISIONS.md`)**: Phase 5 is
> complete, verified via a live run on the Android emulator against a local
> FastAPI backend and a real Supabase dev database (all live requests
> returning 200) — the full 8-beer catalog loading initially; search by beer
> name, brewery, style, and country each returning correct matches; clearing
> search restoring the full catalog; a no-match search showing the
> zero-results state rather than an error; literal `%`/`_` searches matching
> only beers actually containing those characters, not the whole catalog;
> dismissing the Filters sheet without confirming leaving applied
> filters/results untouched; applying multiple filters via "Show results" in
> one reload; removing an active filter chip; "Clear all" + "Show results"
> restoring the unfiltered catalog; opening Beer Detail from
> searched/filtered results and pressing Back preserving query text, applied
> filters, the result list, and scroll position; and pull-to-refresh
> re-fetching with the currently active search/filter parameters rather than
> the unfiltered feed. This is in addition to the automated backend
> (`pytest`) and mobile (`flutter test`) suites — see `docs/DECISIONS.md` for
> the full automated/manual verification breakdown, including which opt-in
> suite remains unexercised in this environment.

---

# Phase 6 — Logging a Beer

Goal: complete the main user action.

Tasks:

- [x] Create beer log endpoint
- [x] Edit beer log
- [x] Delete beer log
- [x] Rating input
- [x] Optional review
- [x] Consumption date
- [x] Optional serving note
- [x] Price
- [x] Currency
- [x] Venue
- [ ] Optional location — deferred: no device-geolocation permission flow this phase; `venue_name` free text covers "where" for now. See `docs/DECISIONS.md`.
- [ ] Optional photo — deferred: no Supabase Storage wiring this phase. See `docs/DECISIONS.md`.
- [x] Quick-log flow
- [x] Detailed-log flow
- [x] Update collection state after logging — built in Phase 7: `BeerLogController` now pings `CollectionRefreshSignal` after every successful create/update/delete, and `CollectionController` listens and refreshes. See that phase's entry.

Also implemented, beyond the original task list, as a scoped product
exception (see `docs/DECISIONS.md`): an optional `serving_volume_ml` field,
purely for a future neutral "recorded volume" statistic — never a
consumption-tracking mechanic.

Exit criteria:

- [x] User can log a beer in a few taps — confirmed on a real device (Android emulator) against the real local FastAPI backend and the real `beerapp-dev` Supabase project.
- [x] A beer may have multiple user logs — verified both by automated tests (no `unique(user_id, beer_id)`, `POST` never upserts) and live: the same beer logged twice produced two independent entries, and deleting one did not affect the other.
- [x] Personal data persists correctly — confirmed live: a created log persists after leaving and reopening Beer Detail, detailed fields (review/serving note/price/currency/venue) persist, a partial edit preserves untouched fields, and `serving_volume_ml` can be both set and explicitly cleared.

**Completion note (2026-09-15)**: automated suites pass — the default
backend suite (`pytest`, excludes `@pytest.mark.integration`) and the
default Flutter suite (`flutter test`) both pass in full, 89 backend tests
and 166 Flutter tests, `flutter analyze` and `dart format` clean. The two
Phase 6 migrations (`20260915120600_create_user_beer_logs_table.sql`,
`20260915120700_grant_beerapp_backend_user_beer_logs.sql`) were applied to
`beerapp-dev` via `supabase db push`, confirmed by `supabase migration list`
(both `local`/`remote` match) and a clean `supabase db lint --linked`.

**Live Android smoke test — passed**, against the real local FastAPI
backend and the real `beerapp-dev` Supabase project: empty state; creating
a log; persistence across leaving/reopening Beer Detail; a beer logged
multiple times as independent entries; detailed fields persisting; a
partial edit preserving untouched fields; `serving_volume_ml` set and
explicitly cleared; deleting one log leaving others untouched; pagination/
"Load more"; a second test account unable to see the first account's logs
(RLS isolation confirmed live, not just in the automated RLS test); no raw
backend error text/stack traces; no unexpected 500s.

**Still not run**: `backend/tests/integration/` (including
`test_user_beer_logs_rls.py`) — `INTEGRATION_DATABASE_URL` is not
configured in this environment, so those tests skip rather than run. This
does not block the exit criteria above (the live smoke test independently
confirmed the same RLS isolation property against real infrastructure), but
the integration suite should still be run against a disposable database
before relying on it as an ongoing regression guard.

---

# Phase 7 — Personal Collection

Goal: turn logging into a visible collection.

Tasks:

- [x] Collection screen — one screen, Logged/Favorites/Wishlist tabs (`CollectionScreen`)
- [x] Unique beers tried — `GET /collection/logged`, derived from `user_beer_logs` via `DISTINCT ON (beer_id)`, never a stored/duplicated count
- [x] Recent beers — the default `sort=recent` on every tab (most-recently-active-first), no separate section needed
- [x] Favorites — `is_favorite` on the new `user_beer_collection` table; Beer Detail AppBar button + the Favorites tab
- [x] Wishlist — `is_wishlist` on the same table; Beer Detail AppBar button + the Wishlist tab
- [x] Filter by country
- [x] Filter by style
- [x] Filter by brewery
- [x] Sort by rating — the beer's *latest* log's rating, never an average (see `docs/DECISIONS.md`)
- [x] Sort by date — `sort=recent`
- [x] Sort by name — case-insensitive
- [x] Collection empty states — distinct message per tab

Note: Collection's current UI is functional, using existing design-system
components (`AppCard`, `AppFilterChip`, shared loading/empty/error states) —
a dedicated visual/UI polish pass (spacing, iconography, empty-state
illustration, etc.) is intentionally deferred to a later design pass, not
part of this phase's exit criteria.

Exit criteria:

- [x] Collection accurately reflects user logs — verified both by automated tests (`test_collection_queries.py`'s unique-beers-tried/multiple-logs cases) and the live Android smoke test below (a beer logged, including a second independent log for the same beer, appeared exactly once under Logged with no manual refresh).
- [x] Wishlist and favorites work independently — verified both by automated tests (service, route, and concurrency-scenario tests all assert one flag never disturbs the other) and the live smoke test below (favorite/wishlist set and cleared independently from Beer Detail, state persisted across navigation and relaunch, correctly isolated per user account).

**Status (2026-09-16)**: complete. Default backend suite (`pytest`,
excludes `@pytest.mark.integration`) and default Flutter suite
(`flutter test`) both pass in full — 120 backend tests (186 total including
the 66 opt-in `@pytest.mark.integration` tests, still not run — no
`INTEGRATION_DATABASE_URL` configured in this environment, see below), 208
Flutter tests, `flutter analyze`/`dart format` and `ruff check`/`ruff format`
clean. The two migrations
(`20260915220833_create_user_beer_collection_table.sql`,
`20260915220843_grant_beerapp_backend_user_beer_collection.sql`) were
applied to `beerapp-dev` via `supabase db push`, confirmed by
`supabase migration list` (all local/remote entries matching) and a clean
`supabase db lint --linked`.

**Live Android smoke test — passed**, against the real local FastAPI
backend and the real `beerapp-dev` Supabase project, reported by the tester
as passing the full circulated checklist: Collection initial state (all
three tabs, no raw backend errors); logging → Collection freshness,
including a beer logged twice still appearing once under Logged; favorite/
wishlist independence from Beer Detail; persistence across navigation and
relaunch; sort by recent/rating/name; country/style/brewery filters
(apply/clear/dismiss-without-applying); pagination if the dev account had
enough rows to exercise it; a second test account's isolation from the
first account's logs and favorite/wishlist state; and no raw backend/SQL
errors, stack traces, or identifiers surfaced in the UI.

**Still not run**: `backend/tests/integration/` (including the new
`test_user_beer_collection_rls.py`/`test_collection_queries.py`/
`test_collection_concurrency.py`) — `INTEGRATION_DATABASE_URL` is not
configured in this environment, so those tests skip rather than run. This
does not block the exit criteria above (the live smoke test independently
confirmed the same isolation/independence properties against real
infrastructure), but the integration suite should still be run against a
disposable database before relying on it as an ongoing regression guard.

---

# Phase 8 — World Map

Goal: implement BeerApp's flagship experience.

Tasks:

- [x] Add MapLibre — `maplibre_gl` (Flutter binding for MapLibre Native)
- [x] Base map style — MapTiler hosted style, loaded via `MapConfig` (client-visible, quota-limited key; see `docs/DECISIONS.md`)
- [x] Beer origin markers — `GET /map/beers`, coordinate falls back to the brewery's pair when the beer has none of its own (never a mixed pair — see `MapRepository`)
- [x] Brewery markers — `GET /map/breweries`
- [x] Marker clustering — client-side only, `maplibre_gl`'s built-in GeoJSON-source clustering
- [x] Country-level exploration — search bar resolves an exact country-name match to `country_id`, camera fits the result
- [x] Region-level exploration — same search bar, free-text `q` when it isn't an exact country match
- [x] Tried / not-tried filters — part of the single-select map mode (`MapMode`)
- [x] Favorite filter — same
- [x] Wishlist filter — same
- [x] Beer preview card — `BeerPreviewCard`, self-sufficient DTO, no follow-up request until "View details"
- [x] Brewery preview card — `BreweryPreviewCard`; no brewery-detail screen exists or was added
- [x] Smooth camera transitions — `animateCamera`, with a fixed-zoom fallback for degenerate (single-point) search results
- [x] Loading states — `LoadingState`/`ErrorState`/`EmptyState`, plus a distinct non-blocking truncation notice and a distinct "map unavailable" configuration state
- [x] Location permission handling if needed — **not needed**: no device GPS/current-location anywhere in this phase, per `PRODUCT.md` §8 and the hedged ROADMAP wording

Exit criteria:

- [x] User can explore beer geographically — implemented, covered by automated tests, and live-verified on a real Android emulator (see Status below)
- [x] Map performance remains acceptable with many points — a server-side safety cap (`CappedList`, surfaced to the client as `truncated`) exists as a Phase 8 backstop; real viewport/bounding-box scale work was deferred to Phase 14, which measured it and did **not** build it (see Phase 14: the map is capped at 2,000 rows and stays a watch item)

**Status (2026-09-16)**: complete. Backend (`pytest`, excluding
`@pytest.mark.integration`) and Flutter (`flutter test`) suites both pass in
full, `flutter analyze`/`dart format` and `ruff check`/`ruff format` clean.

**Live Android smoke test — passed**, against the real local FastAPI backend
and a real MapTiler-configured build, against the full circulated checklist:

- Base map (real tiles, no config/provider error, no location permission prompt) — pass
- All six map modes (All beers/Tried/Not tried/Favorites/Wishlist/Breweries), each cleanly replacing the previous marker set with no duplicate layers — pass
- Clustering, including repeated tap-to-expand with no duplicate markers — pass
- Beer marker → preview card → Beer Detail → back, state/camera preserved — pass
- Brewery marker → preview card, no dead/invented navigation offered — pass
- Search/camera: exact-country search, free-text region search, identical-coordinate handling, single-point fixed zoom, stale-result protection, and clear-search behavior — all pass
- Personal-state freshness: Favorites and Wishlist both confirmed to refresh via the existing `CollectionRefreshSignal` with no app restart or manual refresh. Tried/Not-tried live mutation freshness was **intentionally not exercised** — verifying it would have meant creating or modifying consumption-log data solely for testing, which this project's responsible-product rules avoid; the refresh mechanism itself is identical to and already proven by the Favorites/Wishlist checks above, plus the automated `MapController` staleness/signal tests. Not treated as a gap.
- Error/privacy sanity (no raw backend/SQL/provider errors, no stack traces, no internal ids, no auth token or MapTiler key in any log, no location permission request) — pass
- Stability (repeated tab/mode cycling, preview cards, Beer Detail round-trips, background/resume) — pass, no crashes, no duplicate sources/layers

Two real bugs were found and fixed during this live verification, both now
covered by regression tests — see `docs/DECISIONS.md`'s two 2026-09-16
"live Android verification found..." entries for the technical detail:
a cluster-tap layer-mapping bug (a tap resolving to the cluster's
count-label layer, not its circle, sent the camera to an invalid zoom
instead of expanding), and a search camera-fit stale-data race (a
loading-start notification could consume the camera-fit signature against
stale pre-search markers, silently skipping the correct fit once the real
result arrived).

**Still not run**: `backend/tests/integration/` (including the new
`test_map_queries.py`, covering RLS isolation between two users, the
paired coordinate fallback, per-`state` filtering, and the truncation cap)
— no dedicated disposable `INTEGRATION_DATABASE_URL` is configured in this
environment, so those tests skip rather than run, same caveat as Phase 7.
This does not block the exit criteria above (the live smoke test
independently exercised the RLS-scoped personal-state paths against the
real `beerapp-dev` project), but the integration suite should still be run
against a disposable database before relying on it as an ongoing regression
guard.

---

# Phase 9 — Statistics

Goal: summarize personal beer activity.

Tasks:

- [x] Total unique beers
- [x] Total logs
- [x] Countries discovered
- [x] Styles discovered
- [x] Breweries discovered
- [x] Average rating
- [x] Amount spent
- [x] Monthly activity
- [x] Yearly activity
- [x] Favorite style
- [x] Favorite country
- [x] Favorite brewery
- [x] Statistics UI
- [x] Basic charts

Exit criteria:

- [x] Statistics match underlying log data — live-verified on a real Android emulator against the real local FastAPI backend and existing account data (see Status below)
- [x] Calculations are tested — backend schema/service/route tests and Flutter controller/screen/widget tests pass in full; backend integration tests (`backend/tests/integration/test_statistics_queries.py`, `test_statistics_rls.py`) are written, covering RLS isolation, the trailing-12-months boundary, UTC bucketing, the country fallback, and deterministic favorite tie-breaks, but are **not executed** in this environment (see Status below)

**Status (2026-09-17)**: complete. Backend (`pytest`, excluding
`@pytest.mark.integration`) and Flutter (`flutter test`) suites both pass in
full, `flutter analyze`/`dart format` and `ruff check`/`ruff format` clean.

**Live Android smoke test — passed**, against the real local FastAPI backend
and existing account data only (no fabricated logs/favorites/pricing):

- Navigation: Profile → Statistics entry card, full-screen route, bottom nav hidden, Back returns cleanly — pass
- Overview: unique beers / total logs consistent with existing account data, country/style/brewery counts plausible and cross-checked against Collection, average rating consistent with existing rated logs — pass
- Amount spent: empty/no-priced-data display correct — pass; multi-currency live display — **not exercised** (the existing account has no priced logs, let alone multi-currency ones; no fabricated price/currency data was created to force this)
- Favorites: favorite style/country/brewery match existing Collection favorites exactly — pass
- Charts: monthly chart (12 buckets, zero-log months represented) and yearly chart (only years with data) both render correctly, no clipping/crash — pass. A live-found bug (hardcoded English month labels not respecting the app locale) was fixed before closing this phase — see `docs/DECISIONS.md`.
- Refresh: `CollectionRefreshSignal`-driven refresh verified via an existing Favorite toggle through the normal UI, no fabricated log activity — pass. The log-derived refresh path specifically was **not separately exercised** (it shares the same signal/call site proven by the favorite-toggle check and by `StatisticsController`'s automated tests).
- Error/retry: first-load backend failure showed the correct localized `ErrorState`, Retry recovered once the backend was back — pass
- Localization/privacy: Spanish UI verified end-to-end, including the fixed month labels; no raw backend/SQL errors, no stack traces, no internal ids, no auth token or MapTiler key exposed, no location permission introduced — pass
- Stability: repeated Profile → Statistics → Back, tab switching, pull-to-refresh, background/resume — pass, no crashes, no refresh loop, no stuck loading state

**Still not run**: `backend/tests/integration/test_statistics_queries.py`
and `test_statistics_rls.py` — no dedicated disposable
`INTEGRATION_DATABASE_URL` is configured in this environment, so those
tests skip rather than run, same caveat as Phases 6-8. This does not block
the exit criteria above (the live smoke test independently exercised the
RLS-scoped, per-user statistics paths against the real `beerapp-dev`
project), but the integration suite should still be run against a
disposable database before relying on it as an ongoing regression guard —
in particular, it is the only place the multi-currency amount-spent
grouping is actually proven, since live verification could not exercise it
with real account data.

---

# Phase 10 — Achievements

Goal: add progression and motivation.

Tasks:

- [x] Achievement data model
- [x] Achievement definitions
- [x] Progress values
- [x] Locked state
- [x] Unlocked state
- [x] Unlock timestamp
- [x] Achievement evaluation service
- [x] Achievement screen
- [x] Achievement notifications
- [x] Categories
- [x] Progress bars

Potential categories:

- Beers tried
- Countries
- Regions
- Styles
- Breweries
- Reviews
- Ratings
- Collection
- Special milestones

Only Collection and Special have Phase 10 starter catalog entries
(`collection_first_favorite`, `collection_first_wishlist`,
`collection_curator`) — see `docs/DECISIONS.md` for why the
consumption-count-based categories (Beers tried, Countries, Styles,
Breweries, Reviews, Ratings) and Regions were deferred rather than
populated now. The architecture (backend catalog, `AchievementCategory`
enum, category-grouped screen) already supports all of them.

Exit criteria:

- [x] Achievements are data-driven — catalog lives entirely in
  `backend/app/services/achievement_catalog.py`, not a database table
- [x] Adding a new achievement does not require major application changes —
  one catalog entry plus one localized name/description ARB pair per locale

**Status (2026-09-17)**: complete. Backend (`pytest`, excluding
`@pytest.mark.integration`, 172 passed) and Flutter (`flutter test`, 281
passed) suites both pass in full, `flutter analyze`/`dart format` and
`ruff check`/`ruff format` clean.

**Live-verified against `beerapp-dev`:**

- Both Phase 10 migrations applied successfully (`supabase db push`);
  `supabase migration list` confirms both now applied remotely
- `supabase db lint --linked --level error` passed, before and after the push
- `supabase db push --dry-run` contained exactly the two expected Phase 10
  migrations, nothing else
- `user_achievements` grants verified read-only as `SELECT, INSERT` only for
  `beerapp_backend` — no `UPDATE`/`DELETE`
- `backend_select_own` (SELECT, `USING`) and `backend_insert_own` (INSERT,
  `WITH CHECK`) RLS policies verified present, and no `UPDATE`/`DELETE`
  policy exists
- `GET /health` → 200
- Authenticated `GET /achievements` → 200, returning exactly the three
  starter-catalog keys
- Existing account Collection state (a real prior favorite and wishlist
  entry, never fabricated) was correctly evaluated/backfilled on first call
- Starter catalog rendered correctly (First Favorite, First Wishlist Add,
  Curator), with only the Collection and Special sections shown — no empty
  category headings for Beers Tried/Countries/Styles/Breweries/Reviews/Ratings
- First-load notification baseline correct: no spurious "unlocked" banner
  despite pre-existing unlocks
- Progress/permanence display correct: locked/unlocked bars and Curator's
  prerequisite-count progress all matched expectations
- English UI verified live, no clipping/overflow
- Error/retry verified: stopping the backend produced the correct localized
  network-error state; restarting the backend and retrying recovered fully
- Privacy/error sanitization verified: no raw backend/SQL/JWT/secret data
  was ever shown
- Navigation, repeated Profile↔Achievements cycling, tab switching, and
  background/resume all verified stable — no crash, no request loop, no
  stuck loading state

**Transparent limitations:**

A. **Spanish localization: NOT LIVE-VERIFIED.** Attempting to switch the
emulator's system locale triggered a `system_server`/emulator ANR (RAM
pressure on the test machine, not a BeerApp exception) — the emulator
recovered on its own. Covered instead by: the Spanish ARB strings existing,
`flutter gen-l10n` succeeding, the Flutter localization test suite passing,
and the full Flutter suite (281/281) passing — no source-level missing
achievement localization was found. This is automated/source-verified
coverage, not a live pass, and is not reported as one.

B. **Mutation-driven achievement unlock: NOT EXERCISED live.** No new
Favorite/Wishlist mutation was performed during verification. What *was*
verified live is the idempotent `GET /achievements` backfill path evaluating
pre-existing Collection state and persisting/rendering all three eligible
achievements correctly. The synchronous Collection-mutation transaction path
itself remains covered by `backend/tests/services/test_collection_service.py`
(unit) and `backend/tests/integration/test_collection_achievement_atomicity.py`
(written, not executed — see C).

C. **Real PostgreSQL integration suite: NOT RUN.** No dedicated disposable
`INTEGRATION_DATABASE_URL` is configured in this environment, same caveat as
Phases 6-9. `backend/tests/integration/test_user_achievements_rls.py` and
`test_collection_achievement_atomicity.py` exist and cover cross-user RLS
denial and real-Postgres transactional rollback/atomicity respectively, but
were not executed — this is not claimed as a pass.

---

# Phase 11 — Scanner

Goal: reduce friction when identifying a beer.

First milestone:

- [x] Camera permission
- [x] Barcode scanner
- [x] Barcode lookup
- [x] Matching result
- [x] No-result fallback
- [x] Manual search fallback

Later (deferred, not in scope for this milestone):

- [ ] Label image recognition
- [ ] Suggested matches
- [ ] Confidence score
- [ ] User confirmation

Exit criteria:

- [x] Common supported barcodes can open a matching beer — proven end-to-end
  for EAN-13/EAN-8/UPC-A via backend canonicalization tests and a live
  granted-permission scan of a seeded barcode's catalog lookup; actual
  physical-camera decode of a real printed barcode is NOT EXERCISED (see
  status note below) — this project's emulator has no way to present a
  genuinely scannable barcode image to the camera pipeline.

**Status (2026-09-18)**: complete, with one explicit gap. Backend (`pytest`,
excluding `@pytest.mark.integration`, 200 passed) and Flutter (`flutter
test`, 299 passed) suites both pass in full; `flutter analyze`/`dart format`
and `ruff check`/`ruff format` clean.

**IMPLEMENTED / AUTOMATED VERIFIED** (backend + widget/controller tests, not
live device behavior):

- Barcode canonicalization: EAN-13/EAN-8 accepted as-is, UPC-A zero-prefixed
  to its canonical GTIN-13, GS1 check-digit validated, UPC-E deferred —
  `backend/tests/services/test_barcode_canonicalization.py`
- `GET /beers/barcode/{barcode}`: 200 with canonical `BeerOut` (including a
  12-digit UPC-A request resolving to the identical beer as its 13-digit
  canonical form), 404 for a well-shaped unknown barcode, 422 for
  non-digit/wrong-length/bad-checksum input, 401 unauthenticated —
  `backend/tests/routes/test_catalog_routes.py`
- Repository lookup (found / unknown / null-barcode-never-matches) — written
  against `backend/tests/integration/test_beer_search.py`'s pattern in
  `backend/tests/integration/test_beer_barcode_lookup.py` (opt-in,
  `INTEGRATION_DATABASE_URL`-gated — see the gap note below)
- Seed barcodes are checksum-verified programmatically, not merely
  plausible-looking (this caught and fixed an actually-invalid seed value —
  see `docs/DECISIONS.md`)
- Scanner state machine: successful lookup → `found`; unknown barcode →
  `notFound`, never `error`; a second detection while resolving triggers
  exactly one lookup; a duplicate of an already-shown `notFound` code is
  debounced; a detection arriving while a navigation is already in progress
  is ignored (at most one `BeerDetail` push per decoded barcode); a
  post-dispose barcode event is silently ignored (no notify, no throw) —
  `mobile/test/features/scan/presentation/scan_controller_test.dart`
- Scan screen renders the correct not-found/error UI and actions, and a
  found result triggers exactly one navigation push even under duplicate
  detections — `mobile/test/features/scan/presentation/scan_screen_test.dart`
- `context.go(AppRoutes.discover)` (the "Search manually" destination)
  genuinely reuses the existing Discover branch (same widget instance, no
  reload) rather than this being assumed —
  `mobile/test/app/router_test.dart`

**LIVE EMULATOR VERIFIED** (Android emulator, `beerapp-dev` backend running
locally, real signed-in session):

- Camera permission prompt appears only on first entering the Scan tab, never
  at app startup
- Denying permission shows the correct denied-state message with "Try camera
  again" and "Search manually" actions; re-entering the Scan tab after
  denial shows the same state without an unwanted re-prompt
- After two denials, Android silently stops re-prompting (no dialog on a
  further "Try camera again") — the app correctly stays on the denied state
  without crashing or looping; this live finding is what prompted adding
  explicit "enable it in system settings" guidance to the denied-state copy
- "Search manually" from the denied state navigates to the real Discover
  screen
- Granting permission ("While using the app") reaches the live
  `MobileScanner` camera viewfinder with no error and no black screen
- Camera lifecycle verified via `adb logcat`, not just visually: switching
  away from the Scan tab stops the camera (`CameraService: Stop camera
  streaming`); switching back reopens it cleanly (`Camera open completed`,
  no `controllerNotAttached`/`controllerAlreadyInitialized` errors);
  backgrounding the app (home button) stops the camera; foregrounding it
  restarts the camera cleanly — repeated with no crash

**NOT EXERCISED:**

- Actual decoding of a real physical/printed barcode by the on-device camera
  pipeline. The emulator's virtual camera scene renders a live feed (a
  virtual room) but has no mechanism used here to present a genuinely
  scannable EAN/UPC barcode image, so the found/not-found *decode* path
  itself was only exercised through automated tests (a synthetic barcode
  stream, not the real `MobileScannerController`), never a live scan of a
  real code. Per instruction, no debug-only "pretend this barcode was
  scanned" bypass was added to production code to work around this.
- iOS device/simulator behavior — this environment's live verification is
  Android-emulator-only.

**Real PostgreSQL integration suite: NOT RUN in the default test command.**
`INTEGRATION_DATABASE_URL` is not configured in this environment, same
caveat as every earlier phase; `backend/tests/integration/test_beer_barcode_lookup.py`
exists and was written against the same pattern as the already-established
`test_beer_search.py`, but has not been executed against a disposable
database — not claimed as a pass. The seed/catalog write itself (via
`SEED_DATABASE_URL`/`beerapp_seed`) **was** run live in this session and
succeeded (`backend/scripts/seed_catalog.py`), so the corrected/new barcode
fixtures used in live verification above are real rows in `beerapp-dev`, not
a simulated state.

---

# Phase 12 — Profile and Settings

Goal: complete the user's personal area.

Tasks:

- [ ] Avatar — deferred entirely this phase (no column, no UI, no Storage bucket, no image picker/camera permissions). See `docs/DECISIONS.md`.
- [x] Display name — new `ProfileRepository.updateEditableProfile`, editable from `EditProfileScreen`
- [x] Username — editable from `EditProfileScreen`, reusing the existing validation/uniqueness rules; onboarding's `setUsername` untouched
- [x] Preferred currency — new nullable `profiles.preferred_currency` column, Settings picker, prefills (never overwrites) a new beer log's currency field
- [ ] Preferred units — deferred entirely this phase (no column, no picker, no conversion layer — nothing today displays `serving_volume_ml` with any unit formatting to plug a preference into). See `docs/DECISIONS.md`.
- [x] Language — local, device-only override (`mobile/lib/core/locale/`), EN/ES/system, not a `profiles` column
- [x] Account settings — Settings screen: currency, language, change password (reuses the existing reset-email flow)
- [x] Privacy settings placeholder — dedicated "Privacy settings" row in Settings, routes to the existing placeholder screen (localized EN/ES); no toggles, backend fields, tracking, or permissions — the smallest correct implementation of this specific task
- [x] Logout — pre-existing, unchanged; still reachable from `ProfileScreen`
- [x] Delete account flow — new `DELETE /account` (FastAPI, Supabase Auth Admin API), typed-username confirmation dialog, cascades via existing `ON DELETE CASCADE` FKs
- [x] Legal links — Privacy Policy / Terms of Service rows, static in-app placeholder only (no real content yet). See `docs/DECISIONS.md`.

Exit criteria:

- [x] User can manage account essentials — display name, username, preferred currency, language, and account deletion are all editable from Profile → Edit Profile / Settings; avatar and preferred units are the two explicitly deferred exceptions (see `docs/DECISIONS.md`)

**Status (2026-09-18)**: implementation complete, automated-test-verified.
See this phase's entries in `docs/DECISIONS.md` for the material
architecture decisions (direct-Supabase vs. FastAPI split, the current
Supabase secret-key model, the atomic profile-edit write, the verified
post-delete sign-out sequencing, and the two explicit deferrals).

Backend (`pytest`, excludes `@pytest.mark.integration`, 214 passed) and
Flutter (`flutter test`, 335 passed) suites both pass in full,
`flutter analyze`/`dart format` and `ruff check`/`ruff format` clean (for
every file touched this phase — three pre-existing files elsewhere already
had unrelated formatting drift before this phase and were left untouched).
The migration (`20260918120000_add_profiles_preferred_currency.sql`) was
applied to `beerapp-dev` via `supabase db push`, confirmed by a clean
`supabase db lint --linked --level error`.

**Live emulator verification: NOT EXERCISED**, for two independent,
transparent reasons, not skipped silently:

1. No sign-in credentials or email-inbox access were available in this
   session to reach an authenticated screen — BeerApp requires email
   verification on sign-up (`PRODUCT.md` §6), so a throwaway account
   couldn't be completed either. Covered instead by the automated Flutter
   widget/controller tests (`edit_profile_screen_test.dart`,
   `settings_screen_test.dart`, `log_form_sheet_test.dart`,
   `router_test.dart`'s new-route reachability cases).
2. `DELETE /account`'s real Supabase Auth Admin API call was not exercised
   against a live account: `SUPABASE_SECRET_KEY` is deliberately left
   unconfigured in `.env` (never filled in by the assistant — see
   `docs/DECISIONS.md`), so a live attempt today would only re-confirm the
   already-covered `503` "not configured" path, not real deletion. The
   Admin API request shape itself (`apikey` header, 404-as-success,
   non-2xx handling) is verified by
   `backend/tests/services/test_supabase_admin_client.py` against a mocked
   transport, not a live call.

Per explicit product instruction, no beer log, favorite, wishlist, or
achievement activity was created, edited, or fabricated at any point during
this phase's verification — the preferred-currency log-form-prefill
behavior and the delete-account cascade are both verified through
automated tests only, never through live consumption-adjacent data.
Live verification (both items above) remains an open follow-up whenever
credentials/a configured secret key are available — not required to
consider this phase's implementation done, since ROADMAP.md's own
convention (see Phases 6-11) already treats "automated suite passes, live
pass deferred for a stated reason" as a legitimate, reportable state.

---

# Phase 13 — Beer Contributions

Goal: allow catalog growth.

Tasks:

- [x] Missing beer submission — `POST /beer-contributions`, Profile → Contributions → "Suggest a beer", plus "Suggest this beer" from a Discover search with no results and from a scan whose barcode isn't found (prefilled). Optional barcode reuses the Phase 11 canonicalizer. A missing brewery/style is entered as free text ("Not listed") — no separate brewery submission required
- [x] Brewery submission — `POST /brewery-contributions`, an independent form (country from the catalog or "Not listed" free text)
- [x] Duplicate candidate detection — deterministic, read-only `GET .../duplicate-candidates` before submit. Hard blocks (`409`): a catalog beer already owns the barcode; the user's own identical pending suggestion. Non-blocking warnings: similar catalog beers/breweries, and another user's pending suggestion carrying the same barcode (a boolean only — no row, id or identity)
- [x] Unverified state — a suggestion is stored `pending` and is described as "Suggestion received / Pending review", never "added"; it never becomes a catalog row
- [x] Submission history — `GET /contributions` (the caller's own, both kinds, newest first), shown in Profile → Contributions
- [x] Moderation-ready data model — the `pending/approved/rejected` lifecycle, review columns and `resolved_*` links exist in the schema, tied together by CHECKs; **only `pending` is reachable**. The approve/reject workflow itself is **not built** (see below)

Exit criteria:

- [x] User contributions cannot overwrite verified catalog data directly — no code path in this phase writes `beers`/`breweries`/`beer_styles`/`countries`; `beerapp_backend` remains `SELECT`-only on them and `authenticated`/`anon` have no access to the new tables at all. Proven at the privilege level and end to end (a submission that mirrors a verified beer leaves that beer's name, brewery, ABV, `verified`, `source` and `updated_at` unchanged)

Explicitly **not** in this phase (ROADMAP does not list them; see `docs/DECISIONS.md`):
edits/corrections to existing beers; **approval/rejection and any admin tooling —
a blocker, not an oversight: there is no admin/moderator identity, and no
"approve" endpoint was invented**; editing, withdrawing or a detail view of a
submission; images/storage; rate limiting and trust scoring (Phase 14);
fuzzy/accent-insensitive matching.

**Status (2026-09-18)**: implementation complete and automated-test-verified;
the four migrations are **applied to `beerapp-dev`** and verified (below);
**live emulator verification NOT EXERCISED** — see below.

What was verified, and how:

- Backend default suite (`pytest`, excludes `@pytest.mark.integration`): **336
  passed** (up from 214). `ruff check` clean; `ruff format` clean for every file
  touched (three pre-existing files — `app/repositories/achievements.py`,
  `tests/auth/test_verifier.py`, `tests/integration/test_user_achievements_rls.py`
  — still carry unrelated formatting drift and were left untouched).
- Flutter (`flutter test`): **476 passed** (up from 335); no existing test's
  assertions were changed (existing test files only gained the new
  `contributionRepository` argument and additional cases). `dart format` clean
  for everything touched. `flutter analyze` (Flutter 3.47.4): no issues in any
  file this phase touched; 4 `info`-level `curly_braces_in_flow_control_structures`
  lints are reported in four pre-existing `*_error_text.dart` files this phase
  did not touch, left as they are.
- **The four migrations and 81 new integration tests were run against a real
  Postgres 16** (embedded, installed outside the repo; a minimal
  `auth.users`/`anon`/`authenticated` scaffold; every repo migration applied in
  order) — constraints, unique indexes, RLS, forged `user_id`/`status`, the
  absence of `UPDATE`/`DELETE`, the boolean-only cross-user function and its
  privileges, an actual `auth.users` delete cascading to both tables, and the
  real service running as `beerapp_backend`. **All 81 pass.** This is *not* a
  Supabase project: Supabase's own `auth` schema, PostgREST and role defaults
  were not exercised.
- **Pre-existing finding:** the same run showed **79 of the 111 older
  integration tests fail** (test-side defects; the suite had never been run
  against a real database before). Not touched here. **Resolved in Phase 14**:
  the suite was repaired (test-side defects only) and all 269 integration tests now
  pass on the PostgreSQL scaffold - see `docs/DATABASE.md` ("Testing") and
  `docs/DECISIONS.md`.
- **Migrations applied to `beerapp-dev`** (created with `supabase migration new`,
  timestamps `20260918155136`–`20260918155150`, all after the previous latest),
  with explicit go-ahead. `supabase db push --dry-run` first listed exactly those
  four and nothing else; `supabase db push` then applied them;
  `supabase db lint --linked --level error` reported no schema errors (schemas
  `extensions`, `private`, `public`); `supabase migration list` shows all 18
  local migrations recorded remotely. A read-only check as the `beerapp_backend`
  role then confirmed: both tables exist with RLS on and exactly the
  `backend_select_own`/`backend_insert_own` policies (owner-only, insert pinned
  to `pending`, targeting only `beerapp_backend`); `beerapp_backend` holds
  exactly `SELECT`+`INSERT` (no `UPDATE`/`DELETE`); `anon`, `authenticated` and
  `beerapp_seed` hold nothing; `user_id` FKs are `ON DELETE CASCADE`; the
  `private.other_user_pending_beer_barcode_exists(text)` function is
  `SECURITY DEFINER`, returns `boolean`, has `search_path=""`, and `EXECUTE` is
  held only by `beerapp_backend` and the owner (not `PUBLIC`/`anon`/
  `authenticated`/`beerapp_seed`); `USAGE` on schema `private` is granted to
  `beerapp_backend` only. Compared with a snapshot taken just before the push,
  the four catalog tables' row counts and per-row hashes are unchanged and the
  privileges on all 8 pre-existing tables (4 roles × 7 privileges) are
  unchanged. Both new tables are empty — no contribution rows were created to
  verify anything.
- **Live Android emulator verification: NOT EXERCISED.** It needs sign-in
  credentials (BeerApp requires email verification, `PRODUCT.md` §6) — still
  unavailable — and every live submission would leave pending rows in the shared
  dev database (the migrations themselves are now applied). Covered instead by the widget/controller tests
  (`suggest_beer_screen_test.dart`, `suggest_brewery_screen_test.dart`,
  `contributions_screen_test.dart`, the Discover/Scan/Profile entry-point tests,
  `router_test.dart`). No log, favorite, wishlist or achievement was created at
  any point.

Known limitations (documented, not silent): approval does not exist, so every
suggestion stays pending and the catalog is unchanged; the brewery picker is the
bounded Phase 5 loader (≤ 500 breweries; `GET /breweries` has no `q`); matching
is ASCII/case-insensitive only; cross-user name duplicates are not surfaced.

---

# Phase 14 — Quality and Production Hardening

Goal: prepare for real users.

Status wording used below - **only DONE items are checked**: DONE = satisfied and
evidenced; PARTIAL = part done, the rest stated; BLOCKED = needs something only the
owner can supply; DEFERRED = deliberately postponed; NOT EXERCISED = could not be
run here. Full write-ups are in `docs/DECISIONS.md` (dated 2026-09-21).

Tasks:

- [x] Improve test coverage — DONE. Backend default suite 336 -> 592, Flutter 476 -> 736, integration suite 269; new tests cover the hardening surfaces. No coverage *percentage* was measured.
- [x] Integration tests — DONE on a PostgreSQL scaffold: the complete suite (269) passes with all 19 migrations, including a table x role x privilege security audit; no test touches `beerapp-dev`. **This is not full local Supabase verification** (Docker was unavailable; the preferred stack was not run). See `docs/DATABASE.md`.
- [ ] End-to-end critical flows — **NOT EXERCISED.** No live authenticated flow was run (it needs a disposable account with inbox access). Covered only by controller, widget and service-level tests.
- [ ] Performance profiling — **PARTIAL.** Backend profiled at 2k / 10k / 50k catalog rows on a disposable database (`EXPLAIN (ANALYZE, BUFFERS)`). Flutter profile-mode measurement **NOT EXERCISED**: no Android emulator or device was available.
- [x] Image optimization — DONE. One shared `BeerImage` decodes at display size, with a stable placeholder and the existing fallback; verified by unit/widget tests (device memory saving not measured). URLs and storage untouched.
- [x] Map performance — DONE for redundant work: platform calls in a scripted session 80 -> 19 (`MapDataSynchronizer`). The bounding-box endpoint the Phase 8 note deferred here was **not built** - the map is capped at 2,000 rows (about 43 ms at 50k in the profile) - and stays a watch item. Real-device rendering NOT EXERCISED.
- [ ] API rate limiting — **PARTIAL / DEFERRED.** Implemented: request-body limit (413), bounded inputs, pagination bounds, database/network timeouts. **Not implemented:** requests-per-minute / per-user / edge rate limiting, which is a deployment-layer prerequisite once hosting is chosen. The bounds are not "full rate limiting"; no `429` exists. Trust scoring (from Phase 13) not implemented. There is deliberately **no per-user cap on pending contributions** (payload bounds, ownership controls, duplicate protections and DB constraints apply); a known operational consideration to revisit only if beta/production evidence shows real abuse.
- [x] Error logging — DONE. Backend: standard-library request/error logging with request ids, no query strings, bodies, tokens or secrets. Mobile: global error handlers with debug-only diagnostics. No log aggregation or retention is configured (deployment).
- [ ] Crash reporting — **PARTIAL.** Local/global Flutter error handling, guarded startup and a localized failure screen are implemented; **no remote crash-reporting provider is selected** (owner decision), so device crashes are not collected.
- [ ] Analytics — **NOT IMPLEMENTED, by decision.** No analytics SDK; the privacy-conscious default (no analytics) stands.
- [x] Accessibility audit — DONE (the audit and its fixes). The `PrimaryButton` contrast gap was fixed: the amber gradient's dark end was lightened (`#af8200`) and the label is the existing dark `onSurface`, at least 4.5:1 across the **whole** gradient (worst point 4.90:1, asserted by test); `ScanNavButton` uses the same pair. Open items: no TalkBack or VoiceOver pass; map markers have no screen-reader alternative; navigation labels clamp at 1.3x text; hardware-keyboard focus is not comprehensive (`PrimaryButton` only). Not a WCAG conformance claim.
- [x] Security review — DONE for the code and database (documented). **Not covered:** the remote Supabase Auth dashboard settings (owner-owned), an external penetration test, a dependency vulnerability audit.
- [ ] Database backup strategy — **BLOCKED.** Requirements and open tasks are documented; **nothing is configured and no restore was tested** - no production Supabase project exists (`beerapp-dev` is not production) and the plan tier is the owner's decision.
- [ ] Privacy policy — **BLOCKED.** The external-link infrastructure (validated public HTTPS URL, external browser, placeholder while unset) is implemented; the real text and URL must be supplied by the owner. No legal text was written.
- [x] Adult audience / age-gating review — DONE (facts documented; no contradiction found): mandatory adult-audience acknowledgement, no guest mode, device-local **self-declaration, not age verification**. Per-market and store age-rating review remains for Phase 15.
- [x] Responsible product design review — DONE; no contradiction with `PRODUCT.md` §3 or `CLAUDE.md` in the implementation. The monthly chart's screen-reader summary was reworded to neutral "entries" language, and `PRODUCT.md` §16 was rewritten to match `CLAUDE.md` and the Phase 10 decision (no achievements from log counts, frequency, streaks or volume).
- [ ] Terms — **BLOCKED.** Same as Privacy policy: infrastructure done, real text and URL owner-supplied.
- [ ] Account deletion compliance — **PARTIAL.** The deletion path and cascade to all six user-owned tables are documented and proven on the scaffold; a live deletion against a real project is **NOT EXERCISED**; retention (including future backups) and store deletion-URL requirements are open.

Exit criteria:

- [ ] Core flows are stable — **automated verification complete; not claimed as met.** The final verification pass is green (Flutter 736, backend 592, integration 269), but no live authenticated end-to-end flow has been exercised, so this stays unchecked until one is.
- [ ] App is production-ready — **No.** This is the full production/store readiness question; it depends on Phase 15 and the owner-supplied prerequisites below.

**Status (2026-09-21) - final verification done.**

- **A. Phase 14 engineering/hardening work: complete.** It is implemented, reviewed,
  documented and verified: backend default suite 592 passed and integration suite
  269 passed on a clean rebuild of the disposable PostgreSQL scaffold (scaffold plus
  all 19 migrations, no rows left behind, `beerapp-dev` never touched); Flutter 736
  passed, `flutter analyze` and `dart format` clean; `ruff` clean; an Android
  **release** build compiles with a production-shaped placeholder configuration
  (which the release guard accepts) and a **debug** build compiles with the normal
  development configuration. This is verification of the engineering work, not a
  production-signed or store-ready build.
- **B. Full production/store readiness: NOT achieved, and is not claimed.** It still
  depends on Phase 15 and the owner-supplied prerequisites listed below (legal text
  and URLs, hosting, a production Supabase project with backups, signing, store
  setup, and more).

The `private.set_updated_at()` privilege migration
`20260921100000_revoke_public_execute_on_set_updated_at` is **applied to
`beerapp-dev`**: the dry-run contained exactly that migration; linked lint passed;
all 19 migrations match the remote and none is pending; a read-only before/after
comparison showed only the intended ACL change and no row data changed, and a
re-check at final verification found no drift (both contribution tables still empty).

Found and fixed during final verification: `ios/Runner/Info.plist` was not
well-formed XML (a `--` inside a comment I had added), which Xcode would reject and
the previous test could not see; it is fixed and now covered by a regression test on
the raw file (for the plist and all three Android manifests). Found and documented,
not changed: the merged Android release manifest requests location, WiFi/network-state
and biometric permissions that libraries add (see Phase 15 checks below).

Release blockers (owner-supplied; not chosen or invented here):

1. Real Privacy Policy and Terms **text and public URLs**.
2. Hosting choice and a public **https API URL** (a release build refuses to start against a local or non-https URL).
3. A **production Supabase project**, its plan, backup/PITR configuration and a recorded **restore drill**.
4. A review of the **remote Supabase Auth settings** (redirect allowlist, email confirmation, password policy, CAPTCHA, auth rate limits).
5. **Requests-per-time rate limiting** at the deployment layer.
6. A **crash-reporting provider** decision (and confirmation that analytics stays off).
7. Google **iOS client ID** (`GIDClientID`) - iOS Google sign-in is NOT CONFIGURED; iOS itself was never built or run here.
8. A **disposable test account** with inbox access, for live end-to-end and live account-deletion checks.
9. Release **signing** and store material (Phase 15).

NOT EXERCISED in Phase 14: live authenticated end-to-end flows; live account deletion;
Android profile-mode performance and real map rendering; TalkBack/VoiceOver; anything
on iOS; a real local Supabase stack (Docker); live trigger firing on `beerapp-dev`
after the privilege migration; a backup restore.

---

# Phase 15 — Store Release

Goal: publish BeerApp.

Android:

- [ ] Production package identifier
- [ ] Signing configuration
- [ ] Play Store listing
- [ ] Screenshots
- [ ] App icon
- [ ] Privacy disclosures
- [ ] Internal testing
- [ ] Closed testing
- [ ] Production release

iOS:

- [ ] Apple Developer setup
- [ ] Bundle identifier
- [ ] Signing
- [ ] App Store Connect
- [ ] Screenshots
- [ ] Privacy disclosures
- [ ] TestFlight
- [ ] App Review
- [ ] Production release

Checks carried in from Phase 14 (none is done; each is a known limitation, not a
silent gap):

- [ ] Re-check current App Store policy on whether Sign in with Apple is required
  alongside Google sign-in before any iOS release (Apple sign-in is not implemented)
- [ ] iOS has never been built or run here; supply the Google iOS client ID
  (`GIDClientID`) - Google sign-in on iOS is NOT CONFIGURED
- [ ] Per-market age-gating and store age-rating review (the app has a device-local
  self-declaration only, not age verification)
- [ ] Store account-deletion requirements, including any web deletion URL
- [ ] Physical-device TalkBack and VoiceOver pass; keyboard/focus behaviour is not
  comprehensive
- [ ] Live authenticated end-to-end and live account-deletion checks, with an
  explicitly disposable account
- [ ] Release signing (the release build still uses the debug key)
- [ ] Review the **merged Android permissions** for the store privacy/data-safety
  disclosures: the release APK also requests location, WiFi/network state and
  biometric permissions that libraries add (the app's own manifest declares only
  `INTERNET` and `CAMERA`); decide whether to remove the unused ones

---

# Post-MVP Possibilities

Do not implement these until the core application is stable.

Possible future work:

- Social profiles
- Friends
- Followers
- Activity feed
- Public reviews
- Review likes
- Recommendations
- Nearby beer discovery
- Venue database
- Beer lists
- Shared lists
- Events
- Brewery check-ins
- Advanced achievements
- Seasonal campaigns
- AI recommendations
- Label recognition
- Admin dashboard
- Catalog moderation tools
- Import pipelines
- Web version

---

# Roadmap Rules

1. Finish the current phase before starting large work from a later phase.
2. Small foundational work for future phases is allowed when architecturally necessary.
3. Every completed phase must leave the application runnable.
4. Never sacrifice architecture merely to finish a phase faster.
5. Avoid speculative abstractions with no current use.
6. Add tests to important business rules.
7. Update this roadmap when scope meaningfully changes.
8. Mark tasks complete only when they actually work.
9. Do not silently remove roadmap requirements.
10. Major roadmap changes must be documented in `docs/DECISIONS.md`.
