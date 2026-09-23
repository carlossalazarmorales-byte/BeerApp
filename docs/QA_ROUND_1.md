# QA Round 1

Manual QA backlog. Every item gets an explicit resolution over time: implemented,
intentionally redesigned with owner approval, or explicitly deferred/rejected
with a documented reason. Status tags: open / implemented / deferred / rejected.

---

## Block 1 — Core UX

### 2026-09-22 — Locked/unlocked beer visual state — implemented (2026-09-23)
A beer is "unlocked" for the current user once they have at least one log for
it. Unlocked: normal image/presentation. Locked: grayscale/muted image (never
fully opaque, never blurred), a small lock badge as a corner overlay (not a
large centered icon obscuring the image), beer remains fully tappable, detail
screen remains readable. Accessibility semantics must announce locked state
without making the tile inaccessible. One shared, reusable presentation
component — not per-screen logic. No DB migration was needed for this join:
the existing `user_beer_logs` `(user_id, beer_id, consumed_at, id)` index
serves the per-beer EXISTS lookup, verified against a real disposable
Postgres.

**Implementation:** `mobile/lib/shared/widgets/lockable_beer_image.dart`
(new shared widget: grayscale `ColorFilter`, corner lock badge, localized
semantics). Backend: `GET /beers` now returns `is_tried` per row
(`BeerCatalogOut` in `backend/app/schemas/beers.py`,
`backend/app/repositories/beers.py`), scoped to the RLS-protected
`user_beer_logs` table via `scoped_connection` — verified that another
user's log never marks a beer tried for the current user
(`test_is_tried_reflects_only_the_requesting_users_own_logs`). Adopted by
Discover (`beer_list_tile.dart`), Collection (`collection_tile.dart`, a new
derived `CollectionBeer.isTried` getter), and Beer Detail
(`beer_detail_screen.dart`, derived from `BeerLogController.isLoading`/
`logs.isNotEmpty` so the hero never flashes locked-then-unlocked while
logs are still loading).

### 2026-09-22 — Discover is untried-only, no toggle — implemented (2026-09-23)
The Discover *screen* must show only beers the current user has not yet
unlocked/tried, with no user-facing toggle. Tried beers remain reachable via
Collection, map, and detail flows. This is a product rule for Discover
specifically — it does **not** mean the underlying catalog endpoint loses the
ability to return the full catalog. Must stay server-side (anti-join in the
paginated query), keep existing pagination/infinite-scroll, search, and
filters.

**Implementation:** `GET /beers?untried_only=true` (`backend/app/routes/beers.py`,
`backend/app/repositories/beers.py`'s `_build_query`, a `NOT EXISTS` against
`user_beer_logs`). `DiscoverController` (`mobile/lib/features/discover/presentation/discover_controller.dart`)
always passes `untriedOnly: true` on every load/search/filter/page-more
call — no toggle exposed anywhere in the UI. See the performance entry below
for the required profiling this shipped with.

### 2026-09-22 — Add Beer search uses the full catalog, not untried-only — implemented (2026-09-23)
Add Beer's manual search/select step must be able to find *any* catalog beer,
including beers the user has already tried — a user may deliberately log the
same beer again. Barcode-scanner identification inside Add Beer must likewise
resolve both tried and untried beers. `GET /beers` (or its repository layer)
keeps a general, reusable "list catalog beers" behavior; the untried-only
exclusion is a mode Discover explicitly requests, not a permanent property of
the endpoint. No second catalog implementation was built.

**Implementation:** `AddBeerController`
(`mobile/lib/features/add_beer/presentation/add_beer_controller.dart`) calls
the same `CatalogRepository.getBeers` Discover uses, simply omitting
`untriedOnly` (defaults `false`). Backend: one query builder
(`BeerRepository._build_query`/`list_paginated`) serves both modes; verified
with backend tests that a tried beer is included in the plain/full mode and
excluded only when `untried_only=true`
(`test_untried_only_excludes_a_beer_the_user_has_logged`,
`test_untried_only_includes_a_beer_the_user_has_not_logged`) and with a
Flutter widget test that both a tried and an untried beer are shown and
selectable in Add Beer.

### 2026-09-22 — Filter sheet overflow (Collection + Discover) — implemented (2026-09-23)
Real bug: Collection's filter sheet produces "Bottom Overflowed by 155
pixels" and blocks reaching search/apply/exit controls. Root cause: a plain
non-scrollable `Column` inside the bottom sheet. The identical structural
defect existed in Discover's own filter sheet and was fixed in the same pass.

