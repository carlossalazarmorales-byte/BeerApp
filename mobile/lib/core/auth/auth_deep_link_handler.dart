import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../logging/debug_log.dart';

/// The subset of `app_links`' [AppLinks] this handler needs, so tests can
/// supply a fake instead of a real platform channel.
abstract class DeepLinkSource {
  /// The link that launched the app (cold start), or null if none did.
  /// Per `app_links` guidance this reflects the *current* launch only —
  /// safe to call more than once, but there's nothing new to find after
  /// the first non-null result of a given app process.
  Future<Uri?> getInitialLink();

  /// Links received while the app is already running (warm start).
  Stream<Uri> get uriLinkStream;
}

class AppLinksDeepLinkSource implements DeepLinkSource {
  final AppLinks _appLinks = AppLinks();

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

/// Explicitly captures and exchanges Supabase auth deep links (email
/// confirmation, password recovery) instead of relying on supabase_flutter's
/// built-in automatic URI detection.
///
/// Why: with automatic detection (`detectSessionInUri: true`, the default),
/// a cold-start deep link is exchanged by supabase_flutter as part of
/// `Supabase.initialize()` itself — before app code has had any chance to
/// attach an `onAuthStateChange` listener, so the resulting
/// `passwordRecovery` event (and therefore the app's redirect to
/// `/reset-password`) can be silently missed. This is a documented
/// upstream race: https://github.com/supabase/supabase-flutter/issues/937.
///
/// `main.dart` disables automatic detection
/// (`FlutterAuthClientOptions(detectSessionInUri: false)`) and constructs
/// this handler only *after* `AuthController` already exists and has
/// subscribed to `onAuthStateChange` — removing the race entirely, since
/// nothing exchanges a deep link before our own listener is in place.
/// `getSessionFromUrl` is the exact same PKCE-aware exchange
/// supabase_flutter's automatic path uses internally; this only changes
/// *when* it's called, not how.
class AuthDeepLinkHandler {
  AuthDeepLinkHandler({
    DeepLinkSource? source,
    Future<void> Function(Uri uri)? exchangeSessionFromUrl,
  }) : _source = source ?? AppLinksDeepLinkSource(),
       _exchangeSessionFromUrl =
           exchangeSessionFromUrl ??
           ((uri) => Supabase.instance.client.auth.getSessionFromUrl(uri)) {
    _start();
  }

  final DeepLinkSource _source;

  /// Only this one method is injectable (rather than a whole fake
  /// `GoTrueClient`, which would mean implementing its entire large
  /// interface) — it's the only Supabase call this class makes.
  final Future<void> Function(Uri uri) _exchangeSessionFromUrl;
  StreamSubscription<Uri>? _subscription;

  /// Guards against exchanging the same link twice — a launch link can
  /// otherwise surface both from [DeepLinkSource.getInitialLink] and as
  /// the first event on [DeepLinkSource.uriLinkStream] depending on
  /// platform timing, and a one-time PKCE code would fail (harmlessly, but
  /// noisily) the second time regardless.
  Uri? _lastHandledUri;

  void _start() {
    // Warm start: listen before awaiting the (possibly slower) initial
    // link lookup below, so nothing received in between is missed.
    _subscription = _source.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        DebugLog.error('auth', 'deep link stream error', error);
      },
    );

    unawaited(_handleInitialLink());
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _source.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (error) {
      DebugLog.error('auth', 'getInitialLink failed', error);
    }
  }

  Future<void> _handleUri(Uri uri) async {
    if (!_isAuthCallback(uri)) return;
    if (uri == _lastHandledUri) return;
    _lastHandledUri = uri;

    try {
      await _exchangeSessionFromUrl(uri);
    } on AuthException catch (error) {
      // Invalid/expired/already-used recovery or confirmation links land
      // here. Fail safely: no crash, no state change. Debug builds only, and
      // sanitized (DebugLog strips URLs, tokens and codes) -- the link itself
      // carries a one-time auth code and is never logged.
      DebugLog.error('auth', 'link rejected', error);
    } catch (error) {
      DebugLog.error('auth', 'getSessionFromUrl failed', error);
    }
  }

  /// Matches scheme, host and path against [Env.authRedirectUri] — a
  /// shared custom scheme alone doesn't prove a link is ours (nothing
  /// prevents another app, or a crafted link, from reusing the same
  /// scheme with a different host). Query/fragment are intentionally
  /// ignored: those legitimately vary per request (the one-time code,
  /// event type, etc.) — only the fixed origin needs to match exactly.
  bool _isAuthCallback(Uri uri) {
    final expected = Env.authRedirectUri;
    return uri.scheme == expected.scheme &&
        uri.host == expected.host &&
        uri.path == expected.path;
  }

  void dispose() {
    unawaited(_subscription?.cancel());
  }
}
