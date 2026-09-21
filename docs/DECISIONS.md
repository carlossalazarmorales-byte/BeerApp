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

## 2026-09-16 — Phase 7: one `user_beer_collection` table, not separate `favorites`/`wishlist` tables

Both shapes were weighed before implementation. Two tables (row-exists-means-
true, `INSERT ... ON CONFLICT DO NOTHING` / plain `DELETE`, no boolean/CHECK
to reason about) is the simpler shape *per concept*, but favorites and
wishlist aren't independent concepts in how they're actually read: Beer
Detail's single "what's this beer's state" lookup and the Favorites/Wishlist
tabs both want one row answering "this user's state for this beer," not a
join/union of two tables. Two tables would also double every piece of Phase
6's per-table boilerplate (migration pair, RLS policy, grant, repository)
for what is structurally one row shape appearing twice. Chosen instead: a
single `user_beer_collection` table with `is_favorite`/`is_wishlist`
booleans and `unique(user_id, beer_id)`. The complexity this design takes on
in exchange — keeping "all-false means no row" true under concurrent writes
without a DB-level CHECK to lean on — is confined to one write path,
`CollectionRepository.set_state`, and judged a worthwhile trade. See
`docs/DATABASE.md`'s `user_beer_collection` section for the schema.

## 2026-09-16 — Phase 7: no `CHECK (is_favorite OR is_wishlist)` — the invariant is enforced by the repository, not the database

An earlier version of this design used exactly that CHECK, relying on
Postgres rejecting an all-false write as the signal for the repository to
fall back to a `DELETE`. Rejected once the concurrency implications were
worked through: Postgres CHECK constraints aren't deferrable, so recovering
from a violation means rolling back to a `SAVEPOINT` — and that rollback
releases any row lock acquired after the savepoint, reopening a window where
a *different* concurrent transaction could grab the row between "roll back
the failed write" and "issue the follow-up delete." That window is exactly
the kind of lost-update bug this table's concurrency design otherwise
closes.

The logical invariant — an all-false state is represented by no row, never
a stored row — still holds, but it is now enforced entirely by
`CollectionRepository.set_state` (`backend/app/repositories/collection.py`),
the only write path to this table: the atomic upsert (below) and any needed
`DELETE` run inside one uninterrupted transaction, with no savepoint and no
constraint violation ever invited. `favorited_at`/`wishlisted_at` pairing
stays a DB-level CHECK, since those are single-statement-internal
invariants with no cross-transaction race.

## 2026-09-16 — Phase 7: atomic SQL-side merge for `PATCH /collection/{beer_id}`, not a Python read-modify-write

A read-modify-write split across Python (read current state, compute the
merge, then write) is unsafe under concurrent PATCHes to the same beer: two
overlapping requests can each read stale state and one can silently clobber
the other's field. The fix computes the merge *inside* the SQL statement
against the live row instead:

```sql
insert into public.user_beer_collection (...)
values ($1, $2, coalesce($3, false), coalesce($4, false), ...)
on conflict (user_id, beer_id) do update set
  is_favorite = coalesce($3, user_beer_collection.is_favorite),
  is_wishlist = coalesce($4, user_beer_collection.is_wishlist),
  ...
```

`coalesce(..., user_beer_collection.is_favorite)` reads the *unqualified
table name* to mean "the row's current value at the moment of this locked
write" — Postgres serializes concurrent `ON CONFLICT DO UPDATE`s on the same
key via the row lock, so whichever runs second sees the first's
already-committed value through this reference, never a Python-side guess
made before either committed. Two concurrent first-time inserts on a brand
new `(user_id, beer_id)` are resolved the same way `INSERT ... ON CONFLICT`
is designed to make safe already, with no extra locking code.

Verified against four required concurrency scenarios (initial state,
concurrent request A, concurrent request B, required final state), each run
repeatedly against real overlapping transactions in
`backend/tests/integration/test_collection_concurrency.py`:

- initial `{false, true}`; `favorite=true` / `wishlist=false` → `{true, false}`
- no row; `favorite=true` / `wishlist=true` → exactly one row, `{true, true}`
- initial `{true, true}`; `favorite=false` / `wishlist=false` → no row
- no row; `favorite=false` / `wishlist=true` → exactly one row, `{false, true}`

All four hold regardless of which request's transaction happens to commit
first.

## 2026-09-16 — Phase 7: `PATCH /collection/{beer_id}` is an upsert, deviating from the beer-logs PATCH convention

`docs/API.md`'s beer-logs section establishes PATCH-requires-an-existing-row
(404 otherwise) as the convention. Collection state deliberately breaks it:
this resource's only identity is the `(user_id, beer_id)` pair — there is no
separate `id`, no POST-then-PATCH lifecycle, and "no row" *is* the default
state (`{is_favorite: false, is_wishlist: false}`). Treating a first PATCH
as an ordinary partial update against that implicit default, rather than
requiring a prior POST to create a favorite/wishlist row first, is the
correct behavior for a canonical-state resource, not a special case to
avoid. `GET /collection/{beer_id}` mirrors this: a real beer with no
collection row is 200 (both flags false), and only a `beer_id` that isn't a
real catalog beer is 404 — implemented via a `LEFT JOIN` from `beers` (the
driving table) rather than a second existence-check round-trip.

## 2026-09-16 — Phase 7: `sort=rating` means the beer's latest log's rating, not an average

A beer can have multiple logs, so "this beer's rating" for sort purposes was
a genuine open question, resolved with the product owner before
implementation: latest log's rating, not an average across all rated logs.
Reasoning: it's already exactly what the Logged tab's `latest_logs` CTE
computes (`DISTINCT ON (beer_id) ... ORDER BY consumed_at DESC`), reused
as-is for Favorites/Wishlist at zero extra query complexity, and it keeps
the displayed rating consistent with the "recent" framing used everywhere
else (Beer Detail's own log list, the default sort). It also avoids building
a second, competing notion of "this beer's rating" ahead of ROADMAP.md's own
separate Phase 9 "Average rating" statistics task, which would need to
define that concept properly (weighting, recency, minimum sample size) —
sort order is the wrong place to improvise it. Null/tie-break behavior:
`NULLS LAST`, with `beer_id` as the final deterministic tie-breaker,
consistent with every other list in this app.

## 2026-09-16 — Phase 7: `CollectionRefreshSignal` — mutation-driven Collection freshness, not `RouteObserver`

Considered and rejected: a `RouteObserver`/`RouteAware` hook on `AppShell`
that calls `CollectionController.refresh()` when Beer Detail pops back to
the shell. It would have worked for the single case of "push Beer Detail,
pop back immediately" but not the equally common case of returning to a
*different* tab first (e.g. Discover) and switching to Collection later via
the bottom nav — `IndexedStack` tab switches never push/pop anything for
`RouteAware` to observe, so that path would leave Collection silently stale
until a manual pull-to-refresh. That gap directly conflicts with Phase 6's
own deferred "update collection state after logging" requirement, so it was
rejected rather than accepted as a known limitation.

Chosen instead: `CollectionRefreshSignal`
(`mobile/lib/shared/collection_refresh_signal.dart`), a one-method
`ChangeNotifier` that any successful mutation (`BeerLogController.submitCreate`/
`submitUpdate`/`submitDelete`, `CollectionStateController.setFavorite`/
`setWishlist`) calls after it succeeds. `CollectionController` listens and
calls `refresh()`. This needs no visibility/navigation awareness at all,
because `StatefulShellRoute.indexedStack` keeps every branch's widget
subtree — `CollectionController` included — mounted and responsive even
while a different tab is showing, so the notification is processed and the
data is fresh by the time the user actually switches to Collection,
regardless of which tab a mutation happened from. `AppShell` remains the
plain `StatelessWidget` it was before this phase; no navigation-aware
mechanism was added.

## 2026-09-16 — Phase 8: dedicated `/map/beers`/`/map/breweries`, not extended catalog endpoints

Considered: adding an `include_state=true` flag to the existing `GET
/beers`/`GET /breweries`, or having the Flutter client merge `/beers` with
`/collection/logged`/`/favorites`/`/wishlist` itself. Both rejected —
extending the catalog endpoints couples an unrelated personal-state concern
onto them; client-side merging means multiple round-trips per map render and
pagination drift between independently-paginated lists, exactly the "N+1"/
"duplicate entity" shape this project avoids elsewhere. A dedicated read
model (`MapBeerOut`/`MapBreweryOut`, `backend/app/repositories/map.py`)
joins catalog geo fields with per-user collection/log state in one query per
entity type, self-sufficient for the map's preview cards with no follow-up
request.

## 2026-09-16 — Phase 8: `/map/beers` runs inside `scoped_connection`, not a plain pooled query

`/map/beers` reads `user_beer_logs`/`user_beer_collection` to compute
`is_tried`/`is_favorite`/`is_wishlist` — the same RLS-protected, `app.user_id`
-scoped tables `CollectionRepository`/`BeerLogRepository` read (see the Phase
6 entry above). A first draft ran this as a plain pooled query relying only
on `WHERE ... = $1` predicates; corrected before shipping, since running as
`beerapp_backend` without the transaction-local `app.user_id` setting means
those predicates are the *only* thing preventing cross-user leakage — RLS is
meant to be a backstop against exactly that class of mistake, not something
a new query path can opt out of. `MapRepository.list_beers` now runs via the
same `scoped_connection(pool, user_id)` helper as the other two
repositories, with the explicit `user_id` predicates kept as defense-in-depth
on top of it, not instead of it. `GET /map/breweries` reads only catalog
tables and correctly uses a plain pooled connection — no RLS-protected table
is involved.

## 2026-09-16 — Phase 8: beer coordinate fallback is a paired CASE, never an independent per-field `COALESCE`

A beer's marker uses its own `(latitude, longitude)` if both are set,
otherwise its brewery's pair, otherwise no marker. The naive
implementation — `coalesce(b.latitude, br.latitude)` and
`coalesce(b.longitude, br.longitude)` as two independent expressions — was
rejected even though today's CHECK constraints (`..._lat_lng_paired` on both
tables) happen to make it safe in practice: it encodes "pick a source" as
two separate decisions that could, in principle, disagree (one falling back,
the other not, if either table's pairing invariant were ever weakened),
silently producing a marker at a hybrid coordinate that is neither the
beer's real location nor its brewery's. The actual query
(`backend/app/repositories/map.py`) uses one `CASE` per field, but each
re-checks *both* columns of whichever source it's reading, so latitude and
longitude are always sourced from the same row. Covered by
`backend/tests/integration/test_map_queries.py`'s
`test_fallback_never_mixes_beer_latitude_with_brewery_longitude` and the
own-pair/brewery-pair/excluded cases.

## 2026-09-16 — Phase 8: `/map/beers`/`/map/breweries` are unpaginated but capped, with an explicit `truncated` flag

Neither endpoint uses the shared `Page[T]` envelope. Marker rendering
(clustering, camera-fit) needs the complete current result set at once —
paginating it would visibly break both. But an unbounded response is still
unsafe as the catalog grows, so each query is capped server-side (`cap + 1`
rows fetched; `<= cap` → all returned, `truncated=false`; `> cap` → first
`cap` returned, `truncated=true`) via a small `CappedList[T]` response
schema. Rejected: silently truncating with no signal to the client — that
would make the map factually incomplete while looking successful, exactly
the kind of "correct-looking but wrong" behavior this project avoids. The
cap (2000) is a Phase 8 safety backstop, not real pagination; if it's ever
hit in practice, the actual fix is a viewport/bounding-box query, which
belongs to Phase 14's performance work, not a bigger cap here.

## 2026-09-16 — Phase 8: MapLibre + MapTiler, client-embedded key

**MapLibre** (`maplibre_gl`) was chosen per `PRODUCT.md` §8's stated
preference — open-source, no vendor lock-in, unlike Google Maps'/Mapbox's
proprietary SDKs and terms.

**MapTiler** was chosen as the Phase 8 tile/style provider — no tile
infrastructure existed to self-host, and MapTiler's free tier is standard
for MapLibre integrations. The API key is read via the same dart-define
mechanism as every other build-time config value (`mobile/config/dev.json`,
see `mobile/config/dev.example.json`), through a dedicated `MapConfig`
class (`features/map/data/map_config.dart`) — **not** through `Env`/
`Env.validate()`. This key is a **client-visible, quota-limited
credential**, categorically different from a Supabase `service_role`-style
secret: MapTiler's free tier is explicitly designed for keys to ship inside
client binaries/URLs, rate-limited and usage-tracked per key rather than
kept confidential. No backend tile-proxy was added — it would add latency
and server load for a key that isn't secret in the first place. If a
deployed key is ever abused (e.g. scraped from a public APK), MapTiler's
dashboard supports rotating it and adding client/domain/app-bundle
restrictions and quota limits — a deployment-time hardening step, not
something enforced by the app itself. The key must never be hardcoded in
Dart source, `AndroidManifest.xml`, generated files, tests, or docs.

## 2026-09-16 — Phase 8: an unconfigured map must never block app startup

`Env.validate()` hard-fails startup for genuinely required config
(Supabase, the API base URL) — a missing MapTiler key was initially
considered for the same treatment, then rejected: the map is one feature
among several, not core infrastructure like Supabase, so an unconfigured or
invalid map key must never prevent Auth/Discover/Collection/Profile from
opening. `MapConfig.isConfigured` is checked by `MapScreen` itself; when
false, it renders a localized "map unavailable" state instead of building a
`MapLibreMap`, and the rest of the app works normally. This also means
`MapConfig`, not `Env`, is the only place that knows the provider is
MapTiler — switching providers later touches one file, not
`MapController`/`MapScreen`.

## 2026-09-16 — Phase 8: client-side clustering only, no backend aggregation

`maplibre_gl`'s built-in GeoJSON-source clustering (`cluster: true`) groups
markers at render time; no backend clustering/aggregation endpoint was
built. At the current (and near-term) catalog scale, a backend aggregation
query is unjustified complexity for no visible benefit — client-side
clustering already produces correct, responsive behavior. If usage ever
shows this assumption breaking down, that is explicitly Phase 14's
performance work (alongside viewport/bounding-box querying for the
truncation cap above), not a Phase 8 concern.

## 2026-09-16 — Phase 8: single-select map mode, not independently combinable filters

`PRODUCT.md` §8 lists map "states" (All beers / Tried / Not tried /
Favorites / Wishlist / Breweries) as a flat list, read literally as mutually
exclusive rather than combinable — confirmed as a product decision before
implementation, since `ROADMAP.md`'s phrasing ("Tried / not-tried filters",
"Favorite filter", "Wishlist filter") could otherwise be read either way.
`MapMode` is a single enum (`all`/`tried`/`notTried`/`favorites`/`wishlist`/
`breweries`); `MapController` holds exactly one active mode, never a set of
independent booleans. Simpler UI, simpler query shape (`state=` is a single
value, not an AND-combination), and matches the literal product spec.

