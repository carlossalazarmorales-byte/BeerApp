import 'dart:io' show InternetAddress, InternetAddressType;

/// A specific, value-free reason the build-time configuration is unusable.
/// Only names are ever surfaced (logs, the debug diagnostics line) -- never the
/// configured values, so a bad config can't leak a URL or key through an error.
enum EnvProblem {
  missingSupabaseUrl,
  missingSupabasePublishableKey,
  missingApiBaseUrl,

  /// Release only: must be an https URL.
  supabaseUrlNotHttps,
  apiBaseUrlNotHttps,

  /// Release only: a loopback / private-network / emulator-alias host such as
  /// `localhost`, `10.0.2.2` or `192.168.x.x` -- a development address that can
  /// never be reached by a real user's device.
  supabaseUrlIsLocal,
  apiBaseUrlIsLocal,

  /// Release only: a legal URL that IS configured but is not a public https URL.
  /// (An unset legal URL is fine -- the app keeps its placeholder screen.)
  invalidLegalUrl,
}

/// Thrown by `Env.validate()`. Carries only [EnvProblem] names.
class EnvConfigException implements Exception {
  const EnvConfigException(this.problems);

  final List<EnvProblem> problems;

  @override
  String toString() =>
      'EnvConfigException: ${problems.map((p) => p.name).join(', ')}';
}

/// True for a host a real user's device can never reach on the public internet:
/// loopback, private/link-local/unique-local addresses, the Android emulator's
/// host alias (`10.0.2.2` is inside 10.0.0.0/8), and local-only names.
bool isLocalOrPrivateHost(String host) {
  final name = host.trim().toLowerCase();
  if (name.isEmpty) return true;
  if (name == 'localhost' ||
      name.endsWith('.localhost') ||
      name.endsWith('.local') ||
      name.endsWith('.internal') ||
      name.endsWith('.lan')) {
    return true;
  }

  final address = InternetAddress.tryParse(name);
  if (address == null) {
    // A single-label name ("intranet", "backend") never resolves publicly.
    return !name.contains('.');
  }
  if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
    return true;
  }

  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    final a = bytes[0];
    final b = bytes[1];
    return a == 0 || // 0.0.0.0/8 ("this network", incl. 0.0.0.0)
        a == 10 || // 10.0.0.0/8 (incl. the emulator's 10.0.2.2)
        (a == 172 && b >= 16 && b <= 31) || // 172.16.0.0/12
        (a == 192 && b == 168) || // 192.168.0.0/16
        (a == 100 && b >= 64 && b <= 127) || // 100.64.0.0/10 (CGNAT)
        a == 255; // broadcast
  }
  // IPv6: unspecified (::) and unique-local (fc00::/7).
  return bytes.every((byte) => byte == 0) || (bytes[0] & 0xfe) == 0xfc;
}

/// The parsed URL if [raw] is a well-formed **public https** URL (https, a host,
/// no credentials, not a local/private host); otherwise null.
Uri? parsePublicHttpsUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  if (uri.scheme != 'https' || !uri.hasAuthority || uri.host.isEmpty) {
    return null;
  }
  if (uri.userInfo.isNotEmpty) return null;
  if (isLocalOrPrivateHost(uri.host)) return null;
  return uri;
}

/// Pure validation of the build-time configuration. Values are passed in (not
/// read from `String.fromEnvironment`), so every rule is unit-testable without
/// a real key or a real build.
///
/// - Every mode: the Supabase URL, the publishable key and the API base URL must
///   be present (the pre-existing rule; a dev build against
///   `http://10.0.2.2:8000` is unaffected).
/// - Release additionally: both URLs must be https and public, and any legal URL
///   that is configured must be a public https URL.
List<EnvProblem> findEnvProblems({
  required String supabaseUrl,
  required String supabasePublishableKey,
  required String apiBaseUrl,
  required bool isRelease,
  String legalPrivacyUrl = '',
  String legalTermsUrl = '',
}) {
  final problems = <EnvProblem>[];

  if (supabaseUrl.trim().isEmpty) problems.add(EnvProblem.missingSupabaseUrl);
  if (supabasePublishableKey.trim().isEmpty) {
    problems.add(EnvProblem.missingSupabasePublishableKey);
  }
  if (apiBaseUrl.trim().isEmpty) problems.add(EnvProblem.missingApiBaseUrl);

  if (isRelease) {
    _checkReleaseUrl(
      supabaseUrl,
      notHttps: EnvProblem.supabaseUrlNotHttps,
      isLocal: EnvProblem.supabaseUrlIsLocal,
      problems: problems,
    );
    _checkReleaseUrl(
      apiBaseUrl,
      notHttps: EnvProblem.apiBaseUrlNotHttps,
      isLocal: EnvProblem.apiBaseUrlIsLocal,
      problems: problems,
    );
    for (final legal in [legalPrivacyUrl, legalTermsUrl]) {
      if (legal.trim().isNotEmpty && parsePublicHttpsUrl(legal) == null) {
        problems.add(EnvProblem.invalidLegalUrl);
      }
    }
  }

  return problems;
}

void _checkReleaseUrl(
  String raw, {
  required EnvProblem notHttps,
  required EnvProblem isLocal,
  required List<EnvProblem> problems,
}) {
  if (raw.trim().isEmpty) return; // already reported as missing
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    problems.add(notHttps);
    return;
  }
  if (isLocalOrPrivateHost(uri.host)) problems.add(isLocal);
}
