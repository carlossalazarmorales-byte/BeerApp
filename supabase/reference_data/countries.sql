-- =============================================================================
-- BeerApp reference data: countries                                  *** DRAFT ***
-- =============================================================================
-- STATUS: prepared, NOT reviewed by the owner, NOT applied to any database.
--   Not a migration. Not the dev seed. Apply only with the runbook in
--   supabase/reference_data/README.md, after the owner has worked through
--   supabase/reference_data/countries_review.md and deleted the DRAFT-GUARD
--   block below.
--
-- PROVENANCE (factual sources, no hand-typed rows -- NOT verified against the
-- ISO 3166 Maintenance Agency; OpenJDK and Unicode CLDR are not themselves the
-- ISO 3166 issuing authority, so this is NOT claimed to be an ISO-authoritative
-- list, only a documented, reproducible source):
--   * Code set: 249 country/territory codes EXPOSED BY OpenJDK 21.0.6
--     (java.util.Locale.getISOCountries(IsoCountryCode.PART1_ALPHA2)), which
--     OpenJDK itself derives from ISO 3166-1 alpha-2 but is not the standard's
--     issuing authority. Reserved / exceptional / user-assigned codes (AC, CP,
--     DG, EA, EU, EZ, IC, QO, TA, UN, XA, XB, XK, ZZ) are NOT included.
--   * name: English territory name from Unicode CLDR 42 (Babel 2.11.0).
--     These are CLDR display names, not necessarily ISO's official short names.
--   * continent: Unicode CLDR release-42 territoryContainment (UN M49 hierarchy):
--       002 -> Africa, 142 -> Asia, 150 -> Europe, 009 -> Oceania, 005 -> South America,
--       021 + 013 + 029 (Northern America, Central America, Caribbean) -> North America,
--       AQ -> Antarctica (rule; Antarctica is in no M49 continent group).
--     The table allows exactly seven continent values, so M49's 'Americas' is split as above.
--
-- Rows: 249, sorted by iso_code. Idempotent: ON CONFLICT (iso_code) updates
-- name/continent only. Column contract: public.countries(iso_code ^[A-Z]{2}$ unique,
-- lower(name) unique, continent in the 7 allowed values). No coordinates are stored.
-- Run it as ONE transaction with a privileged role (see the runbook).
-- =============================================================================

-- >>> DRAFT-GUARD-BEGIN (owner: delete this block after reviewing countries_review.md)
do $$
begin
  raise exception 'countries.sql is a DRAFT that has not been reviewed by the owner';
end
$$;
-- <<< DRAFT-GUARD-END

begin;

create temporary table _ref_countries (
  iso_code text not null,
  name text not null,
  continent text not null
) on commit drop;

