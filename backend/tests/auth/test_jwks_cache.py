"""JWKS cache: TTL, refresh cooldown, and key-rotation behaviour.

Bounds on outbound fetches (the point of this file):
- a cold or TTL-expired cache is (re)loaded at most once per attempt, and a
  failed load is not retried until the cooldown has passed;
- an unknown `kid` triggers at most one refresh per cooldown, so a flood of
  forged tokens cannot make the backend hammer the Supabase endpoint;
- keys removed upstream stop being trusted once the TTL passes (fail closed
  if the endpoint cannot be reached to confirm).
"""

import asyncio
import base64

import httpx
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from app.auth.jwks import SUPPORTED_ALGORITHMS, JWKSCache, JWKSUnavailableError

_URL = "https://example.supabase.co/auth/v1/.well-known/jwks.json"
_TTL = 600.0
_COOLDOWN = 30.0


class _Clock:
    def __init__(self) -> None:
        self.now = 1_000.0

    def __call__(self) -> float:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += seconds


def _jwk(kid: str, alg: str = "ES256") -> dict:
    numbers = ec.generate_private_key(ec.SECP256R1()).public_key().public_numbers()

    def b64(value: int) -> str:
        return base64.urlsafe_b64encode(value.to_bytes(32, "big")).rstrip(b"=").decode()

    return {"kty": "EC", "crv": "P-256", "kid": kid, "alg": alg, "use": "sig",
            "x": b64(numbers.x), "y": b64(numbers.y)}  # fmt: skip


class _Endpoint:
    """A scriptable JWKS endpoint that counts fetches."""

    def __init__(self, *bodies: dict) -> None:
        self.bodies = list(bodies)
        self.calls = 0
        self.fail = False
        self.delay = 0.0

    async def __call__(self, request: httpx.Request) -> httpx.Response:
        self.calls += 1
        if self.delay:
            await asyncio.sleep(self.delay)
        if self.fail:
            return httpx.Response(503)
        body = self.bodies[min(self.calls - 1, len(self.bodies) - 1)]
        return httpx.Response(200, json=body)


def _cache(endpoint: _Endpoint, clock: _Clock) -> JWKSCache:
    client = httpx.AsyncClient(transport=httpx.MockTransport(endpoint))
    return JWKSCache(
        _URL, client, ttl_seconds=_TTL, refresh_cooldown_seconds=_COOLDOWN, clock=clock
    )


def _keys(*kids: str) -> dict:
    return {"keys": [_jwk(kid) for kid in kids]}


def _get(cache: JWKSCache, kid: str):
    return asyncio.run(cache.get_key(kid))


# -- initial fetch and cache hits -----------------------------------------------


def test_first_lookup_fetches_once_and_returns_the_key():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    cache = _cache(endpoint, clock)

    key = _get(cache, "k1")

    assert key.algorithm_name == "ES256"
    assert endpoint.calls == 1


def test_repeat_lookups_within_the_ttl_are_cache_hits():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "k1")

    clock.advance(_TTL - 1)
    for _ in range(20):
        _get(cache, "k1")

    assert endpoint.calls == 1


# -- TTL expiry ----------------------------------------------------------------


def test_the_cache_is_reloaded_once_the_ttl_has_passed():
    endpoint, clock = _Endpoint(_keys("k1"), _keys("k1")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "k1")

    clock.advance(_TTL + 1)
    _get(cache, "k1")
    _get(cache, "k1")

    assert endpoint.calls == 2


def test_a_key_removed_upstream_stops_being_trusted_after_the_ttl():
    endpoint, clock = _Endpoint(_keys("old"), _keys("new")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "old")

    clock.advance(_TTL + 1)

    with pytest.raises(KeyError):
        _get(cache, "old")
    assert _get(cache, "new") is not None


def test_after_the_ttl_an_unreachable_endpoint_fails_closed():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "k1")
    endpoint.fail = True

    clock.advance(_TTL + 1)

    # Stale keys are NOT served: whether k1 is still valid cannot be confirmed.
    with pytest.raises(JWKSUnavailableError):
        _get(cache, "k1")


