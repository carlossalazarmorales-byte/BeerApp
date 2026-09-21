"""Idempotent Phase 3 dev catalog seed.

Connects using SEED_DATABASE_URL -- the `beerapp_seed` role's write-capable
connection -- never DATABASE_URL, which is the read-only `beerapp_backend`
connection the running API uses and has no write privilege at all. See
docs/DATABASE.md for the role split.

Run manually from the repo root or backend/:

    python backend/scripts/seed_catalog.py --yes

The script writes fabricated catalog rows marked `verified = true` /
`source = 'dev-seed'`, so it refuses to run unless `ENVIRONMENT` is `local`
or `dev` (unset counts as `local`), `SEED_DATABASE_URL` is set and is not the
runtime `DATABASE_URL`, and `--yes` is passed. Without `--yes` it only prints
the target host (never credentials) and exits. It is never run against a
production database.

Safe to re-run. `countries` has a genuine natural key (iso_code) and is
upserted on it. `beer_styles`/`breweries`/`beers` have no genuine natural
unique key -- names are not globally unique, by design -- so every seeded
row uses a deterministic fixed UUID constant instead, and is upserted on
`id`. No UNIQUE constraint exists purely to make this script easier.
"""

import argparse
import asyncio
import os
import sys
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit
from uuid import UUID

import asyncpg
from dotenv import load_dotenv

_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
_BACKEND_DIR = _REPO_ROOT / "backend"
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

from app.db import parse_dsn_kwargs  # noqa: E402

_SOURCE = "dev-seed"

# `.env` is deliberately loaded inside main(), not at import time: this module
# is imported by tests (for `_BEERS`), and importing it must never inject real
# database credentials into the test process.
_ALLOWED_ENVIRONMENTS = frozenset({"local", "dev"})


class SeedRefusedError(Exception):
    """The seed run was refused before any database connection was opened."""


def check_seed_target(*, seed_url: str | None, runtime_url: str | None, environment: str) -> str:
    """Validate a seed run's target and return its host (never credentials).

    Raises SeedRefusedError when the environment is not `local`/`dev`, when
    SEED_DATABASE_URL is missing or unparseable, or when it is the same value
    as the runtime DATABASE_URL (i.e. the wrong credential).
    """
    if environment not in _ALLOWED_ENVIRONMENTS:
        raise SeedRefusedError(
            f"Refusing to seed: ENVIRONMENT is {environment!r}; this script writes "
            f"fabricated dev catalog data and only runs for {sorted(_ALLOWED_ENVIRONMENTS)}."
        )
    if not seed_url:
        raise SeedRefusedError(
            "SEED_DATABASE_URL is not set. This script requires the beerapp_seed "
            "role's connection string, in .env -- never DATABASE_URL (that's the "
            "read-only beerapp_backend connection, which has no write privilege). "
            "See docs/DATABASE.md."
        )
    if runtime_url and seed_url == runtime_url:
        raise SeedRefusedError(
            "Refusing to seed: SEED_DATABASE_URL is identical to DATABASE_URL. "
            "The seed script must use the dedicated beerapp_seed connection."
        )
    host = urlsplit(seed_url).hostname
    if not host:
        raise SeedRefusedError("SEED_DATABASE_URL has no host; check its format.")
    return host


# (iso_code, name, continent)
_COUNTRIES: list[tuple[str, str, str]] = [
    ("US", "United States", "North America"),
    ("MX", "Mexico", "North America"),
    ("IE", "Ireland", "Europe"),
    ("DE", "Germany", "Europe"),
    ("BE", "Belgium", "Europe"),
    ("NL", "Netherlands", "Europe"),
    ("CZ", "Czech Republic", "Europe"),
    ("JP", "Japan", "Asia"),
    ("AU", "Australia", "Oceania"),
    ("BR", "Brazil", "South America"),
]

