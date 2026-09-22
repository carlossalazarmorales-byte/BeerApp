# Database

PostgreSQL, hosted via Supabase. Ten tables exist in `public`:

- `public.profiles` (Phase 2, extended Phase 12);
- the four global catalog tables (Phase 3): `public.countries`,
  `public.beer_styles`, `public.breweries`, `public.beers`;
- the user-owned tables `public.user_beer_logs` (Phase 6),
  `public.user_beer_collection` (Phase 7) and `public.user_achievements`
  (Phase 10);
- `public.beer_contributions` and `public.brewery_contributions` (Phase 13) —
  private *proposals* for catalog growth, never catalog rows.

Two dedicated roles, `beerapp_backend` (the running API) and `beerapp_seed` (the
dev seed script only), gate access to them, and a `private` schema holds three
trigger/helper functions (see "Function privileges in schema `private`"). There
are 19 migrations under `supabase/migrations/`, all applied to `beerapp-dev`.
Every table has RLS enabled; the access model is below.

## Planned approach

- Schema changes go through migrations — no undocumented destructive changes.
- Every table gets a primary key, explicit foreign keys, appropriate
  constraints, and indexes for common query patterns (e.g. catalog lookups by
  country, brewery, style).
- Row-Level Security (Supabase) enforces least-privilege access — see
  "Access model" below.
