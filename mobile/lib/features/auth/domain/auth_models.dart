/// A signed-in Supabase user, reduced to what the app layer needs — keeps
/// Supabase's `User` type out of the domain/presentation layers.
class AppUser {
  const AppUser({required this.id});

  final String id;
}

/// Auth events the app actually reacts to. Supabase emits several other
/// `AuthChangeEvent` values (token refresh, initial session, ...) that
/// [AuthRepository] implementations filter out before they reach here.
enum AuthEvent { signedIn, signedOut, passwordRecovery }

enum AuthFailureCode {
  invalidCredentials,
  weakPassword,
  network,

  /// A sign-in method exists in the UI/interface but its provider isn't
  /// configured yet (currently: Google, until Step F). Distinct from
  /// [unknown] so the UI can show "not available yet" instead of a generic
  /// error.
  providerNotConfigured,
  unknown,
}

/// Domain-level auth error. UI maps [code] to a localized string — raw
/// GoTrue error text is never shown to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  @override
  String toString() => 'AuthFailure($code)';
}
