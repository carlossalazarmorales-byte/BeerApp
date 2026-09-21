import 'package:flutter/foundation.dart';

import 'env_validator.dart';

/// Build-time configuration read via `--dart-define-from-file`, e.g.
/// `flutter run --dart-define-from-file=config/dev.json` (see
/// `mobile/config/dev.example.json` for the expected shape, and
/// `mobile/config/release.example.json` for a release build). Centralized
/// here so no other file reads `String.fromEnvironment` directly.
///
/// Everything here is PUBLIC configuration that ships inside the app binary --
/// the Supabase URL and *publishable* key, the API URL, the public legal
/// document URLs. There is no secret in this file, and the backend's
/// `SUPABASE_SECRET_KEY` / database URLs must never be added here.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// The Google Cloud **Web** OAuth client ID, passed as `serverClientId` to
  /// `GoogleSignIn.instance.initialize()`. Empty is a valid dev state (no
  /// hard [validate] failure) — it routes Google sign-in to
  /// `UnconfiguredGoogleAuthClient` instead of calling `initialize()` with a
  /// blank ID.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Base URL of the FastAPI backend catalog reads go through -- never the
  /// Supabase project URL. On the Android emulator this is
  /// `http://10.0.2.2:8000` (the emulator's alias for the host machine's
  /// `localhost`); see `mobile/android/app/src/debug/res/xml/` for the
  /// matching debug-only cleartext allowance. A RELEASE build must use a public
  /// https URL: [validate] refuses to start otherwise.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Public https URLs of the Privacy Policy and Terms of Service documents.
  /// Optional: while unset, Settings keeps its "not available yet" placeholder.
  /// Public configuration, not secrets.
  static const String legalPrivacyUrl = String.fromEnvironment(
    'LEGAL_PRIVACY_URL',
  );
  static const String legalTermsUrl = String.fromEnvironment('LEGAL_TERMS_URL');

  /// The deep-link URL Supabase redirects to after email confirmation and
  /// password-reset links, and that Android's intent-filter and iOS's
  /// `CFBundleURLTypes` match (see `AndroidManifest.xml` / `Info.plist`). Fixed
  /// by the app's package name, not per-environment, so it isn't read from
  /// dart-define.
  static const String authRedirectUrl =
      'com.carlossalazarmorales.beerapp://login-callback';

  /// Parsed once from [authRedirectUrl] so its scheme/host/path aren't
  /// duplicated as separate literals elsewhere — [AuthDeepLinkHandler]
  /// compares every incoming link against this rather than just its
  /// scheme, since a custom scheme alone doesn't uniquely identify our
  /// callback (nothing else stops another app or a crafted link from
  /// reusing the same scheme with a different host).
  static final Uri authRedirectUri = Uri.parse(authRedirectUrl);

  /// Throws [EnvConfigException] (carrying only value-free [EnvProblem] names)
  /// if the configuration is unusable, rather than letting Supabase fail later
  /// with an opaque error. In a release build it additionally requires public
  /// https URLs, so a release can never silently ship pointing at localhost,
  /// the emulator alias, or cleartext HTTP.
  static void validate() {
    final problems = findEnvProblems(
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: supabasePublishableKey,
      apiBaseUrl: apiBaseUrl,
      legalPrivacyUrl: legalPrivacyUrl,
      legalTermsUrl: legalTermsUrl,
      isRelease: kReleaseMode,
    );
    if (problems.isNotEmpty) throw EnvConfigException(problems);
  }
}