- Migrations are managed via the Supabase CLI in **remote-only** mode (no
  local Docker dev stack) — `supabase migration new`, hand-edited SQL,
  `supabase db push --dry-run` then `supabase db push`. See `docs/DECISIONS.md`.
  (That describes how migrations reach the *dev project*. The integration tests
  use a separate, disposable database - a local Supabase stack when Docker is
  available, otherwise the repository's PostgreSQL scaffold; see "Testing".)

## `public.profiles` (Phase 2, extended Phase 12)

1:1 with `auth.users`, deliberately minimal — only what application code
actually reads or writes:

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key references auth.users(id) on delete cascade` | same UUID as the auth user |
| `username` | `text`, nullable | non-null immediately for email signups; null for Google signups until `/complete-profile` is completed. Never a placeholder value. |
| `display_name` | `text`, nullable | falls back to `username` in the UI |
| `preferred_currency` | `text`, nullable | Phase 12; `CHECK (preferred_currency is null or preferred_currency ~ '^[A-Z]{3}$')` — the identical shape as `user_beer_logs.currency`'s CHECK. A Settings preference only: never rewrites/derives from any existing `user_beer_logs.currency` value, and Statistics' per-currency `amount_spent` grouping is unaffected (see `docs/DECISIONS.md`). |
| `created_at` | `timestamptz not null default now()` | |
| `updated_at` | `timestamptz not null default now()` | auto-updated via trigger |

**RLS**: `select_own`/`update_own` policies restrict a user to their own row.
No client-facing `INSERT`/`DELETE` policy. Unaffected by Phase 3 — no FK from
any catalog table to `profiles`, preserving `CLAUDE.md`'s Data Model Rule.
Both policies are row-level (`auth.uid() = id`), and the table-level
`grant select, update ... to authenticated` has no column list, so neither
needed a migration change to cover `preferred_currency` — see
`docs/DECISIONS.md`.

Avatar and preferred units remain deliberately unmodeled in Phase 12 — see
`docs/DECISIONS.md` for the deferral rationale. Language preference is also
not a column here: it's a local, device-only override (see
`mobile/lib/core/locale/`), never persisted server-side.

## Catalog tables (Phase 3)

Global, shared, not user-owned — see `CLAUDE.md`'s Data Model Rule and
`docs/ARCHITECTURE.md`'s "Global catalog vs. personal data". `user_beer_logs`,
`favorites`, and `wishlist` — named in `ROADMAP.md`'s original Phase 3 entity
list — are **deferred to Phase 6 (Logging a Beer) / Phase 7 (Personal
Collection)**, where they naturally belong as user-owned entities; Phase 3
built catalog data and the protected backend foundation only. See
`docs/DECISIONS.md`.

### `public.countries`

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `iso_code` | `text not null unique` | ISO 3166-1 alpha-2, `CHECK (iso_code ~ '^[A-Z]{2}$')` |
| `name` | `text not null` | non-blank CHECK, case-insensitive unique index |
| `continent` | `text not null` | fixed CHECK vocabulary (Africa/Antarctica/Asia/Europe/North America/Oceania/South America) — changing the vocabulary still requires a migration |
| `created_at` / `updated_at` | `timestamptz not null default now()` | `updated_at` via `private.set_updated_at()` |

Added for map-style grouping (the `mapa_interactivo` mockup's "Across Europe"
sidebar). There is deliberately no separate `regions` table — `region` stays
free text on `breweries`/`beers`, exactly as `PRODUCT.md` §7 lists it. See
`docs/DECISIONS.md`.

### `public.beer_styles`

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `name` | `text not null` | non-blank CHECK, case-insensitive unique index |
| `category` | `text`, nullable | free text, no fixed taxonomy |
| `description` | `text`, nullable | |
| `origin_country_id` | `uuid references countries(id)`, nullable | |
| `typical_abv_min` / `typical_abv_max` | `numeric(4,2)`, nullable | both `>= 0`, max `>=` min when both present |
| `created_at` / `updated_at` | `timestamptz` | as above |

### `public.breweries`

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `name` | `text not null` | non-blank CHECK; **not unique** — different breweries can legitimately share a name; search index only (`lower(name)`) |
| `country_id` | `uuid not null references countries(id)` | |
| `region` / `city` | `text`, nullable | |
| `latitude` / `longitude` | `numeric(9,6)`, nullable | paired (both null or both set), range-checked |
| `description` / `website` / `logo_url` | `text`, nullable | |
| `verified` | `boolean not null default false` | |
| `source` | `text`, nullable | provenance (`PRODUCT.md` §20) |
| `created_at` / `updated_at` | `timestamptz` | as above |

### `public.beers`

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `official_name` | `text not null` | non-blank CHECK; **not unique** — beer names are not globally unique |
| `brewery_id` | `uuid not null references breweries(id)` | |
| `style_id` | `uuid references beer_styles(id)`, nullable | never a placeholder style |
| `country_id` / `region` / `city` / `latitude` / `longitude` | nullable | a beer's own origin, independent of its brewery's (e.g. brewed for a different market) |
| `abv` | `numeric(4,2)`, nullable | `0–100` |
| `ibu` | `integer`, nullable | `>= 0`, no invented upper bound |
| `description` / `image_url` | `text`, nullable | |
| `barcode` | `text`, nullable | unique partial index `WHERE barcode IS NOT NULL`; scanner lookup via `GET /beers/barcode/{barcode}` (Phase 11, see `docs/API.md`). Stores the canonical GTIN form only (EAN-13/EAN-8 as-is, UPC-A zero-prefixed) — **at most one barcode per beer**; a future packaging/market variant needing multiple codes for one beer would require a normalized `beer_barcodes` table, not built now (see `docs/DECISIONS.md`) |
| `verified` | `boolean not null default false` | |
| `source` | `text`, nullable | |
| `created_at` / `updated_at` | `timestamptz` | as above |

All FKs are `ON DELETE RESTRICT` (the default) — deleting a country/brewery/
style with dependents fails loudly rather than silently orphaning or cascading.

## `public.user_beer_logs` (Phase 6)

The first user-owned entity referencing the catalog — a personal record of
having tried/reviewed a beer, distinct from the global `public.beers` row it
points to (`CLAUDE.md`'s Data Model Rule). A user may log the same beer
multiple times — there is deliberately no `unique(user_id, beer_id)`.

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `user_id` | `uuid not null references auth.users(id) on delete cascade` | owner identity FK — cascades like `profiles.id`, unlike the catalog's `RESTRICT` convention, since the referenced row is the log's own owner, not a shared catalog entity |
| `beer_id` | `uuid not null references beers(id) on delete restrict` | shared catalog reference — `RESTRICT` matches every other FK onto the catalog |
| `rating` | `smallint`, nullable | `1–5` |
| `review` | `text`, nullable | |
| `consumed_at` | `timestamptz not null default now()` | resolved explicitly by the service when omitted (see `docs/API.md`); the DB default is a safety net, not relied upon by the app path |
| `serving_note` | `text`, nullable | |
| `price` / `currency` | `numeric(10,2)` / `text`, nullable | paired (both null or both set); `currency` matches `^[A-Z]{3}$` |
| `venue_name` | `text`, nullable | |
| `serving_volume_ml` | `integer`, nullable | canonical unit is milliliters (`PRODUCT.md` §24); `> 0` when present, no invented upper bound; **never populated automatically** — see `docs/DECISIONS.md` for the scoped product exception this field represents |
| `created_at` / `updated_at` | `timestamptz` | as above, same shared `private.set_updated_at()` trigger, unchanged |

Two composite indexes, chosen to match the app's actual query patterns (both
end in `consumed_at desc, id desc` — `id` is the stable tie-breaker so
pagination stays deterministic when two logs share a `consumed_at`):

- `(user_id, consumed_at desc, id desc)` — the caller's general log history
  (Phase 7).
- `(user_id, beer_id, consumed_at desc, id desc)` — Beer Detail's per-beer
  history; its leftmost columns also cover a plain `(user_id, beer_id)`
  lookup, so no separate index exists for that.

**RLS — request-scoped, not `USING (true)`.** Unlike the catalog tables
(where a blanket `USING (true)` policy for `beerapp_backend` is fine, since
every row is equally readable by any authenticated user), `user_beer_logs`
needs real per-user isolation. The policy compares each row's `user_id`
against a transaction-local Postgres setting, `app.user_id`, that the backend
sets via `select set_config('app.user_id', <verified JWT sub>, true)` at the
start of every `user_beer_logs` transaction
(`backend/app/repositories/beer_logs.py`'s `BeerLogRepository._scoped`):

```sql
create policy backend_owns_rows on public.user_beer_logs
  for all
  to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid)
  with check (user_id = nullif(current_setting('app.user_id', true), '')::uuid);
