"""End-to-end behavior of ContributionService with the REAL repositories
against a real Postgres, connecting as the least-privilege `beerapp_backend`
role (via SET ROLE on each pooled connection) -- so scoped_connection, the
owner-only RLS, the constraint names the service maps, and the boolean-only
cross-user function are all exercised together, as they run in production.

Like test_collection_concurrency.py, these commit real rows (the repository
opens its own transactions) and clean up explicitly in a `finally`.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with
Phase 13's migrations applied. Never DATABASE_URL/SEED_DATABASE_URL or the
shared dev project.
"""

import asyncio
from contextlib import asynccontextmanager
from decimal import Decimal
from uuid import uuid4

import asyncpg
import pytest

from app.errors import ConflictError, NotFoundError
from app.repositories.beers import BeerRepository
from app.repositories.breweries import BreweryRepository
from app.repositories.contributions import ContributionRepository
from app.schemas.contributions import (
    BeerContributionCreate,
    BeerDuplicateCheckQuery,
    BreweryContributionCreate,
    BreweryDuplicateCheckQuery,
)
from app.services.contributions import ContributionService

from .disposable_db import connection_kwargs

pytestmark = pytest.mark.integration

_USER_A = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
_USER_B = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
_CATALOG_BARCODE = "4006381333931"
_OTHER_BARCODE = "96385074"


async def _become_backend_role(conn: asyncpg.Connection) -> None:
    await conn.execute("set role beerapp_backend")


@asynccontextmanager
async def _environment(dsn: str):
    """Seeds two users and a tiny canonical catalog (committed), yields the
    real service plus an admin connection for out-of-band assertions, and
    removes everything it created.
    """
    kwargs = connection_kwargs(dsn)
    admin = await asyncpg.connect(**kwargs)
    ids: dict = {}
    try:
        await admin.execute("insert into auth.users (id) values ($1), ($2)", _USER_A, _USER_B)
        ids["country"] = await admin.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZY', 'Contribution Test Land', 'Europe') returning id"
        )
        ids["brewery"] = await admin.fetchval(
            "insert into public.breweries (name, country_id) values ('Hop House', $1) returning id",
            ids["country"],
        )
        ids["other_brewery"] = await admin.fetchval(
            "insert into public.breweries (name, country_id) "
            "values ('Other Brewery', $1) returning id",
            ids["country"],
        )
        ids["style"] = await admin.fetchval(
            "insert into public.beer_styles (name) values ('Contribution Test Style') returning id"
        )
        ids["catalog_beer"] = await admin.fetchval(
            "insert into public.beers (official_name, brewery_id, barcode, verified) "
            "values ('Hazy IPA', $1, $2, true) returning id",
            ids["brewery"],
            _CATALOG_BARCODE,
        )
        ids["catalog_beer_elsewhere"] = await admin.fetchval(
            "insert into public.beers (official_name, brewery_id) "
            "values ('Hazy IPA', $1) returning id",
            ids["other_brewery"],
        )

        pool = await asyncpg.create_pool(
            **kwargs, min_size=1, max_size=3, init=_become_backend_role
        )
        try:
            service = ContributionService(
                ContributionRepository(pool), BeerRepository(pool), BreweryRepository(pool)
            )
            yield service, ids, admin
        finally:
            await pool.close()
    finally:
        # Deleting the users cascades to their contributions (and profiles).
        await admin.execute("delete from auth.users where id in ($1, $2)", _USER_A, _USER_B)
        await admin.execute("delete from public.beers where brewery_id in ($1, $2)",
                            ids.get("brewery"), ids.get("other_brewery"))  # fmt: skip
        await admin.execute(
            "delete from public.breweries where country_id = $1", ids.get("country")
        )
        await admin.execute("delete from public.beer_styles where id = $1", ids.get("style"))
        await admin.execute("delete from public.countries where id = $1", ids.get("country"))
        await admin.close()


async def _catalog_counts(admin: asyncpg.Connection) -> tuple:
    return tuple(
        [
            await admin.fetchval(f"select count(*) from public.{table}")
            for table in ("countries", "beer_styles", "breweries", "beers")
        ]
    )


def _run(dsn: str, body) -> None:
    async def main() -> None:
        async with _environment(dsn) as (service, ids, admin):
            await body(service, ids, admin)

    asyncio.run(main())


def _beer(ids: dict, **overrides) -> BeerContributionCreate:
    fields = {"official_name": "Brand New Beer", "brewery_id": ids["brewery"]}
    fields.update(overrides)
    return BeerContributionCreate(**fields)


