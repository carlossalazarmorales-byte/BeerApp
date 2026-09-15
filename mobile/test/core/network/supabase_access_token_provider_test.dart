import 'package:beerapp/core/network/supabase_access_token_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_session_source.dart';

void main() {
  test(
    'valid, non-expired session: returns its token, never refreshes',
    () async {
      final sessionSource = FakeSessionSource()
        ..session = fakeSession(expired: false);
      final provider = SupabaseAccessTokenProvider(sessionSource);

      final token = await provider.getAccessToken();

      expect(token, sessionSource.session!.accessToken);
      expect(sessionSource.refreshCallCount, 0);
    },
  );

  test('no session: returns null, never refreshes', () async {
    final sessionSource = FakeSessionSource();
    final provider = SupabaseAccessTokenProvider(sessionSource);

    final token = await provider.getAccessToken();

    expect(token, isNull);
    expect(sessionSource.refreshCallCount, 0);
  });

  test(
    'expired session: refreshes exactly once and returns the refreshed token',
    () async {
      final refreshed = fakeSession(expired: false);
      final sessionSource = FakeSessionSource()
        ..session = fakeSession(expired: true)
        ..refreshedSession = refreshed;
      final provider = SupabaseAccessTokenProvider(sessionSource);

      final token = await provider.getAccessToken();

      expect(token, refreshed.accessToken);
      expect(sessionSource.refreshCallCount, 1);
    },
  );

  test('a failed refresh resolves to null rather than throwing', () async {
    final sessionSource = FakeSessionSource()
      ..session = fakeSession(expired: true)
      ..refreshError = Exception('refresh failed');
    final provider = SupabaseAccessTokenProvider(sessionSource);

    final token = await provider.getAccessToken();

    expect(token, isNull);
    expect(sessionSource.refreshCallCount, 1);
  });

  test('concurrent calls during an expired session share a single in-flight refresh', () async {
    final refreshed = fakeSession(expired: false);
    final sessionSource = FakeSessionSource()
      ..session = fakeSession(expired: true)
      ..refreshedSession = refreshed;
    final provider = SupabaseAccessTokenProvider(sessionSource);

    // Fired back-to-back, synchronously, before any of them has a chance to
    // resolve -- exercising the single-flight guard.
    final tokens = await Future.wait(
      List.generate(5, (_) => provider.getAccessToken()),
    );

    expect(sessionSource.refreshCallCount, 1);
    expect(tokens, List.filled(5, refreshed.accessToken));
  });
}
