from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.auth.jwks import JWKSCache, JWKSUnavailableError
from app.auth.verifier import TokenInvalidError, verify_access_token
from app.config import Settings, get_settings
from app.errors import UNAUTHORIZED_MESSAGE

# auto_error=False: a missing Authorization header should produce our own
# 401 + WWW-Authenticate envelope, not FastAPI's default.
_bearer_scheme = HTTPBearer(auto_error=False)


def get_jwks_cache(request: Request) -> JWKSCache:
    return request.app.state.jwks_cache


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=UNAUTHORIZED_MESSAGE,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
    jwks_cache: JWKSCache = Depends(get_jwks_cache),
) -> str:
    """Verifies the caller's Supabase session JWT and returns the user id
    (`sub` claim). Every failure mode is resolved here, never left to
    propagate to the generic infrastructure exception handler: a bad/
    expired/malformed token is 401 (never logging the raw token), and only
    a JWKS *retrieval* failure -- not the caller's fault -- is 503.
    """
    if credentials is None:
        raise _unauthorized()

    try:
        claims = await verify_access_token(
            credentials.credentials,
            jwks_cache,
            issuer=settings.jwt_issuer,
            audience=settings.jwt_audience,
        )
    except TokenInvalidError as exc:
        raise _unauthorized() from exc
    except JWKSUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to verify session at this time.",
        ) from exc

    return claims["sub"]
