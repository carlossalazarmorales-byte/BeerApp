import time
from dataclasses import dataclass

import httpx
from jwt import PyJWK

# Confirmed against this project's JWKS endpoint before this module was
# written (Phase 3 Step 0 preflight, docs/DECISIONS.md): it exposes an
# asymmetric ES256 key. RS256 is allowed too in case the project's signing
# key is ever rotated to RSA. HS256 (legacy shared-secret) is deliberately
# never accepted here.
SUPPORTED_ALGORITHMS = frozenset({"RS256", "ES256"})


class JWKSUnavailableError(Exception):
    """The JWKS endpoint could not be reached or returned invalid data.

    This is an infrastructure failure, not a bad token -- callers must map
    it to 503, never 401.
    """


@dataclass(frozen=True)
class _CachedJWKS:
    keys_by_kid: dict[str, PyJWK]
    fetched_at: float


class JWKSCache:
    """In-process cache of a Supabase project's JWKS, fetched over
    httpx.AsyncClient (non-blocking on the event loop). Refreshes once when
    an unknown `kid` is looked up, so signing-key rotation works without a
    backend redeploy -- it does not refresh on every request.
    """

    def __init__(self, jwks_url: str, http_client: httpx.AsyncClient) -> None:
        self._jwks_url = jwks_url
        self._http_client = http_client
        self._cache: _CachedJWKS | None = None

    async def get_key(self, kid: str) -> PyJWK:
        if self._cache is None or kid not in self._cache.keys_by_kid:
            await self._refresh()

        if self._cache is None or kid not in self._cache.keys_by_kid:
            raise KeyError(kid)

        return self._cache.keys_by_kid[kid]

    async def _refresh(self) -> None:
        try:
            response = await self._http_client.get(self._jwks_url, timeout=5.0)
            response.raise_for_status()
            data = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise JWKSUnavailableError(str(exc)) from exc

        keys_by_kid: dict[str, PyJWK] = {}
        for raw_key in data.get("keys", []):
            kid = raw_key.get("kid")
            alg = raw_key.get("alg")
            if not kid or alg not in SUPPORTED_ALGORITHMS:
                continue
            keys_by_kid[kid] = PyJWK.from_dict(raw_key)

        self._cache = _CachedJWKS(keys_by_kid=keys_by_kid, fetched_at=time.monotonic())
