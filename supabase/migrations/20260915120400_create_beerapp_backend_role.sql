-- Phase 3: least-privilege Postgres role for the FastAPI backend's direct
-- connection (`DATABASE_URL`). Deliberately NOT the project's postgres/admin
-- role and NOT granted BYPASSRLS -- Supabase's current guidance is to give
-- each external service its own scoped database user rather than the
-- project's admin credentials. See docs/DATABASE.md and docs/DECISIONS.md.
--
-- SELECT-only on the four catalog tables, nothing else. Catalog writes
-- (seeding today, admin flows in a later phase) use a separate admin/direct
-- connection (`SEED_DATABASE_URL`) that the running API never has -- see
-- backend/scripts/seed_catalog.py.
--
-- No password is set here and none is committed. Setting
-- `beerapp_backend`'s password is a one-time manual step run directly
-- against the project after this migration is applied:
--
--   alter role beerapp_backend with password '<generated-strong-password>';
--
-- The resulting password lives only in the backend's local/deployment
-- secrets, as part of DATABASE_URL -- never in a migration, never in git.

create role beerapp_backend with login;

grant usage on schema public to beerapp_backend;

grant select on table public.countries to beerapp_backend;
grant select on table public.beer_styles to beerapp_backend;
grant select on table public.breweries to beerapp_backend;
grant select on table public.beers to beerapp_backend;

create policy select_for_backend on public.countries
  for select
  to beerapp_backend
  using (true);

create policy select_for_backend on public.beer_styles
  for select
  to beerapp_backend
  using (true);

create policy select_for_backend on public.breweries
  for select
  to beerapp_backend
  using (true);

create policy select_for_backend on public.beers
  for select
  to beerapp_backend
  using (true);
