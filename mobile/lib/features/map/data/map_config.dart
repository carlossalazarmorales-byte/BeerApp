/// Map tile/style provider configuration -- the *only* place in the app
/// that knows the provider is MapTiler, so switching providers later never
/// touches `MapController`/`MapScreen`.
///
/// Deliberately separate from `core/config/env.dart`'s `Env` class and its
/// `validate()`: the map is one feature among several, not core app
/// infrastructure like Supabase or the API base URL, so a missing/invalid
/// key must never block Auth/Discover/Collection/Profile from opening.
/// `MapScreen` checks [isConfigured] itself and shows a localized
/// "unavailable" state instead when it's false -- see docs/DECISIONS.md.
///
/// Read the same way as every `Env` field -- via `--dart-define-from-file`
/// (see `mobile/config/dev.example.json`) -- but as its own build-time
/// constant, not routed through `Env`.
///
/// The key is a client-visible, quota-limited credential (MapTiler's free
/// tier is designed to ship inside client binaries/URLs, rate-limited and
/// usage-tracked per key), categorically different from a Supabase
/// `service_role`-style secret that must never leave a server. It is never
/// hardcoded here or anywhere else in source, tests, or docs.
abstract final class MapConfig {
  static const String _apiKey = String.fromEnvironment('MAPTILER_API_KEY');

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// `null` when [isConfigured] is false -- callers must check that (or
  /// handle null) before building a `MapLibreMap` with this.
  static String? get styleUrl => isConfigured
      ? 'https://api.maptiler.com/maps/streets-v2/style.json?key=$_apiKey'
      : null;
}
