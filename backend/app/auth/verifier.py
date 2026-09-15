from typing import Any

import jwt
from jwt import InvalidTokenError

from app.auth.jwks import SUPPORTED_ALGORITHMS, JWKSCache


class TokenInvalidError(Exception):
    """Any token validation failure -- signature, expiry, audience, issuer,
    malformed header, unknown signing key. Callers must map this to 401,
    never 500/503.
    """


async def verify_access_token(
    token: str,
    jwks_cache: JWKSCache,
    *,
    issuer: str,
    audience: str,
) -> dict[str, Any]:
    try:
        unverified_header = jwt.get_unverified_header(token)
    except InvalidTokenError as exc:
        raise TokenInvalidError("malformed token header") from exc

    kid = unverified_header.get("kid")
    if not kid:
        raise TokenInvalidError("token header missing kid")

    try:
        signing_key = await jwks_cache.get_key(kid)
    except KeyError as exc:
        raise TokenInvalidError("unknown signing key") from exc

    # The verification algorithm comes from the matched JWKS key's own
    # declared type, never from the token header's `alg` claim -- this is
    # what closes the classic alg-confusion attack. `jwt.decode`'s
    # `algorithms=` is the actual enforcement point.
    algorithm = signing_key.algorithm_name
    if algorithm not in SUPPORTED_ALGORITHMS:
        raise TokenInvalidError(f"unsupported signing algorithm: {algorithm}")

    try:
        claims = jwt.decode(
            token,
            key=signing_key.key,
            algorithms=[algorithm],
            audience=audience,
            issuer=issuer,
            options={"require": ["exp", "sub"]},
        )
    except InvalidTokenError as exc:
        raise TokenInvalidError(str(exc)) from exc

    # Supabase sets `role: authenticated` on signed-in user access tokens.
    if claims.get("role") != "authenticated":
        raise TokenInvalidError("unexpected role claim")

    if not claims.get("sub"):
        raise TokenInvalidError("missing sub claim")

    return claims
