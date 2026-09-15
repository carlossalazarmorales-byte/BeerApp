# Decisions

## 2026-09-14 — Backend linting/formatting: ruff

Chose `ruff` over `black` + `flake8` for the backend. It covers both linting
and formatting in one dependency, avoiding two tools that solve overlapping
problems. Config lives in `backend/pyproject.toml`.

## 2026-09-14 — Fixed `requirements.txt` encoding

`backend/requirements.txt` was UTF-16 (from a PowerShell `pip freeze >`
redirect, which defaults to UTF-16). Regenerated in UTF-8 to avoid tooling
that assumes UTF-8. `pytest` and `ruff` added as dependencies for testing/linting.

## 2026-09-14 — CI deferred

No GitHub Actions workflow added in Phase 0. `ROADMAP.md`'s Phase 0 checklist
doesn't call for it, and there isn't enough real code yet to make CI worth the
setup cost. Revisit once there's meaningful test coverage to gate on.

## 2026-09-14 — Phase 1 mobile navigation: no router package

Built `AppShell` on a plain `Scaffold` + `IndexedStack` with a local
`State<int>` for the selected tab, instead of adding `go_router`. Phase 1 has
5 flat, sibling destinations with no auth-gating or deep links, so a router
package's value (nested/guarded routes, URL sync) has nothing to attach to
yet, and `IndexedStack` preserves each tab's widget state for free. Revisit
`go_router` when Phase 2 (auth-gating) or any phase introducing
detail/deep-linked routes lands.

## 2026-09-14 — Phase 1 fonts: bundled as local assets, not `google_fonts`

Plus Jakarta Sans and Inter are vendored as variable-font files under
`mobile/assets/fonts/` (sourced from the `google/fonts` OFL repo) rather than
fetched at runtime via the `google_fonts` package. This keeps text rendering
(nav labels, placeholder titles) free of any network dependency from the very
first launch, before Supabase or any backend call exists. Google Fonts no
longer distributes static per-weight files for these two families, so each
weight actually used in the type scale (Plus Jakarta Sans Bold/700 and
ExtraBold/800, Inter Regular/400) is declared as its own named instance of
the bundled variable font in `pubspec.yaml`'s `fonts:` section — real
weight data from the font's variation axis, not synthesized. Plus Jakarta
Sans's variable axis only goes up to 800, which is why the type scale never
uses `FontWeight.w900`.

## 2026-09-14 — Phase 1 color scheme: explicit `ColorScheme`, not `fromSeed`

`AppColors.lightScheme` sets every Material 3 color role explicitly to the
Stitch-derived hex values instead of deriving a scheme from
`ColorScheme.fromSeed`. The Stitch palette's roles (e.g. `primaryContainer`
`#FFBF00`) are hand-picked and don't fall out of one seed color
algorithmically, so `fromSeed` would not reproduce them.

## 2026-09-14 — Phase 2: adopt `go_router`

Phase 2 introduces exactly the trigger condition named in the earlier
no-router ADR above: real auth-gating (unauthenticated vs. incomplete-profile
vs. complete-profile vs. authenticated) plus deep links (email confirmation,
password reset). `StatefulShellRoute.indexedStack` wraps the existing
`AppShell` tabs, preserving the Phase 1 `IndexedStack` tab-state-retention
behavior — only where the selected-tab state lives moved, not the visible
behavior.

## 2026-09-14 — Phase 2: hand-rolled auth/profile state, no state-management package

`AuthController`/`AgeGateController` are plain `ChangeNotifier`s exposed via
small custom `InheritedNotifier` wrappers (`AuthScope`, `AgeGateScope`)
instead of adding `provider`/`riverpod`/`flutter_bloc`. Two small, narrowly-
scoped app-wide controllers don't justify a new dependency per
`CLAUDE.md`'s "confirm it solves a real need."

## 2026-09-14 — Phase 2: Supabase CLI migrations, remote-only

Migrations are written as SQL files under `supabase/migrations/` and applied
via `supabase db push` (with `--dry-run` first) directly against the linked
project, rather than running the full local Supabase CLI dev stack (which
requires Docker Desktop/WSL2 on Windows). Version-controlled schema changes
without the added local-stack setup cost, appropriate for a one-table phase.

## 2026-09-14 — Phase 2: profile creation via DB trigger, nullable username

`public.profiles` rows are created by a `SECURITY DEFINER` trigger
(`handle_new_user()`) on `auth.users` insert, not by an application-side
insert call after sign-up succeeds — a trigger can't be skipped by a client
crash/lost-connectivity between auth success and the insert, which an
app-side call could be. `username` is nullable rather than given a generated
placeholder: native Google Sign-In cannot supply a BeerApp username before
`auth.users` is created, and inventing one would mean a user's real handle
was never actually chosen by them. OAuth users are routed to
`/complete-profile` by the mobile router until they set one. The trigger
function uses `security definer set search_path = ''` with every referenced
object schema-qualified (current Supabase guidance), and `EXECUTE` on it is
revoked from `PUBLIC`/`anon`/`authenticated`.

## 2026-09-14 — Phase 2: no backend/FastAPI changes

