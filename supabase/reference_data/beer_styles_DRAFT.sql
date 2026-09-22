-- =============================================================================
-- BeerApp reference data: beer styles               *** CLAUDE-CREATED DRAFT ***
-- =============================================================================
-- STATUS: a PROPOSAL written by the assistant. It has NOT been reviewed or approved
--   by the owner, is NOT production data, and is NOT applied to any database.
--   Not a migration. Not the dev seed. It becomes production data only after the
--   owner has reviewed every row (names, categories, origins, ABV ranges) and
--   deleted the DRAFT-GUARD block below.
--
-- WHAT IT CONTAINS
--   * 55 generic style names in 11 categories (Ale, Belgian, IPA, Lager, Low & No Alcohol, Pale Ale, Sour & Wild, Specialty, Stout & Porter, Strong Ale, Wheat Beer).
--   * origin: an ISO 3166-1 alpha-2 code where a style is conventionally tied to one
--     country, otherwise null. Countries must already exist (apply countries.sql first).
--   * typical ABV range: broad, APPROXIMATE, unverified ranges in percent. They are a
--     starting point for the owner, not a claim of accuracy.
--   * description is left NULL on purpose: no style-guide text is copied or paraphrased.
--     Existing descriptions are never overwritten by this file.
--
-- Idempotent: ON CONFLICT ((lower(name))) updates category, origin and ABV range only.
-- Run it as ONE transaction with a privileged role (see the runbook).
-- =============================================================================

-- >>> DRAFT-GUARD-BEGIN (owner: delete this block after reviewing every row)
do $$
begin
  raise exception 'beer_styles_DRAFT.sql is an unreviewed assistant draft';
end
$$;
-- <<< DRAFT-GUARD-END

begin;

create temporary table _ref_beer_styles (
  name text not null,
  category text not null,
  origin_iso text,
  abv_min numeric(4, 2) not null,
  abv_max numeric(4, 2) not null
) on commit drop;

