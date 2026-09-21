import asyncio
import base64
from datetime import UTC, datetime, timedelta

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from app.auth.jwks import JWKSCache, JWKSUnavailableError
from app.auth.verifier import TokenInvalidError, verify_access_token

_JWKS_URL = "https://example.supabase.co/auth/v1/.well-known/jwks.json"
_ISSUER = "https://example.supabase.co/auth/v1"
_AUDIENCE = "authenticated"
_KID = "test-key-1"
_SUB = "11111111-1111-1111-1111-111111111111"


def _b64url_uint(value: int) -> str:
    raw = value.to_bytes(32, "big")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


@pytest.fixture
def keypair():
    private_key = ec.generate_private_key(ec.SECP256R1())
    return private_key, private_key.public_key()


def _jwk_dict(public_key, kid: str) -> dict:
    numbers = public_key.public_numbers()
    return {
        "kty": "EC",
        "crv": "P-256",
        "kid": kid,
        "alg": "ES256",
        "use": "sig",
        "x": _b64url_uint(numbers.x),
        "y": _b64url_uint(numbers.y),
    }


def _make_token(private_key, *, kid: str = _KID, **claim_overrides) -> str:
    now = datetime.now(UTC)
    claims = {
        "sub": _SUB,
        "role": "authenticated",
        "aud": _AUDIENCE,
        "iss": _ISSUER,
        "iat": now,
        "exp": now + timedelta(hours=1),
    }
    claims.update(claim_overrides)
    return jwt.encode(claims, private_key, algorithm="ES256", headers={"kid": kid})


def _cache_returning(*json_responses: dict) -> tuple[JWKSCache, list[int]]:
    calls = {"count": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        index = min(calls["count"], len(json_responses) - 1)
        calls["count"] += 1
        return httpx.Response(200, json=json_responses[index])

    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    cache = JWKSCache(_JWKS_URL, http_client)
    return cache, calls


def test_valid_token_is_accepted(keypair):
    private_key, public_key = keypair
    cache, _ = _cache_returning({"keys": [_jwk_dict(public_key, _KID)]})
    token = _make_token(private_key)

    claims = asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))

    assert claims["sub"] == _SUB


def test_expired_token_is_rejected(keypair):
    private_key, public_key = keypair
    cache, _ = _cache_returning({"keys": [_jwk_dict(public_key, _KID)]})
    now = datetime.now(UTC)
    token = _make_token(private_key, iat=now - timedelta(hours=2), exp=now - timedelta(hours=1))

    with pytest.raises(TokenInvalidError):
        asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))


def test_wrong_audience_is_rejected(keypair):
    private_key, public_key = keypair
    cache, _ = _cache_returning({"keys": [_jwk_dict(public_key, _KID)]})
    token = _make_token(private_key, aud="some-other-audience")

    with pytest.raises(TokenInvalidError):
        asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))


def test_wrong_issuer_is_rejected(keypair):
    private_key, public_key = keypair
    cache, _ = _cache_returning({"keys": [_jwk_dict(public_key, _KID)]})
    token = _make_token(private_key, iss="https://not-this-project.supabase.co/auth/v1")

    with pytest.raises(TokenInvalidError):
        asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))


def test_tampered_signature_is_rejected(keypair):
    private_key, public_key = keypair
    other_private_key = ec.generate_private_key(ec.SECP256R1())
    cache, _ = _cache_returning({"keys": [_jwk_dict(public_key, _KID)]})
    # Signed with a different key than the one published under this kid --
    # simulates a tampered/forged token.
    token = _make_token(other_private_key)

    with pytest.raises(TokenInvalidError):
        asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))


def test_wrong_role_claim_is_rejected(keypair):
    private_key, public_key = keypair
    cache, _ = _cache_returning({"keys": [_jwk_dict(public_key, _KID)]})
    token = _make_token(private_key, role="anon")

    with pytest.raises(TokenInvalidError):
        asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))


def test_missing_sub_claim_is_rejected(keypair):
    private_key, public_key = keypair
    cache, _ = _cache_returning({"keys": [_jwk_dict(public_key, _KID)]})
    now = datetime.now(UTC)
    claims_without_sub = {
        "role": "authenticated",
        "aud": _AUDIENCE,
        "iss": _ISSUER,
        "exp": now + timedelta(hours=1),
    }
    token = jwt.encode(claims_without_sub, private_key, algorithm="ES256", headers={"kid": _KID})

    with pytest.raises(TokenInvalidError):
        asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))


def test_unknown_kid_triggers_exactly_one_refresh_then_fails(keypair):
    private_key, public_key = keypair
    # JWKS never actually publishes this token's kid.
    cache, calls = _cache_returning({"keys": [_jwk_dict(public_key, "some-other-kid")]})
    token = _make_token(private_key, kid="missing-kid")

    with pytest.raises(TokenInvalidError):
        asyncio.run(verify_access_token(token, cache, issuer=_ISSUER, audience=_AUDIENCE))

    assert calls["count"] == 1


def test_signing_key_rotation_triggers_refresh_for_new_kid_only(keypair):
    private_key, public_key = keypair
    old_kid_jwk = _jwk_dict(public_key, "old-kid")

    rotated_private_key = ec.generate_private_key(ec.SECP256R1())
    new_kid_jwk = _jwk_dict(rotated_private_key.public_key(), "new-kid")

    cache, calls = _cache_returning({"keys": [old_kid_jwk]}, {"keys": [new_kid_jwk]})

    old_token = _make_token(private_key, kid="old-kid")
    claims = asyncio.run(verify_access_token(old_token, cache, issuer=_ISSUER, audience=_AUDIENCE))
    assert claims["sub"] == _SUB
    assert calls["count"] == 1

    # Re-requesting the already-cached kid must not trigger another fetch.
    asyncio.run(verify_access_token(old_token, cache, issuer=_ISSUER, audience=_AUDIENCE))
    assert calls["count"] == 1

    # A token signed with the rotated key is unknown to the cache -> exactly
    # one refresh, after which it resolves.
    new_token = _make_token(rotated_private_key, kid="new-kid")
    claims = asyncio.run(verify_access_token(new_token, cache, issuer=_ISSUER, audience=_AUDIENCE))
    assert claims["sub"] == _SUB
    assert calls["count"] == 2


def test_jwks_endpoint_failure_raises_jwks_unavailable_not_token_invalid():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    cache = JWKSCache(_JWKS_URL, http_client)

    with pytest.raises(JWKSUnavailableError):
        asyncio.run(cache.get_key(_KID))
