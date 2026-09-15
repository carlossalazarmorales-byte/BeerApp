/// Build-time configuration read via `--dart-define-from-file`, e.g.
/// `flutter run --dart-define-from-file=config/dev.json` (see
/// `mobile/config/dev.example.json` for the expected shape). Centralized
/// here so no other file reads `String.fromEnvironment` directly.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// The deep-link URL Supabase redirects to after email confirmation and
  /// password-reset links, and that Android's intent-filter matches (see
  /// `AndroidManifest.xml`). Fixed by the app's package name, not
  /// per-environment, so it isn't read from dart-define.
  static const String authRedirectUrl =
      'com.carlossalazarmorales.beerapp://login-callback';

  /// Parsed once from [authRedirectUrl] so its scheme/host/path aren't
  /// duplicated as separate literals elsewhere — [AuthDeepLinkHandler]
  /// compares every incoming link against this rather than just its
  /// scheme, since a custom scheme alone doesn't uniquely identify our
  /// callback (nothing else stops another app or a crafted link from
  /// reusing the same scheme with a different host).
  static final Uri authRedirectUri = Uri.parse(authRedirectUrl);

  /// Throws with a clear message if required values weren't supplied,
  /// rather than letting Supabase fail later with an opaque error.
  static void validate() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Run with '
        '--dart-define-from-file=config/dev.json '
        '(copy mobile/config/dev.example.json first).',
      );
    }
  }
}