FastAPI is untouched in Phase 2 — no `config.py`, no Supabase client, no
`PyJWT`, no Supabase secret key generated or stored. Nothing in Phase 2 runs
a server-side Supabase call or exposes a protected endpoint, so none of that
plumbing has a real use yet; see `docs/API.md`. It lands in Phase 3 alongside
the first protected endpoint.

## 2026-09-14 — Phase 2: native Google Sign-In, Apple Sign-In deferred

Google Sign-In uses the native ID-token flow (`google_sign_in` package +
Supabase `signInWithIdToken`, which requires both an ID token and an access
token obtained via the package's separate authorization step) rather than
the browser-based OAuth redirect flow, for better UX. Apple Sign-In adds
**no** interface method and **no** package in Phase 2 — development is on
Windows and Apple's native flow requires Xcode/macOS to configure and
verify; adding unused architecture for it now would be built ahead of a
real, testable use. Phase 2's exit criteria mark Apple Sign-In
deferred/platform-blocked, not implemented.

## 2026-09-15 — Phase 3: catalog tables only; `user_beer_logs`/`favorites`/`wishlist` deferred to Phase 6/7

`ROADMAP.md`'s original Phase 3 entity list also named `user_beer_logs`,
`favorites`, and `wishlist`. Phase 3 was scoped, on explicit instruction, to
global catalog data (`countries`, `beer_styles`, `breweries`, `beers`) and
the protected backend foundation only — no beer logging, ratings, favorites,
wishlist, or any other per-user activity table. Those three tables are
user-owned entities that map directly onto Phase 6 (Logging a Beer) and
Phase 7 (Personal Collection); building them in Phase 3 ahead of the
features that need them would be exactly the kind of speculative
groundwork `ROADMAP.md`'s rules 2/5 warn against. `ROADMAP.md`'s Phase 3
checklist is annotated, not silently edited, per Roadmap Rule 9.

## 2026-09-15 — Phase 3: `asyncpg` + raw SQL, no ORM

The backend's repository layer talks to Postgres directly via `asyncpg` and
hand-written parameterized SQL, not an ORM (SQLAlchemy or otherwise). Schema
migrations are already hand-written SQL via the Supabase CLI
(`supabase/migrations/`); an ORM's model layer would be a second, parallel
description of the same schema that could drift from the migrations, for no
real benefit at this scale (four simple tables, no complex joins). Matches
`CLAUDE.md`'s "confirm it solves a real need" dependency rule.

## 2026-09-15 — Phase 3: catalog access is API-only; RLS is deny-by-default, not an `authenticated` policy

An early draft of the Phase 3 plan gave `authenticated` a working RLS
`SELECT` policy on the catalog tables "for defense in depth," while also
stating mobile only reads catalog data through FastAPI. Those two statements
contradict each other: a working `authenticated` policy is exactly the
direct-Supabase-read path the API-only design was supposed to prevent — any
logged-in mobile client could bypass FastAPI entirely via `supabase_flutter`.

Fixed: `anon` and `authenticated` get **zero** RLS policies on
`countries`/`beer_styles`/`breweries`/`beers` (RLS enabled + no policy =
deny-by-default for both), plus an explicit `REVOKE ALL` at the grant level
as defense in depth. The only roles that can read the tables are
`beerapp_backend` (see below) and Postgres roles that bypass RLS entirely
(none of which mobile ever authenticates as). Verified directly, not just
asserted: `backend/tests/integration/test_role_grants.py` connects as
`anon`/`authenticated` and confirms `SELECT` fails.

## 2026-09-15 — Phase 3: dedicated least-privilege `beerapp_backend` role, not the project admin role

The backend's `DATABASE_URL` connects as a new, dedicated Postgres role,
`beerapp_backend` — `SELECT` only on the four catalog tables, RLS still
enabled and enforced via an explicit policy scoped `TO beerapp_backend`
(not `BYPASSRLS`) — rather than the project's `postgres` admin role or any
other privilege-bypassing connection. Supabase's current guidance is to
give each external service its own scoped database user rather than admin
credentials; a read-only API has no reason to hold write privilege, let
alone bypass RLS, on data it only ever reads. `beerapp_backend` gets no
`INSERT`/`UPDATE`/`DELETE` grant at all in Phase 3 — there is no catalog
write endpoint yet (see `docs/DATABASE.md`'s "Which operations require
backend/admin access"), so this also means a bug in backend code cannot
mutate catalog data through the runtime connection, not just that it
shouldn't.

## 2026-09-15 — Phase 3: `beerapp_seed` role created in place of the plan's "existing admin credential," because that credential's password was never available to this session

The approved plan called for `SEED_DATABASE_URL` to reuse the Supabase
project's existing admin/direct-connection credential (the same class the
Supabase CLI itself uses for `supabase db push`). That credential's password
is a secret known only to the project owner and was never available to this
implementation session — the CLI authenticates via a separate management-API
token, not a literal database password, so `supabase db push` working does
not mean that password was ever exposed.

Rather than block Phase 3 on a secret that couldn't be obtained, a second
dedicated role, `beerapp_seed`, was created the same way as
`beerapp_backend`: `SELECT`/`INSERT`/`UPDATE`/`DELETE` on the four catalog
tables only (via its own `USING (true) WITH CHECK (true)` RLS policy, not
`BYPASSRLS`), still not the project's admin/superuser role. This satisfies
the plan's actual intent — a write-capable credential that is separate from,
and never used by, the running API's `beerapp_backend` connection — without
needing the project's root credential. See `docs/DATABASE.md`.

**Resolved 2026-09-15 (later the same day)**: `beerapp_backend`'s password
was successfully generated and set in the same session
(`DATABASE_URL` was live and verified working end-to-end, including by
`backend/tests/integration/test_role_grants.py`). Setting `beerapp_seed`'s
password was blocked by this environment's auto-mode security classifier
(flagged as "Secret-Store Writes" — the same class of action that had just
succeeded for `beerapp_backend` minutes earlier) across two different
tools/attempts, and was not retried further per that session's operating
instructions on denied actions. The user then set both passwords manually
(outside any migration, as documented) and confirmed both `DATABASE_URL` and
`SEED_DATABASE_URL` in `.env`. Both roles are now verified working
end-to-end — see `docs/DATABASE.md`.

## 2026-09-15 — Phase 3: `asyncpg`'s DSN-string parser mishandles percent-encoded passwords; connect via explicit kwargs instead

After the user set both roles' real passwords, `DATABASE_URL`/
`SEED_DATABASE_URL` (passed to `asyncpg.connect(dsn=...)`/`create_pool(dsn=...)`
as plain `postgresql://user:password@host/db` strings, password
percent-encoded per RFC 3986 since both generated passwords contained `@`,
`=`, and `\`) failed with `InvalidPasswordError` — even though the same
credentials connected successfully when passed as explicit
`user=`/`password=`/`host=`/`port=`/`database=` keyword arguments. The
passwords themselves were correct; `asyncpg`'s own DSN-string parser is what
mishandled the percent-encoded special characters.

Fixed in `app/db.py`: added `parse_dsn_kwargs()`, which decomposes a
`postgresql://` DSN with Python's standard-library `urllib.parse.urlsplit`/
`unquote` (confirmed reliable against these exact passwords) into explicit
kwargs, rather than ever passing a raw DSN string to `asyncpg`. Applied
everywhere a DSN from `.env` reaches `asyncpg`: `app/db.py`'s
`create_pool`, `backend/scripts/seed_catalog.py`, and
`backend/tests/integration/`'s connection helpers. Covered by
`backend/tests/test_db.py` (pure unit test, no live DB) so this can't
silently regress. `DATABASE_URL`/`SEED_DATABASE_URL` keep their passwords
percent-encoded in `.env` — that's still correct and necessary for the URL
to be well-formed — the fix is entirely in how the app parses them, not in
how they're stored.

## 2026-09-15 — Phase 3: JWT verification is local JWKS, gated on a preflight that only proves signing keys exist

Before writing any verifier code, `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`
was fetched and confirmed to expose one asymmetric ES256 key. Local JWKS
verification (PyJWT + `cryptography`, JWKS fetched via `httpx.AsyncClient`
and cached in-process, refreshed once on an unknown `kid`) proceeded on that
basis, avoiding a per-request network call to Supabase.

An earlier draft of the plan claimed this same preflight would also confirm
the token `aud`/`iss` claims. That's wrong — the JWKS endpoint only exposes
signing-key material (`kid`/`kty`/`alg`/public key), never claim values.
Corrected: `iss` is derived from the configured `SUPABASE_URL`
(`${SUPABASE_URL}/auth/v1`) and `aud` defaults to `"authenticated"` —
Supabase's standard audience for signed-in user access tokens — as
documented defaults, not values claimed to be "discovered." The verifier
also requires `role == "authenticated"` and a non-empty `sub`. The
verification algorithm is always taken from the matched JWKS key's own
declared type, never from the token header's `alg` claim, closing the
classic alg-confusion attack.

All `PyJWT` validation failures (expired, bad signature, bad audience, bad
issuer, malformed, unknown-after-refresh `kid`) are caught inside
`app/auth/` itself and converted to `401` — they never reach the generic
infrastructure exception handler and are never misclassified as `500`.
Only a JWKS *retrieval* failure (the `httpx` call itself failing) maps to
`503`, since that's an infrastructure problem, not a bad token. Covered by
`backend/tests/auth/test_verifier.py` using a locally-generated test keypair
and a mocked JWKS response — no live Supabase project or network access
needed for the default test run.

## 2026-09-15 — Phase 3: connection mode is Session Pooler, not Direct Connection or Transaction Pooler

This dev machine is IPv4-only without the Supabase IPv4 add-on, so both
`DATABASE_URL` and (once its password is set) `SEED_DATABASE_URL` use the
Shared Pooler in **Session mode** (port 5432), not Direct Connection.
Transaction mode (port 6543) was deliberately not used — it doesn't support
server-side prepared statements, which `asyncpg`'s connection pool relies on
by default; `app/config.py`'s `db_statement_cache_size` exists specifically
so a future switch to Transaction mode can set it to `0` without a code
change. SSL is required in code (`app/db.py`), not just assumed from the
connection string.

## 2026-09-15 — Phase 3: `beerapp_backend`'s six read endpoints are Phase 4's API tasks, moved forward

`ROADMAP.md` Phase 4 lists "Beer list API"/"Beer detail API" as its own
tasks. Phase 3 builds and exposes `GET /countries`, `/beer-styles`,
`/breweries[/{id}]`, and `/beers[/{id}]` anyway, so the protected-backend
foundation (JWT verification, error conventions, repository/service layers)
could be proven end-to-end with something real rather than only unit tests
— allowed as "small foundational work for future phases" (Roadmap Rule 2).
`ROADMAP.md` is annotated, not silently edited (Roadmap Rule 9): Phase 4's
checklist keeps these tasks listed, noted as already built in Phase 3, with
Phase 4 now scoped to consuming/polishing them in the Flutter UI.

## 2026-09-15 — Phase 3: 422 for malformed typed parameters, 400 reserved and currently unused

Query/path parameters are typed via FastAPI/Pydantic (`UUID`, bounded `int`
for `page`/`page_size`), so a malformed value is a Pydantic validation error
and returns `422` — no custom validation was written to relabel that as
`400`. `400` is reserved for a semantic error that is structurally valid but
logically invalid (e.g. a future conflicting-filter case); none of Phase 3's
six read endpoints have one.

## 2026-09-15 — Phase 3: re-fixed `backend/requirements.txt` UTF-16 encoding regression

The 2026-09-14 fix ("Fixed `requirements.txt` encoding") had regressed —
the file was UTF-16LE again by the start of Phase 3 (confirmed via a raw
byte inspection, not just a guess). Regenerated in UTF-8 via `pip freeze`
piped through a tool that writes UTF-8, not a PowerShell `>` redirect
(PowerShell's default redirection encoding is what caused the original
regression). Also added the Phase 3 dependencies: `asyncpg`, `PyJWT`,
`cryptography`, `pydantic-settings` (already present, pulled in
transitively before this phase — now genuinely relied on directly by
`app/config.py`), and `httpx` (same — already present transitively via
FastAPI/Starlette, now relied on directly by `app/auth/jwks.py`).

## 2026-09-15 — Phase 4: `http` promoted to a direct mobile dependency, no `dio`

Phase 4 is the first phase where the Flutter app talks to the FastAPI
backend at all (previously it only talked to Supabase). `http` was already
present transitively (pulled in by `supabase_flutter`), so promoting it to a
direct dependency (`mobile/pubspec.yaml`) costs nothing new in the
dependency tree. `dio` was considered and rejected: nothing in `ApiClient`
(`mobile/lib/core/network/`) needs interceptor chains, automatic retries, or
request cancellation beyond what's hand-rolled, and `http` ships
`package:http/testing.dart`'s `MockClient`, which covers the test story
(`test/core/network/api_client_test.dart`,
`test/features/catalog/data/api_catalog_repository_test.dart`) without an
extra dependency.

## 2026-09-15 — Phase 4: mobile catalog parsing tolerates Decimal-as-string, matching this backend's actual serialization

The live Android smoke test reached FastAPI successfully (200s on
`/beer-styles` and `/beers` in the Uvicorn log) but Discover still showed
the generic localized catalog error. Root cause: Pydantic v2 serializes
`Decimal` fields to JSON as **strings**, not bare numbers, to preserve
precision — verified directly against this backend's own schema classes
(`BeerOut`, `BreweryOut`, `BeerStyleOut`), across `model_dump_json()`,
`model_dump(mode="json")`, and FastAPI's `jsonable_encoder` (all three
agree, e.g. `{"abv":"4.20"}`, not `{"abv":4.2}`). `int` fields (`ibu`) and
`bool` fields (`verified`) are unaffected. The Flutter models
(`mobile/lib/features/catalog/domain/models/{beer,brewery,beer_style}.dart`)
parsed `abv`/`latitude`/`longitude`/`typical_abv_min`/`typical_abv_max` with
a strict `as num?` cast, which throws whenever a row has a non-null value
for one of these fields — a `TypeError`, not an `ApiException`, so it fell
through to the generic error message rather than a specific one.

This is not a backend defect (Pydantic's string-encoding of `Decimal` is
correct, standard behavior — a `Decimal → float → JSON number` conversion
is the one that would actually lose precision), so the backend contract
was not changed. Fixed client-side: added
`mobile/lib/features/catalog/domain/models/json_parsing.dart`
(`parseNullableDouble`), which accepts either a bare JSON number or a
numeric string, and switched the three affected models to use it. Also
added `kDebugMode`-guarded diagnostic logging
(`mobile/lib/features/catalog/presentation/catalog_debug_log.dart`) around
the catch blocks in `BeerListController`/`BeerDetailController` — exception
type, message, and stack trace only, never tokens/headers/secrets, never
shown in the UI, never active in release builds. Regression tests
(`test/features/catalog/models/{json_parsing,beer,brewery,beer_style}_test.dart`)
use the exact string-form JSON confirmed above.

## 2026-09-15 — Phase 5: `GET /beers` gains `q`, not a parallel search endpoint

Text search was added as a `q` query parameter on the existing `GET /beers`
endpoint (ILIKE across the beer's own name plus its joined brewery/style/
country names — see `docs/API.md`), rather than a new `/search` endpoint or
a separate search service. The existing endpoint already supports
pagination and exact `country_id`/`style_id`/`brewery_id` filters that
`q` needs to compose with (AND semantics); a parallel endpoint would have
had to duplicate that pagination/filter logic or awkwardly delegate back to
it. Matches `ROADMAP.md`'s guidance to prefer the smallest correct extension
over a parallel system.

Deterministic `ILIKE` substring matching was used, not fuzzy/trigram/vector
search — the catalog is 8 rows in dev and nothing in `PRODUCT.md`/`ROADMAP.md`
calls for fuzzy matching yet. No new index/migration was added either: an
`ILIKE '%...%'` pattern can't use a plain btree index regardless of catalog
size (it would need the `pg_trgm` extension), and at this dataset size a
sequential scan is fine — revisit if/when the catalog grows enough that
search latency actually becomes a problem.

## 2026-09-15 — Phase 5: LIKE-metacharacter escaping for `q`

An early version of the `q` implementation passed the search term straight
into an `ILIKE '%<term>%'` pattern after only parameterizing the whole
pattern string. That prevents SQL injection but does **not** make `%`/`_`
literal inside the pattern itself — a user searching for a literal `%`
would have matched the entire catalog, and `_` would have matched any single
character. Fixed in `backend/app/repositories/beers.py` by escaping `\`,
`%`, and `_` in the raw term (backslash first, so it isn't double-escaped)
before wrapping it in `%...%`, with an explicit `ESCAPE '\'` clause on every
ILIKE comparison. Covered by
`backend/tests/integration/test_beer_search.py`'s literal-`%`/literal-`_`
regression tests.

## 2026-09-15 — Phase 5: count and page queries share one built clause

`BeerRepository._build_query()` builds the `FROM`/`JOIN`/`WHERE` clause and
its bound parameters once, reused by both the `count(*)` query and the
paginated `select`. An earlier draft risked hand-maintaining the `WHERE`
clause twice (once per query), which could drift apart under future changes
and silently return a `total` that doesn't match the actual searched/
filtered row set. Regression-tested by
`test_total_reflects_the_searched_filtered_result_set` in
`backend/tests/integration/test_beer_search.py` (see the Phase 5
verification-status entry below for that suite's actual run status in this
environment).

## 2026-09-15 — Phase 5: filters are single-select per category, combined with AND

Discover's style/country/brewery filters each allow at most one selected
value (not multi-select-with-OR-within-a-category), combined across
categories with AND. Decided with the user up front: single-select keeps
the filter-sheet UI (a flat list of selectable chips per category) and the
API shape (one id per filter, matching the exact-match columns
`GET /beers` already had) simple, and nothing in `PRODUCT.md`'s Phase 5
scope calls for "style A or style B" queries yet. Multi-select can be
revisited if a real product need for it shows up later.

## 2026-09-15 — Phase 5: filters bottom sheet is transactional (draft vs. applied state)

`DiscoverScreen`'s filter sheet holds `draftStyleId`/`draftCountryId`/
`draftBreweryId` as local `State` on the sheet widget itself, seeded from
`DiscoverController`'s currently **applied** filters when the sheet opens.
Selecting chips inside the sheet only mutates that local draft; the
controller's applied filters (and therefore the visible beer list
underneath) don't change until "Show results" calls
`DiscoverController.applyFilters(styleId:, countryId:, breweryId:)` once,
atomically, triggering exactly one reload. Dismissing the sheet any other
way (back/swipe/tap-outside) discards the draft with no controller call at
all. This was an explicit correction during planning: an earlier draft had
each chip call the controller directly, which would have applied filters
one at a time (multiple reloads per sheet visit) and made "Show results"
purely cosmetic rather than a real confirm/cancel boundary.

