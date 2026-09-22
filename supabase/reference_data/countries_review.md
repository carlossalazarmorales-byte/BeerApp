# Countries reference data: owner review list

Status: **DRAFT, not reviewed, not applied anywhere.** Generated with the sources described in
the header of `countries.sql`: **249 country/territory codes exposed by OpenJDK 21.0.6, with
CLDR 42 names and UN-M49-derived continent mapping.** OpenJDK and Unicode CLDR are not themselves
the ISO 3166 issuing authority, so this list is **not verified against the ISO 3166 Maintenance
Agency** and is not described as ISO-authoritative -- it is a documented, reproducible source, not
an authoritative one. Nothing here is legal or geopolitical advice; the choices below are the
owner's.

The file contains all 249 codes OpenJDK exposes for ISO 3166-1 alpha-2 and nothing else.
To use fewer rows, delete them from `countries.sql`; to use different names or continents, edit
the values. `countries.sql` refuses to run until its DRAFT-GUARD block is deleted.

Row counts by continent: Africa 60, Antarctica 1, Asia 51, Europe 51, North America 41, Oceania 29, South America 16.

## 1. Decisions the owner must make

1. **Territories.** 54 of the 249 rows are not UN member or observer states (ISO
   assigns codes to territories and dependencies too; the 195 others are the 193 UN
   members plus the observers VA and PS). This split was compiled by the assistant from public UN
   membership, **not** taken from ISO or CLDR: verify it. Decide whether beta needs
   territories at all (beers are usually attributed to a country, but e.g. `HK`, `PR`, `GL` occur):
   `AS`, `AI`, `AQ`, `AW`, `AX`, `BL`, `BM`, `BQ`, `BV`, `CC`, `CK`, `CW`, `CX`, `EH`, `FK`, `FO`, `GF`, `GG`, `GI`, `GL`, `GP`, `GS`, `GU`, `HK`, `HM`, `IM`, `IO`, `JE`, `KY`, `MF`, `MO`, `MP`, `MQ`, `MS`, `NC`, `NF`, `NU`, `PF`, `PM`, `PN`, `PR`, `RE`, `SH`, `SJ`, `SX`, `TC`, `TF`, `TK`, `TW`, `UM`, `VG`, `VI`, `WF`, `YT`.
2. **Transcontinental countries.** CLDR/UN M49 puts each in exactly one continent; the app's map and
   statistics group by this value. Current assignment: `RU` Russia -> Europe, `TR` Turkey -> Asia, `KZ` Kazakhstan -> Asia, `GE` Georgia -> Asia, `AZ` Azerbaijan -> Asia, `AM` Armenia -> Asia, `CY` Cyprus -> Asia, `EG` Egypt -> Africa.
   Confirm or override each.
3. **Territories attached to a different continent than their state.** M49 assigns by geography, e.g.
   `GL` Greenland -> North America, `GF` French Guiana -> South America, `RE` Réunion -> Africa,
   `YT` Mayotte -> Africa, `BV` Bouvet Island -> South America, `SJ` Svalbard & Jan Mayen -> Europe,
   `IO` British Indian Ocean Territory -> Africa, `TF` French Southern Territories -> Africa,
   `HM` Heard & McDonald Islands -> Oceania, `UM` U.S. Outlying Islands -> Oceania,
   `AQ` Antarctica -> Antarctica (rule, not M49).
4. **Names.** These are CLDR 42 English display names. Politically or stylistically sensitive ones to
   confirm: `TW` Taiwan, `PS` Palestinian Territories, `HK` Hong Kong SAR China, `MO` Macao SAR China, `EH` Western Sahara, `MK` North Macedonia, `CD` Congo - Kinshasa, `CG` Congo - Brazzaville, `CI` Côte d’Ivoire, `MM` Myanmar (Burma), `SZ` Eswatini, `TR` Turkey, `CZ` Czechia, `VA` Vatican City, `FK` Falkland Islands, `KP` North Korea, `KR` South Korea, `LA` Laos, `SY` Syria, `RU` Russia, `IR` Iran, `VN` Vietnam, `BN` Brunei, `TL` Timor-Leste, `CV` Cape Verde, `FM` Micronesia, `GB` United Kingdom, `US` United States.
5. **Not included on purpose:** `XK` Kosovo (a user-assigned code, not one OpenJDK exposes as an
   ISO 3166-1 alpha-2 country code), `EU`, `UN`, and other exceptional reservations. Add rows by
   hand only if the owner decides so.

## 2. Full listing

### Africa (60)

`AO` Angola, `BF` Burkina Faso, `BI` Burundi, `BJ` Benin, `BW` Botswana, `CD` Congo - Kinshasa, `CF` Central African Republic, `CG` Congo - Brazzaville, `CI` Côte d’Ivoire, `CM` Cameroon, `CV` Cape Verde, `DJ` Djibouti, `DZ` Algeria, `EG` Egypt, `EH` Western Sahara, `ER` Eritrea, `ET` Ethiopia, `GA` Gabon, `GH` Ghana, `GM` Gambia, `GN` Guinea, `GQ` Equatorial Guinea, `GW` Guinea-Bissau, `IO` British Indian Ocean Territory, `KE` Kenya, `KM` Comoros, `LR` Liberia, `LS` Lesotho, `LY` Libya, `MA` Morocco, `MG` Madagascar, `ML` Mali, `MR` Mauritania, `MU` Mauritius, `MW` Malawi, `MZ` Mozambique, `NA` Namibia, `NE` Niger, `NG` Nigeria, `RE` Réunion, `RW` Rwanda, `SC` Seychelles, `SD` Sudan, `SH` St. Helena, `SL` Sierra Leone, `SN` Senegal, `SO` Somalia, `SS` South Sudan, `ST` São Tomé & Príncipe, `SZ` Eswatini, `TD` Chad, `TF` French Southern Territories, `TG` Togo, `TN` Tunisia, `TZ` Tanzania, `UG` Uganda, `YT` Mayotte, `ZA` South Africa, `ZM` Zambia, `ZW` Zimbabwe

