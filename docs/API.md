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

## Collection (`/collection`, Phase 7)

The second user-owned resource, on the same identity model as beer logs:
`user_id` always comes from the verified JWT, never the request.

| method | path | notes |
|---|---|---|
| GET | `/collection/logged` | `?country_id=&style_id=&brewery_id=&sort=recent\|rating\|name&page=&page_size=` — one row per unique logged beer, derived from `user_beer_logs` (`DISTINCT ON beer_id`) — counted unfiltered, `total` *is* "unique beers tried" |
| GET | `/collection/favorites` | same params, rows with `is_favorite = true` |
| GET | `/collection/wishlist` | same params, rows with `is_wishlist = true` |
| GET | `/collection/{beer_id}` | `{beer_id, is_favorite, is_wishlist}` |
| PATCH | `/collection/{beer_id}` | `{is_favorite?, is_wishlist?}` |

Every list row is self-sufficient — `official_name`, `brewery_name`,
`style_name`, `country_name`, `image_url`, `abv`, `is_favorite`,
`is_wishlist`, `latest_rating`, `latest_consumed_at` all arrive in the same
response, via a `LEFT JOIN` onto `breweries`/`beer_styles`/`countries`
already in the query — no client-side name cache and no follow-up request
per item. `latest_rating`/`latest_consumed_at` are always the beer's
**latest** log's values, never an average, in every tab (see
`docs/DECISIONS.md`); a favorited/wishlisted beer with no logs simply has
both `null`.

**Exact ORDER BY** (`beer_id` is always the final deterministic tie-breaker;
`name` sort compares `lower(official_name)`):

| tab | `sort=recent` | `sort=rating` | `sort=name` |
|---|---|---|---|
| Logged | `latest_consumed_at desc` | `latest_rating desc nulls last, latest_consumed_at desc` | `lower(official_name) asc` |
| Favorites | `favorited_at desc` | `latest_rating desc nulls last, favorited_at desc` | `lower(official_name) asc` |
| Wishlist | `wishlisted_at desc` | `latest_rating desc nulls last, wishlisted_at desc` | `lower(official_name) asc` |

**`GET /collection/{beer_id}` — 404 vs. 200.** "No collection row" and "beer
doesn't exist" are different states: a real catalog beer with no row is 200
with both flags `false` ("not yet in your collection" is a normal state,
not a missing resource); only a `beer_id` that isn't a real catalog beer is
404.

**`PATCH /collection/{beer_id}` is an upsert** — a deliberate, one-resource
exception to the beer-logs convention that PATCH requires an existing row.
This resource's only identity is the `(user_id, beer_id)` pair, and "no row"
*is* its default state, so treating a first PATCH as a normal partial update
against that default is exactly the right behavior, not a special case.
`extra="forbid"` and an empty-patch rejection apply, same as beer logs. 404
only if `beer_id` isn't a real catalog beer.

Fields are always the **absolute** requested value, never a "toggle" — a
retried or double-tapped identical request converges to the same state.
Concurrent PATCHes to the same beer merge correctly (an omitted field
preserves whatever the *other* concurrent request just set, never clobbers
it) — see `docs/DECISIONS.md` and
`backend/tests/integration/test_collection_concurrency.py` for the design
and its verification against four required interleavings.

## Map (`/map`, Phase 8)

Dedicated read model for the world map — never extends `/beers`/`/breweries`,
never client-side-merged from `/collection/*`. Both endpoints return an
**unpaginated but safety-capped** envelope, not the `Page[T]` shape used
elsewhere:

```
{ "items": [...], "truncated": false }
```

Markers need the *complete* current result set at once (clustering and
camera-fit both require it), so pagination doesn't apply — but the result is
still capped server-side (2000 rows) as a safety backstop. If the cap is hit,
`truncated` is `true` and `items` holds only the first 2000 (by name); the
client must treat this as an incomplete result — not silently correct — and
surface it (a non-blocking notice), never claim a camera-fit computed from a
truncated set represents the complete map. This is a Phase 8 backstop, not
real pagination; viewport/bounding-box querying is the actual future-scale
solution and belongs to Phase 14, not here.

| method | path | notes |
|---|---|---|
| GET | `/map/beers` | `?state=all\|tried\|not_tried\|favorites\|wishlist&country_id=&q=` — default `state=all` |
| GET | `/map/breweries` | `?country_id=&q=` — no `state` param: breweries have no favorite/wishlist/tried concept |

**`state`** is the single-select map mode (`MapMode` in the Flutter client) —
exactly one value at a time, never independently combinable filters. It has
no meaning for `/map/breweries`; switching to the "Breweries" mode is a
client-side concern (call `/map/breweries` instead of `/map/beers`, hide beer
markers), not a `state` value.