insert into _ref_countries (iso_code, name, continent)
values
  ('AD', 'Andorra', 'Europe'),
  ('AE', 'United Arab Emirates', 'Asia'),
  ('AF', 'Afghanistan', 'Asia'),
  ('AG', 'Antigua & Barbuda', 'North America'),
  ('AI', 'Anguilla', 'North America'),
  ('AL', 'Albania', 'Europe'),
  ('AM', 'Armenia', 'Asia'),
  ('AO', 'Angola', 'Africa'),
  ('AQ', 'Antarctica', 'Antarctica'),
  ('AR', 'Argentina', 'South America'),
  ('AS', 'American Samoa', 'Oceania'),
  ('AT', 'Austria', 'Europe'),
  ('AU', 'Australia', 'Oceania'),
  ('AW', 'Aruba', 'North America'),
  ('AX', 'Åland Islands', 'Europe'),
  ('AZ', 'Azerbaijan', 'Asia'),
  ('BA', 'Bosnia & Herzegovina', 'Europe'),
  ('BB', 'Barbados', 'North America'),
  ('BD', 'Bangladesh', 'Asia'),
  ('BE', 'Belgium', 'Europe'),
  ('BF', 'Burkina Faso', 'Africa'),
  ('BG', 'Bulgaria', 'Europe'),
  ('BH', 'Bahrain', 'Asia'),
  ('BI', 'Burundi', 'Africa'),
  ('BJ', 'Benin', 'Africa'),
  ('BL', 'St. Barthélemy', 'North America'),
  ('BM', 'Bermuda', 'North America'),
  ('BN', 'Brunei', 'Asia'),
  ('BO', 'Bolivia', 'South America'),
  ('BQ', 'Caribbean Netherlands', 'North America'),
  ('BR', 'Brazil', 'South America'),
  ('BS', 'Bahamas', 'North America'),
  ('BT', 'Bhutan', 'Asia'),
  ('BV', 'Bouvet Island', 'South America'),
  ('BW', 'Botswana', 'Africa'),
  ('BY', 'Belarus', 'Europe'),
  ('BZ', 'Belize', 'North America'),
  ('CA', 'Canada', 'North America'),
  ('CC', 'Cocos (Keeling) Islands', 'Oceania'),
  ('CD', 'Congo - Kinshasa', 'Africa'),
  ('CF', 'Central African Republic', 'Africa'),
  ('CG', 'Congo - Brazzaville', 'Africa'),
  ('CH', 'Switzerland', 'Europe'),
  ('CI', 'Côte d’Ivoire', 'Africa'),
  ('CK', 'Cook Islands', 'Oceania'),
  ('CL', 'Chile', 'South America'),
  ('CM', 'Cameroon', 'Africa'),
  ('CN', 'China', 'Asia'),
  ('CO', 'Colombia', 'South America'),
  ('CR', 'Costa Rica', 'North America'),
  ('CU', 'Cuba', 'North America'),
  ('CV', 'Cape Verde', 'Africa'),
  ('CW', 'Curaçao', 'North America'),
  ('CX', 'Christmas Island', 'Oceania'),
  ('CY', 'Cyprus', 'Asia'),
  ('CZ', 'Czechia', 'Europe'),
  ('DE', 'Germany', 'Europe'),
  ('DJ', 'Djibouti', 'Africa'),
  ('DK', 'Denmark', 'Europe'),
  ('DM', 'Dominica', 'North America'),
  ('DO', 'Dominican Republic', 'North America'),
  ('DZ', 'Algeria', 'Africa'),
  ('EC', 'Ecuador', 'South America'),
  ('EE', 'Estonia', 'Europe'),
  ('EG', 'Egypt', 'Africa'),
  ('EH', 'Western Sahara', 'Africa'),
  ('ER', 'Eritrea', 'Africa'),
  ('ES', 'Spain', 'Europe'),
  ('ET', 'Ethiopia', 'Africa'),
  ('FI', 'Finland', 'Europe'),
  ('FJ', 'Fiji', 'Oceania'),
  ('FK', 'Falkland Islands', 'South America'),
  ('FM', 'Micronesia', 'Oceania'),
  ('FO', 'Faroe Islands', 'Europe'),
  ('FR', 'France', 'Europe'),
  ('GA', 'Gabon', 'Africa'),
  ('GB', 'United Kingdom', 'Europe'),
  ('GD', 'Grenada', 'North America'),
  ('GE', 'Georgia', 'Asia'),
  ('GF', 'French Guiana', 'South America'),
  ('GG', 'Guernsey', 'Europe'),
  ('GH', 'Ghana', 'Africa'),
  ('GI', 'Gibraltar', 'Europe'),
  ('GL', 'Greenland', 'North America'),
  ('GM', 'Gambia', 'Africa'),
  ('GN', 'Guinea', 'Africa'),
  ('GP', 'Guadeloupe', 'North America'),
  ('GQ', 'Equatorial Guinea', 'Africa'),
  ('GR', 'Greece', 'Europe'),
  ('GS', 'South Georgia & South Sandwich Islands', 'South America'),
  ('GT', 'Guatemala', 'North America'),
  ('GU', 'Guam', 'Oceania'),
  ('GW', 'Guinea-Bissau', 'Africa'),
  ('GY', 'Guyana', 'South America'),
  ('HK', 'Hong Kong SAR China', 'Asia'),
  ('HM', 'Heard & McDonald Islands', 'Oceania'),
  ('HN', 'Honduras', 'North America'),
  ('HR', 'Croatia', 'Europe'),
  ('HT', 'Haiti', 'North America'),
  ('HU', 'Hungary', 'Europe'),
  ('ID', 'Indonesia', 'Asia'),
  ('IE', 'Ireland', 'Europe'),
  ('IL', 'Israel', 'Asia'),
  ('IM', 'Isle of Man', 'Europe'),
  ('IN', 'India', 'Asia'),
  ('IO', 'British Indian Ocean Territory', 'Africa'),
  ('IQ', 'Iraq', 'Asia'),
  ('IR', 'Iran', 'Asia'),
  ('IS', 'Iceland', 'Europe'),
  ('IT', 'Italy', 'Europe'),
  ('JE', 'Jersey', 'Europe'),
  ('JM', 'Jamaica', 'North America'),
  ('JO', 'Jordan', 'Asia'),
  ('JP', 'Japan', 'Asia'),
  ('KE', 'Kenya', 'Africa'),
  ('KG', 'Kyrgyzstan', 'Asia'),
  ('KH', 'Cambodia', 'Asia'),
  ('KI', 'Kiribati', 'Oceania'),
  ('KM', 'Comoros', 'Africa'),
  ('KN', 'St. Kitts & Nevis', 'North America'),
  ('KP', 'North Korea', 'Asia'),
  ('KR', 'South Korea', 'Asia'),
  ('KW', 'Kuwait', 'Asia'),
  ('KY', 'Cayman Islands', 'North America'),
  ('KZ', 'Kazakhstan', 'Asia'),
  ('LA', 'Laos', 'Asia'),
  ('LB', 'Lebanon', 'Asia'),
  ('LC', 'St. Lucia', 'North America'),
  ('LI', 'Liechtenstein', 'Europe'),
  ('LK', 'Sri Lanka', 'Asia'),
  ('LR', 'Liberia', 'Africa'),
  ('LS', 'Lesotho', 'Africa'),
  ('LT', 'Lithuania', 'Europe'),
  ('LU', 'Luxembourg', 'Europe'),
  ('LV', 'Latvia', 'Europe'),
  ('LY', 'Libya', 'Africa'),
  ('MA', 'Morocco', 'Africa'),
  ('MC', 'Monaco', 'Europe'),
  ('MD', 'Moldova', 'Europe'),
  ('ME', 'Montenegro', 'Europe'),
  ('MF', 'St. Martin', 'North America'),
  ('MG', 'Madagascar', 'Africa'),
  ('MH', 'Marshall Islands', 'Oceania'),
  ('MK', 'North Macedonia', 'Europe'),
  ('ML', 'Mali', 'Africa'),
  ('MM', 'Myanmar (Burma)', 'Asia'),
  ('MN', 'Mongolia', 'Asia'),
  ('MO', 'Macao SAR China', 'Asia'),
  ('MP', 'Northern Mariana Islands', 'Oceania'),
  ('MQ', 'Martinique', 'North America'),
  ('MR', 'Mauritania', 'Africa'),
  ('MS', 'Montserrat', 'North America'),
  ('MT', 'Malta', 'Europe'),
  ('MU', 'Mauritius', 'Africa'),
  ('MV', 'Maldives', 'Asia'),
  ('MW', 'Malawi', 'Africa'),
  ('MX', 'Mexico', 'North America'),
  ('MY', 'Malaysia', 'Asia'),
  ('MZ', 'Mozambique', 'Africa'),
  ('NA', 'Namibia', 'Africa'),
  ('NC', 'New Caledonia', 'Oceania'),
  ('NE', 'Niger', 'Africa'),
  ('NF', 'Norfolk Island', 'Oceania'),
  ('NG', 'Nigeria', 'Africa'),
  ('NI', 'Nicaragua', 'North America'),
  ('NL', 'Netherlands', 'Europe'),
  ('NO', 'Norway', 'Europe'),
  ('NP', 'Nepal', 'Asia'),
  ('NR', 'Nauru', 'Oceania'),
  ('NU', 'Niue', 'Oceania'),
  ('NZ', 'New Zealand', 'Oceania'),
  ('OM', 'Oman', 'Asia'),
  ('PA', 'Panama', 'North America'),
  ('PE', 'Peru', 'South America'),
  ('PF', 'French Polynesia', 'Oceania'),
  ('PG', 'Papua New Guinea', 'Oceania'),
  ('PH', 'Philippines', 'Asia'),
  ('PK', 'Pakistan', 'Asia'),
  ('PL', 'Poland', 'Europe'),
  ('PM', 'St. Pierre & Miquelon', 'North America'),
  ('PN', 'Pitcairn Islands', 'Oceania'),
  ('PR', 'Puerto Rico', 'North America'),
  ('PS', 'Palestinian Territories', 'Asia'),
  ('PT', 'Portugal', 'Europe'),
  ('PW', 'Palau', 'Oceania'),
  ('PY', 'Paraguay', 'South America'),
  ('QA', 'Qatar', 'Asia'),
  ('RE', 'Réunion', 'Africa'),
  ('RO', 'Romania', 'Europe'),
  ('RS', 'Serbia', 'Europe'),
  ('RU', 'Russia', 'Europe'),
  ('RW', 'Rwanda', 'Africa'),
  ('SA', 'Saudi Arabia', 'Asia'),
  ('SB', 'Solomon Islands', 'Oceania'),
  ('SC', 'Seychelles', 'Africa'),
  ('SD', 'Sudan', 'Africa'),
  ('SE', 'Sweden', 'Europe'),
  ('SG', 'Singapore', 'Asia'),
  ('SH', 'St. Helena', 'Africa'),
  ('SI', 'Slovenia', 'Europe'),
  ('SJ', 'Svalbard & Jan Mayen', 'Europe'),
  ('SK', 'Slovakia', 'Europe'),
  ('SL', 'Sierra Leone', 'Africa'),
  ('SM', 'San Marino', 'Europe'),
  ('SN', 'Senegal', 'Africa'),
  ('SO', 'Somalia', 'Africa'),
  ('SR', 'Suriname', 'South America'),
  ('SS', 'South Sudan', 'Africa'),
  ('ST', 'São Tomé & Príncipe', 'Africa'),
  ('SV', 'El Salvador', 'North America'),
  ('SX', 'Sint Maarten', 'North America'),
  ('SY', 'Syria', 'Asia'),
  ('SZ', 'Eswatini', 'Africa'),
  ('TC', 'Turks & Caicos Islands', 'North America'),
  ('TD', 'Chad', 'Africa'),
  ('TF', 'French Southern Territories', 'Africa'),
  ('TG', 'Togo', 'Africa'),
  ('TH', 'Thailand', 'Asia'),
  ('TJ', 'Tajikistan', 'Asia'),
  ('TK', 'Tokelau', 'Oceania'),
  ('TL', 'Timor-Leste', 'Asia'),
  ('TM', 'Turkmenistan', 'Asia'),
  ('TN', 'Tunisia', 'Africa'),
  ('TO', 'Tonga', 'Oceania'),
  ('TR', 'Turkey', 'Asia'),
  ('TT', 'Trinidad & Tobago', 'North America'),
  ('TV', 'Tuvalu', 'Oceania'),
  ('TW', 'Taiwan', 'Asia'),
  ('TZ', 'Tanzania', 'Africa'),
  ('UA', 'Ukraine', 'Europe'),
  ('UG', 'Uganda', 'Africa'),
  ('UM', 'U.S. Outlying Islands', 'Oceania'),
  ('US', 'United States', 'North America'),
  ('UY', 'Uruguay', 'South America'),
  ('UZ', 'Uzbekistan', 'Asia'),
  ('VA', 'Vatican City', 'Europe'),
  ('VC', 'St. Vincent & Grenadines', 'North America'),
  ('VE', 'Venezuela', 'South America'),
  ('VG', 'British Virgin Islands', 'North America'),
  ('VI', 'U.S. Virgin Islands', 'North America'),
  ('VN', 'Vietnam', 'Asia'),
  ('VU', 'Vanuatu', 'Oceania'),
  ('WF', 'Wallis & Futuna', 'Oceania'),
  ('WS', 'Samoa', 'Oceania'),
  ('YE', 'Yemen', 'Asia'),
  ('YT', 'Mayotte', 'Africa'),
  ('ZA', 'South Africa', 'Africa'),
  ('ZM', 'Zambia', 'Africa'),
  ('ZW', 'Zimbabwe', 'Africa')
;

insert into public.countries (iso_code, name, continent)
select iso_code, name, continent from _ref_countries
on conflict (iso_code) do update
  set name = excluded.name,
      continent = excluded.continent
  where (public.countries.name, public.countries.continent)
        is distinct from (excluded.name, excluded.continent);

-- Sanity check inside the transaction: every row above must now exist exactly as written.
do $$
declare
  expected constant integer := 249;
  matching integer;
begin
  select count(*) into matching
  from _ref_countries r
  join public.countries c using (iso_code)
  where c.name = r.name and c.continent = r.continent;
  if matching <> expected then
    raise exception 'expected % countries to match this file, found %', expected, matching;
  end if;
end
$$;

commit;
