/// Mirrors the `public.profiles` row. `preferred_currency` was added in
/// Phase 12. `avatar_url` and a server-side language preference are
/// deliberately still not modeled — avatar is deferred entirely, and
/// language is a local-only device preference (see
/// `core/locale/locale_controller.dart`), not a profiles column. See
/// docs/DATABASE.md.
class Profile {
  const Profile({
    required this.id,
    this.username,
    this.displayName,
    this.preferredCurrency,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? preferredCurrency;

  /// A username is the one thing that must be set before the shell is
  /// reachable — see the `/complete-profile` gate in the router.
  bool get isComplete => username != null && username!.isNotEmpty;
}

/// Shared canonical username rule — trimmed + lowercased, 3-20 chars,
/// `[a-z0-9_]` — matching `profiles_username_format` (see
/// supabase/migrations). Used by both the onboarding CompleteProfileScreen
/// and Phase 12's EditProfileScreen so the two never drift apart.
final RegExp usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

enum ProfileFailureCode {
  usernameTaken,
  invalidUsername,
  invalidCurrency,
  network,
  unknown,
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.code);

  final ProfileFailureCode code;

  @override
  String toString() => 'ProfileFailure($code)';
}