insert into _ref_beer_styles (name, category, origin_iso, abv_min, abv_max)
values
  ('Light Lager', 'Lager', null, 2.80, 4.20),
  ('Pale Lager', 'Lager', null, 4.00, 5.50),
  ('Pilsner', 'Lager', 'CZ', 4.20, 5.80),
  ('Helles', 'Lager', 'DE', 4.50, 5.50),
  ('Dortmunder Export', 'Lager', 'DE', 5.00, 6.00),
  ('Vienna Lager', 'Lager', 'AT', 4.50, 5.50),
  ('Amber Lager', 'Lager', null, 4.50, 6.00),
  ('Märzen', 'Lager', 'DE', 5.20, 6.20),
  ('Dunkel', 'Lager', 'DE', 4.50, 5.60),
  ('Schwarzbier', 'Lager', 'DE', 4.40, 5.40),
  ('Rauchbier', 'Lager', 'DE', 4.80, 6.00),
  ('Bock', 'Lager', 'DE', 6.00, 7.50),
  ('Doppelbock', 'Lager', 'DE', 7.00, 10.00),
  ('Pale Ale', 'Pale Ale', 'GB', 4.50, 6.20),
  ('English Bitter', 'Pale Ale', 'GB', 3.00, 5.80),
  ('Amber Ale', 'Pale Ale', 'US', 4.50, 6.20),
  ('India Pale Ale', 'IPA', 'GB', 5.00, 7.50),
  ('Session IPA', 'IPA', null, 3.00, 5.00),
  ('New England IPA', 'IPA', 'US', 6.00, 9.00),
  ('Double IPA', 'IPA', 'US', 7.50, 10.00),
  ('Blonde Ale', 'Ale', null, 4.00, 6.00),
  ('Cream Ale', 'Ale', 'US', 4.20, 5.60),
  ('Kölsch', 'Ale', 'DE', 4.40, 5.20),
  ('Altbier', 'Ale', 'DE', 4.50, 5.20),
  ('Brown Ale', 'Ale', 'GB', 4.00, 6.50),
  ('Irish Red Ale', 'Ale', 'IE', 3.80, 5.00),
  ('Scotch Ale', 'Ale', 'GB', 6.00, 10.00),
  ('Barleywine', 'Strong Ale', 'GB', 8.00, 12.00),
  ('Saison', 'Belgian', 'BE', 4.50, 8.50),
  ('Belgian Blonde', 'Belgian', 'BE', 6.00, 7.50),
  ('Belgian Dubbel', 'Belgian', 'BE', 6.00, 7.60),
  ('Belgian Tripel', 'Belgian', 'BE', 7.50, 9.50),
  ('Belgian Quadrupel', 'Belgian', 'BE', 8.00, 12.00),
  ('Witbier', 'Wheat Beer', 'BE', 4.50, 5.50),
  ('Hefeweizen', 'Wheat Beer', 'DE', 4.30, 5.60),
  ('Dunkelweizen', 'Wheat Beer', 'DE', 4.30, 5.60),
  ('Weizenbock', 'Wheat Beer', 'DE', 6.50, 8.50),
  ('American Wheat Beer', 'Wheat Beer', 'US', 4.00, 5.50),
  ('Berliner Weisse', 'Sour & Wild', 'DE', 2.80, 3.80),
  ('Gose', 'Sour & Wild', 'DE', 4.20, 4.80),
  ('Lambic', 'Sour & Wild', 'BE', 5.00, 6.50),
  ('Gueuze', 'Sour & Wild', 'BE', 5.00, 8.00),
  ('Flanders Red Ale', 'Sour & Wild', 'BE', 4.60, 6.50),
  ('Oud Bruin', 'Sour & Wild', 'BE', 4.00, 8.00),
  ('Sour Ale', 'Sour & Wild', null, 3.00, 8.00),
  ('Porter', 'Stout & Porter', 'GB', 4.00, 6.50),
  ('Baltic Porter', 'Stout & Porter', null, 6.50, 9.50),
  ('Dry Stout', 'Stout & Porter', 'IE', 3.80, 5.00),
  ('Milk Stout', 'Stout & Porter', 'GB', 3.00, 6.00),
  ('Oatmeal Stout', 'Stout & Porter', 'GB', 4.20, 5.90),
  ('Imperial Stout', 'Stout & Porter', 'GB', 8.00, 12.00),
  ('Fruit Beer', 'Specialty', null, 2.50, 8.00),
  ('Spiced Beer', 'Specialty', null, 3.00, 9.00),
  ('Radler', 'Specialty', 'DE', 2.00, 3.50),
  ('Non-Alcoholic Beer', 'Low & No Alcohol', null, 0.00, 0.50)
;

-- Every named origin country must already exist.
do $$
declare
  missing text;
begin
  select string_agg(r.origin_iso, ', ' order by r.origin_iso) into missing
  from (select distinct origin_iso from _ref_beer_styles where origin_iso is not null) r
  where not exists (select 1 from public.countries c where c.iso_code = r.origin_iso);
  if missing is not null then
    raise exception 'apply countries.sql first; unknown origin country code(s): %', missing;
  end if;
end
$$;

insert into public.beer_styles
  (name, category, origin_country_id, typical_abv_min, typical_abv_max)
select r.name, r.category,
       (select c.id from public.countries c where c.iso_code = r.origin_iso),
       r.abv_min, r.abv_max
from _ref_beer_styles r
on conflict ((lower(name))) do update
  set category = excluded.category,
      origin_country_id = excluded.origin_country_id,
      typical_abv_min = excluded.typical_abv_min,
      typical_abv_max = excluded.typical_abv_max
  where (public.beer_styles.category, public.beer_styles.origin_country_id,
         public.beer_styles.typical_abv_min, public.beer_styles.typical_abv_max)
        is distinct from (excluded.category, excluded.origin_country_id,
                          excluded.typical_abv_min, excluded.typical_abv_max);

-- Sanity check inside the transaction: every row above must now exist as written.
do $$
declare
  expected constant integer := 55;
  matching integer;
begin
  select count(*) into matching
  from _ref_beer_styles r
  join public.beer_styles s on lower(s.name) = lower(r.name)
  where s.category = r.category
    and s.typical_abv_min = r.abv_min
    and s.typical_abv_max = r.abv_max
    and s.origin_country_id is not distinct from
        (select c.id from public.countries c where c.iso_code = r.origin_iso);
  if matching <> expected then
    raise exception 'expected % styles to match this file, found %', expected, matching;
  end if;
end
$$;

commit;
