import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/domain/profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  final Map<String, Profile> profiles = {};

  /// The fake's stand-in for "whichever user is currently signed in" —
  /// mirrors the real repository reading `auth.currentUser` internally.
  String? currentUserId;

  ProfileFailureCode? setUsernameError;

  /// Set by a test to simulate a transient network/Postgrest failure —
  /// something the fake otherwise never does, unlike the real repository
  /// against a live backend.
  Object? getProfileError;

  void seed(Profile profile) => profiles[profile.id] = profile;

  @override
  Future<Profile?> getProfile(String userId) async {
    if (getProfileError != null) throw getProfileError!;
    return profiles[userId];
  }

  @override
  Future<void> setUsername(String username) async {
    if (setUsernameError != null) throw ProfileFailure(setUsernameError!);
    final id = currentUserId;
    if (id == null) throw const ProfileFailure(ProfileFailureCode.unknown);
    final existing = profiles[id];
    profiles[id] = Profile(
      id: id,
      username: username,
      displayName: existing?.displayName,
    );
  }
}
