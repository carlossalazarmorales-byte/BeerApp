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
        .select('id, username, display_name')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return Profile(
      id: row['id'] as String,
      username: row['username'] as String?,
      displayName: row['display_name'] as String?,
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
      switch (error.code) {
        case '23505':
          throw const ProfileFailure(ProfileFailureCode.usernameTaken);
        case '23514':
          throw const ProfileFailure(ProfileFailureCode.invalidUsername);
        default:
          throw const ProfileFailure(ProfileFailureCode.network);
      }
    }
  }
}