**Implementation:** both `CollectionFilterSheet`
(`mobile/lib/features/collection/presentation/collection_filter_sheet.dart`)
and Discover's `_FiltersSheet`
(`mobile/lib/features/discover/presentation/discover_screen.dart`) now use a
fixed header, a `ConstrainedBox`-capped `Flexible(SingleChildScrollView(...))`
for the filter content (shrinks to content on a small option set, scrolls
once content exceeds the cap), and a fixed footer for "Show results" —
verified reachable and hit-testable in both. Regression widget tests added
in `mobile/test/features/collection/collection_filter_sheet_test.dart` and
`mobile/test/features/discover/discover_screen_test.dart`, each pumping a
~40-140-option filter set on a 400×500 viewport and asserting no thrown
overflow exception and that "Show results" stays tappable.

### 2026-09-22 — Center nav becomes Add Beer (+), Scanner demoted to secondary — implemented (2026-09-23)
Center bottom-nav action changes from Scanner-first to a Plus/Add Beer
screen. Scanner is no longer a primary bottom-nav destination. Add Beer
screen: primary path is search → select beer (full catalog, see above) →
existing `LogFormSheet` → save; secondary path is "Scan barcode" → existing
scanner → if a beer is identified (tried or untried) → same `LogFormSheet` →
save. Scanner never auto-creates or auto-saves a log.

**Implementation:** `mobile/lib/app/router.dart` replaces the `/scan`
`StatefulShellBranch` with `AppRoutes.add` → `AddBeerScreen`; `/scan`
becomes a top-level push-only `GoRoute`. `bottom_nav_bar.dart`'s center slot
now shows `Icons.add`/"Add" (`ScanNavButton`'s icon is a parameter, not
hardcoded). `scan_screen.dart`: a found beer now pops the route with the
`Beer` as its result (`context.pop(beer)`) instead of pushing to Beer
Detail; "Search manually" pops with no beer instead of `context.go`'ing to
Discover (Discover can no longer serve as a full-catalog fallback — see the
Add Beer entry above). The barcode-decoding implementation, the
unknown-barcode → suggest-a-beer handoff, and the never-auto-save guarantee
are all unchanged. New `mobile/lib/features/add_beer/` feature
(`AddBeerScreen`/`AddBeerController`). Covered by
`mobile/test/app/router_test.dart` (branch reachability, `/scan` push/pop),
`mobile/test/features/scan/presentation/scan_screen_test.dart` (rewritten
for the pop-based flow), and
`mobile/test/features/add_beer/add_beer_screen_test.dart` (scan → identified
beer → same log form, scanner never auto-saves).

### 2026-09-22 — Log creation centralized through Add flow — implemented (2026-09-23)
User-facing creation of new logs happens only through the Add/+ flow.
Removed Beer Detail's "Log / Register Beer" creation action. Beer Detail
remains for information, existing log/history display, and other
non-creation actions. Editing an existing log continues through the existing
log/history UI, unchanged.

**Implementation:** `beer_detail_screen.dart`'s primary log-creation button
and `_openLogForm` removed; `LogListSection`'s existing-log edit path
(`log_form_sheet.dart` reused, not duplicated) is untouched. Covered by
`mobile/test/features/catalog/presentation/beer_detail_screen_test.dart`
(asserts the button is absent; a separate test confirms the locked/unlocked
hero states).

### 2026-09-22 — Performance verification required before Discover untried-only ships — implemented (2026-09-23), see escalation below
Profiled the actual proposed query shapes (untried-only first page,
high-offset page, +search, +country/style filter, count) against a real,
RLS-enforced disposable Postgres at synthetic catalogs of ~2,000 / ~10,000 /
~50,000 beers, two selectivities (~7% and ~80% tried).

**Result:** acceptable (sub-~30ms) at all three sizes for plain browsing
(first page, country/style filter). **Not acceptable at 50,000 beers** for
two shapes: untried-only + text search (230–292ms) and deep pagination for
a low-tried-fraction user (~226ms at ~40% through the result set) — both
because the anti-join forces a full sequential scan of `beers`, which no
existing index can avoid. Per the explicit stop condition, **no index,
migration, or architecture change was made automatically.** See the new
escalation entry immediately below. The implemented `untried_only`/`is_tried`
feature itself ships as designed — the current real catalog (~8 beers) is
far below where this becomes observable, and Block 4 (Catalog Expansion) has
not started.

### 2026-09-23 — Manual QA regression: locked/unlocked visual was inverted in Discover and Add Beer — implemented (fix applied 2026-09-23), pending owner retest
Owner manual verification of the implemented Block 1 work found two real bugs
in the just-shipped locked/unlocked wiring (the underlying `is_tried` data
and the `LockableBeerImage` widget itself were correct — only the two screen
call sites were wrong):

- **Discover** (`discover_screen.dart`): every beer shown is untried by
  construction (server-side `untried_only`), so every tile must use the
  *locked* visual — but the call site passed `isUnlocked: !item.isTried`,
  which (since `isTried` is always `false` there) evaluated to `true`,
  showing every Discover beer as unlocked. The invariant is
  `isUnlocked == isTried`, not its negation.
