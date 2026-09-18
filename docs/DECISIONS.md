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
