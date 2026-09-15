import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin seam around `supabase_flutter`'s session/refresh calls, so
/// [SupabaseAccessTokenProvider]'s expiry and single-flight-refresh logic is
/// testable with a fake instead of a live Supabase client.
abstract class SessionSource {
  Session? get currentSession;

  Future<Session?> refreshSession();
}

class SupabaseSessionSource implements SessionSource {
  SupabaseSessionSource(this._client);

  final SupabaseClient _client;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Future<Session?> refreshSession() async =>
      (await _client.auth.refreshSession()).session;
}