# -- a submission is a private pending row, never a catalog row ---------------


def test_submissions_are_pending_and_leave_the_catalog_untouched(integration_dsn):
    async def body(service, ids, admin) -> None:
        before = await _catalog_counts(admin)

        beer = await service.submit_beer(
            user_id=_USER_A,
            payload=_beer(ids, style_id=ids["style"], abv=Decimal("6.5"), barcode=_OTHER_BARCODE),
        )
        brewery = await service.submit_brewery(
            user_id=_USER_A,
            payload=BreweryContributionCreate(
                name="Brand New Brewery", country_id=ids["country"], city="Somewhere"
            ),
        )
        proposed = await service.submit_beer(
            user_id=_USER_A,
            payload=BeerContributionCreate(
                official_name="Proposed Everything",
                proposed_brewery_name="Nobody Knows Brewery",
                proposed_style_name="Weird Style",
            ),
        )

        assert (beer.status, brewery.status, proposed.status) == ("pending",) * 3
        assert beer.barcode == _OTHER_BARCODE
        assert beer.abv == Decimal("6.50")
        # The canonical catalog is exactly as it was: nothing was created,
        # nothing became visible to Discover.
        assert await _catalog_counts(admin) == before
        assert (
            await admin.fetchval(
                "select count(*) from public.beers where official_name = 'Brand New Beer'"
            )
            == 0
        )
        assert (
            await admin.fetchval(
                "select count(*) from public.breweries where name = 'Brand New Brewery'"
            )
            == 0
        )

    _run(integration_dsn, body)


def test_a_submission_never_touches_a_verified_catalog_row(integration_dsn):
    """The phase's exit criterion, end to end: even a suggestion that exactly
    mirrors a verified catalog beer cannot alter it.
    """

    async def body(service, ids, admin) -> None:
        before = await admin.fetchrow(
            "select official_name, brewery_id, abv, verified, source, updated_at "
            "from public.beers where id = $1",
            ids["catalog_beer"],
        )

        await service.submit_beer(
            user_id=_USER_A,
            payload=_beer(ids, official_name="Hazy IPA", abv=Decimal("9.9")),
        )

        after = await admin.fetchrow(
            "select official_name, brewery_id, abv, verified, source, updated_at "
            "from public.beers where id = $1",
            ids["catalog_beer"],
        )
        assert dict(after) == dict(before)
        assert after["verified"] is True

    _run(integration_dsn, body)


# -- history is the caller's own, both kinds, newest first --------------------


def test_history_lists_both_kinds_newest_first_and_only_the_callers_own(integration_dsn):
    async def body(service, ids, admin) -> None:
        await service.submit_beer(user_id=_USER_A, payload=_beer(ids, official_name="First"))
        await service.submit_brewery(
            user_id=_USER_A,
            payload=BreweryContributionCreate(name="Second", country_id=ids["country"]),
        )
        await service.submit_beer(user_id=_USER_A, payload=_beer(ids, official_name="Third"))
        await service.submit_beer(user_id=_USER_B, payload=_beer(ids, official_name="B's own"))

        page = await service.list_history(user_id=_USER_A, page=1, page_size=20)
        assert page.total == 3
        assert [(i.kind, i.title) for i in page.items] == [
            ("beer", "Third"),
            ("brewery", "Second"),
            ("beer", "First"),
        ]
        assert all(i.status == "pending" for i in page.items)

        # Pagination is over the merged list, with a stable total.
        first = await service.list_history(user_id=_USER_A, page=1, page_size=2)
        second = await service.list_history(user_id=_USER_A, page=2, page_size=2)
        assert first.total == second.total == 3
        assert [i.title for i in first.items + second.items] == ["Third", "Second", "First"]

        theirs = await service.list_history(user_id=_USER_B, page=1, page_size=20)
        assert [i.title for i in theirs.items] == ["B's own"]

    _run(integration_dsn, body)


# -- hard blocks --------------------------------------------------------------


def test_a_barcode_already_owned_by_a_catalog_beer_is_a_hard_conflict(integration_dsn):
    async def body(service, ids, admin) -> None:
        with pytest.raises(ConflictError) as raised:
            await service.submit_beer(user_id=_USER_A, payload=_beer(ids, barcode=_CATALOG_BARCODE))
        assert raised.value.code == "barcode_in_catalog"
        assert await admin.fetchval("select count(*) from public.beer_contributions") == 0

    _run(integration_dsn, body)


