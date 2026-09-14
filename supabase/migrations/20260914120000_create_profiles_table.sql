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

-- Case-sensitive-by-construction uniqueness: the application always
-- normalizes (trim + lowercase) before writing, so a plain unique index on
-- the stored value is sufficient and is the actual source of truth against
-- races — there is no separate check-then-insert anywhere in the app.
-- Partial (WHERE username IS NOT NULL) so multiple incomplete OAuth
-- profiles can coexist before each picks a username.
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

-- No insert policy: rows are created only by handle_new_user() below,
-- which runs as SECURITY DEFINER and therefore bypasses RLS.
-- No delete policy: account deletion is a later-phase, deliberate flow.

-- Empty search_path (not `set search_path = public`) per current Supabase
-- guidance for SECURITY DEFINER functions, so every referenced object must
-- be schema-qualified — this closes the search-path-hijacking risk a
-- non-empty path leaves open.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- username is intentionally omitted from the metadata lookup's NOT NULL
  -- assumption: the column is nullable, so this insert succeeds whether or
  -- not the signup provided a username (email signups pass it; Google
  -- signups don't, and are routed to /complete-profile by the app instead).
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    )
  );
  return new;
end;
$$;

-- Not meant to be called directly by any client role — only the trigger
-- (running as the table owner) invokes it.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
