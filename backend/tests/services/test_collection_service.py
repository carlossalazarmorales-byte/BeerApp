import asyncio
from contextlib import asynccontextmanager
from uuid import UUID

import asyncpg
import pytest

from app.errors import NotFoundError, SessionInvalidError
from app.schemas.collection import CollectionStateUpdate
from app.services.collection import CollectionService

_USER_ID = "11111111-1111-1111-1111-111111111111"
_BEER_ID = "44444444-4444-4444-4444-444444444444"


def _collection_beer_row(**overrides) -> dict:
    row = {
        "beer_id": UUID(_BEER_ID),
        "official_name": "Test Beer",
        "brewery_name": "Test Brewery",
        "style_name": "IPA",
        "country_name": "Ireland",
        "image_url": None,
        "abv": None,
        "is_favorite": False,
        "is_wishlist": False,
        "latest_rating": None,
        "latest_consumed_at": None,
    }
    row.update(overrides)
    return row


class _FakeConnection:
    """A sentinel object, not a real asyncpg.Connection -- tests assert
    identity (is) on this to prove two calls shared one connection/
    transaction, without needing a real database.
    """


class _FakePool:
    """Duck-types asyncpg.Pool.acquire() just enough for the real
    scoped_connection() (unmodified, imported by CollectionService) to run
    against it -- so these tests exercise the actual transaction-opening
    code path, not a mock of it.
    """

    def __init__(self, conn: _FakeConnection) -> None:
        self._conn = conn

    @asynccontextmanager
    async def acquire(self):
        yield self._conn


# scoped_connection() calls conn.transaction(isolation=...) and
# conn.execute(...) on whatever `acquire()` yields -- _FakeConnection must
# support both for the real scoped_connection to run unmodified.
def _patch_fake_connection() -> None:
    async def _noop_execute(self, *args, **kwargs):
        return None

    @asynccontextmanager
    async def _noop_transaction(self, isolation=None):
        yield None

    _FakeConnection.execute = _noop_execute
    _FakeConnection.transaction = _noop_transaction


_patch_fake_connection()


class _FakeCollectionRepository:
    def __init__(self) -> None:
        self.logged_result: tuple[list[dict], int] = ([], 0)
        self.favorites_result: tuple[list[dict], int] = ([], 0)
        self.wishlist_result: tuple[list[dict], int] = ([], 0)
        self.get_state_result: dict | None = None
        self.set_state_result: dict | None = None
        self.set_state_error: Exception | None = None
        self.set_state_calls: list[dict] = []

    async def list_logged(self, **kwargs):
        return self.logged_result

    async def list_favorites(self, **kwargs):
        return self.favorites_result

    async def list_wishlist(self, **kwargs):
        return self.wishlist_result

    async def get_state(self, *, user_id: str, beer_id: str):
        return self.get_state_result

    async def set_state_on_connection(
        self, conn, *, user_id: str, beer_id: str, is_favorite, is_wishlist
    ):
        self.set_state_calls.append(
            {
                "conn": conn,
                "user_id": user_id,
                "beer_id": beer_id,
                "is_favorite": is_favorite,
                "is_wishlist": is_wishlist,
            }
        )
        if self.set_state_error is not None:
            raise self.set_state_error
        return self.set_state_result


class _FakeAchievementEvaluator:
    def __init__(self) -> None:
        self.calls: list[dict] = []
        self.error: Exception | None = None

    async def evaluate_and_unlock(self, conn, *, user_id: str) -> None:
        self.calls.append({"conn": conn, "user_id": user_id})
        if self.error is not None:
            raise self.error


def _make_service(repository=None, evaluator=None):
    repository = repository or _FakeCollectionRepository()
    evaluator = evaluator or _FakeAchievementEvaluator()
    pool = _FakePool(_FakeConnection())
    return CollectionService(repository, pool, evaluator), repository, evaluator


def _run(coro):
    return asyncio.run(coro)


# -- list_* pagination passthrough (unaffected by the atomicity change) -----


def test_list_logged_wraps_repository_rows_into_page():
    service, repository, _ = _make_service()
    repository.logged_result = ([_collection_beer_row()], 1)

    page = _run(
        service.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )
    )

    assert page.total == 1
    assert page.items[0].official_name == "Test Beer"


def test_list_favorites_wraps_repository_rows_into_page():
    service, repository, _ = _make_service()
    repository.favorites_result = ([_collection_beer_row(is_favorite=True)], 1)

    page = _run(
        service.list_favorites(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )
    )

    assert page.items[0].is_favorite is True