def test_the_callers_own_identical_pending_suggestion_is_a_hard_conflict(integration_dsn):
    """Exercises the REAL unique-index names the service maps."""

    async def body(service, ids, admin) -> None:
        await service.submit_beer(user_id=_USER_A, payload=_beer(ids, official_name="Dup"))
        with pytest.raises(ConflictError) as raised:
            await service.submit_beer(user_id=_USER_A, payload=_beer(ids, official_name="  dup  "))
        assert raised.value.code == "already_submitted"

        proposed = BeerContributionCreate(
            official_name="Dup2", proposed_brewery_name="Nobody Knows Brewery"
        )
        await service.submit_beer(user_id=_USER_A, payload=proposed)
        with pytest.raises(ConflictError) as raised:
            await service.submit_beer(user_id=_USER_A, payload=proposed)
        assert raised.value.code == "already_submitted"

        brewery = BreweryContributionCreate(name="Dup Brewery", country_id=ids["country"])
        await service.submit_brewery(user_id=_USER_A, payload=brewery)
        with pytest.raises(ConflictError):
            await service.submit_brewery(user_id=_USER_A, payload=brewery)

        proposed_country = BreweryContributionCreate(
            name="Dup Brewery", proposed_country_name="Atlantis"
        )
        await service.submit_brewery(user_id=_USER_A, payload=proposed_country)
        with pytest.raises(ConflictError):
            await service.submit_brewery(user_id=_USER_A, payload=proposed_country)

        # A different user may submit the very same thing.
        await service.submit_beer(user_id=_USER_B, payload=_beer(ids, official_name="Dup"))

    _run(integration_dsn, body)


def test_an_unknown_catalog_reference_is_not_found(integration_dsn):
    async def body(service, ids, admin) -> None:
        with pytest.raises(NotFoundError, match="Brewery"):
            await service.submit_beer(user_id=_USER_A, payload=_beer(ids, brewery_id=uuid4()))
        with pytest.raises(NotFoundError, match="Beer style"):
            await service.submit_beer(user_id=_USER_A, payload=_beer(ids, style_id=uuid4()))
        with pytest.raises(NotFoundError, match="Country"):
            await service.submit_brewery(
                user_id=_USER_A,
                payload=BreweryContributionCreate(name="X", country_id=uuid4()),
            )

    _run(integration_dsn, body)


# -- allow-and-flag: another user's pending barcode ---------------------------


def test_another_users_pending_barcode_is_flagged_not_blocked_and_reveals_nothing(
    integration_dsn,
):
    async def body(service, ids, admin) -> None:
        await service.submit_beer(
            user_id=_USER_A, payload=_beer(ids, official_name="A's Beer", barcode=_OTHER_BARCODE)
        )

        query = BeerDuplicateCheckQuery(
            official_name="B's Beer", brewery_id=ids["brewery"], barcode=_OTHER_BARCODE
        )
        seen_by_b = await service.beer_duplicate_candidates(user_id=_USER_B, query=query)
        seen_by_a = await service.beer_duplicate_candidates(user_id=_USER_A, query=query)

        assert seen_by_b.pending_barcode_duplicate_exists is True
        # The submitter's own pending row is not "another user's".
        assert seen_by_a.pending_barcode_duplicate_exists is False
        # The whole result carries no trace of the other contribution.
        dumped = seen_by_b.model_dump(mode="json")
        assert dumped["name_matches"] == [] and dumped["barcode_match"] is None
        assert "A's Beer" not in str(dumped)
        assert _USER_A not in str(dumped)

        # Allow: B can still submit the same barcode; both stay pending.
        again = await service.submit_beer(
            user_id=_USER_B, payload=_beer(ids, official_name="B's Beer", barcode=_OTHER_BARCODE)
        )
        assert again.status == "pending"
        assert (
            await admin.fetchval(
                "select count(*) from public.beer_contributions where barcode = $1", _OTHER_BARCODE
            )
            == 2
        )

    _run(integration_dsn, body)


def test_no_flag_when_nobody_else_has_the_barcode_or_none_is_given(integration_dsn):
    async def body(service, ids, admin) -> None:
        with_code = BeerDuplicateCheckQuery(
            official_name="X", brewery_id=ids["brewery"], barcode=_OTHER_BARCODE
        )
        without_code = BeerDuplicateCheckQuery(official_name="X", brewery_id=ids["brewery"])
        assert (
            await service.beer_duplicate_candidates(user_id=_USER_B, query=with_code)
        ).pending_barcode_duplicate_exists is False
        assert (
            await service.beer_duplicate_candidates(user_id=_USER_B, query=without_code)
        ).pending_barcode_duplicate_exists is False

    _run(integration_dsn, body)