# (id, name, category, origin_iso_code, abv_min, abv_max)
_BEER_STYLES: list[tuple[UUID, str, str, str | None, Decimal | None, Decimal | None]] = [
    (
        UUID("00000000-0000-4000-9001-000000000001"),
        "Dry Stout",
        "Stout",
        "IE",
        Decimal("4.0"),
        Decimal("5.0"),
    ),
    (
        UUID("00000000-0000-4000-9001-000000000002"),
        "Pale Lager",
        "Lager",
        "DE",
        Decimal("4.2"),
        Decimal("5.5"),
    ),
    (
        UUID("00000000-0000-4000-9001-000000000003"),
        "Weissbier",
        "Wheat Beer",
        "DE",
        Decimal("4.3"),
        Decimal("5.6"),
    ),
    (
        UUID("00000000-0000-4000-9001-000000000004"),
        "Belgian Tripel",
        "Belgian Ale",
        "BE",
        Decimal("7.5"),
        Decimal("9.5"),
    ),
    (
        UUID("00000000-0000-4000-9001-000000000005"),
        "Pilsner",
        "Lager",
        "CZ",
        Decimal("4.0"),
        Decimal("5.0"),
    ),
    (
        UUID("00000000-0000-4000-9001-000000000006"),
        "India Pale Ale",
        "Ale",
        "US",
        Decimal("5.5"),
        Decimal("7.5"),
    ),
    (
        UUID("00000000-0000-4000-9001-000000000007"),
        "Rice Lager",
        "Lager",
        "JP",
        Decimal("4.5"),
        Decimal("5.5"),
    ),
    (
        UUID("00000000-0000-4000-9001-000000000008"),
        "Fruit Lambic",
        "Belgian Ale",
        "BE",
        Decimal("5.0"),
        Decimal("7.0"),
    ),
]

# (id, name, country_iso, region, city, latitude, longitude)
_BREWERIES: list[tuple[UUID, str, str, str | None, str | None, Decimal | None, Decimal | None]] = [
    (
        UUID("00000000-0000-4000-9002-000000000001"),
        "St. James's Gate Brewery",
        "IE",
        None,
        "Dublin",
        Decimal("53.341389"),
        Decimal("-6.286944"),
    ),
    (
        UUID("00000000-0000-4000-9002-000000000002"),
        "Weihenstephan Brewery",
        "DE",
        "Bavaria",
        "Freising",
        Decimal("48.398700"),
        Decimal("11.742700"),
    ),
    (
        UUID("00000000-0000-4000-9002-000000000003"),
        "Brasserie d'Achouffe",
        "BE",
        None,
        "Achouffe",
        Decimal("50.200500"),
        Decimal("5.710800"),
    ),
    (
        UUID("00000000-0000-4000-9002-000000000004"),
        "Pilsner Urquell Brewery",
        "CZ",
        None,
        "Plzen",
        Decimal("49.738400"),
        Decimal("13.373600"),
    ),
    (
        UUID("00000000-0000-4000-9002-000000000005"),
        "Kirin Brewery",
        "JP",
        None,
        "Yokohama",
        Decimal("35.443700"),
        Decimal("139.638000"),
    ),
    # No region/city/lat/lng -- exercises the nullable-location path.
    (
        UUID("00000000-0000-4000-9002-000000000006"),
        "Sierra Desert Test Brewery",
        "US",
        None,
        None,
        None,
        None,
    ),
]

