-- Phase 12: adds public.profiles.preferred_currency. Nullable, no default --
-- existing rows are simply unset until the user picks one in Settings.
-- Mirrors user_beer_logs.currency's exact CHECK pattern (see
-- 20260915120600_create_user_beer_logs_table.sql) for consistency between
-- the two currency-shaped columns in the schema. This is a Settings
-- preference only -- it never rewrites or is derived from any existing
-- user_beer_logs.currency value, and Statistics' per-currency
-- amount-spent grouping is unaffected (see docs/DECISIONS.md).
--
-- No RLS or grant migration is needed: `grant select, update on table
-- public.profiles to authenticated` (20260914120000_create_profiles_table.sql)
-- is table-level with no column list, and both `select_own`/`update_own`
-- RLS policies are row-level (`auth.uid() = id`), so both already cover
-- this new column. `private.set_updated_at()` already fires on any update
-- to this table.

alter table public.profiles
  add column preferred_currency text;

alter table public.profiles
  add constraint profiles_preferred_currency_format check (
    preferred_currency is null or preferred_currency ~ '^[A-Z]{3}$'
  );