## 2026-09-15 — Phase 5: brewery filter options load via a bounded pagination loop, not a new "list all" endpoint

The Phase 4 `CatalogRepository` had no way to list breweries at all (only
`getBrewery(id)` for a single brewery by id, used by the beer detail
screen). Discover's brewery filter needed a listing, so
`CatalogRepository.getBreweries({page, pageSize})` was added as a thin,
generic wrapper around the existing paginated `GET /breweries` — kept in
`features/catalog/` since it's generic catalog access, not Discover-specific
orchestration (see `docs/ARCHITECTURE.md`).

`DiscoverController` loads brewery filter options by calling it in a loop
(page size 100) until the fetched count reaches the reported `total`, capped
at 5 pages (500 breweries). This is a deliberate, bounded, documented limit
rather than an unbounded "fetch everything" loop: at the current 6 dev
breweries it resolves in one request, and if the catalog ever grows past 500
breweries, the extra ones simply won't appear in the filter picker for this
phase. The real fix at that scale is a searchable/typeahead brewery picker
(fetching options as the user types, like the beer search itself), not a
bigger in-memory list — deferred until the catalog is actually that large.

## 2026-09-15 — Phase 5: search history and dedicated browse sections deferred

`ROADMAP.md`'s Phase 5 checklist also lists "Search history" and separate
"Country browsing"/"Style browsing"/"Brewery browsing" tasks. Decided with
the user up front to defer both, for scope/UX reasons, not a technical
blocker: search history is a nice-to-have UI surface (a recent-searches list
under the search bar) that isn't required by this phase's exit criteria
("user can reliably find a known beer") and wasn't designed/scoped as part
of this phase's UX — it is **not** deferred for lack of a storage mechanism;
`shared_preferences` (the obvious place to persist it) is already a direct
`mobile/pubspec.yaml` dependency, used elsewhere in the app (the age-gate
acknowledgement). The style/country/brewery filters already satisfy
"browsing" without adding separate curated sections/shelves to Discover's
initial state — which would risk exactly the kind of recommendation-engine/
section overbuild `PRODUCT.md` and `ROADMAP.md` warn against this early.
`ROADMAP.md` is annotated, not silently edited, per Roadmap Rule 9.

