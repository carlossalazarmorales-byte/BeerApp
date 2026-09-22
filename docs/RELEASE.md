# Release runbook (Phase 15)

Working document for taking BeerApp to the stores. It records **facts, owner-operated
procedures and gates**; it is not a claim that anything is store-ready. "BeerApp" is the
working product name. The Play and App Store **Production release** items stay
**unchecked** until the owner gives a later, explicit instruction; the owner's manual QA and
beta cycle comes after the roadmap.

Evidence labels: **[repo]** read from files, **[build]** observed in a real build on this
machine, **[official]** from Apple/Google/Supabase documentation (links below), **[inference]**
reasoning that has not been proven, **[owner]** the owner must supply or do it.

Hard boundaries that stay in force: no signing keys, store/Supabase/hosting accounts,
production credentials, uploads or public release are created or used by the assistant, and
nothing here changes the applicationId / bundle id / auth scheme
(`com.carlossalazarmorales.beerapp`) until the identity gate below is passed.

## 1. Stage map and gates

| Stage | Content | Gate (owner input needed first) |
|---|---|---|
| **1A** (done in this repo) | merged-manifest inspection, permission provenance, `.aab` compile with placeholder config, backend cleanup, reference-data and beta-catalog tooling, working-name polish, this document | none |
| **1B** | physical-device release smoke test (section 6) | a public HTTPS backend from Stage 3, a physical Android device |
| **2** | permanent identity + release signing (section 8) | final public name, domain/reverse-domain, publisher identity, an upload key **you** create |
| **3** | production infrastructure (sections 3, 4, 5) | hosting choice, domain, production Supabase plan/region, SMTP |
| **4** | store setup + Play internal/closed testing (section 10) | a Google Play Console account; Stages 2 and 3 done |
| **5** | iOS (section 9) | a Mac with Xcode 26, an Apple Developer account, the final iOS auth decision |
| **6** | stop line: beta tracks ready, production unchecked | explicit later instruction for public release |

## 2. Android release build: what was verified (Stage 1A)

Built on this Windows machine with Flutter 3.47.4 and a **placeholder** release configuration
(public-shaped `https` values, fake keys, kept outside the repository and deleted afterwards):

- `flutter build appbundle --release`: succeeded, `app-release.aab` 75.0 MB **[build]**.
- `flutter build apk --release`: succeeded, `app-release.apk` 100.8 MB **[build]**.
- Both are signed with the **debug key** (`build.gradle.kts` still uses `signingConfigs["debug"]`),
  so they are **not** store builds and were never uploaded.
- `apkanalyzer`: applicationId `com.carlossalazarmorales.beerapp`, minSdk 24, targetSdk 36,
  `debuggable` false **[build]**. targetSdk 36 comes from Flutter 3.47.4's defaults and meets
  Google Play's requirement that new apps and updates target API 36 from 2026-08-31
  **[official]**. It is not pinned in `build.gradle.kts`: if Flutter is downgraded the value can
  silently fall, so check it on the final build.
- **R8 minification and resource shrinking are ON for release.** The Flutter Gradle plugin turns them
  on (`FlutterPlugin.kt`, `isMinifyEnabled = true`; `isShrinkResources = true` for apps) and the build
  produced `mapping.txt`. An earlier Phase 15 audit note that said "R8 not enabled" was wrong. This
  is why the physical **release-build** smoke test matters: minification can remove classes that
  debug builds keep. `mobile_scanner` ships consumer keep rules for ML Kit; no app-level rules exist.

Reproduce (from `mobile/`, with a JSON file of placeholder values **outside** the repo):

```
flutter build appbundle --release --dart-define-from-file=<path-outside-repo>/release_placeholder.json
flutter build apk --release --dart-define-from-file=<path-outside-repo>/release_placeholder.json
```

