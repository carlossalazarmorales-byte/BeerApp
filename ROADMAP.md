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
- [x] Map performance remains acceptable with many points — a server-side safety cap (`CappedList`, surfaced to the client as `truncated`) exists as a Phase 8 backstop; real viewport/bounding-box scale work remains deferred to Phase 14 at the current (small) catalog scale

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

- [ ] Camera permission
- [ ] Barcode scanner
- [ ] Barcode lookup
- [ ] Matching result
- [ ] No-result fallback
- [ ] Manual search fallback

Later:

- [ ] Label image recognition
- [ ] Suggested matches
- [ ] Confidence score
- [ ] User confirmation

Exit criteria:

- Common supported barcodes can open a matching beer

---

# Phase 12 — Profile and Settings

Goal: complete the user's personal area.

Tasks:

- [ ] Avatar
- [ ] Display name
- [ ] Username
- [ ] Preferred currency
- [ ] Preferred units
- [ ] Language
- [ ] Account settings
- [ ] Privacy settings placeholder
- [ ] Logout
- [ ] Delete account flow
- [ ] Legal links

Exit criteria:

- User can manage account essentials

---

# Phase 13 — Beer Contributions

Goal: allow catalog growth.

Tasks:

- [ ] Missing beer submission
- [ ] Brewery submission
- [ ] Duplicate candidate detection
- [ ] Unverified state
- [ ] Submission history
- [ ] Moderation-ready data model

Exit criteria:

- User contributions cannot overwrite verified catalog data directly

---

# Phase 14 — Quality and Production Hardening

Goal: prepare for real users.

Tasks:

- [ ] Improve test coverage
- [ ] Integration tests
- [ ] End-to-end critical flows
- [ ] Performance profiling
- [ ] Image optimization
- [ ] Map performance
- [ ] API rate limiting
- [ ] Error logging
- [ ] Crash reporting
- [ ] Analytics
- [ ] Accessibility audit
- [ ] Security review
- [ ] Database backup strategy
- [ ] Privacy policy
- [ ] Adult audience / age-gating review
- [ ] Responsible product design review
- [ ] Terms
- [ ] Account deletion compliance

Exit criteria:

- Core flows are stable
- App is production-ready

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
