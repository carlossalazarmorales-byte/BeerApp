-- Phase 14 hardening: remove the unnecessary PUBLIC EXECUTE privilege from
-- private.set_updated_at().
--
-- Finding (Stage 3 privilege audit): 20260914120000_create_profiles_table.sql
-- revoked EXECUTE from PUBLIC on private.handle_new_user() but not on its
-- sibling private.set_updated_at(), so PostgreSQL's default applied and PUBLIC
-- (hence every role) holds EXECUTE on it. Nothing exposed it while `private`
-- was unreachable to the API roles, but 20260918155150 gave beerapp_backend
-- USAGE on schema `private`, which made this function reachable by that role.
--
-- It is not exploitable -- it is a trigger function (returns `trigger`), which
-- PostgreSQL refuses to run outside a trigger -- but nothing needs anyone to
-- hold EXECUTE on it, so the privilege is removed rather than left as a latent
-- footgun.
--
-- Why this cannot break the existing triggers: PostgreSQL checks EXECUTE on a
-- trigger function when the TRIGGER IS CREATED (by the migration's owner role,
-- which keeps EXECUTE as the function's owner), not when it fires. The seven
-- `*_set_updated_at` triggers therefore keep working for every role that
-- updates those tables (authenticated on profiles, beerapp_backend on the
-- user-owned tables, beerapp_seed on the catalog). The function body, its
-- owner, its `set search_path = ''`, and every trigger definition are
-- unchanged, and no other privilege is touched.
--
-- Forward-only and idempotent: REVOKE of a privilege that is not held is a
-- no-op. Never edits an already-applied migration.

revoke execute on function private.set_updated_at()
  from public, anon, authenticated;
