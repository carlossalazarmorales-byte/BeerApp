# Production reference data (R1): owner runbook

**Status: DRAFT. Nothing in this folder has been reviewed by the owner or applied to any database.**

| File | What it is | Provenance | State |
|---|---|---|---|
| `countries.sql` | 249 country/territory rows: `iso_code`, English `name`, `continent` | 249 codes **exposed by OpenJDK 21.0.6**, with CLDR 42 names and UN-M49-derived continent mapping (see the file header). **Not verified against the ISO 3166 Maintenance Agency** -- OpenJDK/CLDR are documented, reproducible sources, not the ISO issuing authority, so this is not called an ISO-authoritative list | prepared from factual sources, **not owner-reviewed** |
| `countries_review.md` | the decisions the owner must make about it (territories, transcontinental countries, names) and a full listing | generated with the file | for the owner |
| `beer_styles_DRAFT.sql` | 55 generic beer styles: name, category, optional origin country, approximate ABV range | **written by the assistant** (a proposal, not a dataset from an authority); no descriptions, no copied style-guide text | **Claude-created draft, not reviewed, not production-approved** |

These are **not migrations** (migration history is immutable and dev already holds seed rows) and
they are **not the dev seed**. `backend/scripts/seed_catalog.py` must never touch production; it
refuses to. Each file refuses to run until the owner deletes its `DRAFT-GUARD` block, so a file
cannot be applied by accident. Nothing applies these files automatically: not the API, not
`supabase db push`, not a test against anything but a disposable local database.

## Review, then apply (owner)

1. Read `countries_review.md` and decide each item. Edit `countries.sql` (delete rows, change a
   name or continent) as needed. Confirm the ISO list against a source you trust.
2. Read `beer_styles_DRAFT.sql` row by row. The names, categories, origin countries and ABV ranges
   are a starting point only; correct, add or remove rows. If you want a different file name, rename
   it once you have approved it.
3. Delete the `DRAFT-GUARD-BEGIN ... DRAFT-GUARD-END` block from each file you approve.
4. Apply **countries first, then styles**, on the target project, as a privileged role, one file
   per invocation, stopping at the first error:

   ```
   psql "$PRIVILEGED_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/reference_data/countries.sql
   psql "$PRIVILEGED_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/reference_data/beer_styles_DRAFT.sql
   ```

   (`$PRIVILEGED_DATABASE_URL` is yours, kept outside the repository. The Supabase SQL editor
   also works: paste one file at a time.) Each file runs in one transaction and ends with an
   in-transaction check that every row is present exactly as written; a failed check aborts and
   changes nothing.
5. Verify (read-only):

   ```sql
   select count(*) from public.countries;                       -- 249 unless you removed rows
   select continent, count(*) from public.countries group by 1 order by 1;
   select count(*) from public.beer_styles;                     -- 55 unless you edited the file
   select name, category from public.beer_styles order by category, name;
   ```

## Behaviour worth knowing

- **Idempotent.** Re-running updates `name`/`continent` (countries) or `category`, origin and ABV range
  (styles) where they differ; identical rows are not rewritten. Style `description` is never
  written or overwritten.
- **Rows are matched by natural key:** `iso_code` for countries, case-insensitive `name` for styles
  (the tables' unique indexes). A row already present under the same key is updated in place, so
  loading this over the dev database would alter the dev rows with the same keys; it is meant for
  a new project.
- **Catalog rows that reference a country are unaffected by a rename**: they point at the row id,
  not the name.
- **Forward-fix, not rollback.** To undo a bad load, correct the values with an `update` (or delete
  unreferenced rows). Countries and styles referenced by breweries, beers or contributions cannot be
  deleted (foreign keys are `RESTRICT`).

## Tests

`backend/tests/test_reference_data_files.py` (offline) checks the file shape, the guard and the data.
`backend/tests/integration/test_reference_data.py` applies the files, with the guard and the
transaction wrapper removed, to the **disposable** integration database only: it proves they apply,
are idempotent, satisfy every constraint and never overwrite a description. See `docs/DATABASE.md`.