### Antarctica (1)

`AQ` Antarctica

### Asia (51)

`AE` United Arab Emirates, `AF` Afghanistan, `AM` Armenia, `AZ` Azerbaijan, `BD` Bangladesh, `BH` Bahrain, `BN` Brunei, `BT` Bhutan, `CN` China, `CY` Cyprus, `GE` Georgia, `HK` Hong Kong SAR China, `ID` Indonesia, `IL` Israel, `IN` India, `IQ` Iraq, `IR` Iran, `JO` Jordan, `JP` Japan, `KG` Kyrgyzstan, `KH` Cambodia, `KP` North Korea, `KR` South Korea, `KW` Kuwait, `KZ` Kazakhstan, `LA` Laos, `LB` Lebanon, `LK` Sri Lanka, `MM` Myanmar (Burma), `MN` Mongolia, `MO` Macao SAR China, `MV` Maldives, `MY` Malaysia, `NP` Nepal, `OM` Oman, `PH` Philippines, `PK` Pakistan, `PS` Palestinian Territories, `QA` Qatar, `SA` Saudi Arabia, `SG` Singapore, `SY` Syria, `TH` Thailand, `TJ` Tajikistan, `TL` Timor-Leste, `TM` Turkmenistan, `TR` Turkey, `TW` Taiwan, `UZ` Uzbekistan, `VN` Vietnam, `YE` Yemen

### Europe (51)

`AD` Andorra, `AL` Albania, `AT` Austria, `AX` Åland Islands, `BA` Bosnia & Herzegovina, `BE` Belgium, `BG` Bulgaria, `BY` Belarus, `CH` Switzerland, `CZ` Czechia, `DE` Germany, `DK` Denmark, `EE` Estonia, `ES` Spain, `FI` Finland, `FO` Faroe Islands, `FR` France, `GB` United Kingdom, `GG` Guernsey, `GI` Gibraltar, `GR` Greece, `HR` Croatia, `HU` Hungary, `IE` Ireland, `IM` Isle of Man, `IS` Iceland, `IT` Italy, `JE` Jersey, `LI` Liechtenstein, `LT` Lithuania, `LU` Luxembourg, `LV` Latvia, `MC` Monaco, `MD` Moldova, `ME` Montenegro, `MK` North Macedonia, `MT` Malta, `NL` Netherlands, `NO` Norway, `PL` Poland, `PT` Portugal, `RO` Romania, `RS` Serbia, `RU` Russia, `SE` Sweden, `SI` Slovenia, `SJ` Svalbard & Jan Mayen, `SK` Slovakia, `SM` San Marino, `UA` Ukraine, `VA` Vatican City

### North America (41)

`AG` Antigua & Barbuda, `AI` Anguilla, `AW` Aruba, `BB` Barbados, `BL` St. Barthélemy, `BM` Bermuda, `BQ` Caribbean Netherlands, `BS` Bahamas, `BZ` Belize, `CA` Canada, `CR` Costa Rica, `CU` Cuba, `CW` Curaçao, `DM` Dominica, `DO` Dominican Republic, `GD` Grenada, `GL` Greenland, `GP` Guadeloupe, `GT` Guatemala, `HN` Honduras, `HT` Haiti, `JM` Jamaica, `KN` St. Kitts & Nevis, `KY` Cayman Islands, `LC` St. Lucia, `MF` St. Martin, `MQ` Martinique, `MS` Montserrat, `MX` Mexico, `NI` Nicaragua, `PA` Panama, `PM` St. Pierre & Miquelon, `PR` Puerto Rico, `SV` El Salvador, `SX` Sint Maarten, `TC` Turks & Caicos Islands, `TT` Trinidad & Tobago, `US` United States, `VC` St. Vincent & Grenadines, `VG` British Virgin Islands, `VI` U.S. Virgin Islands

### Oceania (29)

`AS` American Samoa, `AU` Australia, `CC` Cocos (Keeling) Islands, `CK` Cook Islands, `CX` Christmas Island, `FJ` Fiji, `FM` Micronesia, `GU` Guam, `HM` Heard & McDonald Islands, `KI` Kiribati, `MH` Marshall Islands, `MP` Northern Mariana Islands, `NC` New Caledonia, `NF` Norfolk Island, `NR` Nauru, `NU` Niue, `NZ` New Zealand, `PF` French Polynesia, `PG` Papua New Guinea, `PN` Pitcairn Islands, `PW` Palau, `SB` Solomon Islands, `TK` Tokelau, `TO` Tonga, `TV` Tuvalu, `UM` U.S. Outlying Islands, `VU` Vanuatu, `WF` Wallis & Futuna, `WS` Samoa

### South America (16)

`AR` Argentina, `BO` Bolivia, `BR` Brazil, `BV` Bouvet Island, `CL` Chile, `CO` Colombia, `EC` Ecuador, `FK` Falkland Islands, `GF` French Guiana, `GS` South Georgia & South Sandwich Islands, `GY` Guyana, `PE` Peru, `PY` Paraguay, `SR` Suriname, `UY` Uruguay, `VE` Venezuela

