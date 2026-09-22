# Beta catalog: owner runbook (R2 tooling)

**Status: tooling only.** This folder holds a *template* and a *runbook*. It contains **no real
brewery or beer**, none was invented, and nothing here has been applied to any database. The
catalog content for the beta is supplied and reviewed by the owner.

What this is **not**: an importer, a moderation/admin tool, a migration or the dev seed. There is
no admin identity in BeerApp; catalog maintenance during the beta is deliberate SQL run by the
owner with a privileged database role. (`beerapp_backend`, the API's role, can only read the
catalog and cannot write it.)

## Order of operations for a new (production) project

1. Apply all migrations (`docs/RELEASE.md`, "Production Supabase").
2. Apply `supabase/reference_data/countries.sql`, then `beer_styles_DRAFT.sql`, each only after
   the owner has reviewed it and deleted its DRAFT-GUARD block (see that folder's README).
3. Load owner-reviewed breweries and beers with a copy of `beta_catalog_template.sql` (below).

**Never** run `backend/scripts/seed_catalog.py` against production: it writes fabricated
`verified` rows and refuses non-local/dev environments by design.

## Loading breweries and beers

1. Copy `beta_catalog_template.sql` to a new file (for example `catalog_beta_001.sql`). Keep
   filled copies wherever you decide; committing real content is a deliberate owner choice.
2. Replace the two placeholder `insert ... values` blocks with your rows:
   - `country_iso` must already exist in `public.countries`; `style_name` must match a
     `public.beer_styles` name (any case) or be `null`.
   - Set `verified` to `true` **only** for rows you personally checked against a reliable
     source. Anything else stays `false`.
   - `barcode`: `null`, or an EAN-8 / GTIN-13 with a valid GS1 check digit. A 12-digit UPC-A
     is written with a leading `0`. This is the same canonical form the scanner and the API
     use; the database itself only enforces that a barcode is unique.
   - Latitude and longitude are set together or not at all. Leave beer coordinates alone: a beer
     without its own coordinates uses its brewery's.
   - No image URLs: add `image_url` later, and only for images you are licensed to use.
3. Delete the `TEMPLATE-GUARD` block **in your copy**.
4. Run it as a privileged role in one go, stopping at the first error, for example:

   ```
   psql "$PRIVILEGED_DATABASE_URL" -v ON_ERROR_STOP=1 -f catalog_beta_001.sql
   ```

   (`$PRIVILEGED_DATABASE_URL` is yours, held outside the repo. The file wraps everything in one
   transaction; validation runs first and aborts everything on the first problem.)
5. Check the result (read-only):

   ```sql
   select count(*) from public.breweries where source = 'owner-curated';
   select count(*) from public.beers where source = 'owner-curated';
   select official_name, barcode from public.beers
    where source = 'owner-curated' order by created_at desc limit 20;
   ```

Re-running a copy is safe: a brewery is "the same" when its name (any case) and country match, a
beer when its brewery and name match, and existing rows are **not** updated. To change an existing
row, correct it directly:

```sql
update public.beers set abv = 5.20 where id = '<beer id>';   -- one reviewed change at a time
```

## Reviewing user contributions during the beta

Contributions are private proposals in their own tables (`beer_contributions`,
`brewery_contributions`); they never change the catalog by themselves and the app has no approval
flow. Approving one is a manual, owner-run step. The database keeps a proposal's status
consistent with these constraints: `status` is `pending`, `approved` or `rejected`; a reviewed row
needs `reviewed_at`; an approved row needs its `resolved_*_id`.

```sql
-- What is waiting?
select id, official_name, proposed_brewery_name, brewery_id, barcode, created_at
  from public.beer_contributions where status = 'pending' order by created_at;
select id, name, proposed_country_name, country_id, city, created_at
  from public.brewery_contributions where status = 'pending' order by created_at;
```

Approve a beer (after you have verified it and its brewery exists in the catalog):

```sql
begin;
with new_beer as (
  insert into public.beers (official_name, brewery_id, style_id, abv, barcode, verified, source)
  values ('<name>', '<brewery id>', null, null, null, false, 'owner-curated')
  returning id
)
update public.beer_contributions c
   set status = 'approved', reviewed_at = now(), resolved_beer_id = new_beer.id,
       review_note = 'Approved by the owner.'
  from new_beer
 where c.id = '<contribution id>' and c.status = 'pending';
commit;
```

Reject one (works the same way for `brewery_contributions`):

```sql
update public.beer_contributions
   set status = 'rejected', reviewed_at = now(), review_note = '<short reason, max 500 chars>'
 where id = '<contribution id>' and status = 'pending';
```

Approving a brewery is the same idea: insert into `public.breweries`, then set
`status = 'approved'`, `reviewed_at = now()` and `resolved_brewery_id` on the contribution.

The snippets above are exercised against a disposable database by
`backend/tests/integration/test_catalog_beta_tooling.py`; still read each one before you run it
against a real project.

## Later

An import pipeline, an admin identity and a moderation UI are explicitly out of scope for this phase
(see `docs/DECISIONS.md`, Phase 13 and Phase 15). Revisit them only with beta evidence.
