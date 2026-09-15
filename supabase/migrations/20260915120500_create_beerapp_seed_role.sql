-- Phase 3: dedicated role for the dev seed script (backend/scripts/seed_catalog.py).
--
-- The plan called for reusing the project's existing admin/direct Postgres
-- credential as SEED_DATABASE_URL. That credential's password is a secret
-- known only to the project owner and was never available to this
-- implementation session, so instead of blocking on it, this migration
-- creates a second dedicated, scoped role -- write access to the four
-- catalog tables only, still not superuser, still not BYPASSRLS. This
-- satisfies the same goal the plan described (a write-capable credential
-- that is separate from, and never used by, the running API's
-- `beerapp_backend` connection) without needing the project's root
-- credential. See docs/DECISIONS.md for the rationale.
--
-- No password is set here and none is committed -- same manual one-time
-- step as beerapp_backend:
--
--   alter role beerapp_seed with password '<generated-strong-password>';
--
-- The resulting password lives only in the developer's local secrets, as
-- SEED_DATABASE_URL -- never in a migration, never in git, and never read
-- by the running FastAPI app.

create role beerapp_seed with login;

grant usage on schema public to beerapp_seed;

grant select, insert, update, delete on table public.countries to beerapp_seed;
grant select, insert, update, delete on table public.beer_styles to beerapp_seed;
grant select, insert, update, delete on table public.breweries to beerapp_seed;
grant select, insert, update, delete on table public.beers to beerapp_seed;

create policy write_for_seed on public.countries
  for all
  to beerapp_seed
  using (true)
  with check (true);

create policy write_for_seed on public.beer_styles
  for all
  to beerapp_seed
  using (true)
  with check (true);

create policy write_for_seed on public.breweries
  for all
  to beerapp_seed
  using (true)
  with check (true);

create policy write_for_seed on public.beers
  for all
  to beerapp_seed
  using (true)
  with check (true);
