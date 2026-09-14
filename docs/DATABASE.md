# Database

No database exists yet — no Supabase project, no schema, no migrations. This
document records intent only, to be implemented starting in Phase 2 (Core
Database).

## Planned approach

- PostgreSQL, hosted via Supabase.
- Schema changes go through migrations — no undocumented destructive changes.
- Every table gets a primary key, explicit foreign keys, appropriate
  constraints, and indexes for common query patterns (e.g. catalog lookups by
  country, brewery, style).
- Row-Level Security (Supabase) enforces that a user can only read/write their
  own personal data (logs, favorites, wishlist).

## Core entities (from `PRODUCT.md` §7)

Global catalog (shared, not user-owned):

- **Beer** — one row per catalog beer, regardless of how many users have
  logged it. Fields include brewery/style/country references, ABV, IBU,
  location, verification/source metadata.
- **Brewery** — name, location, description, verification metadata.
- **Beer Style** — name, category, typical ABV range, origin.

Per-user (never merged into the catalog tables):

- **User** — profile fields (username, display name, avatar, preferred
  currency/units, country, language).
- **User Beer Log** — a user's record of having tried/reviewed a specific
  beer: rating, review, timestamp, optional price/venue/location/photo. A user
  may log the same beer multiple times; "discovered" status and individual
  logs are distinct concepts.

Exact columns, types, and constraints will be defined when Phase 2 implements
the schema — this is a reference for scope, not a finalized DDL.