```

`nullif(..., '')` matters: `current_setting('app.user_id', true)` returns
`NULL` when never set, but a cleared/reset custom GUC can read back as an
empty string depending on session state — casting `''` straight to `uuid`
raises an error rather than cleanly denying access. Normalizing both cases to
`NULL` first means the comparison always evaluates to `NULL` (never `TRUE`,
never an error) when there's no request identity, so an absent/cleared
identity **fails closed** — denies all rows — rather than granting blanket
access or raising a 500. The repository still filters `where user_id = $N`
explicitly on every query in addition to this policy: the RLS policy is a
backstop that makes an isolation bug in the SQL non-exploitable, not a
replacement for careful queries. Verified directly (including deliberately
unfiltered/cross-identity queries a correct repository would never write) by
`backend/tests/integration/test_user_beer_logs_rls.py`.

`beerapp_backend` gets `SELECT`/`INSERT`/`UPDATE`/`DELETE` scoped to this one
table — the running API's first write endpoint anywhere in the backend. It
remains `SELECT`-only on the four catalog tables; this grant is least-privilege,
not a broadening of catalog access.

## `public.user_beer_collection` (Phase 7)

The second user-owned table on the same pattern as `user_beer_logs` above —
canonical favorite/wishlist state, one row per `(user_id, beer_id)`. Distinct
from `user_beer_logs`: a log is a repeatable historical event (a user may log
the same beer many times), while this is toggleable current-state
membership. See `docs/DECISIONS.md` for why one table with two booleans was
chosen over separate `favorites`/`wishlist` tables.

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `user_id` | `uuid not null references auth.users(id) on delete cascade` | owner identity FK, same cascade exception as `user_beer_logs.user_id` |
| `beer_id` | `uuid not null references beers(id) on delete restrict` | shared catalog reference |
| `is_favorite` / `is_wishlist` | `boolean not null default false` | independent flags — a beer can be both, either, or (as a *row*) neither is never actually stored, see below |
| `favorited_at` / `wishlisted_at` | `timestamptz`, nullable | set only on that flag's `false→true` transition, cleared on `true→false` — deliberately **not** `updated_at` (bumped by *any* column change, so it can't answer "most recently added to this state" on its own) |
| `created_at` / `updated_at` | `timestamptz` | as above, same shared trigger |

Constraints: `unique(user_id, beer_id)` (also the `ON CONFLICT` target for
the atomic upsert below), and paired CHECKs
(`(is_favorite) = (favorited_at is not null)`, same for wishlist).
**Deliberately no `CHECK (is_favorite OR is_wishlist)`**: an earlier design
had exactly that CHECK, using a Postgres rejection as the signal to fall back
to a `DELETE`. That's unsafe under concurrency — CHECK constraints aren't
deferrable, so recovering from the violation means rolling back to a
savepoint, and that rollback releases any row lock acquired after it,
reopening a window where a concurrent transaction can grab the row between
the failed write and the follow-up delete. The invariant — an all-false
state is represented by *no row*, never a stored row — still holds; it's
enforced entirely by `CollectionRepository.set_state`
(`backend/app/repositories/collection.py`), the only write path to this
table, inside one uninterrupted transaction:

```sql
insert into public.user_beer_collection
  (user_id, beer_id, is_favorite, is_wishlist, favorited_at, wishlisted_at)
values ($1, $2, coalesce($3, false), coalesce($4, false), ...)
on conflict (user_id, beer_id) do update set
  is_favorite = coalesce($3, user_beer_collection.is_favorite),
  is_wishlist = coalesce($4, user_beer_collection.is_wishlist),
  ...