The keys are the ones in `mobile/config/release.example.json`. A real build needs real public
values (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_SERVER_CLIENT_ID`, `API_BASE_URL`,
`MAPTILER_API_KEY`, `LEGAL_PRIVACY_URL`, `LEGAL_TERMS_URL`) supplied outside git; the release guard
rejects local/non-https hosts.

## 3. Merged Android manifest: findings and permission provenance

Source: `mobile/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`
and `mobile/build/app/outputs/logs/manifest-merger-release-report.txt` from the build above
**[build]**, confirmed against the packaged APK with `apkanalyzer manifest permissions`.

### Requested permissions (9, plus the AndroidX signature permission)

| Permission | Added by | Proof | BeerApp uses it? |
|---|---|---|---|
| `INTERNET` | the app manifest (also Google sign-in, MapLibre, okhttp) | merger report: ADDED from `android/app/src/main/AndroidManifest.xml` | yes (API, Supabase, map tiles) |
| `CAMERA` | the app manifest (also `mobile_scanner`) | merger report | yes (barcode scan, on-device) |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | **`org.maplibre.gl:android-sdk-opengl:13.5.0`** only | merger report: ADDED from that AAR, **no other source**; `gradlew :app:dependencyInsight` shows it comes solely from `project :maplibre_gl` | **no** (see below) |
| `ACCESS_WIFI_STATE` | `android-sdk-opengl:13.5.0` only | merger report | no |
| `ACCESS_NETWORK_STATE` | `android-sdk-opengl:13.5.0` **and** `com.google.android.datatransport:transport-backend-cct:2.3.3` / `transport-runtime:2.2.6` (ML Kit's telemetry transport, via `com.google.mlkit:common:18.11.0`) | merger report: ADDED + MERGED; `dependencyInsight` chain from `mobile_scanner` | indirectly (two SDKs call ConnectivityManager) |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | `androidx.biometric:biometric:1.1.0` | merger report; `dependencyInsight`: `biometric:1.1.0` <- `androidx.credentials:credentials:1.6.0` <- `project :google_sign_in_android` (Credential Manager) | **no** BeerApp code uses biometrics (no `local_auth`) |
| `<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | `androidx.core:core:1.18.0` (signature-level) | merger report | AndroidX internals |

Also merged **[build]**: `uses-feature android.hardware.camera required=false` (app and scanner) and
`android.hardware.wifi required=false` (MapLibre). Exported components: the app's `MainActivity`
(the launcher and the auth deep link), `RevocationBoundService` (play-services-auth; protected by
the `REVOCATION_NOTIFICATION` permission) and `ProfileInstallReceiver` (AndroidX; protected by
`android.permission.DUMP`). `allowBackup="false"`, no cleartext, no `networkSecurityConfig`,
`extractNativeLibs="false"`, `<queries>` only for `PROCESS_TEXT`.

### BeerApp has no location usage

`grep` over `mobile/lib`, `mobile/android/app/src` and `mobile/ios/Runner` finds no location API, no
geolocation package and no `myLocationEnabled`; the only matches are the router's `matchedLocation`
and brewery place text. `pubspec.yaml` has no location package. The map opens centred on a fixed
point (lat 20, lon 0), never on the user. MapLibre's location engine
(`GMSLocationEngine`, `LocationEngineFactory`) is only used when `myLocationEnabled` is enabled
**[inference from the plugin source, not run]**, which BeerApp never does.
The existing test `android_manifest_test.dart` forbids `LOCATION` in the app's own manifest.

### Permission decisions (owner, 2026-09-21)

- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`: removal is **approved only after** the proof in
  section 6. **Not applied.** The source manifests are unchanged; the merged release manifest above
  still requests both.
- `ACCESS_NETWORK_STATE`: **keep** (removing it risks a `SecurityException` in MapLibre and ML Kit
  **[inference]**).
- `ACCESS_WIFI_STATE`, `USE_BIOMETRIC`, `USE_FINGERPRINT`: **keep for this phase**; reconsider after beta
  and device evidence. They are normal (install-time) permissions, not runtime prompts.

### The patch to apply later (Stage 1B, immediately before the device proof)

In `mobile/android/app/src/main/AndroidManifest.xml` add the `tools` namespace and two removals:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" tools:node="remove" />
    <!-- ...INTERNET and CAMERA unchanged... -->
```

Then, in the same change: update the test **`the current source manifests remove nothing`** in
`mobile/test/platform/android_manifest_test.dart` (it deliberately fails once a removal exists;
the helpers already ignore `tools:node="remove"` lines when counting requested permissions);
rebuild the release APK/AAB; re-read the merged manifest and confirm both permissions are gone while
the other six remain; run the device proof. Keep the change only if the proof passes; otherwise revert
it and record why. Do not describe it as verified before then.

### Store-disclosure impact (facts, no form filled)

Google Play's Data safety form defines "collect" as transmitting data off the device; on-device-only
processing need not be disclosed **[official]**. A permission in the manifest is therefore not
itself a data-collection statement, but the two location permissions are runtime ("dangerous")
permissions that BeerApp never requests or uses, which is the reason to remove them. The SDK
telemetry that **does** leave the device: Google ML Kit (bundled barcode model; device info, package
name/version, performance metrics, API configuration; sent over HTTPS; not shared with third parties
per Google's ML Kit disclosure **[official]**). Section 10 lists the inputs for the disclosures.

## 4. Backend for production (host not chosen)

- **Files.** `backend/requirements.txt` is now **runtime only**; `backend/requirements-dev.txt`
  (`-r requirements.txt` plus `pytest`, `iniconfig`, `pluggy`, `ruff`) is for development and CI. Both are
  plain UTF-8 with exact pins; `backend/tests/test_requirements_files.py` guards the split and the
  encoding. Install for development with `pip install -r backend/requirements-dev.txt`.
- **Run command** (from `backend/`; the working directory matters only for the `app` import path):

  ```
  uvicorn app.main:app --host 0.0.0.0 --port 8000
  ```

  Behind a reverse proxy / platform router add `--proxy-headers` and set `--forwarded-allow-ips` to the
  proxy's address. The API itself does not read or log client IPs. There is no Dockerfile, Procfile or CI yet:
  they are written only once a host is chosen.
- **Environment** (`.env.example` documents every variable; supply real values through the host's secret
  store, never git): `ENVIRONMENT` (anything other than `local`/`dev` is production-like: docs off, https
  `SUPABASE_URL` enforced), `SUPABASE_URL`, `DATABASE_URL` (the `beerapp_backend` role, Session Pooler
  port 5432), optional `SUPABASE_SECRET_KEY` (only `DELETE /account` needs it; without it that route
  returns 503), optional pool/timeout/JWKS/`LOG_LEVEL`/`MAX_REQUEST_BODY_BYTES` tuning. `SEED_DATABASE_URL`
  and `INTEGRATION_DATABASE_URL` are never production settings.
- **Removed:** the unused backend `API_BASE_URL` setting and its `.env.example` line (it was declared but
  read nowhere; the Flutter `API_BASE_URL` build define is unrelated). A `.env` that still contains the
  line keeps working: unknown variables are ignored.
- **Not yet done, needs the host:** public HTTPS domain, request-rate limiting at the proxy/edge (the API
  has bounds but no per-time limiting and no `429`), log sink and retention, health probe wiring
  (`GET /health` does not check the database), instance count.

## 5. Production Supabase (owner-operated; do not reuse `beerapp-dev`)

Only after the owner has created a **new** project (plan, region and backups are the owner's choice):

1. **Migrations.** Link the CLI to the new project and apply all 19 migrations from a clean history:
   `supabase link --project-ref <new-ref>`, `supabase db push --dry-run` (the list must be exactly the 19
   files), then `supabase db push`. Never edit an applied migration; fix forward with a new one. Do not
   copy the dev database or its credentials.
2. **Runtime roles.** Migrations create `beerapp_backend` and `beerapp_seed` with `LOGIN` and **no
   password**. Set strong passwords once, by hand, and store them only in the host secret store:
   `alter role beerapp_backend with password '<generated>';` (see the migration headers and
   `docs/DATABASE.md`). Give production **no** `beerapp_seed` credential unless you need it for a catalog
   load, and rotate it afterwards.
3. **Post-migration privilege audit** (read-only; expected results were recorded on the repository's
   disposable scaffold, and a real Supabase project also has its own managed roles such as `service_role`
   and `postgres`):

   ```sql
   -- every public table has row level security (expect 0 rows)
   select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
   -- anon has no table privileges (expect 0 rows)
   select table_name, privilege_type from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'anon';
   -- authenticated: only profiles (SELECT, UPDATE)
   select table_name, string_agg(privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'authenticated' group by table_name;
   -- beerapp_backend: catalog SELECT; INSERT+SELECT on contributions and achievements;
   -- SELECT/INSERT/UPDATE/DELETE only on user_beer_logs and user_beer_collection
   select table_name, string_agg(privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'beerapp_backend' group by table_name order by 1;
   -- private functions: EXECUTE for nobody except the owner (+ beerapp_backend on the one
   -- boolean-only barcode function)
   select p.proname, pg_get_userbyid(p.proowner), p.proacl from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' order by 1;
   -- the app roles cannot bypass RLS
   select rolname, rolbypassrls, rolsuper from pg_roles where rolname like 'beerapp%';
   ```

   Then `supabase db lint --linked --level error` (expect no errors) and, from the repository, the
   integration suite against a disposable database (never against production).
4. **Reference data and catalog.** `supabase/reference_data/` and `supabase/catalog_beta/` (their own READMEs).
   Apply only owner-reviewed files, countries first. Never run `backend/scripts/seed_catalog.py`.
5. **Backups.** The Free plan has no backups and pauses on inactivity; Pro has daily backups with 7-day
   retention; point-in-time recovery is an add-on that needs at least a Small compute add-on; backups exclude
   Storage objects; a restore makes the project unavailable **[official, supabase.com/docs/guides/platform/backups]**.
   Record the plan, the recovery targets and a **restore drill**; account deletion versus backup retention must
   be reconciled in the privacy policy. Nothing is configured or tested yet.
6. **Forward-fix / rollback.** There is no down-migration. Undo by writing a new migration or a reviewed
   corrective statement; restore from a backup only for real data loss.

## 6. Physical-device release smoke test (Stage 1B, postponed to after Stage 3)

Runs against the real or prod-like HTTPS backend, on the final signed build where possible, by the owner
on a physical Android device. **Technical checks only: none may require creating alcohol-consumption or
preference data (logs, favourites, wishlist).** If a later manual check needs those, use automated/synthetic
tests or an eligible adult tester.

1. Install and launch the **release** build; the release guard accepts the configuration (no startup failure).
2. Sign-up / sign-in with email (needs custom SMTP or a project-team-member inbox); the email deep link opens the
   app and completes the flow. [inference] The handler matches the redirect path strictly (`''`): confirm a link
   that arrives as `...://login-callback/` still works.
3. Google sign-in works on the build that will actually be tested (Android OAuth client bound to the package name
   and the SHA-1 of the signing key in use).
4. Map renders, **pans, zooms, and clusters** (catalog rows come from the owner-reviewed reference/beta data);
   no location prompt ever appears.
5. Scanner: camera permission grant and deny flows; decode a **synthetic/test barcode**; a "not in the catalog"
   result is a valid outcome. Nothing is logged automatically.
6. Legal links open in the real browser (needs the real URLs) or show the placeholder.
7. Account deletion with an explicitly **disposable** account: the account is gone and the app returns to sign-in.
8. TalkBack smoke pass over the main flows (a full key-flow pass is required before public launch; VoiceOver
   before any iOS public submission). Hardware-keyboard focus and MapLibre marker accessibility are
   **documented limitations**, not beta blockers.
9. Location-permission removal proof: with the patch from section 3 applied, items 1-5 all pass and
   `apkanalyzer manifest permissions` no longer lists the two location permissions. Only then is the removal called verified.

## 7. Supabase Auth dashboard checklist (owner; not verifiable from the repository)

- **URL Configuration:** Site URL = the production value (not `localhost`); the Redirect URLs allow-list must contain
  the app's redirect `com.carlossalazarmorales.beerapp://login-callback` (or the renamed scheme after Stage 2). A `redirectTo`
  that is not allow-listed falls back to the Site URL **[official, supabase.com/docs/guides/auth/redirect-urls]**.
- **Custom SMTP is required before real testers.** The built-in email service only delivers to members of the
  Supabase project team, at 2 messages per hour, and is "not meant for production use"
  **[official, supabase.com/docs/guides/auth/auth-smtp]**. Needs an owner-controlled sender domain.
- **Email confirmation on**, a password policy (the local template has confirmations off and a minimum length of 6:
  that is the local CLI default, not a production statement), CAPTCHA on sign-up/sign-in/reset, auth rate limits,
  OTP expiry at or below 3600 s **[official, supabase.com/docs/guides/deployment/going-into-prod]**.
- **Google provider:** the Web client ID, plus the Android and (later) iOS client IDs; for native iOS also
  "Skip nonce check" **[official, supabase.com/docs/guides/auth/social-login/auth-google]**.
- **Apple provider:** not enabled and not implemented (owner decision).
- Review remote Auth settings again after any change; they are outside the repository and were never reviewed.

## 8. Signing (Stage 2; owner-operated)

The assistant never generates, receives, stores or asks for keys or passwords.

1. The owner generates an **upload keystore** locally (for example with `keytool -genkeypair ...`), keeps it and its
   passwords outside the repository (`*.jks`, `*.keystore`, `key.properties` are git-ignored), and enrolls in
   **Play App Signing** in Play Console (Google holds the app-signing key; the upload key is replaceable).
2. Stage 2 then adds Gradle wiring that reads a git-ignored `android/key.properties` and **fails the release
   build closed** when it is missing (no silent debug key), an atomic rename of the identifiers if the identity
   changed, adaptive/legacy launcher icons from owner artwork, and `versionCode` discipline
   (`pubspec.yaml version: MAJOR.MINOR.PATCH+N`, one increasing `N` for both stores; nothing to change until then).
3. The owner registers the SHA-1 of the **upload key and of the Play App Signing key** (from Play Console) in the Google
   Cloud Android OAuth client bound to the final package name. A debug SHA-1 will not match store builds.

**Do not change the applicationId / bundle id / auth scheme before this gate.** They become effectively permanent
once a Play or App Store record exists, and the Android OAuth client is bound to the package name.

## 9. iOS: prerequisites and pre-Mac checklist (nothing here is verified; iOS was never built or run)

Blocked until a Mac with **Xcode 26 / the iOS 26 SDK** (required for uploads since 2026-04-28 **[official]**), an Apple
Developer Program account (US$99/yr; individual needs the legal name and 2FA; an organization needs a legal entity and a
D-U-N-S number **[official]**) and the final iOS auth decision exist. Static facts **[repo]**:

- Bundle id `com.carlossalazarmorales.beerapp` (+ `.RunnerTests`); display/bundle name set to "BeerApp" (static edit);
  deployment target 15.0; `TARGETED_DEVICE_FAMILY = 1,2` (iPhone **and iPad**: iPad needs 13" screenshots and iPad
  review; decide iPhone-only vs iPad before the App Store record); no `DEVELOPMENT_TEAM`, no entitlements.
- `Info.plist`: camera usage description only; the auth URL scheme matches Android and `Env`; **no** `GIDClientID`
  and no reversed-client-ID scheme, so Google sign-in on iOS is **not configured**; `ITSAppUsesNonExemptEncryption` is
  missing (the owner answers the export-compliance question); **no `PrivacyInfo.xcprivacy`** in the app (five plugins ship
  their own; none found for `maplibre_gl`; Apple enforces required-reason API declarations on upload **[official]**).
- Launcher icon and launch image are the Flutter defaults; no Podfile (Swift Package Manager integration generated on Windows).
- **Sign in with Apple:** not implemented, not being added now. Apple guideline 4.8 requires an equivalent login option
  (limits data to name+email, can hide the email, no ad tracking) for apps that use a third-party login such as Google to
  set up the primary account, unless the app *exclusively* uses its own account system **[official, App Review Guidelines]**.
  The final iOS decision (add SIWA, drop Google on iOS, or wait) is made when a Mac exists. If SIWA is ever added, account
  deletion must also revoke Apple tokens **[official]**.
- Also needed: an App Store Connect record, App Privacy details, a **demo account** for App Review (there is no guest mode;
  guideline 2.1), DSA trader status for EU availability.

## 10. Store setup inputs (facts; nothing prepared or uploaded)

Official references fetched on 2026-09-21: Apple [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/),
[age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions),
[upcoming requirements](https://developer.apple.com/news/upcoming-requirements/),
[TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview),
[app privacy details](https://developer.apple.com/app-store/app-privacy-details/); Google
[account deletion](https://support.google.com/googleplay/android-developer/answer/13327111),
[Data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[content rating](https://support.google.com/googleplay/android-developer/answer/9859655),
[target API](https://support.google.com/googleplay/android-developer/answer/11926878),
[testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465),
[store listing assets](https://support.google.com/googleplay/android-developer/answer/9866151).

| Topic | Fact | State |
|---|---|---|
| Account deletion | Apple: in-app deletion required if accounts can be created (exists). Google: an in-app path **and a web link** where users can request account and data deletion, naming the app/developer | web page/URL **does not exist** [owner] |
| Privacy policy / Terms | Apple requires a policy link in App Store Connect and in-app; Google requires it in the listing. The policy must cover collection, third parties, retention/deletion | in-app link infrastructure exists; text and URLs **[owner]**; no mandatory Terms acceptance at sign-up unless later decided |
| Data safety / App privacy | required before closed/production tracks (Play) and for submission (Apple) | not started [owner]; facts to feed it: section 11 |
| Age / content rating | Apple: frequent alcohol references => 18+ tier; Google: mandatory IARC questionnaire and target-audience declaration | owner answers; the adult gate is **not** weakened for any store |
| Play testing | new personal accounts: closed test with at least 12 testers opted in for 14 days before production access; Data safety form needed for closed tracks | account type [owner] |
| TestFlight | up to 100 internal and 10,000 external testers; first external build needs Beta App Review; builds expire after 90 days | iOS blocked |
| Play listing assets | icon 512x512 32-bit PNG; feature graphic 1024x500; short description at most 80 characters; at least 2 screenshots | none exist; icon is the Flutter default |
| Apple screenshots | 1-10 per size, no alpha; 6.5" (1284x2778) unless 6.9" is supplied; iPad 13" if iPad is supported | none exist |
| Reviewer access | Apple needs a working demo account | [owner], on the production project |

## 11. Data-practices inputs (facts for whoever writes the disclosures; a fact sheet can be prepared later)

On the device only: camera frames (decoded on-device; never stored or sent), the age-gate acknowledgement, the language
override, the Supabase session (in `SharedPreferences`, not the Keystore/Keychain; `allowBackup=false`).
Sent to the backend/Supabase: email and password (Supabase Auth), Google identity when used (the Google display name is copied
into `profiles.display_name` by a database trigger), username/display name/preferred currency, beer logs (rating, review, date,
serving note, price, venue name, serving volume), favourites/wishlist, achievements, beer/brewery contributions, search text,
a scanned barcode as a lookup (not stored unless submitted as a contribution). Third parties: Supabase, MapTiler (IP, tile
requests, API key), Google (sign-in; ML Kit telemetry on Android), and any host that serves a catalog `image_url`. Not collected: device
location, advertising or device identifiers, analytics events, crash reports, contacts, photos, microphone. No analytics or crash-reporting
SDK is used, by decision. Deletion cascades to every user-owned table; backup retention is undefined until backups exist; there is no
data export.

## 12. Working-name polish (Stage 1A)

Android `android:label`, iOS `CFBundleDisplayName` / `CFBundleName` and the pubspec description now say "BeerApp" (previously
`beerapp`, `Beerapp`/`beerapp`, and the template text). The identifiers and the auth scheme are unchanged. If the final public
name differs, change these three strings with it.
