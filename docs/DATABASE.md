# Database

PostgreSQL, hosted via Supabase. As of Phase 3, six tables exist:
`public.profiles` (Phase 2) and the Phase 3 catalog tables `public.countries`,
`public.beer_styles`, `public.breweries`, `public.beers`, plus two roles
(`beerapp_backend`, `beerapp_seed`) that gate access to the catalog tables.
Migrations live under `supabase/migrations/`.

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

## `public.profiles` (Phase 2)

1:1 with `auth.users`, deliberately minimal — only what Phase 2 code actually
reads or writes:

| column | type | notes |
|---|---|---|
| `id` | `uuid primary key references auth.users(id) on delete cascade` | same UUID as the auth user |
| `username` | `text`, nullable | non-null immediately for email signups; null for Google signups until `/complete-profile` is completed. Never a placeholder value. |
| `display_name` | `text`, nullable | falls back to `username` in the UI |
| `created_at` | `timestamptz not null default now()` | |
| `updated_at` | `timestamptz not null default now()` | auto-updated via trigger |

**RLS**: `select_own`/`update_own` policies restrict a user to their own row.
No client-facing `INSERT`/`DELETE` policy. Unaffected by Phase 3 — no FK from
any catalog table to `profiles`, preserving `CLAUDE.md`'s Data Model Rule.

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
| `barcode` | `text`, nullable | unique partial index `WHERE barcode IS NOT NULL`; future scanner lookup (Phase 11) |
| `verified` | `boolean not null default false` | |
| `source` | `text`, nullable | |
| `created_at` / `updated_at` | `timestamptz` | as above |

All FKs are `ON DELETE RESTRICT` (the default) — deleting a country/brewery/
style with dependents fails loudly rather than silently orphaning or cascading.

## Access model (RLS + roles)

Catalog access is **API-only**: the mobile app never queries these four
tables through Supabase PostgREST directly, not even as an authenticated
user. This is enforced at the database level, not just by convention:

| role | catalog privileges |
|---|---|
| `anon` | none |
| `authenticated` | none |
| `beerapp_backend` | `SELECT` only, all four catalog tables — the running FastAPI app's connection (`DATABASE_URL`) |
| `beerapp_seed` | `SELECT`/`INSERT`/`UPDATE`/`DELETE`, all four catalog tables — `backend/scripts/seed_catalog.py` only (`SEED_DATABASE_URL`), never the running API |

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
`SEED_DATABASE_URL` respectively — verified working end-to-end, including by
`backend/tests/integration/test_role_grants.py` (`beerapp_backend`) and a
one-off privilege check covering both roles (`beerapp_seed`: `SELECT`/
`INSERT`/`UPDATE`/`DELETE` succeed on the four catalog tables, `SELECT` on
`public.profiles` correctly denied). See `docs/DECISIONS.md` for the
session history.

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
assumed from the DSN.

## Seed strategy (dev)

`backend/scripts/seed_catalog.py`, run manually, connects via
`SEED_DATABASE_URL` only — never `DATABASE_URL`, which has no write
privilege. Idempotent: `countries` upserts on its genuine natural key
(`iso_code`); `beer_styles`/`breweries`/`beers` have no natural unique key
(names are not globally unique, by design), so each seeded row uses a
deterministic fixed UUID constant and upserts on `id` — no UNIQUE constraint
was added purely to make seeding easier. Seeded rows are marked
`source = 'dev-seed'`. Never shipped as a migration.

Run twice against the dev project; row counts (10 countries, 8 beer styles,
6 breweries, 8 beers) were identical both times, confirming no duplicates.

## Testing

`backend/tests/integration/` (marked `@pytest.mark.integration`, excluded
from the default `pytest` run) covers the CHECK/FK/unique constraints above
and the `beerapp_backend` privilege boundary, against `INTEGRATION_DATABASE_URL`
(constraint tests, rolled back per test) and `DATABASE_URL` (role/grant
tests — safe to use directly since that role has no write privilege at all).
Neither is `SEED_DATABASE_URL`.
