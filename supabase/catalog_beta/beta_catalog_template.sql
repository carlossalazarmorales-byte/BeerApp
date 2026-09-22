-- =============================================================================
-- BeerApp beta catalog: breweries + beers                         *** TEMPLATE ***
-- =============================================================================
-- STATUS: an UNFILLED TEMPLATE. Every row below is a fake placeholder. It contains
--   no real brewery or beer, is not a migration, and is not applied to any database.
--   Real catalog content is supplied and reviewed by the OWNER, never invented here.
--
-- USE: follow supabase/catalog_beta/README.md. In short: copy this file, replace the
--   placeholder rows with owner-reviewed data, delete the TEMPLATE-GUARD block in
--   YOUR COPY, run it once as a privileged role in ONE transaction. Validation runs
--   first and aborts the whole transaction on the first problem; the inserts are
--   idempotent, so re-running a copy never duplicates rows.
--
-- WHAT IT WRITES: public.breweries and public.beers only, always with
--   source = 'owner-curated'. It never touches user data, contributions or Storage.
--   Beer coordinates, region, city and country are left NULL on purpose: the app falls
--   back to the brewery's. Images are not loaded here (add image_url later only for
--   images you are licensed to use).
-- =============================================================================

-- >>> TEMPLATE-GUARD-BEGIN (delete this block in YOUR COPY after replacing every placeholder)
do $$
begin
  raise exception 'beta_catalog_template.sql is an unfilled template';
end
$$;
-- <<< TEMPLATE-GUARD-END

begin;

create temporary table _beta_breweries (
  key text primary key,             -- your own short label; used only inside this file
  name text not null,
  country_iso text not null,        -- ISO 3166-1 alpha-2; must already exist in public.countries
  region text,
  city text,
  latitude numeric(9, 6),           -- set both or neither; decimal degrees
  longitude numeric(9, 6),
  website text,                     -- optional; must be https://...
  verified boolean not null default false  -- true only for rows you verified against a reliable source
) on commit drop;

create temporary table _beta_beers (
  brewery_key text not null,        -- a key from _beta_breweries above
  official_name text not null,
  style_name text,                  -- must match public.beer_styles.name (any case), or null
  abv numeric(4, 2),                -- percent, 0-100
  ibu integer,
  barcode text,                     -- EAN-8 or GTIN-13 with a valid check digit, or null.
                                    -- A 12-digit UPC-A must be written with a leading 0.
  verified boolean not null default false
) on commit drop;

-- ---- PLACEHOLDER ROWS: replace with your own reviewed data --------------------
-- 'AA' is not a real country code, so this template cannot load even if the guard
-- above is removed without editing the rows.
insert into _beta_breweries (key, name, country_iso, region, city, latitude, longitude, website)
values
  ('example-brewery', 'EXAMPLE BREWERY (placeholder, replace)', 'AA', null, null, null, null, null);

insert into _beta_beers (brewery_key, official_name, style_name, abv, ibu, barcode)
values
  ('example-brewery', 'EXAMPLE BEER (placeholder, replace)', null, null, null, null);
-- ---- end of placeholder rows ---------------------------------------------------

-- Validation: abort the whole transaction if anything is wrong.
do $$
declare
  problems text;
