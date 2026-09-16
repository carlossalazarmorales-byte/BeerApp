-- Phase 7: scoped write grant for beerapp_backend on user_beer_collection,
-- the second table on this pattern after user_beer_logs -- see
-- 20260915120700_grant_beerapp_backend_user_beer_logs.sql for the full
-- rationale (blanket `using (true)` vs. request-scoped RLS, the
-- nullif(current_setting(...), '') fail-closed trick). Not repeated here.

grant select, insert, update, delete
  on table public.user_beer_collection
  to beerapp_backend;

create policy backend_owns_rows on public.user_beer_collection
  for all
  to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid)
  with check (user_id = nullif(current_setting('app.user_id', true), '')::uuid);
