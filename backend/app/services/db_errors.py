"""Translating database constraint failures into API-level errors by
constraint NAME -- never by guessing which foreign key failed.

`user_beer_logs` and `user_beer_collection` have two foreign keys that a
write can violate, and they mean very different things:

- `..._beer_id_fkey`  -- the client named a beer that is not in the catalog:
  a 404 for that beer id (catalog data is global, so this reveals nothing
  about any user).
- `..._user_id_fkey`  -- the caller's own `auth.users` row is gone: a valid
  access token for a deleted account. `DELETE /account` cannot revoke an
  already-issued JWT, so this is reachable. It is a 401 (`SessionInvalidError`),
  not "beer not found".

Any other constraint (or none) is not something this layer can explain, so the
original exception is returned unchanged and surfaces as a sanitized 500.
"""

import asyncpg

from app.errors import NotFoundError, SessionInvalidError

_USER_FOREIGN_KEY_SUFFIX = "_user_id_fkey"


def is_user_foreign_key(exc: asyncpg.ForeignKeyViolationError) -> bool:
    return (exc.constraint_name or "").endswith(_USER_FOREIGN_KEY_SUFFIX)


def translate_beer_write_foreign_key_violation(
    exc: asyncpg.ForeignKeyViolationError, *, beer_constraint: str, beer_id: object
) -> Exception:
    if exc.constraint_name == beer_constraint:
        return NotFoundError(f"Beer {beer_id} not found")
    if is_user_foreign_key(exc):
        return SessionInvalidError()
    return exc
