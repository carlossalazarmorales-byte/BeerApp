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
- [ ] favorites — deferred to Phase 7
- [ ] wishlist — deferred to Phase 7

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
- [ ] Update collection state after logging — deferred to Phase 7: this task most naturally reads as "the Collection screen reflects a newly-created log," which requires a Collection screen that doesn't exist yet (Phase 7's own first task). Phase 6 makes the underlying data queryable and correct (`GET /beer-logs`, ordered/paginated) so Phase 7 can build that screen without any API change, but no visible collection state is actually updated by anything in Phase 6.

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

- [ ] Collection screen
- [ ] Unique beers tried
- [ ] Recent beers
- [ ] Favorites
- [ ] Wishlist
- [ ] Filter by country
- [ ] Filter by style
- [ ] Filter by brewery
- [ ] Sort by rating
- [ ] Sort by date
- [ ] Sort by name
- [ ] Collection empty states

Exit criteria:

- Collection accurately reflects user logs
- Wishlist and favorites work independently

---

# Phase 8 — World Map

Goal: implement BeerApp's flagship experience.

Tasks:

- [ ] Add MapLibre
- [ ] Base map style
- [ ] Beer origin markers
- [ ] Brewery markers
- [ ] Marker clustering
- [ ] Country-level exploration
- [ ] Region-level exploration
- [ ] Tried / not-tried filters
- [ ] Favorite filter
- [ ] Wishlist filter
- [ ] Beer preview card
- [ ] Brewery preview card
- [ ] Smooth camera transitions
- [ ] Loading states
- [ ] Location permission handling if needed

Exit criteria:

- User can explore beer geographically
- Map performance remains acceptable with many points

---

# Phase 9 — Statistics

Goal: summarize personal beer activity.

Tasks:

- [ ] Total unique beers
- [ ] Total logs
- [ ] Countries discovered
- [ ] Styles discovered
- [ ] Breweries discovered
- [ ] Average rating
- [ ] Amount spent
- [ ] Monthly activity
- [ ] Yearly activity
- [ ] Favorite style
- [ ] Favorite country
- [ ] Favorite brewery
- [ ] Statistics UI
- [ ] Basic charts

Exit criteria:

- Statistics match underlying log data
- Calculations are tested

---

# Phase 10 — Achievements

Goal: add progression and motivation.

Tasks:

- [ ] Achievement data model
- [ ] Achievement definitions
- [ ] Progress values
- [ ] Locked state
- [ ] Unlocked state
- [ ] Unlock timestamp
- [ ] Achievement evaluation service
- [ ] Achievement screen
- [ ] Achievement notifications
- [ ] Categories
- [ ] Progress bars

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

Exit criteria:

- Achievements are data-driven
- Adding a new achievement does not require major application changes

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
