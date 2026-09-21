import 'package:beerapp/core/logging/debug_log.dart';
import 'package:flutter_test/flutter_test.dart';

const _jwt =
    'eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIn0.c2lnbmF0dXJlLXBhcnQ';

void main() {
  late List<String> lines;

  setUp(() {
    lines = [];
    DebugLog.sink = lines.add;
  });
  tearDown(DebugLog.reset);

  group('sanitizeForLog', () {
    test('removes URLs including their query (the auth code)', () {
      final cleaned = sanitizeForLog(
        'failed for com.carlossalazarmorales.beerapp://login-callback?code=abc123&type=recovery',
      );

      expect(cleaned, isNot(contains('abc123')));
      expect(cleaned, isNot(contains('login-callback')));
      expect(cleaned, contains('<url>'));
    });

    test('removes https URLs with credentials or parameters', () {
      final cleaned = sanitizeForLog(
        'GET https://user:pw@api.example.com/beers?token=secret failed',
      );

      expect(cleaned, isNot(contains('pw@')));
      expect(cleaned, isNot(contains('secret')));
    });

    test('removes JWTs and bearer tokens', () {
      expect(
        sanitizeForLog('token $_jwt was rejected'),
        isNot(contains('eyJ')),
      );
      expect(
        sanitizeForLog('Authorization: Bearer abc.DEF-123_xyz'),
        isNot(contains('abc.DEF')),
      );
      expect(
        sanitizeForLog('header bearer sometoken123'),
        isNot(contains('sometoken123')),
      );
    });

    test('removes key=value secrets and Supabase key prefixes', () {
      const secrets = {
        'access_token=VALUE1': 'VALUE1',
        'refresh_token: VALUE2': 'VALUE2',
        'apikey=VALUE3': 'VALUE3',
        'password=VALUE4': 'VALUE4',
        'code=VALUE5': 'VALUE5',
        'secret=VALUE6': 'VALUE6',
      };
      secrets.forEach((text, secret) {
        final cleaned = sanitizeForLog(text);
        expect(cleaned, contains('<redacted>'), reason: text);
        expect(cleaned, isNot(contains(secret)), reason: text);
      });
      expect(
        sanitizeForLog('key sb_secret_AbCd-1234 and sb_publishable_XyZ'),
        isNot(contains('AbCd')),
      );
    });

    test('leaves ordinary text alone', () {
      expect(
        sanitizeForLog('profile fetch failed: SocketException'),
        'profile fetch failed: SocketException',
      );
    });
  });

  group('DebugLog', () {
    test('writes nothing when disabled (release builds)', () {
      DebugLog.enabled = () => false;

      DebugLog.message('auth', 'hello');
      DebugLog.error('auth', 'failed', StateError('boom'), StackTrace.current);

      expect(lines, isEmpty);
    });

    test('is enabled in debug builds by default', () {
      // flutter test runs in debug mode, where kDebugMode is true.
      DebugLog.message('auth', 'hello');

      expect(lines, ['[auth] hello']);
    });

    test('logs an error as its type plus a sanitized description', () {
      DebugLog.enabled = () => true;

      DebugLog.error(
        'auth',
        'link rejected',
        Exception('bad link com.example://cb?code=SECRET'),
      );

      expect(lines, hasLength(1));
      expect(lines.single, startsWith('[auth] link rejected: _Exception: '));
      expect(lines.single, isNot(contains('SECRET')));
    });

    test('sanitizes stack traces too', () {
      DebugLog.enabled = () => true;

      DebugLog.error(
        'auth',
        'x',
        StateError('e'),
        StackTrace.fromString('#0 f (https://host/path?token=SECRET:1:1)'),
      );

      expect(lines.join('\n'), isNot(contains('SECRET')));
    });

    test('sanitizes plain messages', () {
      DebugLog.message('auth', 'redirect https://x.example/cb?code=SECRET');

      expect(lines.single, isNot(contains('SECRET')));
    });
  });
}
