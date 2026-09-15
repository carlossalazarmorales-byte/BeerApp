import 'access_token_provider.dart';
import 'supabase_session_source.dart';

/// Reads the current Supabase session's access token, refreshing first when
/// the locally restored session is expired (or about to be) — a locally
/// restored session is not guaranteed fresh at app start. Concurrent callers
/// during a refresh share a single in-flight `refreshSession()` call rather
/// than each triggering their own (a beer-list screen can fire
/// countries/styles/beers requests together, all needing a token at once).
///
/// Never logs the access token or refresh token.
class SupabaseAccessTokenProvider implements AccessTokenProvider {
  SupabaseAccessTokenProvider(this._sessionSource);

  final SessionSource _sessionSource;

  Future<String?>? _inFlightRefresh;

  @override
  Future<String?> getAccessToken() async {
    final session = _sessionSource.currentSession;
    if (session == null) return null;
    if (!session.isExpired) return session.accessToken;

    return _inFlightRefresh ??= _refresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<String?> _refresh() async {
    try {
      final refreshed = await _sessionSource.refreshSession();
      return refreshed?.accessToken;
    } catch (_) {
      // Any refresh failure (an auth-specific rejection, a network hiccup,
      // anything) means "no usable session" -- never let a raw exception
      // escape getAccessToken(); ApiClient doesn't wrap this call in its
      // own try/catch.
      return null;
    }
  }
}
