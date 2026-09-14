# CLAUDE.md — BeerApp

## Mission

BeerApp is an adult-oriented mobile beer discovery, collection and catalog app centered around a world map.

Target platforms:
- Android
- iOS

Preferred stack:
- Flutter + Dart — mobile app
- Python + FastAPI — backend
- PostgreSQL / Supabase — database
- Supabase Auth — authentication
- Supabase Storage — images
- MapLibre — maps
- Git + GitHub — version control

Before significant work, read:
- `PRODUCT.md` for product requirements
- `ROADMAP.md` for implementation order
- relevant files in `/docs`

Do not load or rewrite all documentation for small changes unless necessary.

---

## Stitch

`/stitch` is visual reference material only.

Rules:
- Never modify or delete `/stitch`.
- Do not use Stitch HTML as production code.
- Recreate the design natively in Flutter.
- Preserve the warm cream + beer-gold visual identity while improving UX when justified.

---

## Development Workflow

For every non-trivial task:

1. Inspect the relevant existing files first.
2. Understand the current implementation.
3. Make the smallest correct change.
4. Reuse existing code before creating new abstractions.
5. Do not rewrite unrelated working code.
6. Run relevant tests / linting / analysis.
7. Keep the project runnable.
8. Update documentation only when architecture, product behavior or roadmap state meaningfully changes.

Do not build multiple major roadmap phases at once unless explicitly requested.

---

## Architecture

Keep files focused and understandable.

Flutter should remain feature-oriented, approximately:

`mobile/lib/`
- `app/`
- `core/`
- `design_system/`
- `features/`
- `shared/`

Feature folders may contain:
- `data/`
- `domain/`
- `presentation/`

Use this pragmatically; do not create empty layers just for architectural appearance.

FastAPI should separate:
- routes
- schemas
- services
- repositories
- persistence/models
- configuration

Keep API routes thin. Business logic belongs in services.

Avoid giant files and duplicated logic.

---

## Design System

Do not repeatedly hardcode:
- colors
- typography
- spacing
- radii
- shadows
- component styles

Use shared design-system tokens/components.

The app must be localization-ready. Do not scatter user-facing strings throughout widgets.

---

## Data Model Rule

Global beer data and personal user data must remain separate.

A `Beer` represents one catalog beer.

A personal log/review is a separate user-owned entity.

Never put user-specific rating, favorite, wishlist or personal history directly on the global Beer record.

---

## Database

Use migrations for schema changes.

Use:
- primary keys
- foreign keys
- constraints
- appropriate indexes

Do not perform undocumented destructive schema changes.

Preserve existing user data during migrations.

---

## Authentication and Security

Use Supabase Auth rather than custom password authentication.

Never:
- commit secrets
- expose service-role keys to the mobile client
- trust the client alone for authorization
- store plaintext passwords

Use environment variables and maintain `.env.example`.

Use server-side authorization and/or Supabase Row Level Security.

---

## API

Prefer predictable REST APIs initially.

Keep conventions consistent for:
- endpoint naming
- errors
- status codes
- pagination
- filtering
- response shapes

Do not load an entire potentially large beer catalog when server filtering or pagination is appropriate.

---

## Dependencies

Before adding a package:
- confirm it solves a real need
- prefer stable and maintained packages
- avoid duplicate packages solving the same problem
- consider long-term maintenance

Document major dependency decisions in `docs/DECISIONS.md`.

---

## Quality

Important business rules should have tests.

Prioritize tests for:
- authentication
- permissions
- beer logging/reviews
- statistics
- achievements
- important API services
- database constraints

For Flutter, keep `dart format` and `flutter analyze` clean.

For Python, use the formatter/linter selected during project setup.

Do not claim a feature works unless it has been checked when checking is possible.

---

## Git

Before major changes, inspect Git status.

Never commit:
- secrets
- `.env`
- build outputs
- caches
- unnecessary IDE files

Prefer small, coherent commits with descriptive messages.

Do not rewrite shared Git history unless explicitly instructed.

---

## Responsible Product Design

BeerApp is intended for adults of legal drinking age.

Do not implement:
- drinking streaks
- speed-drinking challenges
- competitive quantity leaderboards
- achievements based on liters consumed
- mechanics that reward increasing alcohol consumption

Achievements may focus on:
- countries
- regions
- breweries
- styles
- catalog discovery
- collections
- reviews
- ratings
- exploration milestones

Review age-gating, privacy and store requirements before release.

---

## First Project Initialization

When asked to begin BeerApp:

1. Read this file.
2. Read `PRODUCT.md`.
3. Read `ROADMAP.md`.
4. Inspect `/stitch`.
5. Inspect the existing repository.
6. Do not build the whole app.
7. Work only on Phase 0 unless explicitly instructed otherwise.
8. Produce a short implementation plan before changing files.
9. Identify missing local tools or decisions.
10. Keep the repository runnable after setup.

---

## Priority Order

When tradeoffs arise, prioritize:

1. Correctness
2. Data safety
3. Maintainability
4. User experience
5. Performance
6. Development speed

Prefer clear, maintainable solutions over clever ones.
