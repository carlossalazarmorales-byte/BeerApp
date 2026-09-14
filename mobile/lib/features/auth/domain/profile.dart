/// Mirrors the Phase 2 `public.profiles` row. `avatar_url` and
/// `preferred_language` are deliberately not modeled — nothing in Phase 2
/// reads or writes them (see docs/DATABASE.md).
class Profile {
  const Profile({required this.id, this.username, this.displayName});

  final String id;
  final String? username;
  final String? displayName;

  /// A username is the one thing that must be set before the shell is
  /// reachable — see the `/complete-profile` gate in the router.
  bool get isComplete => username != null && username!.isNotEmpty;
}

enum ProfileFailureCode { usernameTaken, invalidUsername, network, unknown }

class ProfileFailure implements Exception {
  const ProfileFailure(this.code);

  final ProfileFailureCode code;

  @override
  String toString() => 'ProfileFailure($code)';
}