## 2026-09-16 — Phase 8: reusing `CollectionRefreshSignal` for map freshness, no new signal

The Tried/Not tried/Favorites/Wishlist map modes depend on exactly the same
`user_beer_logs`/`user_beer_collection` data `BeerLogController` and
`CollectionStateController` already notify `CollectionRefreshSignal` about
(see the Phase 7 entry above). Introducing a second, map-specific signal
would mean every future mutation site has to remember to notify *two*
signals to keep both Collection and the map fresh — an easy thing to forget,
and no better than the one that already exists doing double duty.
`MapController` listens to the same `CollectionRefreshSignal` instance
(passed into `MapScreen`/`MapController` alongside `MapRepository`/
`CatalogRepository`) and calls its own `refresh()` on a ping, reusing its
existing generation-counter staleness guard so a signal-triggered reload can
never overwrite a newer mode/search change. The signal's name still says
"Collection" — not renamed, since renaming it would touch every existing
call site for a purely cosmetic reason with no correctness benefit.

## 2026-09-16 — Phase 8: exact country-name search match only, never fuzzy/partial

The map's search bar resolves typed text to either a `country_id` (exact,
case-insensitive, trimmed match against a known country name) or a
free-text `q` region/name search — never a partial/fuzzy country match
(e.g. typing "belg" is a `q` search, not treated as Belgium). Rejected
partial matching because it's ambiguous by construction — "united" matches
both "United States" and "United Kingdom" — and PRODUCT.md/ROADMAP.md never
require it; `q` already covers "search for something that isn't an exact
country name" via the same free-text path used for regions.

## 2026-09-16 — Phase 8: live Android verification found a cluster-tap layer-mapping bug

Tapping a cluster (e.g. the 5-beer cluster near Belgium) zoomed the camera
**out** to a near-whole-world view instead of expanding it. Root cause: each
cluster is rendered as *two* layers sharing one source — a circle bubble and
a point-count text label — and MapLibre's native tap resolution on Android
can resolve a tap to either one, not always the circle. The original
`_handleFeatureTapped` mapped only the circle layer id to its source
(`layerId == beersClusterLayerId ? beersSource : breweriesSource`); a tap
resolved to the count-label layer fell through that binary check into the
*wrong* source, `getClusterExpansionZoom` returned its documented "unknown
cluster" sentinel of `0`, and that was applied directly to the camera.

