import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final supabase.SupabaseClient _client;

  static const String _table = 'profiles';

  @override
  Future<Profile?> getProfile(String userId) async {
    final row = await _client
        .from(_table)
        .select('id, username, display_name, preferred_currency')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return Profile(
      id: row['id'] as String,
      username: row['username'] as String?,
      displayName: row['display_name'] as String?,
      preferredCurrency: row['preferred_currency'] as String?,
    );
  }

  @override
  Future<void> setUsername(String username) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileFailure(ProfileFailureCode.unknown);
    }

    // Normalized here, once, so every write path (not just this one call
    // site) stores the same canonical form the database CHECK constraint
    // expects — the constraint remains the actual source of truth.
    final normalized = username.trim().toLowerCase();

    try {
      await _client
          .from(_table)
          .update({'username': normalized})
          .eq('id', userId);
    } on supabase.PostgrestException catch (error) {
      throw ProfileFailure(mapUsernameWriteError(error));
    }
  }

  @override
  Future<void> updateEditableProfile({
    required String username,
    String? displayName,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileFailure(ProfileFailureCode.unknown);
    }

    final normalizedUsername = username.trim().toLowerCase();
    final trimmedDisplayName = displayName?.trim();
    // Empty (post-trim) display name is written as null, never an empty
    // string — matches the column's existing nullable-free-text semantics
    // (see docs/DATABASE.md).
    final normalizedDisplayName =
        (trimmedDisplayName == null || trimmedDisplayName.isEmpty)
        ? null
        : trimmedDisplayName;

    try {
      // ONE Postgrest .update() call, never two sequential writes — a
      // duplicate-username failure can never leave display_name partially
      // changed while username silently didn't update, or vice versa.
      await _client
          .from(_table)
          .update({
            'username': normalizedUsername,
            'display_name': normalizedDisplayName,
          })
          .eq('id', userId);
    } on supabase.PostgrestException catch (error) {
      // The username CHECK/unique index is still the only constraint that
      // can fire here — display_name has none — so the same mapping as
      // setUsername applies.
      throw ProfileFailure(mapUsernameWriteError(error));
    }
  }

  @override
  Future<void> setPreferredCurrency(String? currency) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileFailure(ProfileFailureCode.unknown);
    }

    try {
      await _client
          .from(_table)
          .update({'preferred_currency': currency})
          .eq('id', userId);
    } on supabase.PostgrestException catch (error) {
      throw ProfileFailure(mapPreferredCurrencyWriteError(error));
    }
  }

  /// Structured Postgres error code, not string matching — factored out as
  /// its own testable function (mirrors
  /// `SupabaseAuthRepository.mapUpdatePasswordError`) so the mapping can be
  /// verified without a live Supabase call. Shared by [setUsername] and
  /// [updateEditableProfile] since both write `username` against the same
  /// constraints.
  @visibleForTesting
  static ProfileFailureCode mapUsernameWriteError(
    supabase.PostgrestException error,
  ) {
    switch (error.code) {
      case '23505':
        return ProfileFailureCode.usernameTaken;
      case '23514':
        return ProfileFailureCode.invalidUsername;
      default:
        return ProfileFailureCode.network;
    }
  }

  @visibleForTesting
  static ProfileFailureCode mapPreferredCurrencyWriteError(
    supabase.PostgrestException error,
  ) {
    switch (error.code) {
      case '23514':
        return ProfileFailureCode.invalidCurrency;
      default:
        return ProfileFailureCode.network;
    }
  }
}