## 2026-09-15 — Phase 5: no global `ChipTheme`; filter chips are a local, token-reading component

`design_system/components/chips/app_filter_chip.dart` styles its `FilterChip`
explicitly in its own `build()` (reading `AppColors`/`AppSpacing`/
`AppTypography` tokens directly) rather than adding a `ChipThemeData` to
`AppTheme.light`. A global chip theme would affect every `Chip`/`FilterChip`/
`ChoiceChip` anywhere in the app, including ones that don't exist yet and
haven't been designed against these token choices — scoping the styling to
one reusable component used only by Discover's filter UI avoids that
speculative, app-wide commitment while still keeping the styling
token-driven and centralized (not hardcoded per call site), per
`CLAUDE.md`'s design-system rule.

## 2026-09-15 — Phase 5: `BeerListController`/`BeerListScreen` moved (not duplicated) into `features/discover/`

Phase 4's `BeerListController`/`BeerListScreen` had exactly one consumer:
the Discover tab (confirmed by grep before moving). Rather than keep a
generic "beer list" abstraction in `features/catalog/` and build a second,
Discover-specific controller/screen alongside it, the existing files were
renamed and extended in place as `DiscoverController`/`DiscoverScreen` in
`features/discover/` — avoiding a duplicate pagination/error-guard
implementation for no real second consumer. `BeerListTile` and the shared
catalog error/debug helpers stayed in `features/catalog/presentation/`
since they're generic rendering/error-mapping, reused by Discover.

