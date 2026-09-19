-- Phase 13: answers ONE cross-user question for the duplicate-candidate check:
-- "does another user have a pending beer contribution with this barcode?"
--
-- beer_contributions RLS is owner-only, so beerapp_backend (under a user's
-- app.user_id) cannot see other users' rows -- and must not be able to. The
-- feature only needs a boolean, so instead of widening that policy this
-- narrowly scoped SECURITY DEFINER function returns nothing but true/false.
-- It never returns a row, id, user_id, or any identity.
--
-- Follows the repo's existing SECURITY DEFINER precedent
-- (private.handle_new_user() in 20260914120000_create_profiles_table.sql):
-- lives in the non-API-exposed `private` schema, `set search_path = ''` with
-- every object schema-qualified, no dynamic SQL, explicit revoke of EXECUTE
-- from PUBLIC/anon/authenticated.
--
-- The caller's identity is read from the transaction-local app.user_id
-- inside the function, not passed as a parameter, so "exclude the caller's
-- own rows" cannot be bypassed by passing a different id. If app.user_id is
-- unset, nullif(...)::uuid is NULL, `user_id <> NULL` is NULL, no row
-- matches, and the result is false -- it fails closed rather than leaking.
--
-- The caller's own pending rows are excluded on purpose: an identical own
-- suggestion is a separate hard-block (unique own-duplicate indexes on the
-- table), not this flag.
--
-- Served by beer_contributions_pending_barcode_idx.

create function private.other_user_pending_beer_barcode_exists(p_barcode text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.beer_contributions c
    where c.barcode = p_barcode
      and c.status = 'pending'
      and c.user_id <> nullif(current_setting('app.user_id', true), '')::uuid
  );
$$;

revoke execute on function private.other_user_pending_beer_barcode_exists(text)
  from public, anon, authenticated;

-- beerapp_backend has no privileges on schema `private` today. USAGE is the
-- one new privilege on it (needed to resolve the function name); it grants
-- no access to any table.
grant usage on schema private to beerapp_backend;
grant execute on function private.other_user_pending_beer_barcode_exists(text)
  to beerapp_backend;
