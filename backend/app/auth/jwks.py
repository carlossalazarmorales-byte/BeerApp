import asyncio
import time
from collections.abc import Callable
from dataclasses import dataclass

import httpx
from jwt import PyJWK
from jwt.exceptions import PyJWTError

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
    httpx.AsyncClient (non-blocking on the event loop).

    Outbound fetches are bounded, because a token's `kid` is attacker-supplied
    and an unauthenticated request can otherwise make the backend call Supabase:

    - **TTL.** A loaded key set is trusted for at most `ttl_seconds`. After
      that it is reloaded, so a key removed upstream stops being trusted. If
      the reload cannot be completed the cache fails closed (JWKSUnavailable ->
      503); stale keys are never served.
    - **Unknown `kid` (key rotation).** A fresh cache that lacks the `kid`
      refreshes once, so rotation works without a redeploy -- but at most once
      per `refresh_cooldown_seconds`, however many forged kids arrive.
    - **Failed load.** Not retried until the cooldown has passed.
    - **Concurrency.** Simultaneous cold/expired lookups share one fetch.

    The initial (or post-TTL) load does not itself start the unknown-`kid`
    cooldown, so a legitimate rotation right after startup still resolves.
    Worst case is therefore about two fetches per cooldown window, plus one
    per TTL. Issuer, audience, algorithm and role validation live in
    app/auth/verifier.py and are unaffected.
    """

    def __init__(
        self,
        jwks_url: str,
        http_client: httpx.AsyncClient,
        *,
        ttl_seconds: float = 600.0,
        refresh_cooldown_seconds: float = 30.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._jwks_url = jwks_url
        self._http_client = http_client
        self._ttl = ttl_seconds
        self._cooldown = refresh_cooldown_seconds
        self._clock = clock
        self._cache: _CachedJWKS | None = None
        self._lock = asyncio.Lock()
        # Earliest time another load may be attempted after a failed one.
        self._retry_load_at = 0.0
        # Earliest time an unknown `kid` may trigger another refresh.
        self._unknown_kid_refresh_at = 0.0

    def _is_fresh(self, now: float) -> bool:
        return self._cache is not None and now - self._cache.fetched_at < self._ttl

    async def get_key(self, kid: str) -> PyJWK:
        now = self._clock()

        if self._is_fresh(now):
            if kid in self._cache.keys_by_kid:
                return self._cache.keys_by_kid[kid]
            if now >= self._unknown_kid_refresh_at:
                # Claimed before the network call so concurrent forged
                # lookups cannot each start their own refresh.
                self._unknown_kid_refresh_at = now + self._cooldown
                await self._load(force=True)
            # else: cooling down -- the kid is simply unknown for now.
        else:
            await self._load(force=False)

        if self._cache is None or kid not in self._cache.keys_by_kid:
            raise KeyError(kid)
        return self._cache.keys_by_kid[kid]

    async def _load(self, *, force: bool) -> None:
        async with self._lock:
            now = self._clock()
            # Another task may have loaded while this one waited for the lock.
            if not force and self._is_fresh(now):
                return
            if now < self._retry_load_at:
                raise JWKSUnavailableError("JWKS fetch failed recently; not retrying yet")
            try:
                keys_by_kid = await self._fetch()
            except JWKSUnavailableError:
                self._retry_load_at = now + self._cooldown
                raise
            self._cache = _CachedJWKS(keys_by_kid=keys_by_kid, fetched_at=self._clock())

    async def _fetch(self) -> dict[str, PyJWK]:
        try:
            response = await self._http_client.get(self._jwks_url, timeout=5.0)
            response.raise_for_status()
            data = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise JWKSUnavailableError(str(exc)) from exc

        raw_keys = data.get("keys", []) if isinstance(data, dict) else None
        if not isinstance(raw_keys, list):
            raise JWKSUnavailableError("JWKS response is not a key set")

        keys_by_kid: dict[str, PyJWK] = {}
        for raw_key in raw_keys:
            if not isinstance(raw_key, dict):
                continue
            kid = raw_key.get("kid")
            alg = raw_key.get("alg")
            if not kid or alg not in SUPPORTED_ALGORITHMS:
                continue
            try:
                keys_by_kid[kid] = PyJWK.from_dict(raw_key)
            except (PyJWTError, ValueError, KeyError, TypeError):
                # One malformed key must not take the rest of the set down.
                continue
        return keys_by_kid
