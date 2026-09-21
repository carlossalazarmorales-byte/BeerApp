import 'env.dart';
import 'env_validator.dart';

/// Where the Privacy Policy and Terms of Service live. Public configuration --
/// each is a public https URL to a document the app owner hosts -- never a
/// secret. A value that is unset, malformed, not https, carries credentials, or
/// points at a local/private host is treated as **not configured** (null), so
/// the app never launches anything it cannot vouch for and never invents a URL.
class LegalConfig {
  const LegalConfig({this.privacyPolicyUri, this.termsOfServiceUri});

  /// Reads the build-time `LEGAL_PRIVACY_URL` / `LEGAL_TERMS_URL`.
  factory LegalConfig.fromEnvironment() => LegalConfig.parse(
    privacyPolicyUrl: Env.legalPrivacyUrl,
    termsOfServiceUrl: Env.legalTermsUrl,
  );

  factory LegalConfig.parse({
    required String privacyPolicyUrl,
    required String termsOfServiceUrl,
  }) => LegalConfig(
    privacyPolicyUri: parsePublicHttpsUrl(privacyPolicyUrl),
    termsOfServiceUri: parsePublicHttpsUrl(termsOfServiceUrl),
  );

  /// Null while not configured; Settings then keeps its "not available yet"
  /// placeholder for that document.
  final Uri? privacyPolicyUri;
  final Uri? termsOfServiceUri;
}
