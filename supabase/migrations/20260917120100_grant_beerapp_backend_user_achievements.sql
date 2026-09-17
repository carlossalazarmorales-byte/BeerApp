-- Deliberately SELECT + INSERT only -- no UPDATE, no DELETE. Achievements
-- are permanent once unlocked (product decision, see docs/DECISIONS.md);
-- omitting these privileges makes revocation or rewriting impossible at the
-- database level, not merely by repository convention.
grant select, insert
  on table public.user_achievements
  to beerapp_backend;

-- Two explicit, command-specific policies rather than the single `for all`
-- backend_owns_rows policy used on user_beer_logs/user_beer_collection --
-- a deliberate, narrow deviation, not a case the established convention
-- required. user_achievements is the first write-once (insert-only) user-
-- owned table, so splitting the policy by command gives defense-in-depth
-- that mirrors the already-narrower SELECT, INSERT-only grant above: even
-- if UPDATE/DELETE grants were mistakenly added later, there would still be
-- no matching RLS policy to authorize rows under either command. See
-- docs/DECISIONS.md.
create policy backend_select_own on public.user_achievements
  for select
  to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid);

create policy backend_insert_own on public.user_achievements
  for insert
  to beerapp_backend
  with check (user_id = nullif(current_setting('app.user_id', true), '')::uuid);
