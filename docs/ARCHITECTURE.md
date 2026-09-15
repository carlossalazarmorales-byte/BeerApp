# Architecture

High-level structure only. This will grow as features land; it does not describe
features that don't exist yet.

## Mobile (`/mobile`)

Flutter app, feature-oriented per `CLAUDE.md`:

```
mobile/lib/
  app/            # app-level setup: entrypoint, routing, theming glue
  core/           # cross-cutting concerns: env config, networking, error handling
  design_system/  # shared tokens/components (colors, typography, spacing, radii)
  features/       # one folder per feature, each optionally split into data/domain/presentation
  shared/         # widgets/utilities used by more than one feature
```

None of these folders exist yet beyond `main.dart` — they will be introduced in
Phase 1 (Design System & App Shell) as they're actually populated, rather than
scaffolded empty ahead of time.

## Backend (`/backend`)

FastAPI app. Layering per `CLAUDE.md`, built out in Phase 3:

```
backend/app/
  routes/         # thin HTTP layer — request/response only
  schemas/        # Pydantic request/response models
  services/       # business logic
  repositories/   # persistence access, hand-written parameterized SQL
  auth/           # JWKS fetch/cache, JWT verification, get_current_user dependency
  dependencies.py # pool -> repository -> service wiring, overridable per layer in tests
  db.py           # asyncpg connection pool
  errors.py       # exception -> JSON error envelope mapping
  config.py       # environment-driven settings (pydantic-settings)
```

No `models/` (ORM) layer: the backend talks to Postgres directly via `asyncpg`
and hand-written SQL in `repositories/`, not an ORM — see `docs/DECISIONS.md`.
Pydantic models in `schemas/` are the only "model" layer, and describe API
shapes, not persistence.

## Data flow

Mobile → FastAPI (REST) → PostgreSQL (via Supabase). Supabase Auth issues the
session token the mobile app attaches to API requests; the backend verifies it
locally (JWKS-based JWT verification, `app/auth/`) and enforces authorization
server-side (see `PRODUCT.md` §27). The mobile app never queries Postgres/
PostgREST directly for catalog data — FastAPI is the only read path, per
`docs/DATABASE.md`. Supabase Storage holds images referenced by URL from
catalog/user records.

The backend's own Postgres connection (`DATABASE_URL`) is a dedicated,
least-privilege role (`beerapp_backend`, `SELECT`-only on the catalog tables)
rather than the project's admin credentials — see `docs/DATABASE.md` for the
full role model and `docs/DECISIONS.md` for the rationale.

## Global catalog vs. personal data

Per `CLAUDE.md` and `PRODUCT.md` §7: `Beer`, `Brewery`, and `Beer Style` are
global catalog entities, shared across all users. A user's rating, review,
favorite, wishlist, or drinking history is never stored on those records — it
lives in a separate user-owned `User Beer Log` entity referencing the catalog
beer by id. This separation must hold at the database, API, and mobile-model
level.