def test_list_wishlist_wraps_repository_rows_into_page():
    service, repository, _ = _make_service()
    repository.wishlist_result = ([_collection_beer_row(is_wishlist=True)], 1)

    page = _run(
        service.list_wishlist(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )
    )

    assert page.items[0].is_wishlist is True


# -- get_state: 404 vs. 200 distinction --------------------------------------


def test_get_state_raises_not_found_when_repository_returns_none():
    service, repository, _ = _make_service()
    repository.get_state_result = None

    with pytest.raises(NotFoundError):
        _run(service.get_state(user_id=_USER_ID, beer_id=_BEER_ID))


def test_get_state_returns_false_false_for_a_real_beer_with_no_row():
    service, repository, _ = _make_service()
    repository.get_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": False,
        "is_wishlist": False,
    }

    result = _run(service.get_state(user_id=_USER_ID, beer_id=_BEER_ID))

    assert result.is_favorite is False
    assert result.is_wishlist is False


# -- set_state: FK violation -> NotFoundError, evaluator not invoked --------


def _fk_error(constraint_name: str | None) -> asyncpg.ForeignKeyViolationError:
    error = asyncpg.ForeignKeyViolationError("simulated")
    error.constraint_name = constraint_name
    return error


def test_set_state_foreign_key_violation_becomes_not_found_and_skips_evaluator():
    service, repository, evaluator = _make_service()
    repository.set_state_error = _fk_error("user_beer_collection_beer_id_fkey")

    with pytest.raises(NotFoundError):
        _run(
            service.set_state(
                user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
            )
        )

    assert evaluator.calls == []


def test_set_state_passes_absolute_requested_values_to_repository():
    service, repository, _ = _make_service()
    repository.set_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": True,
        "is_wishlist": False,
    }

    _run(
        service.set_state(
            user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
        )
    )

    call = repository.set_state_calls[0]
    assert call["is_favorite"] is True
    assert call["is_wishlist"] is None  # omitted field passed through as None, not coerced


def test_set_state_returns_repository_result():
    service, repository, _ = _make_service()
    repository.set_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": False,
        "is_wishlist": False,
    }

    result = _run(
        service.set_state(
            user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=False)
        )
    )

    assert result.is_favorite is False
    assert result.is_wishlist is False


# -- atomicity: mutation and evaluation share one connection/transaction ----


def test_set_state_invokes_evaluator_with_the_same_connection_as_the_mutation():
    """The key regression test for the atomicity fix: proves
    repository.set_state_on_connection and evaluator.evaluate_and_unlock
    both ran against the exact same connection object, without needing a
    real database -- see docs/DECISIONS.md.
    """
    service, repository, evaluator = _make_service()
    repository.set_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": True,
        "is_wishlist": False,
    }

    _run(
        service.set_state(
            user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
        )
    )

    assert len(evaluator.calls) == 1
    mutation_conn = repository.set_state_calls[0]["conn"]
    evaluator_conn = evaluator.calls[0]["conn"]
    assert mutation_conn is evaluator_conn
    assert evaluator.calls[0]["user_id"] == _USER_ID


def test_set_state_propagates_evaluator_failure_instead_of_reporting_success():
    """Unit-level proxy for "evaluator failure rolls back the mutation" --
    real rollback behavior itself requires Postgres (see
    tests/integration/test_collection_achievement_atomicity.py). This proves
    the service does not swallow the evaluator's exception to report the
    Collection mutation as independently successful.
    """
    service, repository, evaluator = _make_service()
    repository.set_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": True,
        "is_wishlist": False,
    }
    evaluator.error = RuntimeError("boom")

    with pytest.raises(RuntimeError):
        _run(
            service.set_state(
                user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
            )
        )


def test_set_state_for_a_deleted_account_is_session_invalid_and_skips_evaluator():
    service, repository, evaluator = _make_service()
    repository.set_state_error = _fk_error("user_beer_collection_user_id_fkey")

    with pytest.raises(SessionInvalidError):
        _run(
            service.set_state(
                user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
            )
        )

    assert evaluator.calls == []


@pytest.mark.parametrize("constraint", [None, "", "something_else_fkey"])
def test_set_state_unrecognized_foreign_key_violation_is_not_guessed_at(constraint):
    service, repository, _ = _make_service()
    repository.set_state_error = _fk_error(constraint)

    with pytest.raises(asyncpg.ForeignKeyViolationError):
        _run(
            service.set_state(
                user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
            )
        )