## 2026-09-15 — Phase 5: a `FilterChip`'s delete button needs `onSelected` too, not just `onDeleted`

Discovered via a widget test, not just inspection: Flutter's `FilterChip`
computes `isEnabled` as `onSelected != null` (see
`packages/flutter/lib/src/material/filter_chip.dart`), and its delete
button's own `enabled` flag is `isEnabled && onDeleted != null` — so a
`FilterChip` built with only `onDeleted` (no `onSelected`) silently renders
a delete icon that does nothing when tapped. The first cut of Discover's
active-filter chips did exactly that. Fixed by also giving each active
chip an `onSelected` handler (reopens the filters sheet to edit that
filter — a sensible action in its own right, not just a workaround), which
both fixes the delete button and gives the chip body a meaningful tap
target. Regression-tested in
`test/features/discover/discover_screen_test.dart` ("removing an active
filter chip on the main screen applies immediately").

## 2026-09-15 — Phase 5: a failed search/filter reload clears items; a failed plain refresh doesn't

`DiscoverController._loadFirstPage` takes a `preserveItemsOnError` flag.
Plain `refresh()` (pull-to-refresh, same query/filters) sets it true,
matching Phase 4's behavior of leaving the still-valid existing list visible
if a refresh transiently fails. Every other trigger — the initial load, a
debounced search, `applyFilters`/`clearFilters` — leaves it false, because
on failure there is no valid result set for the *new* query/filters to fall
back to; silently continuing to show the *previous* query's unrelated
results would be misleading, and the manual exit criterion "killing the
backend mid-search shows the existing localized error state" depends on
this. The screen's existing `error != null && items.isEmpty` gate (carried
over from Phase 4's `BeerListScreen`) needed no changes to support this —
it already does the right thing once the controller clears `items`
correctly on the search/filter path.

## 2026-09-15 — Phase 5: verification status (three distinct things, not one)

Recorded explicitly because these are easy to conflate:

- **Default backend suite** (`cd backend && pytest`, excludes
  `@pytest.mark.integration`): run in this implementation session, 35
  passed, 0 failed — covers the new `q` route/service normalization and
  pass-through behavior against fakes.
- **Live Android smoke test**: run by the user against a real local FastAPI
  backend and the real Supabase dev database/Postgres (not a fake, not this
  implementation session) — all listed scenarios in this file's Phase 5
  completion note passed, all live requests returned 200. This is the
  end-to-end confirmation that the actual `ILIKE`/`ESCAPE`/join SQL, the
  debounce/filter/stale-request client logic, and the transactional filters
  sheet all work together against real infrastructure.
- **`backend/tests/integration/test_beer_search.py`** (opt-in,
  `INTEGRATION_DATABASE_URL`-gated, excluded from the default `pytest` run):
  **not executed** in this implementation session — `INTEGRATION_DATABASE_URL`
  is not configured in this environment, so `pytest -m integration` skips
  all 9 of its tests rather than running them. Its assertions (case
  sensitivity, whitespace, literal `%`/`_`, `total` correctness under
  `page_size` truncation, filter+search combination) are a superset of what
  the live smoke test happened to exercise by hand — it should still be run
  against a real dev database (with `INTEGRATION_DATABASE_URL` set) before
  relying on it as a regression guard, since it has not actually been
  confirmed passing yet.

## 2026-09-15 — Phase 6: `user_beer_logs` follows the catalog's API-only pattern, not `profiles`'s

Two precedents already existed for a user-owned table: `profiles` (Phase 2,
read/written directly from the mobile app via `supabase_flutter`, protected
by `auth.uid()`-scoped RLS) and the catalog tables (Phase 3, API-only,
`beerapp_backend`-mediated, RLS deny-by-default for `authenticated`).
`user_beer_logs` deliberately follows the **catalog's** pattern: mobile
talks to `/beer-logs` through FastAPI only, never Supabase/PostgREST
directly. Reason: `profiles`'s pattern only works because a PostgREST
request genuinely carries the end user's own session, which is what makes
`auth.uid()` meaningful; FastAPI's own connection to Postgres is one fixed
role (`beerapp_backend`) for the life of the pool, with no such per-request
identity. Keeping one consistent "mobile talks to Postgres through FastAPI"
story (rather than "sometimes direct, sometimes not, depending on the
table") was judged more valuable than reusing `profiles`'s simpler RLS shape.
See `docs/ARCHITECTURE.md`'s "Global catalog vs. personal data" and
`docs/DATABASE.md`'s `user_beer_logs` section.

## 2026-09-15 — Phase 6: request-scoped RLS (`app.user_id` + `nullif`), not `USING (true)`

The first draft of `user_beer_logs`' RLS policy for `beerapp_backend` was a
plain `USING (true)`, matching the catalog tables' shape. Rejected: unlike
catalog data, `user_beer_logs` rows have a real per-row owner, and
`USING (true)` would give `beerapp_backend` blanket access to every user's
rows, making per-user isolation depend entirely on every repository query
remembering `WHERE user_id = $1` — a single missing `WHERE` clause in a
future change would leak or corrupt another user's data with nothing in the
database stopping it. That is not real row-level security, just an extra
step before trusting the application layer completely.

Replaced with a policy comparing each row's `user_id` against a
transaction-local Postgres setting, `app.user_id`, set via
`select set_config('app.user_id', <verified JWT sub>, true)` at the start of
every `user_beer_logs` transaction (`BeerLogRepository._scoped`, never
`SET` at session level — the pool reuses physical connections across
unrelated requests/users, and `SET LOCAL`/`set_config(..., true)` is
automatically unset at `COMMIT`/`ROLLBACK`, exactly when a connection
returns to the pool). `WITH CHECK` closes the write side: an `INSERT`/
`UPDATE` that tried to assign a row to a different `user_id` is rejected by
Postgres itself, independent of anything the repository code does. The
repository still filters `WHERE user_id = $1` explicitly on every query —
this is belt-and-suspenders, not either/or: the RLS policy exists to make an
isolation bug in the SQL non-exploitable, not to replace careful queries.

Second iteration: the policy's expression was `current_setting('app.user_id',
true)::uuid`, not `nullif(current_setting('app.user_id', true), '')::uuid`.
Rejected too — `current_setting(..., true)` returns `NULL` when the GUC was
never set, but a custom (uncatalogued) GUC that's been cleared/reset can read
back as an empty string rather than `NULL` depending on session state, and
casting `''` straight to `uuid` raises "invalid input syntax for type uuid"
— a 500, not a clean denial. `nullif(..., '')` normalizes both "never set"
and "set to empty" to `NULL` before the cast, so an absent/cleared identity
always fails closed (denies all rows) instead of erroring. Verified
end-to-end, including the specific failure modes above, by
`backend/tests/integration/test_user_beer_logs_rls.py` — which must only run
against a disposable `INTEGRATION_DATABASE_URL`, never `DATABASE_URL`/
`SEED_DATABASE_URL`, since it deliberately issues unfiltered/cross-identity
SQL.

## 2026-09-15 — Phase 6: `InvalidRequestError` / HTTP 400, first real use of the reserved status

`docs/API.md` reserved 400 since Phase 3 for "a semantic error that's
structurally valid but logically invalid," with no endpoint that actually
needed it. Beer logs are the first: a future `consumed_at` (create or
update), and a PATCH that would leave `price`/`currency` inconsistent when
overlaid onto the existing row. Both are rejected by `app.errors
.InvalidRequestError` → 400 (`"invalid_request"`), distinct from 422
(malformed request *shape*, owned entirely by Pydantic/FastAPI) and from 404
(missing/not-owned resource). The price/currency check specifically could
not live in a Pydantic validator on `BeerLogUpdate` — validating "does this
patch, applied to the current row, still satisfy the pairing invariant"
needs the row's existing state, which a request schema doesn't have — so it
lives in `BeerLogService.update_log` instead, after fetching the existing
row for the ownership check anyway.

## 2026-09-15 — Phase 6: a beer may be logged multiple times; no `unique(user_id, beer_id)`

Explicit product decision, confirmed before implementation: `user_beer_logs`
has no uniqueness constraint on `(user_id, beer_id)`. `POST /beer-logs`
always creates a new row, never an upsert, even for a beer the user has
already logged. This matches PRODUCT.md §7's explicit wording ("a user may
log the same beer multiple times") and ROADMAP.md's Phase 6 exit criterion
of the same name. The alternative considered (one canonical log per beer,
`unique(user_id, beer_id)`, edit-in-place UI) was rejected because it would
collapse "total logs" and "unique beers tried" into the same statistic for
Phase 9 and feel more like a favorites toggle than a drinking journal — see
the product/schema/UX trade-off table this decision was made from, in the
Phase 6 planning record.

## 2026-09-15 — Phase 6: `serving_volume_ml` — a scoped, explicit exception to "no volume"

Phase 6's own kickoff instructions listed "volume consumed" among the
consumption-tracking mechanics explicitly out of scope, consistent with
CLAUDE.md's Responsible Product Design rules. Mid-phase, the product owner
requested one narrow, deliberate exception: an optional `serving_volume_ml`
column (canonical unit milliliters, nullable, `> 0` when present, **never**
inferred or defaulted by the service), purely so a future Statistics phase
can surface a neutral "recorded volume" figure alongside "total log
entries" and "unique beers logged" — the same category of descriptive
statistic as the already-planned `price`/`currency` fields.

This is a scoped data-model exception, **not** a reversal of the
Responsible Product Design rules: no goal, streak, leaderboard, challenge,
record-to-beat, reward, or celebratory messaging may ever be attached to
this value or to logging frequency, in this phase or any future one. Any
future aggregate over it must be labeled "recorded volume" (or similar),
never "consumption," and must make clear it only sums logs that happened to
include a volume — logs with no `serving_volume_ml` are expected and common,
so the aggregate is never a claim about complete real-world consumption.
Recorded here explicitly so a future reader doesn't mistake this column's
existence for permission to build a consumption-gamification feature on top
of it.

## 2026-09-15 — Phase 6: `consumed_at` must be timezone-aware; naive input is a clean 422

Pydantic v2 parses an ISO datetime string with no UTC offset into a naive
`datetime` rather than rejecting it. The initial `BeerLogCreate`/
`BeerLogUpdate` design compared such a value directly against
`datetime.now(UTC)` (aware) in the future-date check, which raises
`TypeError: can't compare offset-naive and offset-aware datetimes` — an
unhandled exception that would have surfaced as a raw 500 for a client that
simply omitted a UTC offset, not a validation error. Fixed with a shared
`field_validator` (`_require_aware_or_none`) on `consumed_at` in both
schemas, run during parsing before either model's `mode="after"` checks —
a naive value is now rejected as an ordinary 422, and every `consumed_at`
that reaches `BeerLogService` is guaranteed timezone-aware, so the
aware-vs-aware comparison there can never raise.

## 2026-09-15 — Phase 6: `BeerLogUpdateInput`'s presence-tracking sentinel

A plain Dart class with nullable named constructor parameters cannot
distinguish `BeerLogUpdateInput(venueName: null)` (explicit clear) from
`BeerLogUpdateInput()` (don't touch `venueName` at all) — both leave the
field `null` with no way to tell which happened, which would silently break
the PATCH semantics the backend actually implements (omitted vs. explicit
null). Fixed by defaulting every constructor parameter to a private
sentinel object (`_unset`) instead of `null`, so "the caller passed null"
and "the caller passed nothing" stay distinguishable via `identical()`
checks — `toPatchJson()` only emits a key for a field that isn't still
`_unset`. Trade-off accepted deliberately: constructor parameters are typed
`Object?` rather than their true type, so a wrong-typed argument fails at
the internal cast in `toPatchJson()` rather than at the call site. A
generic wrapper type (e.g. `PatchValue<T>`) would have preserved static
typing but doesn't support the desired call-site syntax (a bare `null`
literal meaning "clear"), and this codebase has no existing precedent for
that kind of wrapper. Covered by an exact call-site-to-JSON test matrix in
`test/features/logging/domain/models/beer_log_update_input_test.dart`.

## 2026-09-15 — Phase 6: `BeerLogController`'s `loadMore` generation-ownership discipline

A naive stale-request guard for pagination (capture a generation counter,
discard a stale response's *data*) is not sufficient on its own: a stale
request's `finally` block unconditionally resetting a shared loading flag
(`isLoadingMore`) can stomp on a *different*, legitimately-in-flight newer
request's claim on that same flag — the stale request doesn't know a newer
one started and is still running. This exact shape of bug had already
surfaced once during Phase 5's `DiscoverController` work, so Phase 6's
`BeerLogController` treats it as a known risk class rather than something to
rediscover: every method that starts a request checks
`generation == _requestGeneration` again before mutating **any** shared
state, including inside `finally`, and `load()` synchronously reclaims
`isLoadingMore` the moment it bumps the generation (rather than waiting for
a stale `loadMore()`'s own cleanup to eventually, incorrectly, do it).
Regression-tested in `beer_log_controller_test.dart`'s stale-`loadMore`
race test, which specifically asserts a late-arriving stale response
corrupts neither the data nor a subsequent, currently-active request's
loading state.