**Coordinate fallback.** A beer's marker uses its own `(latitude,
longitude)` pair if *both* are set; otherwise its brewery's pair if *both*
are set; otherwise the beer has no marker and is silently absent from
`items` (not an error). The two fields are always read from the **same
source** — the query can never combine one table's latitude with the
other's longitude (see `backend/app/repositories/map.py`).

**Response fields are self-sufficient** for the map's preview cards — no
follow-up request:

- `MapBeerOut`: `beer_id`, `official_name`, `brewery_name`, `latitude`,
  `longitude` (effective, per the fallback above), `country_name`, `region`
  (both display-only, independently falling back from the beer's own value to
  its brewery's, unrelated to the coordinate-pairing rule), `is_tried`,
  `is_favorite`, `is_wishlist`.
- `MapBreweryOut`: `brewery_id`, `name`, `latitude`, `longitude`,
  `country_name`, `city`, `region`, `description`, `website`, `verified`. No
  personal-state fields — breweries have no favorite/wishlist/tried concept.

**`is_tried`/`is_favorite`/`is_wishlist`** read the same tables
`/collection/logged`/`/collection/favorites`/`/collection/wishlist` do
(`user_beer_logs`/`user_beer_collection`), scoped to the requesting user —
`GET /map/beers` runs its query inside the same RLS-scoping
`scoped_connection` transaction `CollectionRepository`/`BeerLogRepository`
use, not a plain pooled connection, since those tables are RLS-protected on
the transaction-local `app.user_id` setting. `GET /map/breweries` needs no
such scoping — it reads only catalog tables.

## Statistics (`/statistics`, Phase 9)

A single aggregate resource summarizing the caller's own beer activity —
descriptive only, never a goal/streak/leaderboard/consumption target (see
CLAUDE.md's Responsible Product Design rules). One endpoint, no query
parameters, no pagination:

| method | path | notes |
|---|---|---|
| GET | `/statistics` | auth required, returns `StatisticsOut` directly — not the `Page[T]` envelope, since this is one aggregate object, not a list |

Response shape (`monthly_activity` truncated to 2 of its always-exactly-12
entries below for brevity):

```json
{
  "total_unique_beers": 5,
  "total_logs": 7,
  "countries_discovered": 3,
  "styles_discovered": 4,
  "breweries_discovered": 5,
  "average_rating": 3.6666666667,
  "amount_spent": [
    { "currency": "EUR", "total": "4.00" },
    { "currency": "USD", "total": "12.50" }
  ],
  "monthly_activity": [
    { "month": "2025-10-01", "log_count": 0 },
    { "month": "2025-11-01", "log_count": 2 }
  ],
  "yearly_activity": [
    { "year": 2024, "log_count": 3 },
    { "year": 2026, "log_count": 4 }
  ],
  "favorite_style": "IPA",
  "favorite_country": "Ireland",
  "favorite_brewery": "Test Brewery"
}
```

**Unique beers vs. total logs.** `total_logs` is `count(*)` over the caller's
`user_beer_logs`; `total_unique_beers` is the count of *distinct* `beer_id`
among them. The two diverge whenever a beer is logged more than once — there
is no `unique(user_id, beer_id)` constraint on `user_beer_logs` specifically
so this distinction stays meaningful (see docs/DECISIONS.md, Phase 6).

**`average_rating`** is the unweighted mean of `rating` across the caller's
own logs where `rating is not null` — unrated logs are excluded from both
the numerator and the denominator (never treated as a 0). `null` when the
caller has no rated logs. This is a different concept from Collection's
`sort=rating` (the *latest* log's rating for one beer, Phase 7) — it's a
personal aggregate across all of a user's own logs, not a per-beer aggregate
across logs.

**`amount_spent`** is grouped strictly **per currency**, one row per
currency the caller has actually priced a log in — logs with a null `price`
or `currency` are excluded entirely, and currencies are never summed
together into one figure (there's no per-user default/preferred currency
until Phase 12 profile editing, so a blind sum would silently misrepresent
the true amount).

**`monthly_activity`** is the trailing 12 **UTC calendar months**,
**zero-filled** — always exactly 12 entries, oldest first, one per month
including months with zero logs, keyed by the first day of that UTC month.
Bucketing uses `consumed_at AT TIME ZONE 'UTC'`, independent of the
database connection's session timezone.

**`yearly_activity`** is **all UTC calendar years that have ≥1 log**,
all-time — deliberately **not** zero-filled (a gap year with no logs simply
has no entry), a different shape from `monthly_activity`'s rolling window.

**`favorite_style`/`favorite_country`/`favorite_brewery`** are each the
*mode* (most frequent) dimension among the caller's `user_beer_collection`
rows with `is_favorite = true` — derived from **Collection favorites, not
from log frequency or rating**. `null` when the caller has zero favorites
(never an error, never a fabricated "most common" among nothing). Ties are
broken deterministically: highest count first, then case-insensitive name
ascending, then a stable id ascending as a final tie-break (so two entities
with an identical display name still resolve consistently).

**Country fallback.** `countries_discovered` and `favorite_country` use a
beer's *effective* country: its own `beers.country_id` if set, otherwise its
brewery's `breweries.country_id` — the identical
`coalesce(b.country_id, br.country_id)` pattern `/map` already uses (see
above), so a beer with no country of its own is never silently excluded
from country-based statistics. Since `breweries.country_id` is `NOT NULL`,
the effective country can never be null — unlike `style_id`, which can be
genuinely absent for a beer and is excluded from `styles_discovered`/
`favorite_style` in that case. This fallback is **not** applied to style or
brewery — those are always exactly `beer.style_id`/`beer.brewery_id`.
