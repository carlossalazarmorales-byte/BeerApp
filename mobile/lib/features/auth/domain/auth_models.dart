/// A signed-in Supabase user, reduced to what the app layer needs — keeps
/// Supabase's `User` type out of the domain/presentation layers.
class AppUser {
  const AppUser({required this.id, this.email});

  final String id;

  /// Nullable because Supabase's own `User.email` is nullable (not every
  /// auth method populates it), even though both methods this app supports
  /// today (email/password, Google ID-token) do in practice. Added in
  /// Phase 12 so Settings' "Change password" row can trigger the existing
  /// reset-email flow without asking the user to retype their address.
  final String? email;
}

/// Auth events the app actually reacts to. Supabase emits several other
/// `AuthChangeEvent` values (token refresh, initial session, ...) that
/// [AuthRepository] implementations filter out before they reach here.
enum AuthEvent { signedIn, signedOut, passwordRecovery }

enum AuthFailureCode {
  invalidCredentials,
  weakPassword,

  /// Maps Supabase Auth's structured `same_password` error code — the new
  /// password matches the current one. Kept distinct from [weakPassword]
  /// so the UI can show a specific, correct message instead of the
  /// generic one.
  samePassword,
  network,

  /// A sign-in method exists in the UI/interface but its provider isn't
  /// configured yet (currently: Google, until Step F). Distinct from
  /// [unknown] so the UI can show "not available yet" instead of a generic
  /// error.
  providerNotConfigured,

  /// The user dismissed the Google account picker. Distinct from [unknown]
  /// so the UI can reset silently instead of showing an error message.
  cancelled,
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
