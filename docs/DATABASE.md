# Database

PostgreSQL, hosted via Supabase. As of Phase 2, one table exists:
`public.profiles` (migration `supabase/migrations/20260914120000_create_profiles_table.sql`).
The rest of the schema described below (catalog + user-log tables) is
**Phase 3 — Core Database** scope, not yet implemented.

## Planned approach

- Schema changes go through migrations — no undocumented destructive changes.
- Every table gets a primary key, explicit foreign keys, appropriate
  constraints, and indexes for common query patterns (e.g. catalog lookups by
  country, brewery, style).
- Row-Level Security (Supabase) enforces that a user can only read/write their
  own personal data (logs, favorites, wishlist, profile).
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

`avatar_url`, `preferred_language`, `preferred_currency`, `preferred_units`,
`country` are **not** columns yet — nothing in Phase 2 reads or writes them.
Language currently comes from the existing Flutter localization/device
locale, not a stored preference. These are added later (avatar with Supabase
Storage; the rest with Phase 12 — Profile and Settings) as additive,
non-breaking migrations.

**Username rules**, enforced primarily in the database:

- Normalized (trimmed + lowercased) by the app before every write — a
  handle, not a display name.
- `CHECK (username IS NULL OR username ~ '^[a-z0-9_]{3,20}$')`.
- A partial unique index (`WHERE username IS NOT NULL`) is the actual source
  of truth for uniqueness, not a client-side check-then-insert — a `23505`
  violation is caught and surfaced as "username already taken."

**RLS** (least privilege): `select_own`/`update_own` policies restrict a user
to their own row (`auth.uid() = id`). No client-facing `INSERT` policy — rows
are created only by the `handle_new_user()` trigger (`SECURITY DEFINER`,
`search_path = ''`, every referenced object schema-qualified, `EXECUTE`
revoked from `PUBLIC`/`anon`/`authenticated`) on `auth.users` insert. No
`DELETE` policy. Profiles are not public.

## Core entities planned for Phase 3 (from `PRODUCT.md` §7)

Global catalog (shared, not user-owned):

- **Beer** — one row per catalog beer, regardless of how many users have
  logged it. Fields include brewery/style/country references, ABV, IBU,
  location, verification/source metadata.
- **Brewery** — name, location, description, verification metadata.
- **Beer Style** — name, category, typical ABV range, origin.

Per-user (never merged into the catalog tables):

- **User Beer Log** — a user's record of having tried/reviewed a specific
  beer: rating, review, timestamp, optional price/venue/location/photo. A user
  may log the same beer multiple times; "discovered" status and individual
  logs are distinct concepts.

Exact columns, types, and constraints for these will be defined when Phase 3
implements them — this is a reference for scope, not a finalized DDL.
