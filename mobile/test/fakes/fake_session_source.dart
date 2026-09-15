import 'dart:convert';

import 'package:beerapp/core/network/supabase_session_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a syntactically valid (unsigned) JWT string with the given `exp`
/// claim (seconds since epoch) -- [Session.isExpired] decodes this locally
/// without verifying the signature, so a real Supabase-issued token isn't
/// needed to control its expiry in tests.
String fakeAccessToken({required int exp}) {
  String segment(Object payload) =>
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '${segment({'alg': 'none'})}.${segment({'exp': exp})}.sig';
}

Session fakeSession({required bool expired}) {
  final exp = expired
      ? DateTime.now().subtract(const Duration(minutes: 5))
      : DateTime.now().add(const Duration(hours: 1));
  return Session(
    accessToken: fakeAccessToken(
      exp: exp.toUtc().millisecondsSinceEpoch ~/ 1000,
    ),
    tokenType: 'bearer',
    user: const User(
      id: 'user-1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
}

class FakeSessionSource implements SessionSource {
  Session? session;
  Session? refreshedSession;
  Object? refreshError;
  int refreshCallCount = 0;

  @override
  Session? get currentSession => session;

  @override
  Future<Session?> refreshSession() async {
    refreshCallCount += 1;
    final error = refreshError;
    if (error != null) throw error;
    return refreshedSession;
  }
}
