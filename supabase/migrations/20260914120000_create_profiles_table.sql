-- Phase 2: minimal public.profiles table, 1:1 with auth.users.
-- See docs/DATABASE.md and the Phase 2 plan for the full rationale.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  -- Nullable: non-null immediately for email signups (username supplied at
  -- signup), null for Google signups until /complete-profile is completed.
  -- Never invent a placeholder value here or in application code.
  username text,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (
    username is null or username ~ '^[a-z0-9_]{3,20}$'
  )
);

-- The application always normalizes (trim + lowercase) before writing, so a
-- plain unique index on the stored value is sufficient and is the actual
-- source of truth against races: there is no separate check-then-insert
-- anywhere in the app. Partial (WHERE username IS NOT NULL) so multiple
-- incomplete OAuth profiles can coexist before each picks a username.
create unique index profiles_username_unique_idx
  on public.profiles (username)
  where username is not null;

alter table public.profiles enable row level security;

create policy select_own on public.profiles
  for select
  using (auth.uid() = id);

create policy update_own on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- No insert policy: rows are created only by private.handle_new_user()
-- below, which runs as SECURITY DEFINER and therefore bypasses RLS.
-- No delete policy: account deletion is a later-phase, deliberate flow.

-- RLS above restricts *rows*, not table-level access -- current Supabase
-- projects no longer auto-grant Data API roles access to new public
-- tables, so that access must be explicit here too. Minimal and
-- deterministic: anon gets nothing; authenticated gets exactly
-- SELECT + UPDATE (RLS still confines both to the caller's own row); no
-- INSERT/DELETE for anyone at the table-privilege level either.
revoke all on table public.profiles from anon, authenticated;

grant select, update
  on table public.profiles
  to authenticated;

-- Trigger helpers live outside public (and outside any schema Supabase's
-- Data API exposes) since neither needs to be remotely callable -- only
-- the two triggers below ever invoke them. Nothing is granted to
-- anon/authenticated on this schema; a new schema starts with no privileges
-- granted to PUBLIC by default, so this is explicit belt-and-suspenders
-- rather than compensating for a real default-privilege gap.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Empty search_path (not `set search_path = public`) per current Supabase
-- guidance for SECURITY DEFINER functions, so every referenced object must
-- be schema-qualified. This closes the search-path-hijacking risk a
-- non-empty path leaves open. handle_new_user() genuinely needs elevated
-- privilege here: it inserts into public.profiles on behalf of a new
-- auth.users row, which the new user has no RLS-granted insert right to do
-- themselves (by design -- see "No insert policy" above).
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_username text;
  display_name_value text;
  conflicting_constraint text;
begin
  -- Normalize the same way the application does (trim + lowercase) before
  -- ever considering the value. Email signups supply a real username in
  -- this metadata; OAuth (Google) signups don't, and may also send
  -- garbage/absent values -- neither case may abort account creation.
  normalized_username := nullif(
    trim(both from lower(new.raw_user_meta_data ->> 'username')),
    ''
  );

  -- If what's left doesn't satisfy the same pattern as the table's CHECK
  -- constraint, drop it to NULL rather than let the constraint reject the
  -- whole insert (which would also fail the auth.users insert in the same
  -- transaction, breaking signup entirely). A NULL username routes the
  -- user through /complete-profile in the app -- never an invented value.
  if normalized_username is not null
    and normalized_username !~ '^[a-z0-9_]{3,20}$' then
    normalized_username := null;
  end if;

  display_name_value := coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name'
  );

  -- Attempt-and-catch rather than pre-check-then-insert: a pre-check has a
  -- race (two signups normalizing to the same username can both pass a
  -- SELECT check before either INSERTs). The unique index is the actual,
  -- atomic source of truth; this just recovers from it losing gracefully.
  begin
    insert into public.profiles (id, username, display_name)
    values (new.id, normalized_username, display_name_value);
  exception
    when unique_violation then
      get stacked diagnostics conflicting_constraint = constraint_name;

      -- Only recover from the username collision by falling back to NULL.
      -- Any other unique violation here (e.g. a duplicate id, which would
      -- mean a real bug -- auth.users.id should never repeat) must still
      -- abort loudly rather than be silently swallowed.
      if conflicting_constraint <> 'profiles_username_unique_idx' then
        raise;
      end if;

      -- Never touches the existing profile that holds this username, and
      -- never invents a replacement -- the new user is simply left without
      -- one and routed through /complete-profile by the app's router.
      insert into public.profiles (id, username, display_name)
      values (new.id, null, display_name_value);
  end;

  return new;
end;
$$;

-- Not meant to be called directly by any client role: only the trigger
-- (running as the table owner) invokes it, and its elevated privilege
-- makes an explicit revoke worth the extra line even though Postgres
-- already refuses to invoke a trigger function outside trigger context.
revoke execute on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Deliberately NOT SECURITY DEFINER: this only ever assigns NEW.updated_at,
-- which requires no privilege beyond what the invoking role (the user
-- updating their own row, permitted by the update_own RLS policy above)
-- already has. No EXECUTE revoke either -- there is no elevated privilege
-- to protect here, and Postgres refuses to call any trigger function
-- outside trigger context regardless of grants, so a revoke would add
-- ceremony without adding safety. Still moved into `private` alongside
-- handle_new_user() since it's equally an internal-only trigger helper
-- with no reason to be reachable through the Data API.
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();