# -- unknown kid: key rotation and the cooldown ---------------------------------


def test_an_unknown_kid_triggers_one_refresh_that_resolves_a_rotated_key():
    endpoint, clock = _Endpoint(_keys("old"), _keys("old", "new")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "old")

    assert _get(cache, "new") is not None
    assert endpoint.calls == 2


def test_a_flood_of_unknown_kids_causes_at_most_one_refresh_per_cooldown():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "k1")  # initial load

    for i in range(200):
        with pytest.raises(KeyError):
            _get(cache, f"forged-{i}")

    assert endpoint.calls == 2  # initial load + exactly one refresh


def test_unknown_kid_refresh_is_allowed_again_after_the_cooldown():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "k1")
    with pytest.raises(KeyError):
        _get(cache, "forged-a")
    assert endpoint.calls == 2

    clock.advance(_COOLDOWN + 1)
    with pytest.raises(KeyError):
        _get(cache, "forged-b")
    assert endpoint.calls == 3

    with pytest.raises(KeyError):
        _get(cache, "forged-c")
    assert endpoint.calls == 3  # cooldown restarted


def test_a_rotation_arriving_during_the_cooldown_resolves_after_it():
    endpoint, clock = _Endpoint(_keys("old"), _keys("old"), _keys("old", "new")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "old")
    with pytest.raises(KeyError):
        _get(cache, "forged")  # starts the cooldown

    with pytest.raises(KeyError):
        _get(cache, "new")  # not yet published / within cooldown: no fetch
    assert endpoint.calls == 2

    clock.advance(_COOLDOWN + 1)
    assert _get(cache, "new") is not None


def test_cached_kids_keep_resolving_during_the_cooldown():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    cache = _cache(endpoint, clock)
    _get(cache, "k1")
    with pytest.raises(KeyError):
        _get(cache, "forged")

    assert _get(cache, "k1") is not None
    assert endpoint.calls == 2


# -- failures ------------------------------------------------------------------


def test_a_failed_load_is_not_retried_until_the_cooldown_has_passed():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    endpoint.fail = True
    cache = _cache(endpoint, clock)

    for _ in range(5):
        with pytest.raises(JWKSUnavailableError):
            _get(cache, "k1")
    assert endpoint.calls == 1

    endpoint.fail = False
    clock.advance(_COOLDOWN + 1)
    assert _get(cache, "k1") is not None
    assert endpoint.calls == 2


def test_a_malformed_jwks_body_is_unavailable_not_a_crash():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=["not", "an", "object"])

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    cache = JWKSCache(_URL, client, clock=_Clock())

    with pytest.raises(JWKSUnavailableError):
        _get(cache, "k1")


# -- concurrency ----------------------------------------------------------------


def test_concurrent_cold_lookups_share_a_single_fetch():
    endpoint, clock = _Endpoint(_keys("k1")), _Clock()
    endpoint.delay = 0.05
    cache = _cache(endpoint, clock)

    async def burst():
        return await asyncio.gather(*(cache.get_key("k1") for _ in range(25)))

    keys = asyncio.run(burst())

    assert len(keys) == 25
    assert endpoint.calls == 1


# -- validation is not weakened ---------------------------------------------------


def test_keys_with_unsupported_algorithms_or_no_kid_are_never_trusted():
    body = {
        "keys": [
            _jwk("hs", alg="HS256"),
            {**_jwk("none-alg"), "alg": None},
            {k: v for k, v in _jwk("x").items() if k != "kid"},
            _jwk("good"),
        ]
    }
    endpoint, clock = _Endpoint(body), _Clock()
    cache = _cache(endpoint, clock)

    assert _get(cache, "good") is not None
    for kid in ("hs", "none-alg"):
        with pytest.raises(KeyError):
            _get(cache, kid)
    assert SUPPORTED_ALGORITHMS == frozenset({"RS256", "ES256"})