# (id, official_name, brewery_id, style_id or None, country_iso or None,
#  region, city, latitude, longitude, abv, ibu, barcode)
_BEERS: list[tuple] = [
    (
        UUID("00000000-0000-4000-9003-000000000001"),
        "Guinness Draught",
        UUID("00000000-0000-4000-9002-000000000001"),
        UUID("00000000-0000-4000-9001-000000000001"),
        "IE",
        None,
        None,
        None,
        None,
        Decimal("4.2"),
        45,
        # Checksum-corrected EAN-13 dev fixture (GS1 mod-10 check digit for
        # payload 500021300707 is 5, not the 2 this previously ended in --
        # see app/services/barcode.py). Synthetic-looking but a genuinely
        # valid canonical code, for scanner dev/testing.
        "5000213007075",
    ),
    (
        UUID("00000000-0000-4000-9003-000000000002"),
        "Weihenstephaner Hefeweissbier",
        UUID("00000000-0000-4000-9002-000000000002"),
        UUID("00000000-0000-4000-9001-000000000003"),
        "DE",
        None,
        None,
        None,
        None,
        Decimal("5.4"),
        14,
        # Deliberately synthetic, checksum-valid EAN-13 dev fixture -- never
        # presented as a real commercial code.
        "2222222222222",
    ),
    (
        UUID("00000000-0000-4000-9003-000000000003"),
        "Pilsner Urquell",
        UUID("00000000-0000-4000-9002-000000000004"),
        UUID("00000000-0000-4000-9001-000000000005"),
        "CZ",
        None,
        None,
        None,
        None,
        Decimal("4.4"),
        40,
        # Deliberately synthetic, checksum-valid EAN-8 dev fixture.
        "11111115",
    ),
    (
        UUID("00000000-0000-4000-9003-000000000004"),
        "La Chouffe",
        UUID("00000000-0000-4000-9002-000000000003"),
        UUID("00000000-0000-4000-9001-000000000004"),
        "BE",
        None,
        None,
        None,
        None,
        Decimal("8.0"),
        25,
        None,
    ),
    (
        UUID("00000000-0000-4000-9003-000000000005"),
        "Kirin Ichiban",
        UUID("00000000-0000-4000-9002-000000000005"),
        UUID("00000000-0000-4000-9001-000000000007"),
        "JP",
        None,
        None,
        None,
        None,
        Decimal("5.0"),
        12,
        None,
    ),
    # No style_id, no country_id -- exercises both nullable FKs at once.
    (
        UUID("00000000-0000-4000-9003-000000000006"),
        "Mystery Desert Ale",
        UUID("00000000-0000-4000-9002-000000000006"),
        None,
        None,
        None,
        None,
        None,
        None,
        Decimal("6.0"),
        None,
        None,
    ),
    (
        UUID("00000000-0000-4000-9003-000000000007"),
        "Chouffe Cherry",
        UUID("00000000-0000-4000-9002-000000000003"),
        UUID("00000000-0000-4000-9001-000000000008"),
        "BE",
        None,
        None,
        None,
        None,
        Decimal("6.5"),
        None,
        None,
    ),
    # Brewed by a Japanese brewery for the Australian market -- exercises a
    # beer's own country/city/lat/lng differing from its brewery's.
    (
        UUID("00000000-0000-4000-9003-000000000008"),
        "Kirin Ichiban (AU Import)",
        UUID("00000000-0000-4000-9002-000000000005"),
        UUID("00000000-0000-4000-9001-000000000002"),
        "AU",
        None,
        "Sydney",
        Decimal("-33.868800"),
        Decimal("151.209300"),
        Decimal("4.8"),
        11,
        None,
    ),
]


async def _seed_countries(conn: asyncpg.Connection) -> dict[str, UUID]:
    ids: dict[str, UUID] = {}
    for iso_code, name, continent in _COUNTRIES:
        row = await conn.fetchrow(
            """
            insert into public.countries (iso_code, name, continent)
            values ($1, $2, $3)
            on conflict (iso_code) do update set
                name = excluded.name,
                continent = excluded.continent
            returning id
            """,
            iso_code,
            name,
            continent,
        )
        ids[iso_code] = row["id"]
    return ids


