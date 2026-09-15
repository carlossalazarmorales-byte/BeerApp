# API

Phase 3 adds the backend's first protected endpoints and, with them, the
first real conventions below. `GET /health` remains unauthenticated.

## Auth

Every endpoint except `/health` requires a Supabase session JWT as a Bearer
token (`Authorization: Bearer <token>`). The backend verifies it itself —
`app/auth/` — via local JWKS-based verification (no per-request call to
Supabase): signature, algorithm restricted to an explicit allowlist
(`RS256`/`ES256`, selected from the matched signing key's own type, never
trusted from the token header), `exp`, `iss` (derived from `SUPABASE_URL`),
`aud` (defaults to `authenticated`), and the `role` claim (`authenticated`).
See `docs/DECISIONS.md` for the JWKS preflight this was gated on.

FastAPI has no role in *issuing* sessions — that's still entirely Supabase
Auth via `supabase_flutter` on the mobile side (Phase 2). FastAPI only
verifies tokens Supabase already issued.

## Conventions

- **Pagination**: `?page=&page_size=` (1-indexed, default `page_size=20`, max
  `page_size=100`). Paginated responses: `{ "items": [...], "page": ...,
  "page_size": ..., "total": ... }`.
- **Errors**: every error response shares one envelope:
  `{ "error": { "code": ..., "message": ... } }`.
- **401** — missing/invalid/expired bearer token; includes
  `WWW-Authenticate: Bearer`. Raised entirely inside `app/auth/` — a bad
  token never reaches the generic infrastructure error handler.
- **404** — a well-typed resource id that doesn't exist.
- **422** — malformed UUIDs, invalid typed query/path parameters,
  out-of-range `page`/`page_size`, and any other request-shape validation
  FastAPI/Pydantic owns. This is the default outcome for "the input didn't
  parse."
- **400** — reserved for a semantic error that is structurally valid but
  logically invalid. None of Phase 3's endpoints currently have such a case;
  no custom validation was written just to produce one.
- **503** — the JWKS endpoint itself is unreachable (an infrastructure
  failure, not a bad token).
- **500** — any other unhandled infrastructure failure (`asyncpg`, `httpx`).
  Raw driver/library exceptions and stack traces never reach the client.

## Endpoints (Phase 3)

Read-only, all requiring a valid session (any authenticated user — none are
admin-gated; there is no catalog write endpoint yet, see
`docs/DATABASE.md`'s access model):

| method | path | notes |
|---|---|---|
| GET | `/countries` | unpaginated (small, bounded set) |
| GET | `/beer-styles` | unpaginated |
| GET | `/breweries` | `?country_id=&page=&page_size=` |
| GET | `/breweries/{id}` | |
| GET | `/beers` | `?country_id=&style_id=&brewery_id=&page=&page_size=` |
| GET | `/beers/{id}` | |

These correspond to `ROADMAP.md` Phase 4's "Beer list API"/"Beer detail API"
tasks — the read-API foundation moved forward into Phase 3 (allowed as "small
foundational work for future phases," Roadmap Rule 2) so the protected
backend could be proven end-to-end. Phase 4 consumes and polishes these in
the Flutter UI (loading/empty/error states, favorite/wishlist actions) rather
than rebuilding them — see `docs/DECISIONS.md`.
