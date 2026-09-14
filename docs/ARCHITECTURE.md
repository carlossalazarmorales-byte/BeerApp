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

FastAPI app. Target layering per `CLAUDE.md`:

```
backend/app/
  routes/         # thin HTTP layer — request/response only
  schemas/        # Pydantic request/response models
  services/       # business logic
  repositories/   # persistence access
  models/         # ORM / persistence models
  config.py       # environment-driven settings
```

Currently the app is a single `app/main.py` exposing `GET /health`. The layered
split above will be introduced once real endpoints exist — splitting it now for
one endpoint would be premature.

## Data flow

Mobile → FastAPI (REST) → PostgreSQL (via Supabase). Supabase Auth issues the
session token the mobile app attaches to API requests; the backend verifies it
and enforces authorization server-side (see `PRODUCT.md` §27). Supabase Storage
holds images referenced by URL from catalog/user records.

## Global catalog vs. personal data

Per `CLAUDE.md` and `PRODUCT.md` §7: `Beer`, `Brewery`, and `Beer Style` are
global catalog entities, shared across all users. A user's rating, review,
favorite, wishlist, or drinking history is never stored on those records — it
lives in a separate user-owned `User Beer Log` entity referencing the catalog
beer by id. This separation must hold at the database, API, and mobile-model
level.
