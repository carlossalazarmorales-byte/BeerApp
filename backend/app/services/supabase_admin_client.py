import httpx


class SupabaseAdminClientError(Exception):
    """The Supabase Auth Admin API call failed for reasons other than the
    user already being gone -- an infrastructure failure, not a caller
    error. Callers must map this to 503, never 401/500.
    """


class SupabaseAdminClientNotConfigured(SupabaseAdminClientError):
    """No secret key is configured. Checked before any request is made, so
    an unconfigured deployment never attempts a call with no credential.
    """


class SupabaseAdminClient:
    """Thin wrapper around the Supabase Auth Admin API, using the shared
    httpx.AsyncClient already created in app/main.py's lifespan -- no new
    Python SDK dependency for one call.

    Verified against current official Supabase docs (not the legacy
    service_role pattern): sb_secret_... keys are not JWTs and must be sent
    on the `apikey` header only -- sending one on `Authorization: Bearer`
    instead causes Supabase to try to parse it as a JWT and reject the
    request with "Invalid JWT". See
    https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys
    (fetched during Phase 12 planning) and docs/DECISIONS.md.
    """

    def __init__(
        self,
        http_client: httpx.AsyncClient,
        *,
        supabase_url: str,
        secret_key: str | None,
    ) -> None:
        self._http_client = http_client
        self._supabase_url = supabase_url
        self._secret_key = secret_key

    async def delete_user(self, user_id: str) -> None:
        """DELETE {supabase_url}/auth/v1/admin/users/{user_id}. A 404
        (already gone) is treated as success -- idempotent by design. Any
        other non-2xx response raises SupabaseAdminClientError.
        """
        if not self._secret_key:
            raise SupabaseAdminClientNotConfigured("SUPABASE_SECRET_KEY is not configured.")

        url = f"{self._supabase_url}/auth/v1/admin/users/{user_id}"
        try:
            response = await self._http_client.delete(
                url,
                headers={"apikey": self._secret_key},
                timeout=10.0,
            )
        except httpx.HTTPError as exc:
            raise SupabaseAdminClientError(str(exc)) from exc

        if response.status_code == 404:
            return

        if response.status_code >= 400:
            # Never include the secret key or the raw response body (which
            # could echo request headers back) in the exception message.
            raise SupabaseAdminClientError(
                f"Supabase Auth Admin API returned {response.status_code}."
            )
