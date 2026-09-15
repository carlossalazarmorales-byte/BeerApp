-- Phase 6: scoped write grant for beerapp_backend on user_beer_logs only --
-- it remains SELECT-only on the four catalog tables (see
-- 20260915120400_create_beerapp_backend_role.sql). This is the running
-- API's first write endpoint anywhere in the backend.
--
-- Unlike the catalog tables' `using (true)` policy (fine there, since
-- beerapp_backend is the *only* path to that data and every row is equally
-- readable by every authenticated user), a blanket `using (true)` here
-- would give beerapp_backend unfiltered access to every user's rows,
-- relying entirely on every repository query remembering
-- `where user_id = $1`. That is not real per-user isolation -- a single
-- missing WHERE clause in a future change would leak or corrupt another
-- user's data with nothing in the database stopping it.
--
-- Instead, this policy compares each row's user_id against a
-- transaction-local Postgres setting, app.user_id, that the backend sets via
-- `select set_config('app.user_id', <verified JWT sub>, true)` at the start
-- of every user_beer_logs transaction (see
-- backend/app/repositories/beer_logs.py's BeerLogRepository._scoped). The
-- repository still filters `where user_id = $1` explicitly on every query
-- (belt) in addition to this policy (suspenders): a future repository bug
-- that forgets that WHERE clause still can't return or affect another
-- user's rows, because RLS restricts the visible/affected rows regardless
-- of what the application's own WHERE clause says. The WITH CHECK clause
-- closes the write-side equivalent: an INSERT/UPDATE that tried to assign a
-- row to a different user_id is rejected by Postgres itself.
--
-- nullif(current_setting('app.user_id', true), '') rather than a bare
-- current_setting(...)::uuid cast: current_setting(..., true) returns NULL
-- when the GUC was never set in this session, but a custom (uncatalogued)
-- GUC that has been cleared/reset can read back as an empty string rather
-- than SQL NULL depending on session/connection state. Casting '' directly
-- to uuid raises "invalid input syntax for type uuid", which would surface
-- as a 500 instead of cleanly denying access. Wrapping in nullif(..., '')
-- normalizes both "never set" and "set to empty" to SQL NULL first, so the
-- cast always succeeds and the row comparison always evaluates to NULL (not
-- an error) when there is no request identity -- NULL is never TRUE in a
-- USING/WITH CHECK clause, so an absent identity fails closed (denies all
-- rows) rather than granting blanket access or raising.

grant select, insert, update, delete
  on table public.user_beer_logs
  to beerapp_backend;

create policy backend_owns_rows on public.user_beer_logs
  for all
  to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid)
  with check (user_id = nullif(current_setting('app.user_id', true), '')::uuid);