returning ...;
-- then, in the same transaction, if the returned row is now false/false:
delete from public.user_beer_collection where user_id = $1 and beer_id = $2;
```

`$3`/`$4` are `NULL` when a PATCH field was omitted ("preserve current").
`coalesce(..., user_beer_collection.is_favorite)` reads the *live* row at the
moment of the locked write (not a value computed in application code before
either transaction committed), which is what makes two concurrent PATCHes on
the same row merge correctly instead of one clobbering the other's field —
verified against four required concurrency scenarios in
`backend/tests/integration/test_collection_concurrency.py`. See
`docs/DECISIONS.md` for the full derivation.

Two partial indexes serve the Favorites/Wishlist tabs (each `WHERE`-guarded
so the other flag's rows don't bloat it):

- `(user_id, favorited_at desc, id desc) where is_favorite`
- `(user_id, wishlisted_at desc, id desc) where is_wishlist`

The `unique(user_id, beer_id)` index also serves Beer Detail's single-row
lookup and the Logged tab's join onto this table.

**RLS/grants** are the identical shape as `user_beer_logs` — same
`backend_owns_rows` policy (`app.user_id` + `nullif(..., '')`), same
`SELECT`/`INSERT`/`UPDATE`/`DELETE` grant to `beerapp_backend` only,
`anon`/`authenticated` denied at both the grant and policy level. Verified by
`backend/tests/integration/test_user_beer_collection_rls.py`.

## Statistics (Phase 9)

No new table, column, or migration — `GET /statistics` (`StatisticsRepository`)
reads `user_beer_logs`, `user_beer_collection`, and the catalog tables
entirely **read-only**, aggregating server-side via a handful of SQL
queries/CTEs. It reuses `scoped_connection` and the same `backend_owns_rows`
RLS policies described above; there is nothing Statistics-specific at the
schema level.

The one thing that *is* Statistics-specific: `scoped_connection` gained an
optional `isolation` parameter (default `None`, preserving every existing
caller's plain `READ COMMITTED` behavior unchanged — `BeerLogRepository`,
`CollectionRepository`, and `MapRepository` all still call it with zero
extra arguments). `StatisticsRepository` is the only caller that passes
`isolation="repeatable_read"`, so its several read-only aggregate statements
(overview counts, amount-spent-by-currency, monthly/yearly activity,
favorites) all observe one consistent snapshot for the whole request, rather
than each seeing whatever happened to be committed by the time it ran. See
`docs/DECISIONS.md` for why `REPEATABLE READ` was chosen over merging
everything into a single mega-query.

## `public.user_achievements` (Phase 10)

Persists only the *unlocked* moment of an achievement — never progress,
which stays fully derived at read time from `user_beer_collection` (same
philosophy as Statistics above). Achievements are permanent once unlocked
(product decision, see `docs/DECISIONS.md`), which is what this table's
shape and grants are built around.

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `user_id` | `uuid not null references auth.users(id) on delete cascade` | owner identity FK |
| `achievement_key` | `text not null` | **not** an FK or enum — validated only against `ACHIEVEMENT_CATALOG` in `backend/app/services/achievement_catalog.py` (see `docs/DECISIONS.md` for why the catalog is code, not a table). A persisted row whose key is no longer in the current catalog (a retired achievement) is silently ignored by the application, not an integrity error. |
| `unlocked_at` | `timestamptz not null default now()` | written once; see below |

Constraint: `unique(user_id, achievement_key)` — also the `ON CONFLICT DO
NOTHING` target for the idempotent unlock write. No `created_at`/`updated_at`
and no `set_updated_at` trigger: rows are write-once and are never updated.

**Grants are deliberately `SELECT, INSERT` only** — no `UPDATE`, no `DELETE`
— for `beerapp_backend`. This makes revocation or rewriting an achievement
impossible at the database level, not merely by repository convention.

**RLS uses two explicit, command-specific policies** rather than the single
`for all` `backend_owns_rows` policy used on `user_beer_logs`/
`user_beer_collection`:

```sql
create policy backend_select_own on public.user_achievements
  for select to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid);

create policy backend_insert_own on public.user_achievements
  for insert to beerapp_backend
  with check (user_id = nullif(current_setting('app.user_id', true), '')::uuid);
```

This is a deliberate, narrow deviation, not a case the established
convention required — `user_achievements` is the first write-once
(insert-only) user-owned table, so splitting the policy by command gives
defense-in-depth that mirrors the already-narrower grant: even if `UPDATE`/
`DELETE` were mistakenly granted later, there would still be no matching
policy to authorize rows under either command. Covered by
`backend/tests/integration/test_user_achievements_rls.py` (written; not yet
executed against a disposable database in this environment — see ROADMAP.md
Phase 10 status). The grant/policy shape itself was independently confirmed
by a read-only check directly against `beerapp-dev` when the migrations were
applied.

**`unlocked_at` semantics**: for an achievement evaluated synchronously
alongside its triggering mutation (in Phase 10, every Collection `PATCH`
via `AchievementEvaluator`, invoked in the *same* database transaction as
the `user_beer_collection` write — see `docs/DECISIONS.md`), this is the
timestamp of the first successful atomic transaction that detected and
persisted the satisfied condition. For anything only ever caught by the
`GET /achievements` repair/backfill evaluation, it means "first detected by
the system" — never a reconstructed or fabricated historical moment.
`ON CONFLICT DO NOTHING` guarantees it is never rewritten once set.

## `public.beer_contributions` / `public.brewery_contributions` (Phase 13)

User-owned **proposals** for catalog growth — a beer or brewery a user says is
missing. **A contribution is not a catalog row**: nothing in this phase writes
`public.beers`, `public.breweries`, `public.beer_styles` or `public.countries`,
and nothing about a contribution is visible through Discover, Map, Statistics
or Achievements (they read only the catalog and the personal-activity tables).
It is deliberately *not* modeled as an unverified `beers`/`breweries` row:
catalog reads do not filter on `verified`, so such a row would appear in
Discover the moment it was inserted. Two typed tables rather than one generic
table with a JSON payload: the two entities have different required columns
and constraints.

Both tables share the lifecycle/ownership columns:

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key default gen_random_uuid()` | |
| `user_id` | `uuid not null references auth.users(id) on delete cascade` | owner; cascades like every user-owned table, so `DELETE /account` (Phase 12) stays complete. Never exposed to other users or in any API response |
| `status` | `text not null default 'pending'` | `CHECK` in `('pending','approved','rejected')`. **Only `pending` is reachable today**: no moderator workflow exists, and the INSERT policy pins `status = 'pending'` |
| `reviewed_at` / `review_note` | `timestamptz` / `text`, nullable | moderation columns, reserved for a future moderator. `CHECK`: `(status = 'pending') = (reviewed_at is null)`, no `review_note` while pending, note ≤ 500 |
| `resolved_beer_id` / `resolved_brewery_id` | `uuid`, nullable, `references beers/breweries on delete restrict` | set by a future moderator on approval. `CHECK`: `(status = 'approved') = (resolved_* is not null)` |
| `created_at` | `timestamptz not null default now()` | write-once — no `updated_at`, no trigger (same rationale as `user_achievements`) |