Fixed in `mobile/lib/features/map/presentation/map_cluster_utils.dart`:
`clusterSourceIdForLayer` now explicitly maps all four cluster-related layer
ids (both entities' circle *and* count-label layers) to their two sources,
`parseClusterId` never substitutes a default for an unparseable id, cluster
expansion centers on the tapped cluster feature's own `geometry.coordinates`
(not the imprecise screen-tap `LatLng`), and a `getClusterExpansionZoom`
result `<= 0` (or a thrown exception) leaves the camera untouched instead of
applying it. Covered by `mobile/test/features/map/map_cluster_utils_test.dart`,
including a test reproducing the count-label-layer case specifically.
Re-verified live: repeated cluster taps now zoom in and split correctly
(5 → 1 + 4 → 1 + 2 + 2) with no duplicate markers.

## 2026-09-16 — Phase 8: live Android verification found a search camera-fit stale-data race

Searching an exact country name (e.g. "Belgium") correctly narrowed the
marker set but zoomed the camera **out** to a near-whole-world view instead
of into the searched country. Root cause: `MapController._load()` calls
`notifyListeners()` twice per search — once when `isLoading` flips to `true`
(before the repository call resolves) and once on completion.
`MapScreen._maybeFitCamera` fit the camera and recorded `_lastFitSignature`
on the *first* notification too, while `beers`/`breweries` still held the
*previous* (broad, pre-search) result; once the real filtered result
arrived a moment later, the signature was already "used" and the correct
fit was silently skipped.

Fixed by adding an eligibility guard, `cameraFitSignatureToRecord`
(`mobile/lib/features/map/presentation/map_camera_fit.dart`): a camera fit
is only ever computed for a completed, successful load (`isLoading` false,
`error` null) for a signature not already recorded — never on the
loading-start notification, and never on a failed one. An empty completed
result still records its signature (so a later `CollectionRefreshSignal`
refresh of the same search doesn't re-trigger a fit the user didn't just
ask for), but never moves the camera. Covered by
`mobile/test/features/map/map_camera_fit_test.dart`, including a test
reproducing the exact loading-start-vs-completed race. Re-verified live:
exact-country and free-text region searches now zoom correctly into the
result, single-point/identical-coordinate results still use the fixed
degenerate zoom, and clearing a search never forces a fit.

## 2026-09-17 — Phase 9: `fl_chart`, scoped narrowly to the two activity charts

The first charting dependency added to the app (`mobile/pubspec.yaml`).
Chosen over alternatives (`syncfusion_flutter_charts`, `graphic`,
hand-rolled `CustomPainter` widgets) for being pure-Dart with no native
platform code, widely used and actively maintained, and free of any
functional overlap with an existing dependency. Deliberately scoped to only
`MonthlyActivityChart`/`YearlyActivityChart` — the simple counts (unique
beers, discovered countries/styles/breweries, amount spent, favorites) stay
plain `AppCard`/`StatTile` widgets, never charted, since a bar/pie rendering
of a single number adds visual weight without adding information.

## 2026-09-17 — Phase 9: favorite style/country/brewery derive from Collection favorites, not log frequency or rating

ROADMAP.md's "Favorite style"/"Favorite country"/"Favorite brewery" tasks
don't specify a source. Two readings were considered: (a) the most
frequently *logged* dimension, or highest-average-rated, across
`user_beer_logs`; (b) the mode among the user's `user_beer_collection` rows
with `is_favorite = true`. Chose (b) — a "favorite" is what the user
explicitly marked as a favorite, not an inference from how often they logged
something (which conflates "tried a lot" with "liked a lot"). This is a
different concept from the Phase 7 decision that `sort=rating` means a
beer's *latest log's* rating, not an average — that decision is about
ranking already-collected beers within a tab; this one is about which
*dimension* (style/country/brewery) is most represented among favorites.
Neither contradicts the other.

Ties are broken deterministically: highest count of favorited beers first,
then case-insensitive name ascending, then a stable id ascending as the
final tie-break, so two entities with an identical display name (a name
collision on `breweries.name`, which — unlike `countries.name`/
`beer_styles.name` — has no case-insensitive uniqueness constraint) still
resolve to the same answer on every request rather than depending on
incidental row order. Zero favorites yields `null` for all three fields,
never an error and never a fabricated "most common" among nothing.

## 2026-09-17 — Phase 9: amount spent grouped strictly per currency, never summed

`user_beer_logs.price`/`currency` are per-log and independently nullable —
nothing assigns a user a default/preferred currency until Phase 12 profile
editing. Blindly summing `price` across logs with different currencies
would produce a number with no real meaning (e.g. "16.50" from 12.50 USD +
4.00 EUR). `amount_spent` is therefore a list, one entry per currency the
user has actually priced a log in (`group by currency`), and any log
missing either `price` or `currency` is excluded entirely rather than
folded into a default/null-currency bucket. This is a correctness
requirement, not a formatting preference — see docs/API.md.

## 2026-09-17 — Phase 9: monthly activity is a zero-filled rolling window, yearly activity is all-time and not zero-filled

`monthly_activity` and `yearly_activity` look like the same kind of
statistic but are deliberately different shapes. Monthly is the trailing 12
UTC calendar months, zero-filled via a `generate_series` CTE left-joined
against the actual per-month counts — always exactly 12 entries, so a chart
consuming it never needs to handle a variable-length x-axis or synthesize
missing months itself. Yearly is all UTC calendar years that have ≥1 log,
with no zero-fill — an all-time view has no natural "window" to zero-fill
against, and a user's account could span many empty years if it were
zero-filled from account creation. Both bucket via
`consumed_at AT TIME ZONE 'UTC'` specifically (not relying on the
database connection's session `timezone` GUC, which the pool can vary
across reused physical connections) so bucketing is reproducible regardless
of which pooled connection serves a given request.

## 2026-09-17 — Phase 9: country-based statistics reuse `/map`'s effective-country fallback

`countries_discovered` and `favorite_country` use
`coalesce(b.country_id, br.country_id)` — a beer's own country if set,
otherwise its brewery's — the identical pattern already established for
`/map/beers` (see the 2026-09-16 Phase 8 coordinate-fallback entries above).
Reusing it here rather than inventing a second country-resolution rule
keeps "which country does this beer belong to" answered consistently
everywhere in the app. Because `breweries.country_id` is `NOT NULL`, this
fallback can never itself produce `null` — unlike `style_id`, which is
genuinely nullable on `beers` and is excluded from `styles_discovered`/
`favorite_style` when absent, there is no "beer excluded from country
statistics" case to handle. The fallback is deliberately **not** extended to
style or brewery — a beer's style and brewery are always exactly
`beer.style_id`/`beer.brewery_id`, never inferred from anything else.

## 2026-09-17 — Phase 9: `StatisticsRepository` opts into `REPEATABLE READ`; every other `scoped_connection` caller is unchanged

`get_statistics` runs five separate SQL statements (overview counts,
amount-spent-by-currency, monthly activity, yearly activity, favorites) to
keep each one readable, rather than one large combined query. A plain `READ
COMMITTED` transaction (`scoped_connection`'s existing default) doesn't
guarantee all five see the same snapshot — a log or favorite committed by a
concurrent request between two of the five statements could produce an
internally inconsistent response (e.g. `total_logs` reflecting a new log
that `monthly_activity` doesn't yet).

Rather than collapsing the five queries into one hard-to-maintain statement,
or changing every caller's isolation level, `scoped_connection` gained an
optional `isolation` parameter (`backend/app/repositories/scoped_connection.py`),
defaulting to `None` — the exact behavior every existing caller
(`BeerLogRepository`, `CollectionRepository`, `MapRepository`) already had,
verified unchanged since none of them pass it. `StatisticsRepository` is the
only caller that passes `isolation="repeatable_read"`: a read-only aggregate
is exactly the case `REPEATABLE READ` is for — the snapshot is fixed at the
first statement and held for the whole transaction, with zero write-conflict
risk since nothing in `get_statistics` writes.

## 2026-09-17 — Phase 9: live Android verification found a hardcoded-English month-label bug

Switching the app to Spanish correctly localized every other string on the
Statistics screen, but the monthly activity chart's x-axis kept showing
English month abbreviations ("Jan Feb Mar..."). Root cause:
`MonthlyActivityChart` (`mobile/lib/features/statistics/presentation/widgets/monthly_activity_chart.dart`)
built its labels from a hardcoded `const List<String> _monthAbbreviations`
instead of routing them through `AppLocalizations`.

Fixed by adding 12 short-month ARB keys (`statisticsMonthJan`...`statisticsMonthDec`)
to `app_en.arb`/`app_es.arb` and a `_localizedMonthLabel(l10n, month)` helper
in the same file, replacing the hardcoded list — still no `intl` dependency
added, per the original scoping decision above. Covered by a new
`monthly_activity_chart_test.dart` (English renders English abbreviations,
Spanish renders Spanish ones and never the English ones). Re-verified live:
the chart now reads "ene feb mar abr may jun jul ago sep oct nov dic" in
Spanish with no clipping/overflow.

## 2026-09-17 — Phase 10: achievement catalog is code, not a database table

ROADMAP.md's exit criteria for Phase 10 require achievements to be
"data-driven" and that "adding a new achievement does not require major
application changes." Two ways to satisfy that were considered: a database
table of achievement definitions (key, category, threshold), or a static
catalog in backend code.

Chose code (`ACHIEVEMENT_CATALOG` in `backend/app/services/achievement_catalog.py`
— a `dict[str, AchievementDefinition]`). A DB table would need its own
migration, its own admin-facing write path (explicitly out of scope — "do
not build an admin achievement CMS" per the original planning brief), and
would still need backend code changes to interpret new metric/prerequisite
shapes; it buys nothing a code catalog doesn't already give. Adding a normal
future achievement is one dict entry plus one localized name/description ARB
pair per locale (`achievement_localizations.dart` on the mobile side) — no
migration, no new Dart class, satisfying "does not require major application
changes" without the operational overhead of a second source of truth.

Corollary: `user_achievements.achievement_key` is a plain `text` column, not
an FK to a definitions table and not a Postgres enum — validated only in
application code against the current catalog. A persisted row whose key is
later retired from the catalog is simply skipped when building the
`GET /achievements` response (the response is built by iterating the
catalog and checking it against the unlocked-rows map, never the reverse),
rather than being treated as a data-integrity error.

## 2026-09-17 — Phase 10: hybrid evaluation (Collection-mutation-triggered + read-time backfill), not purely lazy

The first design considered evaluating the achievement catalog only lazily,
inside `GET /achievements` — mirroring Statistics's fully-derived-on-read
philosophy, with zero eager hooks into existing mutation code. That has a
real gap given the Phase 10 starter catalog's *reversible* conditions
(favorite/wishlist state): a user could satisfy a condition (favorite a
beer) and reverse it (unfavorite) before ever opening the Achievements
screen. Since progress itself is never persisted, nothing would ever capture
that the condition was once true, and the achievement — despite being
permanent by product decision — would never unlock at all.

Fixed by introducing a small `AchievementEvaluator` service
(`backend/app/services/achievement_evaluator.py`) with one method,
`evaluate_and_unlock`, invoked from two places:

1. `CollectionService.set_state`, immediately after its own mutation
   succeeds — the primary trigger for reversible achievements, so an unlock
   is captured at the moment a condition first becomes true, before it can
   ever be reversed unseen.
2. `AchievementsService.get_achievements`, before building its response — an
   idempotent repair/backfill path (covers e.g. data that predates this
   feature), not the only place unlocks can happen.

No background worker or queue: `evaluate_and_unlock` is cheap (two small
`COUNT(*)` queries against `user_beer_collection` for the current 3-entry
catalog) and fully idempotent (`INSERT ... ON CONFLICT DO NOTHING`), so
calling it synchronously inside an existing request is not a scaling
concern at this stage. `BeerLogService` is deliberately **not** wired to
this evaluator in Phase 10 — there is no approved log-derived starter
achievement, so adding the hook now would be speculative; see the starter
catalog scope entry below.

## 2026-09-17 — Phase 10: Collection mutation and achievement evaluation share one database transaction

Triggering evaluation from `CollectionService.set_state` (previous entry) is
not sufficient by itself if the mutation and the evaluation run in separate
transactions: the Collection write could commit, evaluation could then fail
for any reason, and if the condition is reversed before anything ever
retries, the fact that it was once satisfied is unrecoverably lost — exactly
the gap the previous fix was meant to close.

Fixed by making both run inside the same transaction. `AchievementsRepository`
and one method of `CollectionRepository` (`set_state_on_connection`, an
extraction of the existing `set_state` SQL with no logic change) are written
to operate on an already-open `asyncpg.Connection` passed in by the caller,
rather than each opening its own `scoped_connection`. `CollectionService.set_state`
now owns the transaction boundary itself: it opens one `scoped_connection`,
runs the Collection upsert/delete on that connection, then runs
`AchievementEvaluator.evaluate_and_unlock` on the *same* connection, all
before the block exits and commits. If evaluation raises, the exception
propagates out of that block and the whole transaction — Collection mutation
included — rolls back.

This is a deliberate, accepted trade-off: an unexpected bug in achievement
evaluation now surfaces as a 500 on the Collection `PATCH` itself, rather
than silently succeeding at the mutation while losing the achievement
opportunity. Considered acceptable because `evaluate_and_unlock` is small,
pure, and has direct unit coverage
(`backend/tests/services/test_achievement_evaluator_service.py`), plus a
dedicated integration test written to prove the real-Postgres rollback
behavior (`backend/tests/integration/test_collection_achievement_atomicity.py`)
— not yet executed against a disposable database in this environment (see
ROADMAP.md Phase 10 status), so the rollback claim itself rests on the unit
test's proxy assertion (the service propagates the evaluator's exception
rather than swallowing it) until that integration run happens.
`AchievementsRepository` not taking a `pool` in its constructor — every
method takes a connection instead — is the resulting, deliberate deviation
from every other repository in this codebase; `AchievementsService.get_achievements`
opens its own `scoped_connection` for the read-time backfill path, so the
same connection-taking repository methods serve both call sites without
duplicating any SQL.

`user_achievements`'s RLS also uses two explicit command-specific policies
(`backend_select_own`, `backend_insert_own`) rather than the single `for
all` policy used on `user_beer_logs`/`user_beer_collection` — see
`docs/DATABASE.md` for the shape; recorded here because it's the same
permanence-first reasoning as the grant/transaction decisions above:
defense-in-depth matching the already-narrower `SELECT, INSERT`-only grant,
not a case the established single-policy convention required deviating
from.

## 2026-09-17 — Phase 10: starter catalog excludes logged-activity counts and `profile_complete`; `collection_curator` checks unlocked prerequisites, not simultaneous live metrics

The first proposed starter catalog included achievements based on counts of
logged beers, countries/styles/breweries discovered through logs, reviews
written, and ratings given — all categories PRODUCT.md §16 lists as
acceptable. **Rejected on review**: the mechanic of counting *logged
consumption activity* toward an unlock threshold creates an incentive to log
more drinking activity to reach a number, which sits outside the approved
product boundary (PRODUCT.md §3 / CLAUDE.md Responsible Product Design)
even though the category labels themselves are fine. The categories remain
in `AchievementCategory` (backend and mobile) for a future, non-incentivizing
data source (e.g. Discover-driven "viewed" activity) — only their Phase 10
*definitions* are deferred, not the architecture's support for them.

A `profile_complete` achievement (reusing the existing client-side
`Profile.isComplete` definition, `mobile/lib/features/auth/domain/profile.dart`)
was also considered and deferred: the backend has no grant at all on
`public.profiles` today (it's read/written directly by the client via
Supabase's native `auth.uid()` RLS, never proxied through `beerapp_backend`),
so evaluating it server-side would require a new grant migration — a real
cross-system coupling change not justified for one starter achievement. Can
be revisited alongside Phase 12 (Profile and Settings).

The shipped Phase 10 starter catalog is three Collection-only entries:
`collection_first_favorite`, `collection_first_wishlist`, and the compound
`collection_curator`. `collection_curator` was originally specified as
"favorites_count >= 1 AND wishlist_count >= 1" checked against live metrics
— but since those counts are live and reversible, a user who favorited then
unfavorited something, then later only wishlisted something, could never
trigger it, even though `collection_first_favorite` stayed permanently
unlocked the whole time. Fixed by giving `AchievementDefinition` a second
way to specify a condition, `prerequisite_keys` (other catalog keys that
must already be permanently unlocked), used instead of `requirements` for
compound entries — permanence-safe by construction, since it checks the
already-unlocked set rather than live metrics evaluated together.

## 2026-09-18 — Phase 11: dedicated `GET /beers/barcode/{barcode}`, canonicalization enforced at the request boundary

Considered and rejected: extending `GET /beers` with a `barcode` filter
(the precedent Phase 5's `q` set — see the "gains `q`, not a parallel search
endpoint" entry above). Rejected here specifically because a barcode lookup
is single-result-or-404 semantics, not a searched/filtered *list* — forcing
it through the `Page[T]` envelope would be a worse fit than the small
duplication of a second endpoint, and unlike `q`, a barcode lookup shares no
pagination/filter-composition logic with `list_beers` worth reusing.

Canonicalization/validation (`backend/app/services/barcode.py`) is wired in
via a Pydantic v2 `Annotated[str, AfterValidator(canonicalize_barcode)]` on
the route's path parameter, not a service-layer check after the fact. A
`ValueError` raised inside the validator becomes an ordinary FastAPI
`RequestValidationError` → the existing 422 handler — no new exception class,
no new handler, and validation happens before the repository is ever
touched. `canonicalize_barcode` has its own direct unit tests
(`backend/tests/services/test_barcode_canonicalization.py`), independent of
the route.

## 2026-09-18 — Phase 11: `mobile_scanner`, version-pinned after reading its source, not assumed from memory

Chosen over `flutter_barcode_scanner` (less actively maintained, more opaque
native UI, harder to control camera lifecycle manually) and `camera` +
`google_mlkit_barcode_scanning` (two packages, more transitive dependencies,
more moving parts for the same outcome). No cloud service, no account, no
API key — camera frames never leave the device; the backend only ever
receives an already-decoded digit string.

Pinned to `^7.4.2` (Dart `^3.7.0` / Flutter `>=3.29.0` required — compatible
with this project's Flutter 3.47.4 / Dart 3.13.3) after fetching and reading
its actual changelog/source rather than implementing against a remembered or
assumed API shape. This directly resolved several version-specific design
questions instead of guessing:

- `MobileScannerController(autoStart: false, formats: [...])` and manual
  `start()`/`stop()`/`dispose()` are current, valid API for this version.
- The plugin already self-guards a double `start()` call
  (`MobileScannerErrorCode.controllerInitializing`/`controllerAlreadyInitialized`)
  and, critically, throws a distinct `controllerNotAttached` if `start()` is
  called before a `MobileScanner` widget has actually mounted — this is the
  mechanism `ScanController`'s lifecycle design (below) is built around,
  rather than an assumption about when it's "probably safe" to call it.
  Verified directly against the installed package's source
  (`mobile_scanner_controller.dart`/`mobile_scanner_error_code.dart`), not
  the package's own documentation prose alone.
- The currently-recommended detection pattern is listening to
  `controller.barcodes` directly, not the `onDetect` widget callback —
  `ScanController` takes an injectable `barcodeStream` (defaulting to
  `cameraController.barcodes`) specifically so tests can feed synthetic
  `BarcodeCapture`s without touching platform channels at all.
- `controller.dispose()` is `async`; `ChangeNotifier.dispose()` (and
  therefore `State.dispose()`) is not. `ScanController.dispose()` sets a
  synchronous `_disposed` flag first (checked by every late-completing
  callback before it touches state or calls `notifyListeners()`), cancels
  its stream subscription synchronously, then chains
  `cameraController.stop().then((_) => cameraController.dispose())`
  unawaited with a `catchError` — stop-then-dispose in the correct order,
  errors logged rather than left as an unhandled async rejection (this also
  covers the legitimate case of disposing a controller that was never
  successfully started, which reaches a real platform call and can
  genuinely fail on some devices/emulators).

No `permission_handler` dependency was added. `mobile_scanner` already owns
camera permission end-to-end (`MobileScannerController.value.hasCameraPermission`,
the `permissionDenied` error code) — adding a second package to manage the
same OS permission would create two independent paths that could disagree
about its state. The one capability `permission_handler` would have added —
distinguishing "denied" from "permanently denied" to show an "Open Settings"
button — was deliberately not built: live verification on an Android
emulator confirmed that after two denials, a fresh `start()` attempt just
silently fails to re-prompt (Android's own behavior, not something the app
needs to detect), and the denied-state copy explains this in words ("enable
it in your device's system settings") instead. A settings-launcher button
can be added later if real user feedback calls for it, without weakening the
current one-package-owns-permission design in the meantime.

## 2026-09-18 — Phase 11: camera lifecycle stops before navigating, guarded restart after, `TickerMode` (not a hand-rolled visibility signal) drives tab-active state

Three responsibilities were deliberately kept on three separate methods
(`ScanController.resetForScanning` / `startIfEligible` / `stopScanner`)
rather than one combined "retry" call, specifically so a decoded barcode's
navigation sequence could be gotten right: on a successful lookup, the
controller sets a `_navigationInProgress` guard, calls `stopScanner()`, and
only then flips to `found`. The **screen** (not the controller) reacts by
`await`ing `context.push(AppRoutes.beerDetailPath(...))` — the camera stays
stopped for the beer detail screen's entire lifetime, including if the user
backgrounds the app while it's open. Only once that `push` future resolves
(user returned) does the screen clear the guard and attempt a *guarded*
restart — eligible only if the Scan tab is still active and the app is still
resumed, since returning from a push can land on any tab, not necessarily
back on Scan.

`TickerMode.valuesOf(context).enabled` (read in `didChangeDependencies`,
`TickerMode.of` having been deprecated in a Flutter release before this
project's 3.47.4) is the signal for "is the Scan tab actually the active
`StatefulShellRoute.indexedStack` branch" — go_router keeps every branch's
navigator mounted, so `ScanScreen`'s own `initState`/`dispose` never fire on
an ordinary tab switch, and `TickerMode` is what go_router itself flips for
the inactive branches. No custom visibility-tracking mechanism was built.
`WidgetsBindingObserver`/`AppLifecycleState` covers the orthogonal
app-background/foreground case; both signals gate `startIfEligible()`
independently.

Live emulator verification (see `ROADMAP.md`'s Phase 11 status) confirmed
this design actually holds, via `adb logcat`'s `CameraService` lines, not
just by reading the code: switching away from Scan stops the camera,
switching back reopens it cleanly with no `controllerNotAttached`/
`controllerAlreadyInitialized` errors, and the same holds across app
background/foreground.

## 2026-09-18 — Phase 11: `beers.barcode` stays a single nullable column; multi-barcode support explicitly deferred

The column and its unique partial index already existed (added in Phase 3,
anticipating this phase — see `docs/DATABASE.md`). Reusing it as-is, rather
than introducing a normalized `beer_barcodes` table to support multiple
codes per beer (e.g. regional packaging variants), was the deliberate
smallest-correct choice for this milestone: no current requirement needs
more than one barcode per beer, and normalizing ahead of an actual need
would be exactly the kind of speculative groundwork this project's rules
warn against. This is recorded as an explicit, known limitation — **at most
one canonical barcode per beer** — not silently described as if the current
schema already supported packaging variants. A `beer_barcodes` table is the
correct future shape if that need materializes; no code here assumes the
column can't eventually be superseded by one.

UPC-E was deferred for the same reason from the decoding side: no
unambiguous canonical mapping to the existing EAN-8/EAN-13/UPC-A→GTIN-13
scheme was established, so it is neither enabled in the mobile scanner's
`formats` list nor accepted by `canonicalize_barcode` — an 8-digit UPC-E
input is rejected, not silently treated as EAN-8.

## 2026-09-18 — Phase 11: an existing "13-digit-shaped" seed barcode was actually invalid; fixed, not just replaced

While implementing the shared `canonicalize_barcode` check-digit validation,
the pre-existing "Guinness Draught" dev seed barcode (`5000213007072`,
present since Phase 3) was hand- and then programmatically verified against
the standard GS1 mod-10 algorithm and found to fail it — the correct check
digit for that payload is `5`, not `2`. This was not a hypothetical risk:
it's exactly the class of bug this session's own barcode-canonicalization
work was written to catch. Corrected to `5000213007075` in
`backend/scripts/seed_catalog.py`, with two more deliberately synthetic
(never presented as real commercial codes), checksum-valid fixtures added
(one more EAN-13, one EAN-8) so dev/testing has multiple real lookups —
while most seeded beers deliberately keep `barcode = null`, since a beer
with no barcode is normal product behavior, not a gap to fill in. A
regression test (`TestSeedCatalogBarcodesAreValid` in
`backend/tests/services/test_barcode_canonicalization.py`) now verifies
every non-null seeded barcode programmatically rather than by eyeballing it,
so this class of bug can't silently reappear.

## 2026-09-18 — Phase 12: `preferred_currency` stays direct-Supabase; account deletion goes through FastAPI

Two profile-lifecycle changes land in the same phase, and they deliberately
take opposite architectures — recorded here so the asymmetry reads as a
decision, not an inconsistency.

`preferred_currency` is a simple owned-row read/write, exactly like
`username`/`display_name` before it: the existing `select_own`/`update_own`
RLS policies and the table-level `grant select, update ... to authenticated`
already cover it with zero migration changes beyond `ALTER TABLE ADD
COLUMN`/`ADD CONSTRAINT` (see `docs/DATABASE.md`). Routing this single field
through FastAPI would add a network hop and a new backend surface for a
write Supabase's own RLS already secures correctly — it would be new
architecture for no behavioral benefit, breaking the established "profiles
is 100% direct-Supabase" pattern from Phase 2 for no reason.

Account deletion is different in kind, not degree. Deleting an `auth.users`
row requires the Supabase Auth **Admin** API, which needs a service-level
secret no mobile client may ever hold (`CLAUDE.md`'s "never expose
service-role keys to the mobile client"). That secret can only live
server-side, so this one operation necessarily goes through FastAPI even
though nothing else about `profiles` does. `AccountService`/`SupabaseAdminClient`
(`backend/app/services/`) touch no Postgres table at all — they call the
Admin API only, letting the existing `ON DELETE CASCADE` foreign keys (see
`docs/DATABASE.md`) handle every dependent row.

## 2026-09-18 — Phase 12: current Supabase secret-key model (`SUPABASE_SECRET_KEY`), optional at boot

Supabase is transitioning away from the legacy `service_role` API key toward
`sb_publishable_...`/`sb_secret_...` keys (confirmed against current official
Supabase docs during planning, not assumed from memory — see the next entry).
`backend/app/config.py`'s `supabase_secret_key: str | None = None` uses this
current naming and key shape, not `SUPABASE_SERVICE_ROLE_KEY`/a legacy JWT.

Made optional (`| None`, no `Settings` validation failure when unset)
rather than required, unlike `supabase_url`/`database_url`: this is the
first backend secret that gates exactly one endpoint (`DELETE /account`)
rather than something every request needs. Requiring it would mean a
developer who hasn't configured account deletion yet can't run the backend
at all — disproportionate for one feature. `SupabaseAdminClient.delete_user`
checks for a missing key itself and raises `SupabaseAdminClientNotConfigured`
(a `SupabaseAdminClientError` subtype) before attempting any request, which
the route maps to `503` — "this feature isn't available right now," not a
boot-time failure or a `500`. `.env.example` documents the field with an
empty placeholder only; the real value is configured directly in the
git-ignored local `.env`, never requested in chat, never logged, never
returned in any API response.

## 2026-09-18 — Phase 12: Supabase Admin API auth is `apikey`-header-only, verified against current docs, not assumed from the legacy pattern

Before implementing `SupabaseAdminClient`, the current Supabase Admin API
contract was fetched and read directly
(https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys),
rather than assuming the legacy `Authorization: Bearer <service_role-jwt>`
pattern still applies to the new key format. It doesn't: `sb_secret_...`
keys are not JWTs, and the docs explicitly warn that sending one on
`Authorization: Bearer` (which many Supabase clients do by default for the
old key shape) causes the platform to try to parse it as a JWT and reject
the request with "Invalid JWT". The correct, verified shape is the `apikey`
header only. `SupabaseAdminClient.delete_user`
(`backend/app/services/supabase_admin_client.py`) sends exactly that, and
`backend/tests/services/test_supabase_admin_client.py` asserts both halves
of this directly — the header is present and correct, and no `Authorization`
header is ever sent — so a future regression back to the legacy pattern
would fail a test rather than fail silently against a live project.

## 2026-09-18 — Phase 12: avatar and preferred units deferred entirely

ROADMAP.md's Phase 12 checklist names both `Avatar` and `Preferred units` as
tasks. Both are deferred rather than built, on explicit product direction
given before implementation:

- **Avatar** would require a new `avatar_url` column, a Supabase Storage
  bucket, an image picker/cropper dependency, and camera/media permissions —
  real new infrastructure with no current consumer, exactly the kind of
  speculative groundwork `CLAUDE.md`/`ROADMAP.md` warn against. `ProfileScreen`
  keeps its existing placeholder icon; no column was added.
- **Preferred units** was scoped down for a concrete reason, not just
  deferred by default: nothing in the app today actually *displays*
  `serving_volume_ml` with any unit formatting at all — it's a raw ml
  integer everywhere (the log form, any future log detail view). Adding a
  `preferred_units` column and picker with no consuming display logic would
  be a preference nobody's UI reads yet.

Both remain unchecked in `ROADMAP.md`'s Phase 12 section with an explicit
deferral note, per Roadmap Rule 9 (annotate, never silently drop).

## 2026-09-18 — Phase 12: legal links are a static in-app placeholder, not real content

`ROADMAP.md`'s "Legal links" task is satisfied by two Settings rows
(Privacy Policy, Terms of Service) that navigate to the existing
`mobile/lib/shared/widgets/placeholder_screen.dart` — the same "coming soon"
widget used for genuinely-not-built-yet Phase 1 destinations — rather than
linking to any real document. No `url_launcher`, no `WebView`, no fabricated
URL: none of that infrastructure has a real destination to point at yet.
Real legal content (and the decision of how to present it — in-app page vs.
external link) is explicitly a pre-release concern, tracked under
`ROADMAP.md`'s existing Phase 14/15 sections, not invented here to fill the
row.

## 2026-09-18 — Phase 12: `profile_complete` achievement remains unenabled

Phase 10 deferred a `profile_complete` achievement specifically because
FastAPI had no grant on `public.profiles` at all, noting it "can be
revisited alongside Phase 12." Revisited, and still not built: this phase's
only new backend code (`AccountService`/`SupabaseAdminClient`) calls the
Supabase Auth Admin API, not Postgres, and never acquires any `SELECT`/
`UPDATE` grant on `profiles`. The precondition Phase 10 was waiting on still
doesn't hold, so nothing here changes that achievement's status — recorded
as a deliberate non-change, not an oversight.

## 2026-09-18 — Phase 12: `updateEditableProfile` is one atomic Postgrest call, not two sequential writes

The first design considered for Edit Profile called the existing
`ProfileRepository.setUsername` and a new, independent `setDisplayName`
sequentially. Rejected: if the username write succeeds and the display-name
write then fails (or vice versa), the profile ends up in a state the user
never asked for and the screen has no correct way to report — "it partially
saved" is not a state this app's error model has a message for anywhere
else. `SupabaseProfileRepository.updateEditableProfile`
(`mobile/lib/features/auth/data/supabase_profile_repository.dart`) issues a
single `.update({'username': ..., 'display_name': ...})` Postgrest call
instead — one statement, so the row is guaranteed either fully updated or
not updated at all. `setUsername` itself is untouched and still used by the
onboarding `CompleteProfileScreen` flow, which only ever has a username to
write. Both methods share one static, independently-tested error-mapping
function (`mapUsernameWriteError`), since `display_name` has no format
constraint of its own — the username CHECK/unique index is still the only
constraint either write path can violate.

## 2026-09-18 — Phase 12: post-delete local sign-out relies on gotrue's verified `_signOut` sequencing, not a new session-clearing API

After a confirmed `DELETE /account` succeeds, the deleted user's local
Supabase session still needs to clear immediately so the app reaches
`unauthenticated` — but the account is already gone server-side, so the
existing `signOut()`'s network revoke call could plausibly fail. Read
directly from the installed `gotrue-2.27.2` package source
(`gotrue_client.dart`'s `_signOut`, not assumed): for any scope other than
`others` (the default, `local`, included), local session state is cleared
and the `signedOut` event fires **synchronously, unconditionally, before**
the network revoke call is even attempted; only 401/403/404 from that call
are swallowed, anything else rethrows. `SignOutScope.local` is *not* a
"skip the network call" mode either — it still posts to
`/logout?scope=local`, just requesting a narrower server-side revocation;
this SDK version has no built-in "local-only, no network attempt" method.

Given that, local state is already guaranteed correct the moment
`signOut()` is called, regardless of what it does next — so the fix is at
the call site, not a new SDK capability: Settings' delete-account flow
wraps the post-delete `signOut()` call in a try/catch that discards any
exception, rather than surfacing a false "something went wrong" error on a
screen that's already navigating away. `FakeAuthRepository.signOut()`
(`mobile/test/fakes/fake_auth_repository.dart`) was updated to clear local
state and fire `signedOut` *before* consulting `errorToThrow`, mirroring
this exact verified sequencing, so the regression test in
`settings_screen_test.dart` (a throwing `signOut()` still reaching
`unauthenticated` with no error shown) actually exercises the real ordering
rather than a fake that happened to already behave differently.

**Documented residual risk, not closed this phase**: deleting `auth.users`
invalidates refresh sessions, but an already-issued **access** JWT is a
stateless, signature-verified token `get_current_user` never checks against
a revocation list — it remains technically valid until its own `exp`
(commonly ~1 hour) even after the account and all cascaded data are gone.
Every table it could still address now has zero rows for that id, so no
other user's data is exposed, but this must never be described as instant
invalidation of already-issued access tokens.

## 2026-09-18 — Phase 13: a contribution is a private proposal in its own tables, never a catalog row

Two typed tables — `beer_contributions` and `brewery_contributions` — rather
than inserting an unverified row into `beers`/`breweries`, and rather than one
generic `contributions` table with a JSON payload.

Rejected: **unverified catalog rows** (`PRODUCT.md` §21's "submitted as
unverified"). Catalog reads (`BeerRepository`, `MapRepository`, statistics,
achievements) deliberately do not filter on `verified`, so an unverified
`beers` row would appear in Discover, on the map and in a user's statistics the
instant it was inserted — exactly what ROADMAP's exit criterion ("user
contributions cannot overwrite verified catalog data directly") and the
`CLAUDE.md` Data Model Rule forbid. Read here as: the *submission* is
unverified/pending, and a catalog row appears only after moderation.
`PRODUCT.md` §21 was clarified accordingly.

Rejected: **one generic table + JSON**. The two entities have different
required fields and constraints (a brewery needs a country; a beer's brewery is
canonical-or-proposed, its style optional), so a single table would be sparse
with cross-column CHECKs, and a JSON payload would give up the foreign keys,
CHECKs and typed columns that make a future moderator's job safe. The cost is
some structural repetition between the two tables (the lifecycle columns) —
accepted.

The structural guarantee, not a convention: no repository method writes a
catalog table, `beerapp_backend` holds no privilege to (`SELECT` only there,
unchanged), and the mobile app has no route to. Enforced and tested at the
privilege level (`test_backend_role_still_cannot_write_any_catalog_table`) and
end to end (`test_a_submission_never_touches_a_verified_catalog_row`).

## 2026-09-18 — Phase 13: contributions are FastAPI-mediated, not direct Supabase writes

Not chosen merely because `profiles` uses direct Supabase, nor merely because
FastAPI exists — chosen because every requirement points the same way. A
submission must (1) validate references against the canonical catalog, (2)
reuse the one barcode canonicalizer/checksum in Python
(`backend/app/services/barcode.py`) rather than duplicate it in Dart or RLS
SQL, (3) run duplicate checks against tables the client cannot read, (4) fix
`status` server-side (the request schema has no such field), and (5) do check +
insert in one transaction. Direct writes under `authenticated` RLS could do
only the last of those. It reuses the `user_achievements` pattern exactly:
`SELECT`/`INSERT`-only grants to `beerapp_backend`, two command-specific
`app.user_id` policies, `scoped_connection`; no new role, secret or
dependency, and `authenticated` gets nothing.

## 2026-09-18 — Phase 13: free-text proposals for a missing brewery, style or country

Decided with the user: a beer whose brewery is not in the catalog carries
`proposed_brewery_name` (exactly one of it and `brewery_id`), and the forms
offer a "Not listed" option for brewery, style and country that reveals a text
field and sends `proposed_brewery_name` / `proposed_style_name` /
`proposed_country_name`. Recorded explicitly as a *proposal*: it never creates
a `countries`/`beer_styles`/`breweries` row. There is intentionally **no
foreign key or reference from a beer contribution to a brewery contribution**;
the user is never forced to submit a brewery first, and "Suggest a brewery"
stays an independent feature satisfying ROADMAP's own "Brewery submission"
task. This matters in practice: the dev seed has only 10 countries and 8
styles, so canonical-only pickers would have blocked real users. The cost is
that a moderator must resolve a proposed name to a canonical row at approval
time.

## 2026-09-18 — Phase 13: duplicate detection is deterministic; hard blocks vs. soft warnings

Names are not unique in the catalog by design (`beers.official_name` and
`breweries.name` carry no unique constraint), so a same-name match can only
ever be a *warning*. The rules:

- **Hard block (`409`)**: a catalog beer already owns the barcode
  (`barcode_in_catalog`); the caller already has an identical pending
  suggestion (`already_submitted`, backed by per-user partial unique indexes so
  a retry/double-tap cannot create two rows).
- **Soft, non-blocking** (returned by a read-only
  `GET .../duplicate-candidates`, not a `409`, which keeps the error envelope
  unchanged): same-name catalog beers at the same/matching brewery, same-name
  catalog breweries, and `pending_barcode_duplicate_exists`.

Deterministic on purpose (case-insensitive equality on a trimmed,
whitespace-collapsed name; no fuzzy matching, no `unaccent`): predictable,
testable, index-friendly. Catalog-side comparison uses `lower(name)` so it is
served by the existing `beers_official_name_idx`/`breweries_name_idx`; a name
alone never matches (it must align with the brewery), or "Pilsner" would match
half the catalog. Known limits: accent-insensitive matching and cross-user
name duplicates are not handled — the latter are private by design and left to
the future moderator.

## 2026-09-18 — Phase 13: another user's pending barcode is flagged, not blocked, via a boolean-only `SECURITY DEFINER` function

Decided with the user ("allow and flag"). Two users may both have the same
barcode pending; the second submitter sees a non-blocking warning ("Another
pending suggestion may already include this barcode") and may still submit.
A hard block was rejected: with no moderator yet, one wrong first submission
would hold a barcode indefinitely.

The flag needs one cross-user fact that owner-only RLS (correctly) hides. The
policy is **not** widened and `beerapp_backend` is **not** given cross-user read
access: a narrowly scoped `private.other_user_pending_beer_barcode_exists(text)
returns boolean` answers it. It is the first `SECURITY DEFINER` function since
`private.handle_new_user()` and follows its precedent (non-API-exposed `private`
schema, `set search_path = ''`, schema-qualified body, no dynamic SQL,
`EXECUTE` revoked from `PUBLIC`/`anon`/`authenticated`, granted only to
`beerapp_backend`). Identity is read from `app.user_id` inside the function, not
passed in, so "exclude my own rows" cannot be bypassed, and no identity yields
`false` (fails closed). The API and UI carry only the boolean — never the row,
its id, its owner, or any detail. The one new privilege is `USAGE` on schema
`private` for `beerapp_backend`, which grants no table access. Its behavior and
privileges are covered by real-Postgres tests (`test_contributions_rls.py`).
There is deliberately no unique index on a pending barcode; a non-unique partial
index serves the function and a future moderator's lookup.

## 2026-09-18 — Phase 13: the moderation lifecycle is in the schema now; approval is deferred and blocked on admin identity

ROADMAP asks for a "moderation-ready data model", so `status`
(`pending`/`approved`/`rejected`), `reviewed_at`, `review_note` and
`resolved_beer_id`/`resolved_brewery_id` exist now, tied together by CHECKs
(`(status = 'pending') = (reviewed_at is null)`, `(status = 'approved') =
(resolved_* is not null)`, no note while pending). **Only `pending` is reachable**:
no endpoint, role or UI can set another status, `beerapp_backend` has no
`UPDATE`/`DELETE`, and the `INSERT` policy pins `status = 'pending'`. The client
also treats an unrecognized status as `unknown`, never as approved.

**Approval is deliberately not implemented, and this is a blocker rather than
an oversight**: BeerApp has no admin/moderator identity or role architecture
(`PRODUCT.md` §22 keeps administration out of the mobile app), so any "approve"
endpoint would have to invent one, which would be insecure. Design intent for
when it exists — one privileged, server-side transaction that locks the pending
row, re-checks the barcode/name against `beers`, inserts or merges the canonical
row with the right `verified`/`source`, and marks the contribution approved with
`resolved_*` set; callable by no normal user. Until then contributions stay
pending and the catalog is unchanged, which is the documented state.

## 2026-09-18 — Phase 13: `ConflictError` / HTTP 409 with machine-readable codes

First 409 in the API. `ConflictError(code, message)` puts a *specific* code in
the standard `{error: {code, message}}` envelope (`barcode_in_catalog`,
`already_submitted`) instead of the generic `conflict`, because the client must
branch on which of the two happened without parsing prose; the envelope's shape
is unchanged. The service maps `asyncpg` violations by **constraint name**
(`UniqueViolationError` on the four own-duplicate indexes →
`already_submitted`; `ForeignKeyViolationError` on the three catalog FKs → `404`
like `beer_logs`), so those names are part of the contract and are given
explicitly in the migrations and pinned by a test. An unrecognized violation
(including `user_id_fkey`, e.g. a still-valid JWT for a just-deleted account) is
re-raised as a `500` rather than misreported. Flutter maps `409` to
`ConflictApiException` (keeps `code`); localized text always comes from the
feature's own mapping, never from the backend message.

## 2026-09-18 — Phase 13: contributions are immutable and private this phase

No edit, withdraw, delete, per-item detail, or other users' visibility: ROADMAP
asks for submission *history*, not editing, and immutability is enforced by the
grants (no `UPDATE`/`DELETE`). A contributor's identity is never exposed in any
API or UI; the only cross-user signal is the boolean above. Rate limiting, trust
scoring and other abuse tooling belong to Phase 14, not here; the safeguards
that belong naturally to this design are in place (auth required, length/shape
constraints, ownership from the JWT only, own-duplicate uniqueness,
server-controlled status). Images, media and Supabase Storage were not touched
(none is required, matching Phase 12's deferral).

## 2026-09-18 — Phase 13: findings recorded while verifying (not fixed here)

- **The older integration suite had never been run against a real database.**
  Executed for the first time against a disposable local Postgres 16, 79 of its
  111 pre-existing tests fail, for test-side reasons (see the status note in
  `docs/DATABASE.md`). Not fixed: outside this phase, and each cause is only
  read from the error output. Phase 13's own 81 integration tests pass.
- **Phase 11's note on UPC-E is slightly overstated.** An 8-digit input is
  accepted whenever it happens to carry a valid EAN-8 check digit (e.g.
  `01234565`), so "an 8-digit UPC-E input is rejected, not silently treated as
  EAN-8" holds only for UPC-E codes that fail that check. The behavior is the
  inherent ambiguity of an 8-digit code, unchanged here; the claim, not the code,
  needed the caveat.
- **Verification technique.** With no configured `INTEGRATION_DATABASE_URL`, the
  migrations and tests were run against an embedded Postgres 16 installed
  outside the repository (scratch directory, no repo dependency added) with a
  minimal `auth.users`/`anon`/`authenticated` scaffold — a faithful check of the
  SQL, constraints, RLS and function privileges, but *not* a Supabase project: it
  does not exercise Supabase's own `auth` schema, PostgREST, or the real Supabase
  roles/defaults.

## 2026-09-21 — Phase 14: security review (posture after hardening, and what it does not cover)

A review of the security posture as it stands after Phase 14 Stages 1-5. Every
control below is backed by an automated test unless it says otherwise; anything
that could not be exercised is listed under "Not covered".

**Controls in place**

- **Token verification.** `app/auth/` verifies Supabase JWTs locally against the
  project's JWKS: signature, an algorithm allowlist (`RS256`/`ES256`, chosen from
  the matched key's own type, never from the token header), `exp`, `iss`, `aud`
  and `role`. Every failure is one uniform 401.
- **Bounded JWKS refresh.** A token's `kid` is attacker-supplied, so the key
  cache cannot be allowed to trigger an outbound fetch per request. A loaded key
  set is trusted for at most `JWKS_CACHE_TTL_SECONDS` (default 600 s); an unknown
  `kid` or a failed load can trigger a refresh at most once per
  `JWKS_REFRESH_COOLDOWN_SECONDS` (default 30 s). The very first load does not
  start the unknown-`kid` cooldown, so a legitimate key rotation right after
  startup still resolves. Worst case is about two fetches per cooldown window.
  Validation itself was not loosened. (`tests/auth/test_jwks_cache.py`)
- **Request-body limit.** 64 KiB by default (`MAX_REQUEST_BODY_BYTES`), enforced
  twice: a declared `Content-Length` over the limit is refused without reading the
  body, and the bytes actually received are counted as they stream, so a chunked
  body or an understated length is cut off as soon as the limit is crossed. Both
  return **413** in the standard error envelope (`payload_too_large`).
- **Input bounds aligned to the schema.** `price` is `numeric(10,2)`-shaped
  (`max_digits=10`, `decimal_places=2`); `serving_volume_ml` is bounded only by
  the `integer` column's maximum (2,147,483,647 - a deliberate decision: no
  tighter cap was justified); `page` is `1..10,000` (`MAX_PAGE`) and `page_size`
  `1..100`; search `q` is capped at 100 characters and rejects NUL; text fields have explicit
  maximum lengths (beer-log `review` 2,000, `serving_note` 500, `venue_name` 200;
  contribution fields match their database CHECKs); barcodes are ASCII digits only (a non-ASCII "digit" such as an Arabic-Indic
  numeral is rejected at the request boundary instead of reaching the database
  CHECK as a 500). Overflow is a 422, never a 500.
- **Database and network timeouts.** Connect 10 s, acquire (waiting for a pooled
  connection) 10 s, command 30 s - all configurable and all `> 0`. A saturated
  or unreachable database fails fast instead of hanging requests.
- **Sanitized error behaviour.** 413, 503 and 500 all use the standard envelope
  and never carry driver text, SQL, stack traces or constraint names. **503**
  is reserved for genuinely temporary availability failures (connection lost or
  refused, server saturated or shutting down, statement cancelled, our own
  timeouts, DNS); constraint violations, bad SQL, data errors and every other
  exception stay **500** - a programming error must not masquerade as "try
  again later". A valid token for a deleted account (its `user_id` foreign key
  fails) is a **401**, decided by the *constraint name*, so it is no longer
  misreported as "beer not found" and reveals nothing about any other user.
- **Request logging.** Standard-library logging only. One line per request:
  request id, method, path, status, duration. The path is the matched route
  *template* (`/beers/{beer_id}`), never the query string (search text,
  barcodes); bodies, `Authorization` and tokens are never read or logged. Every
  response carries `X-Request-ID`; a client-supplied id is kept only if it is
  short and made of safe characters. `uvicorn.access`, `httpx` and `httpcore` are
  quieted because they would log the query string and outbound URLs.
- **Production surface.** `/docs`, `/redoc` and `/openapi.json` exist only when
  `ENVIRONMENT` is `local` or `dev`. The check fails closed: any other value,
  including a misspelling, is treated as production-like (docs off, `https`
  required for `SUPABASE_URL`). `/health` is a deliberate, documented liveness
  probe: unauthenticated, identical everywhere, and it does not touch the
  database.
- **Mobile release guard.** A release build refuses to start (a localized
  "not configured correctly" screen, value-free diagnostics) unless the Supabase
  URL, the publishable key and the API URL are present, both URLs are `https`,
  and neither host is loopback/private/link-local/CGNAT or a local-only name
  (this catches `http://10.0.2.2:8000`). Debug builds keep the relaxed rules.
- **Legal URLs.** Public `https` only, no credentials, no local/private host.
  Unset means the placeholder screen; a value that is *configured but invalid in
  a release build* is a startup configuration failure, not a silent downgrade to
  the placeholder (an owner decision: a broken compliance link should be caught
  before shipping). Opened in the external/default browser, never a WebView.
- **Database boundary.** `backend/tests/integration/test_security_audit.py`
  pins the exact set of `public` tables, RLS on every one, the full table x role
  x privilege matrix for `anon`, `authenticated`, `beerapp_backend` and
  `beerapp_seed`, nothing granted to `PUBLIC`, the exact set of RLS policies
  (owner policies keyed on the request identity, never `USING (true)` for user
  data), the catalog unwritable by the backend role, the contribution tables
  `SELECT`+`INSERT` only, and that *every* foreign key to `auth.users` cascades
  and none is unaudited. It also audits every function in `private`: a fixed
  `search_path` on each `SECURITY DEFINER` function, only the intended `EXECUTE`
  grants, and nothing reachable through `USAGE` on schema `private`. A new table,
  function or policy fails these tests until it is reviewed and added.
- **`private.set_updated_at()`.** The audit found `EXECUTE` still held by
  `PUBLIC` (PostgreSQL's default for a new function), so `anon`,
  `authenticated` and `beerapp_backend` could call it. It is a trigger function
  and not callable meaningfully, but there was no reason to leave it open, so
  migration `20260921100000_revoke_public_execute_on_set_updated_at` revokes it
  from `public, anon, authenticated`. Owner and definition are unchanged; the
  seven `updated_at` triggers still fire for their real writers without any role
  holding `EXECUTE` (proven).
- **Integration-suite isolation.** The suite refuses to run unless its database
  is disposable: it may not equal, or share a host with, `DATABASE_URL` or
  `SEED_DATABASE_URL`, and must be loopback unless
  `INTEGRATION_DATABASE_ALLOW_REMOTE` is set. No test connects to `beerapp-dev`
  or to any DSN from the runtime `.env`.
- **Seed-script guard.** `scripts/seed_catalog.py` refuses to run unless
  `ENVIRONMENT` is `local`/`dev`, the target differs from the runtime
  `DATABASE_URL`, and `--yes` is passed; without `--yes` it prints only the target
  host, never credentials.
- **Android.** `allowBackup="false"` (the app's local storage holds the auth
  session), no backup-rule files, `INTERNET` and `CAMERA` only in the app's *own*
  (main) manifest - **but the built release APK requests more, merged in from
  libraries** (see "Not covered" below) - release cleartext blocked (only the *debug* source set allows
  cleartext, and only to `10.0.2.2`), the only exported component is the launcher
  activity. All pinned by `test/platform/android_manifest_test.dart`.
- **Credential hygiene.** Two database role credentials that had been committed to
  a tracked test file were rotated by the project owner and the tracked file now
  uses obviously fake values; a scan confirmed no tracked file contains the old
  ones. Git history was deliberately **not** rewritten (CLAUDE.md), so the old
  values remain in private history - rotated, therefore no longer valid.
  `.gitignore` now also covers signing and cloud-config files.

**Not covered / remaining limitations (stated, not silent)**

- **No requests-per-time-window rate limiting** (see the rate-limiting entry).
- **The remote Supabase Auth settings were not reviewed** - redirect allowlist,
  email confirmation, password policy, CAPTCHA and Supabase's own auth rate limits
  are dashboard settings, not in the repository. This is owner-owned and open.
- **Residual access-token lifetime.** Deleting an account cannot revoke an
  already-issued access JWT; it stays valid until `exp`. Reads then return
  nothing and writes now fail with 401 (the user foreign key), so this is not a
  data-exposure path, but the token still authenticates.
- **`ssl="require"` encrypts but does not verify the server certificate.** It
  protects against passive eavesdropping, not an active man-in-the-middle on the
  path to the database pooler. Whether to pin the CA is a deployment decision.
- **Server logs are sensitive.** The application does not log secrets, bodies or
  query strings, but an unhandled asyncpg error's traceback (server side only,
  never sent to the client) can contain a `DETAIL:` line with row values. No log
  aggregation, retention policy or access control exists yet; when one is chosen
  it must be treated as holding personal data.
- **The backend credential is the trust boundary.** RLS scopes each request by a
  transaction-local `app.user_id` that `beerapp_backend` sets itself, so RLS here is
  defence in depth against a *bug*, not against a compromised backend credential.
- **Operational consideration: no per-user cap on pending contributions.** This
  is a deliberate decision, not a missing Phase 14 implementation. Each
  contribution is bounded in size and protected by ownership controls (owner-only
  rows, `user_id` from the verified token, `status` pinned to `pending`), duplicate
  protections and database constraints; the *count* is not capped, because an
  arbitrary product-state cap was not justified without evidence. Requests-per-time
  limiting belongs to the deployment layer once hosting is chosen. A pending-state
  cap will be reconsidered only if beta or production evidence shows a real abuse
  problem.
- **Not done:** an external penetration test; a dependency vulnerability audit
  (`pip-audit` or equivalent) - no dependency was upgraded in Phase 14 by design
  (`flutter pub` reports 7 packages with newer, constraint-incompatible versions);
  R8/minification tuning; release signing (Phase 15; the release build still uses
  the debug key); certificate pinning.
- **The shipped Android APK requests more permissions than the app's own
  manifest declares.** Inspecting the merged manifest of the release build (final
  verification) shows, besides `INTERNET` and `CAMERA`: `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`, `ACCESS_WIFI_STATE` and `ACCESS_NETWORK_STATE` (added by
  MapLibre's `android-sdk-opengl`; `ACCESS_NETWORK_STATE` also by the ML Kit
  transport library), and `USE_BIOMETRIC` / `USE_FINGERPRINT` (added by
  `androidx.biometric`, a transitive dependency). The app uses none of location,
  WiFi state or biometrics itself. These predate Phase 14 and were not changed: the
  manifest test pins only the app's own manifests. They matter for the store privacy
  and data-safety disclosures (Phase 15), and each can be removed with a
  `tools:node="remove"` entry once that is decided and tested on a device. A
  decision for the owner - not made here.
- **iOS is unverified.** No iOS build or run was possible on this machine.
  The auth-redirect URL scheme is registered in `Info.plist`, but Google Sign-In
  on iOS needs a `GIDClientID` that has **not** been supplied and was **not**
  invented - **NOT CONFIGURED, a release blocker** until the owner provides a
  Google iOS client ID.
- **Deep links** use a custom URL scheme, not a verified App Link/Universal Link;
  whether another app on a device could claim the same scheme was not assessed.

## 2026-09-21 — Phase 14: adult-audience / age-gating review

Facts about what the app does today, checked against `PRODUCT.md` §3/§6 and
`CLAUDE.md`. This is a description of the implementation, **not a claim of legal
compliance in any jurisdiction**.

- **Model.** BeerApp is adult-only and authentication is mandatory - there is no
  guest mode and no path into the app without an account.
- **The gate.** The first screen (`WelcomeScreen`) has a required checkbox,
  "I confirm I am of legal drinking age in my jurisdiction." Sign in, sign up and
  Google sign-in are disabled until it is checked, and acknowledging is what
  advances the user.
- **It is the first thing the router decides.** The age gate is the *first* layer
  of the router's redirect: until it is acknowledged, every location redirects to
  the welcome screen. It is merged with the auth controller into one redirect
  decision so neither can be skipped by targeting the other. Tested: with the gate
  unacknowledged, a direct navigation to the sign-in route bounces back to welcome
  (`test/app/router_test.dart`); the checkbox gating of the three sign-in actions is
  covered in `test/features/auth/welcome_screen_test.dart`. An operating-system
  deep link was not separately tested against the gate.
- **What it is.** A **self-declaration stored locally on the device**
  (`SharedPreferences` key `age_gate_acknowledged`, a boolean). It is not sent to
  the backend, not tied to an account, and not verified.
- **What it is not.** It is not identity or age *verification*: no date of birth,
  no document check, no per-country legal age. The statement is deliberately
  jurisdiction-neutral ("legal drinking age in my jurisdiction").
- **Consequences of "device-local", stated plainly.** A reinstall or cleared app
  data asks again; a second account on the same device is not asked again; and the
  backend neither knows nor enforces it, so a caller holding a valid token and
  using the API directly is not subject to the gate. That is inherent to the
  chosen model, not an accidental gap.
- **No attempt to bypass store or platform requirements.** Nothing here claims or
  implies a store age rating or questionnaire answer.
- **Contradictions found: none.** The implementation matches PRODUCT.md §3 and §6
  and CLAUDE.md, so it was not redesigned.
- **Still to do before release, per PRODUCT.md §3 ("must be reviewed before
  release in each market"):** the store age-rating questionnaires, each target
  market's age-assurance expectations, and whether a stronger mechanism is
  required for any market. That is Phase 15 / counsel territory and is **not done**.
  (Separately, Apple sign-in - listed in PRODUCT.md §6 as an initial method and
  unchecked in ROADMAP Phase 2 - is not implemented; whether Apple requires it
  alongside Google sign-in on iOS should be checked against current App Store
  policy in Phase 15.)

## 2026-09-21 — Phase 14: responsible product design review

Each rule in `PRODUCT.md` §3 and `CLAUDE.md` ("Responsible Product Design"),
checked against the code as it stands. **Result: no contradiction found.** One
Phase 14 string is called out below as a judgement call.

| Rule | Finding |
|---|---|
| No achievements based on quantity consumed | The achievement catalog (`app/services/achievement_catalog.py`) has exactly three entries: first favorite, first wishlist item, and a "collection curator" that requires those two. All derive from the *collection* (`is_favorite`/`is_wishlist`); none reads `user_beer_logs`, and none counts logs, beers tried or volume. The unused categories (`beers_tried`, `countries`, ...) exist in the enum but have no entries, on purpose. `PRODUCT.md` §16 was rewritten in Phase 14 to say exactly this: achievements must not reward or encourage drinking quantity, frequency, streaks or consumption volume, and log counts are not a valid source. |
| No streaks, leaderboards, speed or quantity competition | None exists in the backend or the app. (The only occurrences of "streak" in the code are comments stating there are none.) |
| Statistics are descriptive, not a target | The screen shows unique beers, total logs, countries/styles/breweries discovered, average rating, amount spent on priced logs, a favorite style/country/brewery, and monthly/yearly activity charts. There are no goals, targets, comparisons, rankings, notifications or "keep it up" copy. **Recorded volume is not computed or shown at all** (PRODUCT.md §15 lists it as a possibility; it was not built). |
| Scanner never auto-logs | `ScanScreen` only looks a barcode up and navigates to the existing beer detail screen; it never creates a beer, a log or a contribution. A "not found" result *offers* a suggestion, which the user must start and submit themselves. |
| Contributions never modify the canonical catalog | Suggestions live in their own tables and only reach `pending`. `beerapp_backend` is `SELECT`-only on the four catalog tables (audited), and an end-to-end test shows a submission that mirrors a verified beer leaves it unchanged. |
| Favorites/wishlist are collection metadata | They live on the separate, user-owned `user_beer_collection` row, never on the global `Beer` record (the CLAUDE.md data-model rule), and are independent of logging. |
| No new Phase 14 copy introduces consumption pressure | New strings were reviewed: loading and error messages, the startup-failure screen, legal-link placeholders, the delete-account field label, the collection rating label ("Rated 4 out of 5"), and the chart summaries. Only the chart summaries touch consumption data - see "Resolved" below. |
| Verification did not create consumption data | No log, favorite, wishlist entry or achievement was created on `beerapp-dev` at any point in Phase 14. Profiling used synthetic rows in a disposable local database only; the remote migration check was read-only and compared per-table row counts and content hashes before and after. Live emulator flows were **not exercised**. |

**Resolved: chart summary wording.** The monthly chart's screen-reader summary
gives a screen-reader user what a sighted user reads off the bars, and it is
descriptive, not a goal. An earlier draft framed the tallest month as the
"busiest"; on review that language was rejected as competitive framing. It now
reads, for example, "Monthly activity over the last 12 months: 11 entries in total.
Month with most entries: January, 5 entries." (Spanish: "... 11 registros en total.
Mes con más registros: enero, 5 registros."), using "entries" and no ranking, goal
or comparison words. A test asserts that no such words appear in either language.
Nothing else in Phase 14 ranks activity.

**Resolved: `PRODUCT.md` §16.** The section used to list "Number of unique beers"
and "Number of logs" as possible achievement categories, which contradicted
`CLAUDE.md` and the Phase 10 decision. It was rewritten to match them and the
implementation: achievements must not reward or encourage drinking quantity,
frequency, streaks or consumption volume; logged consumption is not a valid
achievement source; the starter achievements (first favorite, first wishlist,
collection curator) are collection/curation based. §3 gained the same rule. No new
achievement was added.

**Observation, not a contradiction:** the empty-state text "Log a beer or favorite
one to see your statistics here" is a neutral invitation, not a target.

## 2026-09-21 — Phase 14: account-deletion review

Documents the deletion path as it exists and what was and was not proved. Not a
statement of regulatory or store compliance.

- **Architecture.** Settings -> Delete account -> a confirmation dialog that
  requires typing the user's own username -> `DELETE /account` on FastAPI with the
  session token. The backend deletes the account of the token's verified `sub`
  (never a client-supplied id) by calling the Supabase Auth **Admin API**
  (`DELETE {SUPABASE_URL}/auth/v1/admin/users/{id}`, `apikey` header, 10 s
  timeout). Deleting through the Admin API - not by writing to `auth.users` - is
  the only path Supabase supports, and no Postgres role holds that privilege.
- **Backend-only secret.** The Admin call uses `SUPABASE_SECRET_KEY`
  (`sb_secret_...`), held only in the backend environment, optional at boot, never
  logged, never in a response, never in `mobile/config/*`. If it is unset, only
  `DELETE /account` degrades (503); the rest of the API is unaffected.
- **Data removal is by cascade, not by application code.** Every user-owned table
  references `auth.users(id) ON DELETE CASCADE`: `profiles`, `user_beer_logs`,
  `user_beer_collection`, `user_achievements`, `beer_contributions` and
  `brewery_contributions`. `AccountService` deliberately deletes nothing itself.
- **Integration proof.** `test_security_audit.py` asserts that every foreign key
  to `auth.users` cascades and that none is unaudited, and that deleting an
  `auth.users` row removes every row the user owns across all six tables; the
  per-table cascade tests and the contributions cascade test do the same. This was
  run against the disposable PostgreSQL scaffold - **not** a real Supabase project
  (see `docs/DATABASE.md`).
- **Status codes and idempotency.** `204` with an empty body on success. A `404`
  from Supabase (already deleted) is treated as success, so a retry is always safe
  and "already deleted" is indistinguishable from "just deleted". A failed Admin
  call, or a missing secret key, is a sanitized `503` - never a `500`, `404` or
  `403`.
- **Local sign-out sequencing.** The app signs the user out locally only *after* a
  `204`; on failure it shows a generic error and keeps the session so the user can
  retry. The sequencing relies on the verified gotrue behaviour recorded in the
  Phase 12 entry.
- **Residual access-token lifetime (unchanged limitation).** The already-issued
  access JWT stays valid until `exp`. Reads return nothing; writes now fail with
  `401` because the `user_id` foreign key no longer resolves (Phase 14 - previously
  misreported as "beer not found"/500).
- **NOT EXERCISED:** a live end-to-end deletion against a real Supabase project.
  The owner's own account was **not** deleted, and the only permitted live test is
  one with an explicitly disposable account.
- **Open items for the retention/privacy statement and Phase 15:** whether
  Supabase-managed copies (auth logs, and backups once they exist) outlive the
  deletion and for how long; that there is no data-export feature; that Google
  Play's requirements for account deletion (including a web-accessible deletion
  path for apps that offer account creation) must be checked against current
  policy; and, once a moderation workflow exists, how an *approved* contribution
  that became a catalog row relates to its deleted author.

## 2026-09-21 — Phase 14: database backup strategy is not configured

**Nothing here was configured, and no restore was tested.**

- `beerapp-dev` is a development project. It is **not** production and its backup
  posture says nothing about production.
- **No production Supabase project exists yet.** What backups and point-in-time
  recovery (PITR) are available depends on the plan and project that will be
  chosen; that choice, and its cost, belong to the owner. No paid plan was chosen
  or recommended.
- What is and is not recoverable *without* backups: the **schema** is fully
  reproducible from `supabase/migrations/` in Git. **User data** (logs,
  collection, achievements, contributions, profiles) exists only in the database,
  so it is exactly what backups must protect. Catalog rows in dev come from a
  dev-only seed script and are not a source of truth for production.
- Decisions and tasks that remain **release/deployment work**: choose the plan and
  region; enable and verify automated backups (and PITR if the recovery-point
  target needs it); set retention; decide who may access and restore them; agree
  recovery point/time targets; **perform and record a restore drill**; and reconcile
  retention with account deletion (see the account-deletion entry).
- **Status of the restore test: NOT EXERCISED - it cannot truthfully be marked
  passed until a project with backups exists.**

## 2026-09-21 — Phase 14: rate limiting - what exists and what does not

Precise wording matters here, because "rate limiting" is a ROADMAP item.

**Implemented - deterministic technical bounds** (they cap the *size and cost of a
single request*, not how often a client may call):

- a request-body limit (64 KiB, 413);
- bounded inputs: text lengths, numeric ranges, barcode shape, query length;
- pagination bounds (`page` <= 10,000, `page_size` <= 100);
- database connect/acquire/command timeouts and a bounded connection pool;
- a bounded JWKS refresh rate (so unauthenticated forged tokens cannot make the
  backend call Supabase repeatedly).

**Not implemented: requests-per-minute, per-user or per-IP limiting, and any
distributed/edge rate limiting.** These bounds are **not** "full rate limiting":
nothing stops a client from sending many valid requests quickly, and the API returns
no `429` (a `429` will be added only when a code path really produces one).

**Deployment-layer prerequisite.** True rate limiting needs the hosting
environment: a reverse proxy, API gateway or edge/WAF that sees the real client
address and can share counters across instances. It should be chosen and
configured once hosting is chosen; an in-process limiter would be per-instance and
easy to sidestep. Supabase Auth's own limits on sign-in and sign-up are a remote
setting that was not reviewed.

**Related, also not implemented:** trust scoring (deferred from Phase 13). There is
also **no per-user cap on pending contributions**, by decision: an arbitrary
product-state cap will not be invented without evidence. The protections that do
exist are the payload/input bounds, ownership controls, duplicate protections and
database constraints; the future steps are deployment-layer distributed request-rate
limiting once hosting is selected, and reconsidering a pending-state cap only if
beta or production evidence shows a real abuse problem. This is a known operational
consideration, not a missing Phase 14 implementation.

## 2026-09-21 — Phase 14: crash reporting and analytics

**Crash handling - implemented locally, no remote provider selected.**
- Flutter: `FlutterError.onError` and `PlatformDispatcher.instance.onError` are
  installed, so an uncaught async error does not terminate the app and no
  exception text or stack trace reaches the UI. A guarded bootstrap
  (`launchApp`) turns a startup failure into a localized failure screen (a
  non-retryable "not configured correctly" screen, or a retryable "couldn't start"
  screen). Diagnostics are written only in debug builds, and only value-free names
  or types.
- Backend: structured, safe request and error logging (see the security review).
- **There is no remote crash-reporting provider** (no Sentry, Firebase or
  equivalent): crashes on user devices are not collected anywhere. Choosing a
  provider - and what it may collect - is an open pre-release decision for the owner.

**Analytics - not implemented.** No analytics SDK, no event tracking, no
advertising identifier. The privacy-conscious default (`PRODUCT.md` §28) is to
collect none, and that default stands; it is not "planned but pending".

Neither remote crash reporting nor analytics may be described as implemented.

## 2026-09-21 — Phase 14: legal documents - infrastructure only, content blocked

Supersedes, in part, "Phase 12: legal links are a static in-app placeholder".

**Implemented**
- `LEGAL_PRIVACY_URL` and `LEGAL_TERMS_URL` build-time values (public
  configuration, never secrets; see `mobile/config/release.example.json`).
- Validation: a legal URL is used only if it is `https`, has a host, carries no
  credentials and is not a loopback/private/local host. Unset (or, in a debug
  build, invalid) leaves the placeholder screen; a configured-but-invalid URL in a
  **release** build is a startup configuration failure (owner decision).
- Settings opens a valid URL in the external/default browser
  (`LaunchMode.externalApplication`); no WebView. A launch failure shows a
  localized error.
- `url_launcher` became a **direct** dependency (`^6.3.2`). It was already in the
  dependency tree transitively through `supabase_flutter` at this exact locked
  version, so no new package or native code was added; it is declared directly
  because the app now calls it itself, and a transitive dependency can change
  without notice.

**Still blocked (owner-supplied)**
- The real Privacy Policy **text** and its public **URL**.
- The real Terms of Service **text** and its public **URL**.
- No legal text was written or fabricated, and no URL was invented. Until both URLs
  are supplied, release builds show the placeholders.

## 2026-09-21 — Phase 14: accessibility review (Stage 5 audit)

An audit of BeerApp's own widgets. It is **not a WCAG conformance claim** and no
external audit was done.

**Fixed** (each with a test that failed before the fix): `PrimaryButton` and
`SecondaryButton` now expose a button role and enabled/disabled state, and a
disabled `PrimaryButton` exposes no tap action; `PrimaryButton` gained keyboard
focus, Enter/Space activation and a visible focus ring, and its label wraps
instead of overflowing at 2x text; `SecondaryButton` has a visible disabled style;
filter chips have a 48 dp hit target; beer and collection tiles are single labelled
buttons, and the icon-only favorite/wishlist/rating state is announced (localized,
EN/ES); text fields keep their accessible name once text is typed (and the drawn
placeholder is hidden from semantics so it is not read twice); the delete-account
confirmation field is labelled; both statistics charts have a localized summary in
place of their drawing; 11 inline spinners/progress bars announce "Loading...";
the bottom navigation bar no longer overflows at 2x text and no longer announces
each item twice.

**Contrast.** Computed from the design tokens (so a token change re-runs it) in
`test/accessibility/token_contrast_test.dart`: every text pair checked reaches AA
4.5:1, and graphics/icons reach 3:1. The one pair that used to fail - the
`PrimaryButton` label - was fixed in Phase 14 (see the next entry), and the test now
asserts AA compliance over the whole gradient instead of recording a gap. It is a
token-level computation, not a measurement of rendered pixels, and does not cover
images, map tiles, text over user content or platform-drawn UI.

**Also verified:** 2x text scale does not overflow the buttons, tiles, navigation
bar, error/empty states, filter chip, charts or the startup-failure screen (widget
tests); list and hero images decode at display size (see the performance entry).

**Remaining limitations**
- No TalkBack pass on a device, and no VoiceOver pass at all (no device or iOS
  build was available).
- **Map markers are drawn natively by MapLibre and have no screen-reader
  alternative.** The same beers and breweries are reachable through Discover and
  Collection.
- Bottom-navigation labels stop scaling at 1.3x (as Material's own
  `NavigationBar` does) and shrink to fit; the full name remains available to
  screen readers.
- Hardware-keyboard focus exists for `PrimaryButton` only; the list tiles are not
  keyboard-focusable. `PRODUCT.md` §29 lists "clear focus states"; this is only
  partly met.
- Large-text behaviour was tested in widgets, not on a device.
- Keyboard/focus and screen-reader behaviour must be re-verified on real devices
  before release (a Phase 15 check).

## 2026-09-21 — Phase 14: the amber call-to-action gradient was adjusted for WCAG AA

The `PrimaryButton` label was white over the Stitch gradient `primary` `#795900` ->
`primaryContainer` `#ffbf00`. Measured over the whole gradient (sampled every
0.5%), white was 6.48:1 at the dark end but 1.65:1 at the bright end, and **no
existing token, and no colour at all, passed 4.5:1 across it**: even pure black gets
only 3.24:1 at the dark end, because the gradient spans relative luminance 0.112 to
0.585. The dark end was too dark for any dark label; the bright end too bright for a
light one.

**Decision (owner):** keep an amber gradient, lighten its dark end, and use an
existing dark token for the label. Implemented as:

- `AppColors.primaryGradientStart` = `#af8200`, 40% of the way from `primary` to
  `primaryContainer` (same amber hue; the gradient's ends remain visibly different at
  2.1:1);
- `AppGradients.primary` = `primaryGradientStart` -> `primaryContainer`, top-left to
  bottom-right, one shared token;
- `AppColors.onPrimaryGradient` = the existing `onSurface` (`#1b1c1a`), used for the
  `PrimaryButton` label and icon.

**Measured** (`onSurface` on the gradient): 4.90:1 at the dark end (the worst point
of the whole gradient), 6.00 at 25%, 7.26 at the centre, 8.75 at 75%, 10.35 at the
bright end. The focus ring (also `onSurface`) is at least 3:1 against every point.
`token_contrast_test.dart` asserts the endpoints, the midpoint and the worst of 201
samples (>= 4.5, and > 4.8 to keep headroom), and that both `PrimaryButton` and
`ScanNavButton` really draw that gradient and colour.

**Preserved:** the disabled styling (flat `surfaceContainerHigh`, `onSurfaceVariant`
label), the press animation, the focus ring and keyboard activation.

**Visible changes to report:** primary buttons now have a dark label on a slightly
lighter, more golden gradient; **`ScanNavButton` uses the same gradient and now has a
dark icon instead of a white one** - it used the identical failing pair, and leaving
it on the old gradient would have meant two different amber gradients. The button's
glow shadow is unchanged. `docs/DESIGN_SYSTEM.md` records the token change (Stitch
remains the unmodified reference).

## 2026-09-21 — Phase 14: performance review (measured, with the limits of the measurements)

**Method (backend).** A disposable local PostgreSQL 16 (never `beerapp-dev`),
catalogs of **2,000, 10,000 and 50,000 beers** (breweries scaled with them) and
one heavy user (2,000 logs, up to 300 favorites and 300 wishlist entries). The
*real* repositories ran as the `beerapp_backend` role; each case had 5 warm-up and
40 timed runs (median/p95 reported), and every statement was replayed under
`EXPLAIN (ANALYZE, BUFFERS)`. Measured result vs. limitation: **these are local,
single-machine timings on a PostgreSQL scaffold, not Supabase** - the *scaling
shape* is the reliable part, not the absolute milliseconds.

**Measured results (median ms).**

| Query | 2k | 10k | 50k |
|---|---|---|---|
| Discover page 1 | 1.2 | 2.2 | 8.6 |
| Discover page 100 (offset 1,980) | 1.9 | 4.9 | 28.1 |
| Text search `q` (e.g. "stout") | 5.0 | 21.1 | 102 |
| Country / style filter | 0.7 | 0.8-1.0 | 1.2-1.4 |
| Barcode lookup | 0.3 | 0.3 | 0.4 |
| Map beers, all (capped at 2,000 rows) | 8.6 | 15.9 | 42.6 |
| Map breweries | 1.4 | 4.2 | 9.4 |
| Collection, logged | 4.5 | 7.5 | 15.9 |
| Statistics | 7.2 | 9.4 | 17.4 |

- **Scan strategy.** Filtered lookups (country, style, brewery, barcode) use
  indexes and stay roughly flat. Everything else is a sequential scan with a top-N
  sort and grows roughly linearly with the catalog.
- **Search scaling finding.** Text search (`ILIKE '%q%'` across beer, brewery,
  style and country with joins) is the only query that becomes slow: about 5 ms at
  2k, 21 ms at 10k and about 100 ms at 50k rows (p95 about 108 ms). The dev
  catalog is 32 rows, so this is a **future watch item**, not a current problem.
- **High offset / `MAX_PAGE`.** `MAX_PAGE` stays 10,000 (owner decision). A request
  at `MAX_PAGE` returns an empty page in about 64 ms at 50k, because the sort must
  still run (a 5.6 MB external merge) before everything is discarded. That is
  2x-8x a normal page and does not grow with the page number, so the bound is not
  an amplification risk at this size. **Alternatives, evidence only and not
  implemented:** short-circuit when `offset >= total` (the count is already
  computed); cursor pagination.
- **Map (Flutter side).** Every controller notification used to rebuild both
  GeoJSON collections and make 2 source uploads and 6 layer-visibility calls, even
  when nothing changed. `MapDataSynchronizer` now uploads a source only when its
  content fingerprint changed and sets visibility only when the beers/breweries mode
  flips. Measured on a scripted 10-notification session: **80 platform calls
  (20 uploads) before, 19 (7 uploads) after**, identical final state. Building a
  **2,000-feature** GeoJSON collection took about 0.7 ms (about 374 KB serialized)
  and a no-op resync about 0.13 ms - measured under the JIT on a desktop, so
  indicative only.
- **Images.** List/collection thumbnails and the detail hero share one `BeerImage`
  that decodes at display size (box x device pixel ratio x 1.5, aspect ratio kept)
  instead of decoding the full source, with a stable placeholder and the existing
  fallback icon. Verified by unit and widget tests; the memory saving on a device
  was not measured.

**Not exercised:** no Android emulator or device was available, so there is **no
profile-mode frame-timing measurement**, no real map rendering measurement, and no
authenticated live flow was profiled (no credentials were created; no consumption
data was generated).

**Future watch items (none implemented, each needs owner approval and, where it
touches the schema, a migration):** a `pg_trgm` index for text search if the
catalog reaches tens of thousands of rows; a viewport/bounding-box map endpoint
(the map is capped at 2,000 rows, so the cost today is the truncation banner, not
speed); cursor pagination; the `offset >= total` short-circuit.

## 2026-09-21 — Phase 14: integration suite and migration status

Supersedes the Phase 13 finding "79 of the 111 older integration tests fail".

- **Cause and repair.** All failures were defects in the older *tests* (made-up
  `user_id`s with no `auth.users` row, seeding catalog data after switching to the
  read-only role, un-paired favorite/wishlist columns, a brewery without its
  `country_id`, `confdeltype` bytes vs. str, `abv` overflowing `numeric(4,2)`), plus
  the never-categorised remainder. None was a production defect and no production
  schema was changed to satisfy a test.
- **Result.** The complete integration suite - **269 tests** - passes against a
  disposable database with every migration applied. That includes the security audit
  above. It is a Postgres-scaffold result; **it is not full local Supabase
  verification**, and it has not been run against a local Supabase stack.
- **Environment.** The first choice remains a real local Supabase stack via Docker
  (`supabase start`). Docker was unavailable here, so the verified fallback is a
  repository-owned scaffold (`backend/tests/integration/support/`) applied to a
  local throwaway PostgreSQL 16. See `docs/DATABASE.md` for how to run it and what it
  does not reproduce. No test touches `beerapp-dev`.
- **Migration `20260921100000_revoke_public_execute_on_set_updated_at`** (the
  `private.set_updated_at()` privilege hardening) is **applied to `beerapp-dev`**.
  `supabase db push --dry-run` listed exactly that one migration and nothing else;
  `db push` applied it; `supabase db lint --linked --level error` reported no schema
  errors; `supabase migration list` shows all **19** local migrations recorded
  remotely. A read-only snapshot before and after showed only the intended change -
  the function's ACL went from "`PUBLIC` has `EXECUTE`" to owner-only - with owner,
  definition, `search_path`, the eight triggers, the other functions' ACLs and the
  `private` schema's `USAGE` unchanged. **No row data was created or modified**
  for the verification (row counts and content hashes of all ten tables matched).
  Live trigger firing on `beerapp-dev` was **not** exercised (proven in the
  disposable database instead), and the applied migration must not be edited.

## 2026-09-21 — Phase 14: final verification (results, and two findings)

The close-out pass. Every result below was produced in that pass, not carried over.

- **Backend.** Default suite **592 passed** (269 integration deselected, as
  collected); `ruff check` and `ruff format --check` clean (136 files).
- **Integration.** The disposable database was rebuilt from clean state (databases
  and cluster roles dropped) through the repository's own scaffold and helper,
  applying the scaffold plus all **19** migrations; the complete suite, **269
  passed** (no skips), ran with only the loopback disposable DSN set (no
  `DATABASE_URL`/`SEED_DATABASE_URL` in the process); every table was at 0 rows
  before and after, so nothing was left behind. This is a Postgres-scaffold result,
  not full local Supabase.
- **Flutter.** `dart format` (273 files) and `flutter analyze` clean; **736 passed**
  in 79 files. Areas confirmed by their actual results: router/auth guards, age gate,
  catalog and search, logging, collection, map (including the synchronizer),
  statistics, achievements, scanner, profile/settings, contributions,
  startup/global error handling, release environment validation, legal link states,
  accessibility, the `PrimaryButton`/`ScanNavButton` contrast test, the platform
  manifest/plist regression tests and the image-decode tests.
- **Android release build.** `flutter build apk --release` with a temporary
  configuration of public placeholder values (public https Supabase/API/legal URLs,
  fake keys) compiled; the release guard accepts that same configuration and
  rejects the emulator URL in release (checked with the real validator). The built
  APK's merged manifest has `allowBackup=false` and no cleartext flag, network-security
  config or `debuggable`. It is debug-signed and is **not** a store-ready or
  production-signed build; the temporary configuration was deleted. The app bundle
  was left for Phase 15.
- **Android debug build.** `flutter build apk --debug` with the normal development
  configuration compiled. (A first attempt failed only because the machine's disk
  was full while copying the finished APK; after clearing git-ignored build output it
  succeeded.) Runtime UI: NOT EXERCISED (no emulator or device).
- **`beerapp-dev`, read-only.** `supabase migration list`: all 19 local migrations
  match remote; `db push --dry-run`: "Remote database is up to date" (nothing
  pending); `db lint --linked --level error`: no errors; a SELECT-only snapshot
  matched the one taken right after the migration exactly (0 differences):
  `private.set_updated_at()` has an owner-only ACL and no role can execute it, all 8
  triggers and the `private` schema privileges are unchanged, and
  `beer_contributions`/`brewery_contributions` have 0 rows. Nothing was created,
  reset or seeded.
- **Secrets and hygiene.** Nothing staged. All 540 tracked and untracked-but-visible
  files were scanned (paths and counts only): none contains an old rotated database
  credential; no private key, `sb_secret_` key, cloud-config or signing file is
  present; the only token/DSN-shaped strings are obvious test fixtures
  (`.example.invalid` hosts, a fake project ref, a JWT with a 19-character
  signature) and placeholder example configs. `.env` and the real mobile config
  files are git-ignored and untracked; `build.gradle` is untouched (no signing or
  application-id change), so no Phase 15 work entered the tree.
- **iOS (static checks only).** `Info.plist` content: the auth URL scheme matches
  the Android intent filter and `Env`, a camera usage description is present, there
  is no `GIDClientID`, no other usage descriptions, no ATS override and no
  entitlement or provisioning files. **iOS build and runtime: NOT EXERCISED - needs
  macOS/Xcode.**

**Finding 1 - fixed: `Info.plist` was not well-formed XML.** The comment added in
Phase 14 for the auth URL scheme contained a double hyphen, which XML forbids, so a
strict parser (and therefore Xcode) rejects the file. The existing plist test
stripped comments before inspecting the file and could not see it. The comment was
reworded, and the platform tests now check the raw plist and all three Android
manifests for illegal comments (verified by making the test fail on the defective
file, then pass on the fixed one). All 12 native XML/plist files parse strictly.

**Finding 2 - documented, not changed: the shipped APK requests more permissions
than the app's own manifest.** See the security review ("Not covered").

**Not exercised in Phase 14 (not test failures):** a live authenticated end-to-end
flow; live account deletion (no disposable account); physical barcode decoding;
TalkBack; VoiceOver; an Android profile-mode run (no device or emulator); iOS build
and runtime; a real local Supabase stack via Docker; a backup restore; live trigger
firing on `beerapp-dev` after the privilege migration.

**Status.** Phase 14 *engineering* work is complete. Full production/store readiness
is not: it depends on Phase 15 and the owner-supplied prerequisites in `ROADMAP.md`.

## 2026-09-21 — Phase 14: other decisions recorded

- **`MAX_PAGE` stays 10,000** (owner decision); the measurement above is evidence
  only.
- **The database-error mapping stays constraint-name based**, with integration
  assertions that the expected foreign-key names exist; no migration was made to
  rename constraints.
- **`serving_volume_ml` is bounded only by the `integer` maximum**; no tighter cap.
- **`ApiClient` timeout stays 20 seconds** (owner decision), mapped to the existing
  localized network error; it will be revisited only on real-device evidence.
  `413` and `503` are mapped to localized errors; `429` is not, since the API does
  not return it.
- **The environment check fails closed** (see the security review).
- **`intl` is still not declared directly** (a Category C item; `dart fix` will add
  it silently, so check `pubspec.yaml` after running it).