# -- duplicate candidates against the real catalog ----------------------------


def test_beer_candidates_match_the_catalog_by_name_and_brewery_case_insensitively(
    integration_dsn,
):
    async def body(service, ids, admin) -> None:
        result = await service.beer_duplicate_candidates(
            user_id=_USER_A,
            query=BeerDuplicateCheckQuery(official_name="  hAzY   iPa ", brewery_id=ids["brewery"]),
        )
        assert [str(b.id) for b in result.name_matches] == [str(ids["catalog_beer"])]
        assert result.barcode_match is None and result.brewery_matches == []

        # Scoped to the brewery: the same name at another brewery is not a match.
        other = await service.beer_duplicate_candidates(
            user_id=_USER_A,
            query=BeerDuplicateCheckQuery(
                official_name="Hazy IPA", brewery_id=ids["other_brewery"]
            ),
        )
        assert [str(b.id) for b in other.name_matches] == [str(ids["catalog_beer_elsewhere"])]

        # A name that is not in the catalog matches nothing.
        none = await service.beer_duplicate_candidates(
            user_id=_USER_A,
            query=BeerDuplicateCheckQuery(official_name="Nope", brewery_id=ids["brewery"]),
        )
        assert none.name_matches == []

    _run(integration_dsn, body)


def test_beer_candidates_for_a_proposed_brewery_resolve_it_by_name(integration_dsn):
    async def body(service, ids, admin) -> None:
        result = await service.beer_duplicate_candidates(
            user_id=_USER_A,
            query=BeerDuplicateCheckQuery(
                official_name="Hazy IPA", proposed_brewery_name=" hop  house "
            ),
        )
        assert [b.name for b in result.brewery_matches] == ["Hop House"]
        assert [str(b.id) for b in result.name_matches] == [str(ids["catalog_beer"])]

    _run(integration_dsn, body)


def test_beer_candidates_report_a_catalog_barcode_owner(integration_dsn):
    async def body(service, ids, admin) -> None:
        result = await service.beer_duplicate_candidates(
            user_id=_USER_A,
            query=BeerDuplicateCheckQuery(
                official_name="Anything", brewery_id=ids["brewery"], barcode=_CATALOG_BARCODE
            ),
        )
        assert result.barcode_match is not None
        assert str(result.barcode_match.id) == str(ids["catalog_beer"])
        assert result.pending_barcode_duplicate_exists is False

    _run(integration_dsn, body)


def test_candidates_report_the_callers_own_pending_suggestion(integration_dsn):
    async def body(service, ids, admin) -> None:
        await service.submit_beer(user_id=_USER_A, payload=_beer(ids, official_name="Mine"))
        query = BeerDuplicateCheckQuery(official_name="MINE", brewery_id=ids["brewery"])

        assert (
            await service.beer_duplicate_candidates(user_id=_USER_A, query=query)
        ).already_submitted
        # Private: another user's identical-looking check is not told about it.
        assert not (
            await service.beer_duplicate_candidates(user_id=_USER_B, query=query)
        ).already_submitted

    _run(integration_dsn, body)


def test_brewery_candidates_match_by_name_within_the_country(integration_dsn):
    async def body(service, ids, admin) -> None:
        match = await service.brewery_duplicate_candidates(
            user_id=_USER_A,
            query=BreweryDuplicateCheckQuery(name=" HOP HOUSE", country_id=ids["country"]),
        )
        assert [str(b.id) for b in match.name_matches] == [str(ids["brewery"])]

        # A proposed (unlisted) country cannot collide with a catalog brewery.
        proposed = await service.brewery_duplicate_candidates(
            user_id=_USER_A,
            query=BreweryDuplicateCheckQuery(name="Hop House", proposed_country_name="Atlantis"),
        )
        assert proposed.name_matches == []

        await service.submit_brewery(
            user_id=_USER_A,
            payload=BreweryContributionCreate(name="Mine", country_id=ids["country"]),
        )
        mine = await service.brewery_duplicate_candidates(
            user_id=_USER_A,
            query=BreweryDuplicateCheckQuery(name="mine", country_id=ids["country"]),
        )
        assert mine.already_submitted is True

    _run(integration_dsn, body)