`beer_contributions` adds: `official_name` (required, 1–200 after trim);
`brewery_id` **XOR** `proposed_brewery_name` (`CHECK num_nonnulls = 1`);
`style_id` / `proposed_style_name` (at most one — a style stays optional);
`abv numeric(4,2)` (0–99.99, same as `beers.abv`); `barcode` (nullable,
canonical GTIN only — `CHECK ^([0-9]{8}|[0-9]{13})$`; the GS1 check digit is
validated once, in `backend/app/services/barcode.py`, not duplicated in SQL).
There is deliberately **no reference to `brewery_contributions`**: a beer
suggestion whose brewery is not in the catalog carries the free-text
`proposed_brewery_name` and never depends on a separate brewery suggestion.

`brewery_contributions` adds: `name` (required, 1–200); `country_id` **XOR**
`proposed_country_name`; `region` / `city` (optional, 1–100). No coordinates,
website or description — a moderator verifies and geocodes.

The `proposed_*` columns are how "not in the list" is modeled: an explicit
free-text proposal, never a write to `countries`/`beer_styles`/`breweries`.
All FKs onto the catalog are `ON DELETE RESTRICT`, matching every other FK
onto it.

**Indexes.** Both: `(user_id, created_at desc, id desc)` for the history list.
Own-duplicate guards — partial **unique** indexes `where status = 'pending'`
on `(user_id, lower(btrim(name)), <canonical id>)` and on
`(user_id, lower(btrim(name)), lower(btrim(<proposed name>)))` (two indexes
each, one per form, so no `uuid::text` cast sits in an index expression): one
user cannot hold two equivalent pending suggestions, so a retry or double-tap
cannot create two rows. Deliberately per-user: other users' rows are private,
so cross-user name duplicates are a future moderator's concern. On
`beer_contributions` there is also a **non-unique** partial index on
`(barcode) where barcode is not null and status = 'pending'` — two users may
each have the same barcode pending (the second is *flagged*, not blocked; see
`docs/DECISIONS.md`), and the index serves both the flag lookup and a future
moderator's duplicate search.

**RLS and grants — the `user_achievements` shape.** RLS is enabled;
`anon`/`authenticated` are `REVOKE`d everything; `beerapp_backend` gets
`SELECT` and `INSERT` only — **no `UPDATE`, no `DELETE`**, so a user can
neither edit, withdraw nor approve a submission at the database level (a
future moderator will use a separate privileged role, never this one). Two
command-specific policies keyed on the transaction-scoped `app.user_id`, the
same fail-closed `nullif(...)` pattern as `user_beer_logs`:

```sql
create policy backend_select_own on public.beer_contributions
  for select to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid);

create policy backend_insert_own on public.beer_contributions
  for insert to beerapp_backend
  with check (
    user_id = nullif(current_setting('app.user_id', true), '')::uuid
    and status = 'pending'
  );
```

(identical on `brewery_contributions`). The `status = 'pending'` in the INSERT
policy means even a row that satisfies every table `CHECK` cannot be inserted
already approved. `beerapp_backend` remains `SELECT`-only on the four catalog
tables.

**`private.other_user_pending_beer_barcode_exists(p_barcode text) returns
boolean`.** The one cross-user question the duplicate check needs — "does
*another* user have a pending suggestion with this barcode?" — cannot be
answered under owner-only RLS, and the policy is deliberately **not** widened.
Instead a narrowly scoped `SECURITY DEFINER` function answers it with a bare
boolean and never returns a row, id, `user_id` or any identity. It follows the
existing `SECURITY DEFINER` precedent (`private.handle_new_user()`): lives in
the non-API-exposed `private` schema, `set search_path = ''` with every object
schema-qualified, no dynamic SQL, `EXECUTE` revoked from
`PUBLIC`/`anon`/`authenticated` and granted only to `beerapp_backend` (which
gains `USAGE` on schema `private` — the one new privilege on it, granting no
table access). The caller's identity is read from `app.user_id` *inside* the
function rather than passed as an argument, so "exclude my own rows" cannot be
bypassed; with no identity set it returns `false` (fails closed). A caller's
own pending rows are excluded on purpose — an identical own suggestion is a
separate hard block (the unique indexes above).

