-- Minimal Supabase-like scaffold for the DISPOSABLE integration database.
--
-- TEST SUPPORT ONLY. Apply it (as a superuser) to an EMPTY, LOCAL, THROWAWAY
-- PostgreSQL database BEFORE the repository's supabase/migrations/*.sql, and only
-- when a real local Supabase stack (`supabase start`, which needs Docker) is not
-- available. Never apply it to beerapp-dev or to any shared or production database.
--
-- This is NOT a Supabase emulator. It provides only what the migrations and the
-- integration tests depend on:
--   * the `anon`, `authenticated` and `service_role` roles Supabase provides;
--   * a minimal `auth.users` table and `auth.uid()`;
--   * Supabase's DEFAULT privileges on new `public` objects, so the migrations'
--     explicit REVOKEs are tested against realistic defaults rather than a bare
--     Postgres where nothing is granted.
-- It does NOT provide GoTrue, PostgREST, the pooler, the other Supabase-managed
-- roles/extensions, or a non-superuser `postgres` role. See docs/DATABASE.md.
--
-- No passwords, no login roles, no project identifiers, no URLs. Roles are
-- cluster-level, so role creation is idempotent (a new database in the same
-- cluster reuses them); the schema objects are created fresh.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

create schema extensions;

-- ONLY the columns the migrations and the tests actually use: `id` (every
-- user_id column in the app references auth.users(id)) and `raw_user_meta_data`
-- (read by private.handle_new_user() when it creates a profile). The real
-- GoTrue table has many more; they are deliberately not reproduced here.
create schema auth;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  raw_user_meta_data jsonb
);

-- Supabase's auth.uid(): the caller's user id from the request JWT settings.
create function auth.uid() returns uuid
language sql stable
as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    ),
    ''
  )::uuid
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema extensions to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

-- Supabase's DEFAULT privileges: every new object the migration-owning role
-- creates in `public` is automatically granted to anon/authenticated/
-- service_role. Each migration's `revoke all ... from anon, authenticated` has
-- to override exactly this, which is what the privilege audit verifies.
-- Applied FOR the role running this script (the same role runs the migrations),
-- so no machine-specific role name is assumed.
do $$
begin
  execute format(
    'alter default privileges for role %I in schema public '
    'grant all on tables to anon, authenticated, service_role',
    current_user
  );
  execute format(
    'alter default privileges for role %I in schema public '
    'grant all on sequences to anon, authenticated, service_role',
    current_user
  );
  execute format(
    'alter default privileges for role %I in schema public '
    'grant all on functions to anon, authenticated, service_role',
    current_user
  );
end
$$;
