import 'dart:convert';
import 'dart:io';

import 'package:beerapp/core/config/env.dart';
import 'package:beerapp/core/config/env_validator.dart';
import 'package:flutter_test/flutter_test.dart';

const _supabaseUrl = 'https://abc.supabase.co';
const _key = 'sb_publishable_test_only';

List<EnvProblem> _problems({
  String supabaseUrl = _supabaseUrl,
  String key = _key,
  String apiBaseUrl = 'https://api.example.com',
  bool isRelease = true,
  String privacy = '',
  String terms = '',
}) => findEnvProblems(
  supabaseUrl: supabaseUrl,
  supabasePublishableKey: key,
  apiBaseUrl: apiBaseUrl,
  isRelease: isRelease,
  legalPrivacyUrl: privacy,
  legalTermsUrl: terms,
);

Map<String, dynamic> _configFile(String name) =>
    jsonDecode(File('config/$name').readAsStringSync()) as Map<String, dynamic>;

List<EnvProblem> _problemsFor(Map<String, dynamic> config, bool isRelease) =>
    findEnvProblems(
      supabaseUrl: config['SUPABASE_URL'] as String,
      supabasePublishableKey: config['SUPABASE_PUBLISHABLE_KEY'] as String,
      apiBaseUrl: config['API_BASE_URL'] as String,
      legalPrivacyUrl: (config['LEGAL_PRIVACY_URL'] as String?) ?? '',
      legalTermsUrl: (config['LEGAL_TERMS_URL'] as String?) ?? '',
      isRelease: isRelease,
    );

