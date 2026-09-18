import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/domain/profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  final Map<String, Profile> profiles = {};

  /// The fake's stand-in for "whichever user is currently signed in" —
  /// mirrors the real repository reading `auth.currentUser` internally.
  String? currentUserId;

  ProfileFailureCode? setUsernameError;
  ProfileFailureCode? updateEditableProfileError;
  ProfileFailureCode? setPreferredCurrencyError;

  /// Set by a test to simulate a transient network/Postgrest failure —
  /// something the fake otherwise never does, unlike the real repository
  /// against a live backend.
  Object? getProfileError;

  /// Records call order -- e.g. `updateEditableProfile`,
  /// `setPreferredCurrency`. Lets a test assert a screen performs exactly
  /// one write (never two independent sequential ones) per save.
  final List<String> callLog = [];

  void seed(Profile profile) => profiles[profile.id] = profile;

  @override
  Future<Profile?> getProfile(String userId) async {
    if (getProfileError != null) throw getProfileError!;
    return profiles[userId];
  }

  @override
  Future<void> setUsername(String username) async {
    callLog.add('setUsername');
    if (setUsernameError != null) throw ProfileFailure(setUsernameError!);
    final id = currentUserId;
    if (id == null) throw const ProfileFailure(ProfileFailureCode.unknown);
    final existing = profiles[id];
    profiles[id] = Profile(
      id: id,
      username: username,
      displayName: existing?.displayName,
      preferredCurrency: existing?.preferredCurrency,
    );
  }

  @override
  Future<void> updateEditableProfile({
    required String username,
    String? displayName,
  }) async {
    callLog.add('updateEditableProfile');
    if (updateEditableProfileError != null) {
      throw ProfileFailure(updateEditableProfileError!);
    }
    final id = currentUserId;
    if (id == null) throw const ProfileFailure(ProfileFailureCode.unknown);
    final existing = profiles[id];
    // Both fields written together, never partially — mirrors the real
    // repository's single-statement atomicity.
    profiles[id] = Profile(
      id: id,
      username: username,
      displayName: displayName,
      preferredCurrency: existing?.preferredCurrency,
    );
  }

  @override
  Future<void> setPreferredCurrency(String? currency) async {
    callLog.add('setPreferredCurrency');
    if (setPreferredCurrencyError != null) {
      throw ProfileFailure(setPreferredCurrencyError!);
    }
    final id = currentUserId;
    if (id == null) throw const ProfileFailure(ProfileFailureCode.unknown);
    final existing = profiles[id];
    profiles[id] = Profile(
      id: id,
      username: existing?.username,
      displayName: existing?.displayName,
      preferredCurrency: currency,
    );
  }
}
