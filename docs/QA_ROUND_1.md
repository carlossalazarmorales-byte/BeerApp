# QA Round 1

Manual QA backlog. Every item gets an explicit resolution over time: implemented,
intentionally redesigned with owner approval, or explicitly deferred/rejected
with a documented reason. Status tags: open / implemented / deferred / rejected.

---

## Block 1 — Core UX

### 2026-09-22 — Locked/unlocked beer visual state — open (decided, pending implementation)
A beer is "unlocked" for the current user once they have at least one log for
it. Unlocked: normal image/presentation. Locked: grayscale/muted image (never
fully opaque, never blurred), a small lock badge as a corner overlay (not a
large centered icon obscuring the image), beer remains fully tappable, detail
screen remains readable. Accessibility semantics must announce locked state
without making the tile inaccessible. One shared, reusable presentation
component — not per-screen logic. No DB migration is currently expected for
this specific join: the existing `user_beer_logs`
`(user_id, beer_id, consumed_at, id)` index already serves the per-beer EXISTS
lookup this requires, and this EXISTS pattern is already implemented and
exercised by the current Map and Collection query paths.

### 2026-09-22 — Discover is untried-only, no toggle — open (decided, pending implementation)
The Discover *screen* must show only beers the current user has not yet
unlocked/tried, with no user-facing toggle. Tried beers remain reachable via
Collection, map, and detail flows. This is a product rule for Discover
specifically — it does **not** mean the underlying catalog endpoint loses the
ability to return the full catalog. See the next entry for how Add Beer's
different requirement is kept compatible with this. Must stay server-side
(anti-join in the paginated query), keep existing pagination/infinite-scroll,
search, and filters. See the performance-note entry below before
implementing.

### 2026-09-22 — Add Beer search uses the full catalog, not untried-only — open (decided, pending implementation)
Add Beer's manual search/select step must be able to find *any* catalog beer,
including beers the user has already tried — a user may deliberately log the
same beer again. Barcode-scanner identification inside Add Beer must likewise
resolve both tried and untried beers. Consequently `GET /beers` (or its
repository layer) must keep a general, reusable "list catalog beers" behavior;
the untried-only exclusion is a mode Discover explicitly requests (e.g. a
query/repository parameter), not a permanent property of the endpoint. Do not
build a second catalog implementation for Add Beer — both features must go
through the same underlying repository/query/search/filter logic, just with
that parameter set differently.

### 2026-09-22 — Filter sheet overflow (Collection + Discover) — open (decided, pending implementation)
Real bug: Collection's filter sheet produces "Bottom Overflowed by 155
pixels" and blocks reaching search/apply/exit controls. Root cause: a plain
non-scrollable `Column` inside the bottom sheet. The identical structural
defect exists in Discover's own filter sheet (not yet reported by QA, but
present) and must be fixed in the same pass, not deferred. Target layout:
fixed header (if applicable), scrollable filter content, fixed/reachable
bottom actions, safe on small screens, large option counts, and supported
text scaling. Regression tests required for both sheets.

### 2026-09-22 — Center nav becomes Add Beer (+), Scanner demoted to secondary — open (decided, pending implementation)
Center bottom-nav action changes from Scanner-first to a Plus/Add Beer
screen. Scanner is no longer a primary bottom-nav destination. Add Beer
screen: primary path is search → select beer (full catalog, see above) →
existing `LogFormSheet` → save; secondary path is "Scan barcode" → existing
scanner → if a beer is identified (tried or untried) → same `LogFormSheet` →
save. Scanner must never auto-create or auto-save a log (already true today —
preserve this). Implementation replaces the current Scan `StatefulShellBranch`
in the router with an Add branch; Scanner becomes a push-only route reached
from Add. Today the scanner navigates a recognized barcode straight to Beer
Detail; under the new flow it instead needs to return the identified beer back
into the Add flow (a result-return/callback/route-result mechanism, whichever
fits the existing router architecture), so some change to the scanner
screen/controller/route-result flow should be expected — this is not
predeclared as untouched. Constraints: preserve the existing barcode-decoding
implementation, do not build a second scanner, preserve the existing
unknown-barcode → suggest-a-beer contribution handoff as-is, and ensure both a
known *tried* and a known *untried* beer can return into the Add flow.

### 2026-09-22 — Log creation centralized through Add flow — open (decided, pending implementation)
User-facing creation of new logs happens only through the Add/+ flow. Remove
Beer Detail's "Log / Register Beer" creation action. Beer Detail remains for
information, existing log/history display, and other non-creation actions.
Editing an existing log continues through the existing log/history UI
(unchanged). Reuse the existing `LogFormSheet`/`BeerLogController` from the
Add flow — do not duplicate the form.

### 2026-09-22 — Performance verification required before Discover untried-only ships — open
No DB migration is currently expected from the existing schema/indexes, but
this must not be treated as a final conclusion until the Discover
untried-only query is profiled. Before shipping, profile the actual proposed
query shape (Discover's anti-join mode, not Add Beer's general mode) on the
disposable database at synthetic catalog sizes of ~2,000 / ~10,000 / ~50,000
beers (comparable to Phase 14). Measure, using `EXPLAIN (ANALYZE, BUFFERS)`
where useful: untried-only first page, untried-only high-offset page,
untried-only + search, untried-only + country/style filters, and the count
query if pagination keeps one. Do not add `pg_trgm`, new indexes, cursor
pagination, or migrations unless this evidence shows a real need — if it
does, report that as a separate proposal before implementing it. This
profiling is the first sub-step of the Discover untried-only implementation
stage, not a separate documentation task.

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
