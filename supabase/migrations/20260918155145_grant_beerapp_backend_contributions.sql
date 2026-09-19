-- Phase 13: scoped grants for beerapp_backend on the two contribution tables.
--
-- Deliberately SELECT + INSERT only -- no UPDATE, no DELETE, exactly like
-- public.user_achievements (see 20260917120100_grant_beerapp_backend_user_achievements.sql).
-- Submissions are immutable this phase and there is no moderator workflow;
-- omitting these privileges makes editing, withdrawing, or self-approving a
-- contribution impossible at the database level, not merely by repository
-- convention. A future moderator uses a separate privileged role -- never
-- this one. beerapp_backend remains SELECT-only on the four catalog tables:
-- nothing here lets a contribution write catalog data.
--
-- RLS is request-scoped on app.user_id (set by scoped_connection), the same
-- mechanism and the same nullif(...) fail-closed guard as user_beer_logs /
-- user_achievements. Two command-specific policies rather than one `for all`
-- policy, mirroring the already-narrow grant. The SELECT policy is
-- owner-only and is intentionally NOT widened: the one cross-user question
-- the feature needs is answered by a boolean-only function in the next
-- migration, not by making other users' rows readable.
--
-- The INSERT policy pins status = 'pending' so a contribution cannot be
-- created already approved/rejected (the table CHECKs additionally tie the
-- review columns to a non-pending status). anon/authenticated get nothing.

grant select, insert on table public.brewery_contributions to beerapp_backend;
grant select, insert on table public.beer_contributions to beerapp_backend;

create policy backend_select_own on public.brewery_contributions
  for select
  to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid);

create policy backend_insert_own on public.brewery_contributions
  for insert
  to beerapp_backend
  with check (
    user_id = nullif(current_setting('app.user_id', true), '')::uuid
    and status = 'pending'
  );

create policy backend_select_own on public.beer_contributions
  for select
  to beerapp_backend
  using (user_id = nullif(current_setting('app.user_id', true), '')::uuid);

create policy backend_insert_own on public.beer_contributions
  for insert
  to beerapp_backend
  with check (
    user_id = nullif(current_setting('app.user_id', true), '')::uuid
    and status = 'pending'
  );