Verified against a real Postgres by
`backend/tests/integration/test_contributions_constraints.py` (CHECKs, unique
indexes, FK delete rules, the cascade — including an actual `auth.users`
delete), `test_contributions_rls.py` (owner-only visibility, forged
`user_id`/`status`, no `UPDATE`/`DELETE`, no client-role access, the function's
behavior and privileges), and `test_contributions_service_end_to_end.py` (the
real service running as `beerapp_backend`, including "the catalog is exactly as
it was afterward").

## Access model (RLS + roles)

Catalog access is **API-only**: the mobile app never queries these four
tables through Supabase PostgREST directly, not even as an authenticated
user. This is enforced at the database level, not just by convention:

| role | catalog privileges | `user_beer_logs` / `user_beer_collection` privileges | `user_achievements` privileges | `beer_contributions` / `brewery_contributions` privileges |
|---|---|---|---|---|
| `anon` | none | none | none | none |
| `authenticated` | none | none | none | none |
| `beerapp_backend` | `SELECT` only, all four catalog tables — the running FastAPI app's connection (`DATABASE_URL`) | `SELECT`/`INSERT`/`UPDATE`/`DELETE` on both, own rows only per the request-scoped RLS policy above (Phase 6/7) | `SELECT`/`INSERT` only, own rows only (Phase 10) — no `UPDATE`/`DELETE` | `SELECT`/`INSERT` only, own rows only, `INSERT` pinned to `status = 'pending'` (Phase 13) — no `UPDATE`/`DELETE`; plus `EXECUTE` on the boolean-only `private.other_user_pending_beer_barcode_exists` |
| `beerapp_seed` | `SELECT`/`INSERT`/`UPDATE`/`DELETE`, all four catalog tables — `backend/scripts/seed_catalog.py` only (`SEED_DATABASE_URL`), never the running API | none | none | none |

Per-user ownership on `user_beer_logs`/`user_beer_collection` is enforced by
the repository's explicit `WHERE user_id = $1` filtering plus the
transaction-scoped RLS policy above (both tables share the same
`scoped_connection` helper, `backend/app/repositories/scoped_connection.py`)
— not by `auth.uid()` (there is no PostgREST session here, unlike `profiles`)
and not by a blanket `USING (true)` policy.

RLS is enabled on all four tables. `anon`/`authenticated` have **no policies
at all** on them (deny-by-default) plus an explicit `REVOKE ALL` at the table
grant level — belt-and-suspenders, same pattern as `profiles`. `beerapp_backend`
and `beerapp_seed` each have their own explicit policy (`USING (true)`, scoped
`TO` that role) rather than `BYPASSRLS` — neither role needs to bypass RLS to
do its job, so neither gets the broader privilege. Verified directly (not just
asserted) by `backend/tests/integration/test_role_grants.py` and, for the
constraint set, `backend/tests/integration/test_constraints.py`.

Neither `beerapp_backend` nor `beerapp_seed` is the project's `postgres`
admin role — Supabase's current guidance is a separate, scoped database user
per external service, not the project's admin credentials. See
`docs/DECISIONS.md` for the full rationale, including why `beerapp_seed`
exists as a second dedicated role rather than reusing the project's admin
connection as originally planned.

**Manual step after applying `supabase/migrations/..._create_beerapp_backend_role.sql`
and `..._create_beerapp_seed_role.sql`**: neither migration sets a password
(none is committed). Both were set manually against the project (outside any
migration) and are now in the local `.env` as `DATABASE_URL` and
`SEED_DATABASE_URL` respectively. They were **rotated by the project owner in
Phase 14** (a test file had committed the earlier values); the local `.env` holds
the current ones and no password is in any tracked file. When first set, a one-off
privilege check against the project covered both roles (`beerapp_seed`: `SELECT`/
`INSERT`/`UPDATE`/`DELETE` succeed on the four catalog tables, `SELECT` on
`public.profiles` correctly denied). The privilege boundary is now verified
continuously against the **disposable** database by `test_role_grants.py` and
`test_security_audit.py` (see "Testing" below) - not against the shared project.
See `docs/DECISIONS.md` for the session history.

## Connection strategy

Two distinct connection strings — `DATABASE_URL` (`beerapp_backend`, read
path for the running API) and `SEED_DATABASE_URL` (`beerapp_seed`, write path
for the seed script only) — are never the same value and neither is
committed. Both are backend-only: they live in the repo-root `.env` (git
ignored) and are never referenced from `mobile/config/*`.

This dev machine is IPv4-only without the Supabase IPv4 add-on, so both
connections use the **Shared Pooler in Session mode** (port 5432,
`aws-1-eu-west-1.pooler.supabase.com`), not Direct Connection and not
Transaction mode (port 6543) — Transaction mode doesn't support server-side
prepared statements, which a persistent backend pool relies on by default.
If `DATABASE_URL`/`SEED_DATABASE_URL` are ever pointed at a Transaction
Pooler connection instead, `app/config.py`'s `db_statement_cache_size` must
be set to `0`. SSL is required and enforced in code (`app/db.py`), not just
assumed from the DSN. `ssl="require"` **encrypts the connection but does not verify
the server certificate**, so it does not defend against an active man-in-the-middle
on the path to the pooler; whether to verify or pin the CA is a deployment decision.

The pool is bounded on every axis (Phase 14): connect 10 s
(`DB_CONNECT_TIMEOUT_SECONDS`), acquiring a pooled connection 10 s
(`DB_ACQUIRE_TIMEOUT_SECONDS`), and each statement 30 s
(`DB_COMMAND_TIMEOUT_SECONDS`). A timeout or an unreachable/saturated database
surfaces as a sanitized `503` (see `docs/API.md`), never a hung request.

## Seed strategy (dev)

`backend/scripts/seed_catalog.py`, run manually, connects via
`SEED_DATABASE_URL` only — never `DATABASE_URL`, which has no write
privilege. Since Phase 14 it also refuses to run unless `ENVIRONMENT` is `local`
or `dev` (unset counts as `local`), `SEED_DATABASE_URL` is set and differs from
`DATABASE_URL`, and `--yes` is passed; without `--yes` it prints only the target
host (never credentials) and exits — it writes fabricated `verified` rows, so it
must never reach a production database. Idempotent: `countries` upserts on its genuine natural key
(`iso_code`); `beer_styles`/`breweries`/`beers` have no natural unique key
(names are not globally unique, by design), so each seeded row uses a
deterministic fixed UUID constant and upserts on `id` — no UNIQUE constraint
was added purely to make seeding easier. Seeded rows are marked
`source = 'dev-seed'`. Never shipped as a migration.

Run twice against the dev project; row counts (10 countries, 8 beer styles,
6 breweries, 8 beers) were identical both times, confirming no duplicates.

## Production reference data and beta catalog tooling (Phase 15, Stage 1A)

A new project's `countries`, `beer_styles`, `breweries` and `beers` are empty: no migration
loads them, and the dev seed above must never reach production. Phase 15 adds **files, not
migrations, applied nowhere**:

- `supabase/reference_data/countries.sql` - 249 country/territory codes exposed by OpenJDK 21.0.6
  (**not verified against the ISO 3166 Maintenance Agency**; OpenJDK/CLDR are documented,
  reproducible sources, not the ISO issuing authority) with CLDR 42 English names and
  UN-M49-derived continents (mapped onto the table's 7 continent values); prepared from factual
  sources, **owner review pending** (`countries_review.md`).
- `supabase/reference_data/beer_styles_DRAFT.sql` - 55 generic styles proposed by the assistant;
  **not reviewed, not production-approved**, no descriptions.
- `supabase/catalog_beta/beta_catalog_template.sql` - an unfilled template (fake placeholders only)
  for owner-reviewed breweries and beers, with validation (including the GS1 check digit) and an
  idempotent load, plus a runbook for approving or rejecting contributions by hand.

Each refuses to run until the owner deletes its guard block, runs in one transaction, and is
idempotent (countries by `iso_code`, styles by `lower(name)`; breweries and beers are matched by
name and country / brewery). They are exercised only on the disposable integration database
(`tests/integration/test_reference_data.py`, `test_catalog_beta_tooling.py`). See
`supabase/reference_data/README.md`, `supabase/catalog_beta/README.md` and `docs/RELEASE.md`.

## Function privileges in schema `private` (Phase 14)

Three functions live in `private`, and each one's `EXECUTE` privilege is audited
(`backend/tests/integration/test_security_audit.py`):

| function | kind | who may `EXECUTE` |
|---|---|---|
| `private.handle_new_user()` | `SECURITY DEFINER` trigger (creates the profile row) | its owner only |
| `private.other_user_pending_beer_barcode_exists(text)` | `SECURITY DEFINER`, boolean-only (Phase 13) | `beerapp_backend` and its owner |
| `private.set_updated_at()` | trigger function (maintains `updated_at`) | its owner only — see below |

Both `SECURITY DEFINER` functions pin `search_path = ''`. `USAGE` on schema
`private` is granted to `beerapp_backend` only (nobody can create objects there),
and the audit checks that this exposes nothing beyond the one intended helper.

**`private.set_updated_at()`.** PostgreSQL grants `EXECUTE` on a new function to
`PUBLIC` by default, and the original migration did not revoke it, so `anon`,
`authenticated` and `beerapp_backend` could call it. Migration
`20260921100000_revoke_public_execute_on_set_updated_at` revokes it from
`public, anon, authenticated`. The function body, its owner and every trigger
definition are unchanged, and the owner keeps its privileges. A trigger function
runs with the *invoking* statement's rights and needs no `EXECUTE` grant to fire, so
the seven `updated_at` triggers keep working for their real writers - the
integration tests prove this rather than assume it. The original migration was
not edited; this one is forward-only.

## Migration status (2026-09-21)

- 19 migrations exist; **all 19 are recorded on `beerapp-dev`**
  (`supabase migration list`).
- The last one, `20260921100000_revoke_public_execute_on_set_updated_at`, was
  applied in Phase 14 after a `supabase db push --dry-run` that listed **exactly
  that migration** and nothing else. `supabase db lint --linked --level error`
  afterwards reported no schema errors.
- Read-only verification against `beerapp-dev` compared a snapshot taken before
  and after the push. The only difference was the intended one: the
  function's ACL changed from "`PUBLIC` has `EXECUTE`" to owner-only (and the
  effective `EXECUTE` for `PUBLIC`, `anon`, `authenticated`, `beerapp_backend` and
  `beerapp_seed` went from true to false). Owner, definition, `search_path`, all
  eight triggers, the other two functions' ACLs and `USAGE` on schema `private`
  were unchanged, and the row counts and content hashes of all ten tables were
  identical - **no row data was created or modified for verification.**
- **Not exercised on `beerapp-dev`:** live firing of the triggers after the
  change (it is proven in the disposable database instead).
- An applied migration is never edited; corrections are new forward-only migrations.

## Backup and restore

**Not configured. No restore has been tested.**

- `beerapp-dev` is a development project, **not production**, and says nothing
  about production backups.
- **No production Supabase project exists yet.** The backups and point-in-time
  recovery (PITR) that will be available depend on the plan and project chosen,
  which is the owner's decision; none has been chosen.
- The **schema** is reproducible from `supabase/migrations/`. **User data** exists
  only in the database, so it is what backups must protect; dev catalog rows come
  from a dev-only seed and are not a source of truth for production.
- Release/deployment tasks still open: choose the plan; enable and verify automated
  backups (and PITR if the recovery-point target needs it); set retention and access;
  agree recovery point/time targets; **run and record a restore drill**; reconcile
  retention with account deletion. Until a project with backups exists, the restore
  test **cannot truthfully be marked passed.** See `docs/DECISIONS.md`.

## Testing

### Backend suites

- **Default suite** (`python -m pytest`): unit and route tests with no database.
  Integration tests are deselected by default (`addopts = "-m 'not integration'"`).
- **Integration suite** (`python -m pytest -m integration`): 269 tests against a real
  PostgreSQL with every repository migration applied. It runs **only** against a
  disposable database named by `INTEGRATION_DATABASE_URL`. Without that variable the
  tests skip.

### The disposable-database rule (hard, enforced in code)

Several tests deliberately issue SQL a correct repository would never write
(unfiltered and cross-identity queries, forged `user_id`s), and a few commit rows. So
**no integration test may touch `beerapp-dev`, production or any shared database**,
not even read-only. `backend/tests/integration/disposable_db.py` enforces this:
`INTEGRATION_DATABASE_URL` may not equal, or share a host with, `DATABASE_URL` or
`SEED_DATABASE_URL` (those are protected values, never targets), and its host must
be loopback unless `INTEGRATION_DATABASE_ALLOW_REMOTE=1` is set for a dedicated
hosted test database. The connecting role must be able to `SET ROLE beerapp_backend`
(a superuser, or an explicit membership). The privilege tests connect to the
disposable database and switch roles; they do not use `DATABASE_URL`. SSL follows
the DSN (`sslmode`), so a local server without TLS works; the running API's
`ssl="require"` is unchanged.

### Environment: which database

1. **Preferred: a real local Supabase stack** (`supabase start`, requires Docker).
   It provides Supabase's own `auth` schema, roles and defaults, so the migrations run
   as they will on a real project.
2. **Current verified fallback: the repository's PostgreSQL scaffold.** Where Docker
   is unavailable, apply `backend/tests/integration/support/supabase_scaffold.sql`
   followed by every migration in filename order to an **empty, local, throwaway**
   PostgreSQL 16 database. `backend/tests/integration/support/apply_schema.py` does
   both (it refuses a non-disposable target and an already-scaffolded database, and
   never drops anything):

   ```
   INTEGRATION_DATABASE_URL=postgresql://postgres@127.0.0.1:5432/beerapp_test \
       python backend/tests/integration/support/apply_schema.py
   ```

   The scaffold is test support only: no passwords, project identifiers, URLs,
   Postgres binaries or Docker scripts.

### Status (2026-09-21)

**The complete integration suite (269 tests) passes** against the scaffold with all
19 migrations applied, and the default suite passes separately. This supersedes the
Phase 13 finding that 79 of 111 older tests failed: those were defects in the *tests*
(fake `user_id`s without an `auth.users` row, catalog rows seeded after switching to
the read-only role, un-paired favorite/wishlist columns, a brewery without its
`country_id`, `confdeltype` bytes vs. str, `abv` overflowing `numeric(4,2)`), all
repaired without changing the production schema. The suite now includes
`test_security_audit.py` (table x role x privilege matrix, RLS, policies, cascades,
constraint names, `private` function privileges) and `test_schema_support.py` /
`test_disposable_db_guard.py` (the helper and the guard themselves).

**This is scaffold verification, not full Supabase verification.** It has not been run
against a local Supabase stack, and no test has touched `beerapp-dev`.

### What the scaffold does not reproduce

The scaffold provides only the `anon`, `authenticated` and `service_role` roles, a
minimal `auth.users` (just `id` and `raw_user_meta_data`) with `auth.uid()`, and
Supabase's default privileges on new `public` objects (so the migrations' explicit
`REVOKE`s are tested against realistic defaults). It does **not** provide GoTrue
(real auth behaviour, the Admin API, JWT issuing), PostgREST, the connection pooler
(session vs. transaction mode, TLS), the other Supabase-managed roles, schemas and
extensions, the non-superuser `postgres` role, or real password/login roles for
`beerapp_backend` and `beerapp_seed` (the tests reach them by `SET ROLE`). Behaviour
that depends on any of those - for example a real `DELETE /account` through the Admin
API, or pooler quirks - is **not** covered by this suite.

### Special cases

`test_collection_concurrency.py` proves `CollectionRepository.set_state`'s atomic
merge is race-safe under real concurrent transactions (two separate connections, not
two savepoints); it is one of the few places that commits rows for real, with
explicit cleanup, and it too runs only against the disposable database.
