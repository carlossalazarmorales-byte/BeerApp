import 'profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getProfile(String userId);

  /// Sets the current user's username. The database's partial unique index
  /// on `username` (see supabase/migrations) is the actual source of truth
  /// for uniqueness — implementations must surface a `23505` violation as
  /// `ProfileFailure(ProfileFailureCode.usernameTaken)` rather than doing a
  /// separate check-then-insert.
  ///
  /// Kept for the onboarding `CompleteProfileScreen` flow, which only ever
  /// writes a username. Phase 12's Edit Profile screen uses
  /// [updateEditableProfile] instead — never this method — so username and
  /// display name are always written together, atomically.
  Future<void> setUsername(String username);

  /// Updates username and display name together as ONE write, so a
  /// duplicate-username failure can never leave `display_name` changed
  /// while `username` silently didn't update (or vice versa). Always pass
  /// the full desired state — there is no partial/independent
  /// display-name-only write path. Same uniqueness/format error mapping as
  /// [setUsername] (`usernameTaken` / `invalidUsername`), since
  /// `display_name` itself has no format constraint.
  Future<void> updateEditableProfile({
    required String username,
    String? displayName,
  });

  /// Sets or clears (`null`) the current user's preferred currency. The
  /// database's CHECK constraint (see supabase/migrations) is the actual
  /// source of truth for the `^[A-Z]{3}$` shape — implementations must
  /// surface a `23514` violation as
  /// `ProfileFailure(ProfileFailureCode.invalidCurrency)`.
  Future<void> setPreferredCurrency(String? currency);
}
