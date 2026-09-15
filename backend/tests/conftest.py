import pytest
from fastapi import HTTPException, status
from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user
from app.main import app


def _raise_unauthorized() -> None:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing or invalid credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )


@pytest.fixture
def client() -> TestClient:
    # No `with` block: the lifespan (real DB pool / JWKS cache) never runs.
    # Every test overrides get_current_user and the relevant service
    # dependency directly, so nothing here needs app.state to exist.
    return TestClient(app)


@pytest.fixture
def authenticated():
    """Overrides get_current_user to simulate a valid session, without
    exercising the real JWT verification logic -- that's covered in
    isolation by tests/auth/test_verifier.py.
    """
    app.dependency_overrides[get_current_user] = lambda: "11111111-1111-1111-1111-111111111111"
    yield
    app.dependency_overrides.pop(get_current_user, None)


@pytest.fixture
def authenticated_as():
    """Like `authenticated`, but lets a test choose which user id
    get_current_user returns -- used by ownership-isolation tests that need
    to act as two different users within the same test (e.g. create a beer
    log as user A, then attempt to read/edit/delete it as user B).
    """

    def _apply(user_id: str) -> None:
        app.dependency_overrides[get_current_user] = lambda: user_id

    yield _apply
    app.dependency_overrides.pop(get_current_user, None)


@pytest.fixture
def unauthenticated():
    """Overrides get_current_user to raise the same 401 the real dependency
    raises on a missing/invalid token, so route tests can assert the route
    is wired to the auth dependency without depending on real JWKS/network.
    """
    app.dependency_overrides[get_current_user] = _raise_unauthorized
    yield
    app.dependency_overrides.pop(get_current_user, None)
