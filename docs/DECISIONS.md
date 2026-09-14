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
