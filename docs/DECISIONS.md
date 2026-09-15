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
