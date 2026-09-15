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
- **404** — a well-typed resource id that doesn't exist. For a user-owned
  resource (beer logs), also covers "exists, but isn't yours" — deliberately
  indistinguishable from "doesn't exist" at all, never a 403, so a client
  can't use the status code to probe for another user's data.
- **422** — malformed UUIDs, invalid typed query/path parameters,
  out-of-range `page`/`page_size`, and any other request-shape validation
  FastAPI/Pydantic owns. This is the default outcome for "the input didn't
  parse."
- **400** — a semantic error that is structurally valid but logically
  invalid given the resource's current state. Unused through Phase 3–5;
  Phase 6's beer logs are the first real cases: a future `consumed_at`
  (create or update), and a PATCH that would leave `price`/`currency`
  inconsistent (see the beer-logs section below).
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
| GET | `/beers` | `?country_id=&style_id=&brewery_id=&q=&page=&page_size=` |
| GET | `/beers/{id}` | |

These correspond to `ROADMAP.md` Phase 4's "Beer list API"/"Beer detail API"
tasks — the read-API foundation moved forward into Phase 3 (allowed as "small
foundational work for future phases," Roadmap Rule 2) so the protected
backend could be proven end-to-end. Phase 4 consumes and polishes these in
the Flutter UI (loading/empty/error states, favorite/wishlist actions) rather
than rebuilding them — see `docs/DECISIONS.md`.

## Text search (`GET /beers?q=`, Phase 5)

`q` (optional, max 100 characters) does a case-insensitive substring search
across a beer's own name, its brewery's name, its style's name, and its
country's name (via the beer's own `country_id` — see the limitation below),
ANDed with any `country_id`/`style_id`/`brewery_id` filters also present on
the request. Matching is deterministic (`ILIKE`), never fuzzy/semantic —
consistent with `ROADMAP.md`'s "prefer simple, deterministic database-backed
search" guidance for this phase.

Normalization happens server-side, independent of what the client sends:
surrounding whitespace is stripped, and a whitespace-only (or now-empty)
value after trimming is treated as "no search" rather than an empty ILIKE
term. `%` and `_` in `q` are matched **literally** — the backend escapes
both (and the SQL escape character itself) before building the ILIKE
pattern, so a user searching for a literal `%` or `_` only matches beers
that actually contain that character, never the whole catalog.

Pagination's `total` always reflects the exact same searched/filtered row
set as the returned page — the count query and the page query share one
`FROM`/`JOIN`/`WHERE` clause built once, so they can't drift apart.

**Known limitation**: "country" search matches a beer's own `country_id`
field, not its brewery's country. A beer with no `country_id` set won't be
found by searching its brewery's country name. Not a regression — no country
search existed before Phase 5 — but worth knowing when a search doesn't
surface an expected result.

## Beer logs (`/beer-logs`, Phase 6)

The first user-owned resource and the first write endpoints anywhere in the
API. `user_id` is never a request field on any of these — it always comes
from the verified JWT's `sub` claim (`get_current_user`), and the create
schema structurally forbids an `extra` `user_id` key rather than silently
ignoring one.

| method | path | notes |
|---|---|---|
| POST | `/beer-logs` | create a log for the current user; always inserts a new row — never an upsert, even for a beer already logged (a user may log the same beer multiple times) |
| GET | `/beer-logs` | `?beer_id=&page=&page_size=`, always scoped to the caller — there is no `user_id` query param at all; results ordered `consumed_at DESC, id DESC` (deterministic — `id` breaks ties when two logs share a `consumed_at`), wrapped in the standard `Page` envelope |
| GET | `/beer-logs/{id}` | 404 if missing or not owned |
| PATCH | `/beer-logs/{id}` | partial update; 404 if missing or not owned |
| DELETE | `/beer-logs/{id}` | 204, 404 if missing or not owned |

Request/response fields: `beer_id` (create-only, required), `rating`
(1–5), `review`, `consumed_at`, `serving_note`, `price`, `currency`
(3-letter code), `venue_name`, `serving_volume_ml` (milliliters, `> 0`,
never inferred — see `docs/DECISIONS.md`). All optional beyond `beer_id`.

**PATCH semantics**: omitting a field leaves it unchanged; explicitly
sending `null` clears it (where the column allows — `consumed_at` cannot be
cleared, since it's `NOT NULL`). An empty PATCH body is rejected as 422. The
`price`/`currency` pairing (both set or both cleared) is validated against
the **resulting** state — the existing row's values overlaid with the
patch — not just the two fields present in the request, so e.g. patching
only `review` on a log that already has a price never re-triggers the
pairing check, but clearing only `currency` while `price` stays set is
rejected (400) unless `price` is cleared in the same request.

**`consumed_at` must be timezone-aware.** A value with no UTC offset is
rejected as 422 (not the ambiguous "maybe midnight UTC, maybe local time"
naive datetime) on both create and update. An aware value in the future is
a 400, on both create and update. Omitted on create, it defaults to the
server's current time.