void main() {
  group('required values (every build mode)', () {
    for (final isRelease in [false, true]) {
      test('a complete configuration is valid (release: $isRelease)', () {
        expect(_problems(isRelease: isRelease), isEmpty);
      });

      test('reports each missing value by name (release: $isRelease)', () {
        expect(
          _problems(
            supabaseUrl: '',
            key: '',
            apiBaseUrl: '',
            isRelease: isRelease,
          ),
          [
            EnvProblem.missingSupabaseUrl,
            EnvProblem.missingSupabasePublishableKey,
            EnvProblem.missingApiBaseUrl,
          ],
        );
      });

      test('whitespace-only values count as missing (release: $isRelease)', () {
        expect(
          _problems(key: '   ', isRelease: isRelease),
          contains(EnvProblem.missingSupabasePublishableKey),
        );
      });
    }
  });

  group('development workflows keep working (not a release build)', () {
    test('the documented emulator config is accepted', () {
      expect(
        _problems(apiBaseUrl: 'http://10.0.2.2:8000', isRelease: false),
        isEmpty,
      );
    });

    test('localhost, a LAN address and plain http are all accepted', () {
      for (final url in [
        'http://localhost:8000',
        'http://127.0.0.1:8000',
        'http://192.168.1.20:8000',
      ]) {
        expect(
          _problems(apiBaseUrl: url, isRelease: false),
          isEmpty,
          reason: url,
        );
      }
    });

    test('a local Supabase stack over http is accepted', () {
      expect(
        _problems(supabaseUrl: 'http://127.0.0.1:54321', isRelease: false),
        isEmpty,
      );
    });

    test('an invalid legal URL is ignored in debug (placeholder is used)', () {
      expect(_problems(isRelease: false, privacy: 'http://nope'), isEmpty);
    });
  });

  group('release builds require public https', () {
    test('cleartext http is rejected for the API and for Supabase', () {
      expect(_problems(apiBaseUrl: 'http://api.example.com'), [
        EnvProblem.apiBaseUrlNotHttps,
      ]);
      expect(_problems(supabaseUrl: 'http://abc.supabase.co'), [
        EnvProblem.supabaseUrlNotHttps,
      ]);
    });

    test('the emulator alias over http is reported as not https', () {
      expect(
        _problems(apiBaseUrl: 'http://10.0.2.2:8000'),
        contains(EnvProblem.apiBaseUrlNotHttps),
      );
    });

    const localHosts = [
      'localhost',
      'LOCALHOST',
      'app.localhost',
      '127.0.0.1',
      '127.9.9.9',
      '10.0.2.2', // the Android emulator's alias for the host machine
      '10.1.2.3',
      '192.168.0.10',
      '172.16.0.1',
      '172.31.255.255',
      '169.254.10.10',
      '100.64.0.1',
      '0.0.0.0',
      '[::1]',
      '[fd00::1]',
      '[fe80::1]',
      'printer.local',
      'db.internal',
      'intranet',
    ];
    for (final host in localHosts) {
      test('https://$host is rejected as a local address', () {
        expect(_problems(apiBaseUrl: 'https://$host:8000'), [
          EnvProblem.apiBaseUrlIsLocal,
        ]);
        expect(_problems(supabaseUrl: 'https://$host'), [
          EnvProblem.supabaseUrlIsLocal,
        ]);
      });
    }

    const publicHosts = [
      'api.example.com',
      'abc.supabase.co',
      '8.8.8.8',
      '172.15.0.1', // just below 172.16.0.0/12
      '172.32.0.1', // just above it
      '11.0.0.1',
      '192.169.0.1',
    ];
    for (final host in publicHosts) {
      test('https://$host is accepted as public', () {
        expect(_problems(apiBaseUrl: 'https://$host'), isEmpty);
      });
    }

    test('a malformed URL is reported, never thrown', () {
      for (final url in ['not a url', 'https://', '://x', 'ftp://x.com']) {
        expect(
          _problems(apiBaseUrl: url),
          contains(EnvProblem.apiBaseUrlNotHttps),
          reason: url,
        );
      }
    });

    test('every problem is reported together', () {
      expect(
        _problems(
          supabaseUrl: 'http://localhost:54321',
          apiBaseUrl: 'http://10.0.2.2:8000',
        ),
        [EnvProblem.supabaseUrlNotHttps, EnvProblem.apiBaseUrlNotHttps],
      );
    });

    test('a set legal URL must be public https; unset is fine', () {
      expect(_problems(), isEmpty);
      expect(
        _problems(
          privacy: 'https://legal.example.com/privacy',
          terms: 'https://legal.example.com/terms',
        ),
        isEmpty,
      );
      expect(_problems(privacy: 'http://legal.example.com/privacy'), [
        EnvProblem.invalidLegalUrl,
      ]);
      expect(_problems(terms: 'https://localhost/terms'), [
        EnvProblem.invalidLegalUrl,
      ]);
    });
  });

  group('isLocalOrPrivateHost', () {
    test('is case-insensitive and trims', () {
      expect(isLocalOrPrivateHost(' LocalHost '), isTrue);
      expect(isLocalOrPrivateHost(''), isTrue);
    });

    test('public names are not local', () {
      expect(isLocalOrPrivateHost('www.example.org'), isFalse);
    });
  });

  group('parsePublicHttpsUrl', () {
    test('accepts a plain public https URL and trims it', () {
      expect(
        parsePublicHttpsUrl('  https://example.com/privacy?lang=en '),
        Uri.parse('https://example.com/privacy?lang=en'),
      );
    });

    test('rejects everything else', () {
      for (final raw in [
        '',
        '   ',
        'example.com/privacy',
        'http://example.com',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://x#Intent;end',
        'https://user:pass@example.com/p',
        'https://localhost/p',
        'https://192.168.1.1/p',
        'https:///path',
        'not a url',
      ]) {
        expect(parsePublicHttpsUrl(raw), isNull, reason: raw);
      }
    });
  });

  group('EnvConfigException', () {
    test('describes only problem names -- never a configured value', () {
      const exception = EnvConfigException([
        EnvProblem.apiBaseUrlIsLocal,
        EnvProblem.missingSupabasePublishableKey,
      ]);

      final text = exception.toString();
      expect(text, contains('apiBaseUrlIsLocal'));
      expect(text, contains('missingSupabasePublishableKey'));
      expect(text, isNot(contains('http')));
      expect(text, isNot(contains('sb_')));
    });
  });

  group('Env.validate() in this (non-release) test run', () {
    test('throws EnvConfigException listing the missing values', () {
      // `flutter test` passes no --dart-define values, so all three are unset.
      expect(
        Env.validate,
        throwsA(
          isA<EnvConfigException>().having((e) => e.problems, 'problems', [
            EnvProblem.missingSupabaseUrl,
            EnvProblem.missingSupabasePublishableKey,
            EnvProblem.missingApiBaseUrl,
          ]),
        ),
      );
    });
  });

  group('the checked-in configuration examples', () {
    test('dev.example.json is a valid debug config but can NOT be shipped', () {
      final dev = _configFile('dev.example.json');

      expect(_problemsFor(dev, false), isEmpty);
      expect(
        _problemsFor(dev, true),
        contains(EnvProblem.apiBaseUrlNotHttps),
        reason: 'a release built from the dev config must refuse to start',
      );
    });

    test('release.example.json satisfies the release guard once filled in', () {
      final release = _configFile('release.example.json');

      expect(_problemsFor(release, true), isEmpty);
      expect(_problemsFor(release, false), isEmpty);
    });

    test('both examples define the same keys', () {
      expect(
        _configFile('release.example.json').keys.toSet(),
        _configFile('dev.example.json').keys.toSet(),
      );
    });

    test('the examples hold only placeholders, no real-looking secrets', () {
      for (final name in ['dev.example.json', 'release.example.json']) {
        final text = File('config/$name').readAsStringSync();
        expect(text, isNot(contains('eyJ')), reason: name);
        expect(text, isNot(matches(RegExp(r'sb_secret_'))), reason: name);
        expect(text, contains('your-'), reason: '$name should be placeholders');
      }
    });
  });
}