async def _seed_beer_styles(conn: asyncpg.Connection, country_ids: dict[str, UUID]) -> None:
    for style_id, name, category, origin_iso, abv_min, abv_max in _BEER_STYLES:
        origin_country_id = country_ids.get(origin_iso) if origin_iso else None
        await conn.execute(
            """
            insert into public.beer_styles
                (id, name, category, origin_country_id, typical_abv_min, typical_abv_max)
            values ($1, $2, $3, $4, $5, $6)
            on conflict (id) do update set
                name = excluded.name,
                category = excluded.category,
                origin_country_id = excluded.origin_country_id,
                typical_abv_min = excluded.typical_abv_min,
                typical_abv_max = excluded.typical_abv_max
            """,
            style_id,
            name,
            category,
            origin_country_id,
            abv_min,
            abv_max,
        )


async def _seed_breweries(conn: asyncpg.Connection, country_ids: dict[str, UUID]) -> None:
    for brewery_id, name, country_iso, region, city, latitude, longitude in _BREWERIES:
        await conn.execute(
            """
            insert into public.breweries
                (id, name, country_id, region, city, latitude, longitude,
                 verified, source)
            values ($1, $2, $3, $4, $5, $6, $7, true, $8)
            on conflict (id) do update set
                name = excluded.name,
                country_id = excluded.country_id,
                region = excluded.region,
                city = excluded.city,
                latitude = excluded.latitude,
                longitude = excluded.longitude,
                source = excluded.source
            """,
            brewery_id,
            name,
            country_ids[country_iso],
            region,
            city,
            latitude,
            longitude,
            _SOURCE,
        )


async def _seed_beers(conn: asyncpg.Connection, country_ids: dict[str, UUID]) -> None:
    for (
        beer_id,
        official_name,
        brewery_id,
        style_id,
        country_iso,
        region,
        city,
        latitude,
        longitude,
        abv,
        ibu,
        barcode,
    ) in _BEERS:
        country_id = country_ids[country_iso] if country_iso else None
        await conn.execute(
            """
            insert into public.beers
                (id, official_name, brewery_id, style_id, country_id, region,
                 city, latitude, longitude, abv, ibu, barcode, verified, source)
            values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, true, $13)
            on conflict (id) do update set
                official_name = excluded.official_name,
                brewery_id = excluded.brewery_id,
                style_id = excluded.style_id,
                country_id = excluded.country_id,
                region = excluded.region,
                city = excluded.city,
                latitude = excluded.latitude,
                longitude = excluded.longitude,
                abv = excluded.abv,
                ibu = excluded.ibu,
                barcode = excluded.barcode,
                source = excluded.source
            """,
            beer_id,
            official_name,
            brewery_id,
            style_id,
            country_id,
            region,
            city,
            latitude,
            longitude,
            abv,
            ibu,
            barcode,
            _SOURCE,
        )


async def seed(seed_url: str) -> None:
    conn = await asyncpg.connect(**parse_dsn_kwargs(seed_url), ssl="require")
    try:
        country_ids = await _seed_countries(conn)
        await _seed_beer_styles(conn, country_ids)
        await _seed_breweries(conn, country_ids)
        await _seed_beers(conn, country_ids)
    finally:
        await conn.close()

    print(
        f"Seeded {len(_COUNTRIES)} countries, {len(_BEER_STYLES)} beer styles, "
        f"{len(_BREWERIES)} breweries, {len(_BEERS)} beers."
    )


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Seed the dev catalog (fabricated data).")
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Actually write. Without it, only the target host is printed.",
    )
    args = parser.parse_args(argv)

    load_dotenv(_REPO_ROOT / ".env")
    seed_url = os.environ.get("SEED_DATABASE_URL")
    try:
        host = check_seed_target(
            seed_url=seed_url,
            runtime_url=os.environ.get("DATABASE_URL"),
            environment=os.environ.get("ENVIRONMENT", "local"),
        )
    except SeedRefusedError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc

    if not args.yes:
        print(
            f"Target host: {host}\n"
            f"This writes fabricated catalog rows (verified=true, source={_SOURCE!r}). "
            "Re-run with --yes to proceed.",
            file=sys.stderr,
        )
        raise SystemExit(2)

    print(f"Seeding {host} ...")
    asyncio.run(seed(seed_url))


if __name__ == "__main__":
    main()