- **Add Beer** (`add_beer_screen.dart`): same inverted expression
  (`isUnlocked: !item.isTried`) — a beer the user had already logged showed
  locked/gray, and a never-logged beer showed normal/unlocked, backwards
  from intent.

**Fix:** both call sites changed to `isUnlocked: item.isTried`. Collection
(`collection_tile.dart`) and Beer Detail
(`beer_detail_screen.dart`) were already correct and are unchanged.
Regression tests added asserting the lock icon's presence/absence per state
in Discover, Add Beer, and (net-new coverage) Collection
(`collection_tile_test.dart`).

Manual QA also found two related freshness bugs, fixed in the same pass:

- **Add Beer didn't update immediately after saving a new log.** Fixed with
  `AddBeerController.markTried(beerId)`, called only after
  `LogFormSheet.show` confirms a save succeeded — flips that one item's
  `isTried` in place (no re-search, no fake/optimistic pre-save state).
- **Discover didn't reflect a log created elsewhere (e.g. Add Beer).**
  `DiscoverController` now also listens to `CollectionRefreshSignal` (the
  same mutation-driven, navigation-independent signal
  `BeerLogController.submitCreate/submitUpdate/submitDelete` already fires,
  and `CollectionController` already listened to) and calls its existing
  `refresh()` on notification. Reused rather than replaced: the signal's
  actual trigger conditions were already generic ("any beer-log mutation
  anywhere"), only its name/doc comment were Collection-specific — the doc
  comment was broadened to name both consumers rather than introducing a
  second signal or renaming the class (smaller diff, no behavior change for
  existing Collection call sites).

**Not yet manually retested by the owner** — do not treat Block 1 as
manually verified until this fix is retested. See the manual-retest list at
the end of this entry's corresponding implementation report.

### 2026-09-23 — Escalation: Discover search/deep-pagination will need a scaling fix before Block 4's catalog growth — open
Evidence (see the performance entry above): at ~50,000 beers, `untried_only`
combined with text search takes ~230–290ms, and deep pagination for a user
who has tried few beers takes ~226ms — both driven by an unavoidable
sequential scan on `public.beers` (no index can pre-filter "not referenced
by another table"). Not a Block 1 blocker at today's real catalog size, but
must be resolved before Block 4 grows the catalog toward that range.
Candidate fixes to evaluate then (none implemented, none decided): a
trigram/`pg_trgm` index to speed the search side independent of the
anti-join, restructuring the anti-join (e.g. a materialized "untried count"
or a different join shape), or cursor-based pagination for the deep-offset
case. Owner decision needed on which to pursue once Block 4 is scheduled.

---

## Block 2 — Map

### 2026-09-22 — Country fill by unlocked percentage — open (not yet triaged)
Countries colored by the percentage of that country's catalog the user has
unlocked: gray when the catalog has beers but 0% unlocked, progressively more
amber/gold as completion rises, full gold at 100%.

### 2026-09-22 — Zero-catalog countries need an explicit visual treatment — open (not yet triaged)
Countries with zero catalog beers need a separate, explicit visual treatment,
to be designed later — must not be conflated with the 0%-unlocked-but-has-beers
gray state above.

### 2026-09-22 — Beer-origin points, locked gray / unlocked gold — open (not yet triaged)
Map points represent beer origin (not where a beer is sold), styled gray when
locked and gold when unlocked, consistent with the Block 1 locked/unlocked
visual language.

### 2026-09-22 — Brewery map mode should be reconsidered — open (not yet triaged)
Probably removed or separated from the main map mode; needs a decision.

---

## Block 3 — Profile

### 2026-09-22 — Duplicate Profile title — open (not yet triaged)
### 2026-09-22 — Additional statistics, including a spending statistic — open (not yet triaged)
### 2026-09-22 — More responsible achievements — open (not yet triaged)
Must not silently turn consumption volume into an achievement/competitive
metric — preserves the existing Responsible Product Design constraints in
CLAUDE.md.
### 2026-09-22 — Simplify beer suggestion UI to name-only — open (not yet triaged)
### 2026-09-22 — Contribution-owner notification strategy — open (not yet triaged)
To be resolved later.
### 2026-09-22 — Creator-support section concept — open (not yet triaged)
Concept only; payment implementation deferred until legally/operationally
appropriate (per existing CLAUDE.md guidance).

---

## Block 4 — Catalog Expansion

### 2026-09-22 — Catalog is insufficient (currently ~8 beers) — open (not yet triaged)
Need a strategy for thousands of real beers: legitimate/licensed/open data
sources, images and image licensing, deduplication, barcodes,
breweries/styles/countries, origin coordinates. No blind scraping or copying
unlicensed datasets/images.

---

## Block 5 — Polish

### 2026-09-22 — Final BeerApp logo on auth screen — open (not yet triaged)
### 2026-09-22 — Locale follows system locale when supported, else English — open (not yet triaged)
More languages later; not a priority now.
