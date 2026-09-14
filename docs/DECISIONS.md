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
