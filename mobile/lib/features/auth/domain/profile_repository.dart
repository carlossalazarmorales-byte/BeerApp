import 'profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getProfile(String userId);

  /// Sets the current user's username. The database's partial unique index
  /// on `username` (see supabase/migrations) is the actual source of truth
  /// for uniqueness — implementations must surface a `23505` violation as
  /// `ProfileFailure(ProfileFailureCode.usernameTaken)` rather than doing a
  /// separate check-then-insert.
  Future<void> setUsername(String username);
}