begin
  select concat_ws(
    E'\n',
    (select 'unknown brewery_key on beer: ' || string_agg(distinct e.brewery_key, ', ')
       from _beta_beers e
      where not exists (select 1 from _beta_breweries r where r.key = e.brewery_key)
     having count(*) > 0),
    (select 'unknown country_iso (apply countries.sql first): '
            || string_agg(distinct r.country_iso, ', ')
       from _beta_breweries r
      where not exists (select 1 from public.countries c where c.iso_code = r.country_iso)
     having count(*) > 0),
    (select 'unknown style_name (must match public.beer_styles): '
            || string_agg(distinct e.style_name, ', ')
       from _beta_beers e
      where e.style_name is not null
        and not exists (select 1 from public.beer_styles s where lower(s.name) = lower(e.style_name))
     having count(*) > 0),
    (select 'blank name: ' || count(*) from (
        select name from _beta_breweries where length(trim(name)) = 0
        union all
        select official_name from _beta_beers where length(trim(official_name)) = 0) b
     having count(*) > 0),
    (select 'latitude/longitude must be set together and in range: '
            || string_agg(r.key, ', ')
       from _beta_breweries r
      where (r.latitude is null) <> (r.longitude is null)
         or r.latitude not between -90 and 90
         or r.longitude not between -180 and 180
     having count(*) > 0),
    (select 'website must start with https://: ' || string_agg(r.key, ', ')
       from _beta_breweries r
      where r.website is not null and r.website !~ '^https://[^ ]+$'
     having count(*) > 0),
    (select 'abv must be between 0 and 100 and ibu >= 0: '
            || string_agg(e.official_name, ', ')
       from _beta_beers e
      where e.abv not between 0 and 100 or e.ibu < 0
     having count(*) > 0),
    -- Barcode: 8 or 13 ASCII digits and the GS1 mod-10 check digit (the same rule the API
    -- applies to scanned codes; the database itself only enforces uniqueness).
    (select 'barcode is not a valid EAN-8/GTIN-13: ' || string_agg(e.official_name, ', ')
       from _beta_beers e
      where e.barcode is not null
        -- CASE (not OR) so the digit casts only run on strings that already passed the pattern.
        and case
              when e.barcode ~ '^([0-9]{8}|[0-9]{13})$' then
                (10 - (
                  select sum(substr(reverse(e.barcode), i, 1)::integer
                             * case when i % 2 = 0 then 3 else 1 end)
                    from generate_series(2, length(e.barcode)) as i
                ) % 10) % 10 <> right(e.barcode, 1)::integer
              else true
            end
     having count(*) > 0),
    (select 'barcode repeated in this file: ' || string_agg(barcode, ', ') from (
        select barcode from _beta_beers where barcode is not null
        group by barcode having count(*) > 1) d
     having count(*) > 0),
    -- A barcode already owned by a DIFFERENT beer is a conflict; the same beer (a re-run) is fine.
    (select 'barcode already belongs to another beer: ' || string_agg(e.barcode, ', ')
       from _beta_beers e
       join public.beers x on x.barcode = e.barcode
      where not exists (
        select 1
          from _beta_breweries r
          join public.countries c on c.iso_code = r.country_iso
          join public.breweries b on lower(b.name) = lower(r.name) and b.country_id = c.id
         where r.key = e.brewery_key
           and x.brewery_id = b.id
           and lower(x.official_name) = lower(e.official_name))
     having count(*) > 0)
  ) into problems;

  if problems <> '' then
    raise exception E'catalog validation failed:\n%', problems;
  end if;
end
$$;

-- Breweries: no natural unique key exists (names repeat), so a brewery is "the same" when
-- name (any case) and country match. Existing breweries are left untouched.
insert into public.breweries
  (name, country_id, region, city, latitude, longitude, website, verified, source)
select r.name, c.id, r.region, r.city, r.latitude, r.longitude, r.website, r.verified, 'owner-curated'
from _beta_breweries r
join public.countries c on c.iso_code = r.country_iso
where not exists (
  select 1 from public.breweries b
   where lower(b.name) = lower(r.name) and b.country_id = c.id
);

-- Beers: "the same" = same brewery and name (any case). Existing beers are left untouched.
insert into public.beers (official_name, brewery_id, style_id, abv, ibu, barcode, verified, source)
select e.official_name, b.id, s.id, e.abv, e.ibu, e.barcode, e.verified, 'owner-curated'
from _beta_beers e
join _beta_breweries r on r.key = e.brewery_key
join public.countries c on c.iso_code = r.country_iso
join public.breweries b on lower(b.name) = lower(r.name) and b.country_id = c.id
left join public.beer_styles s on lower(s.name) = lower(e.style_name)
where not exists (
  select 1 from public.beers x
   where x.brewery_id = b.id and lower(x.official_name) = lower(e.official_name)
);

commit;
