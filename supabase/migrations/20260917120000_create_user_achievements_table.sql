-- Phase 10: persisted achievement unlocks. Progress itself is always derived
-- live from user_beer_logs/user_beer_collection (see docs/DECISIONS.md,
-- same philosophy as Phase 9 Statistics) -- the only thing that needs to
-- survive later data changes is the moment a condition was first satisfied,
-- because unlocks are permanent by product decision and must never be lost
-- or rewritten once recorded.
create table public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  -- Not a FK / not an enum: the achievement catalog is code
  -- (app/services/achievement_catalog.py, see docs/DECISIONS.md), so this
  -- column is validated against ACHIEVEMENT_CATALOG in application code
  -- only. Adding a new achievement therefore never requires a migration. A
  -- persisted row whose key no longer exists in the current catalog (a
  -- retired achievement) is simply ignored by the application, not an
  -- integrity error.
  achievement_key text not null,
  unlocked_at timestamptz not null default now(),
  constraint user_achievements_user_key_unique unique (user_id, achievement_key)
  -- No created_at/updated_at, no set_updated_at trigger: rows are
  -- write-once and permanent by design (see docs/DECISIONS.md) -- there is
  -- nothing here that is ever updated.
);

-- unique(user_id, achievement_key)'s backing index already serves both the
-- ON CONFLICT DO NOTHING target and "list my achievements" (WHERE user_id
-- = $1) -- the catalog is a couple dozen rows per user at most, no
-- additional index is justified.

alter table public.user_achievements enable row level security;
revoke all on table public.user_achievements from anon, authenticated;
