import 'dart:async';
import 'dart:convert';

import 'package:beerapp/core/network/access_token_provider.dart';
import 'package:beerapp/core/network/api_client.dart';
import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/features/achievements/presentation/achievements_error_text.dart';
import 'package:beerapp/features/catalog/presentation/catalog_error_text.dart';
import 'package:beerapp/features/collection/presentation/collection_error_text.dart';
import 'package:beerapp/features/contributions/presentation/contribution_error_text.dart';
import 'package:beerapp/features/logging/presentation/beer_log_error_text.dart';
import 'package:beerapp/features/map/presentation/map_error_text.dart';
import 'package:beerapp/features/statistics/presentation/statistics_error_text.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Token implements AccessTokenProvider {
  @override
  Future<String?> getAccessToken() async => 'token-123';
}

ApiClient _client(
  Future<http.Response> Function(http.Request request) handler, {
  Duration? timeout,
}) {
  final httpClient = MockClient(handler);
  return timeout == null
      ? ApiClient(
          httpClient: httpClient,
          baseUrl: 'https://api.example.com',
          accessTokenProvider: _Token(),
        )
      : ApiClient(
          httpClient: httpClient,
          baseUrl: 'https://api.example.com',
          accessTokenProvider: _Token(),
          requestTimeout: timeout,
        );
}

/// A request that never completes (a stalled connection).
Future<http.Response> _stalled(http.Request _) =>
    Completer<http.Response>().future;

http.Response _envelope(int status, String code, String message) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'message': message},
      }),
      status,
    );

void main() {
  group('request timeout', () {
    const short = Duration(milliseconds: 40);

    test('the default is finite and generous enough for a slow connection', () {
      expect(defaultApiRequestTimeout, greaterThan(const Duration(seconds: 5)));
      expect(
        defaultApiRequestTimeout,
        lessThanOrEqualTo(const Duration(seconds: 60)),
      );
    });

    test(
      'a stalled GET fails with TimeoutApiException instead of hanging',
      () async {
        final client = _client(_stalled, timeout: short);

        await expectLater(
          client.getJson('/beers'),
          throwsA(isA<TimeoutApiException>()),
        );
      },
    );

    test('every verb is bounded', () async {
      final client = _client(_stalled, timeout: short);

      await expectLater(
        client.postJson('/beer-logs', body: {'a': 1}),
        throwsA(isA<TimeoutApiException>()),
      );
      await expectLater(
        client.patchJson('/beer-logs/1', body: {'a': 1}),
        throwsA(isA<TimeoutApiException>()),
      );
      await expectLater(
        client.deleteJson('/account'),
        throwsA(isA<TimeoutApiException>()),
      );
    });

    test(
      'a timeout IS a NetworkApiException, so existing UI mappings apply',
      () async {
        final client = _client(_stalled, timeout: short);

        await expectLater(
          client.getJson('/beers'),
          throwsA(isA<NetworkApiException>()),
        );
      },
    );

    test('a timeout carries no URL, token or server text', () async {
      final client = _client(_stalled, timeout: short);

      try {
        await client.getJson('/beers');
        fail('expected a timeout');
      } on TimeoutApiException catch (error) {
        expect(error.statusCode, isNull);
        expect(error.message, 'Request timed out.');
        expect(error.toString(), isNot(contains('token-123')));
        expect(error.toString(), isNot(contains('api.example.com')));
      }
    });

    test('a response that arrives in time is unaffected', () async {
      final client = _client(
        (request) async => http.Response(jsonEncode({'ok': true}), 200),
        timeout: const Duration(seconds: 5),
      );

      expect(await client.getJson('/beers'), {'ok': true});
    });

    test('the default timeout applies when none is given', () async {
      var reached = false;
      final client = _client((request) async {
        reached = true;
        return http.Response('{}', 200);
      });

      await client.getJson('/beers');

      expect(reached, isTrue);
    });
  });

  group('backend status handling', () {
    test('413 payload_too_large maps to PayloadTooLargeApiException', () async {
      final client = _client(
        (request) async =>
            _envelope(413, 'payload_too_large', 'Request body is too large.'),
      );

      await expectLater(
        client.postJson('/beer-logs', body: {'a': 1}),
        throwsA(
          isA<PayloadTooLargeApiException>()
              .having((e) => e.statusCode, 'statusCode', 413)
              .having((e) => e.code, 'code', 'payload_too_large'),
        ),
      );
    });

    test(
      '503 service_unavailable maps to ServiceUnavailableApiException',
      () async {
        final client = _client(
          (request) async => _envelope(
            503,
            'service_unavailable',
            'The service is temporarily unavailable. Please try again.',
          ),
        );

        await expectLater(
          client.getJson('/beers'),
          throwsA(
            isA<ServiceUnavailableApiException>()
                .having((e) => e.statusCode, 'statusCode', 503)
                .having((e) => e.code, 'code', 'service_unavailable'),
          ),
        );
      },
    );

    test('a 413 or 503 with a non-JSON body still maps by status', () async {
      final tooLarge = _client((request) async => http.Response('<html>', 413));
      final unavailable = _client((request) async => http.Response('', 503));

      await expectLater(
        tooLarge.getJson('/x'),
        throwsA(isA<PayloadTooLargeApiException>()),
      );
      await expectLater(
        unavailable.getJson('/x'),
        throwsA(isA<ServiceUnavailableApiException>()),
      );
    });

    test(
      'there is no special handling for 429 (the backend never returns it)',
      () async {
        final client = _client(
          (request) async => _envelope(429, 'x', 'slow down'),
        );

        await expectLater(
          client.getJson('/x'),
          throwsA(
            isA<ApiException>()
                .having(
                  (e) => e.runtimeType,
                  'plain ApiException',
                  ApiException,
                )
                .having((e) => e.statusCode, 'statusCode', 429),
          ),
        );
      },
    );

    test(
      'a deleted-account 401 is an ordinary UnauthorizedApiException',
      () async {
        final client = _client(
          (request) async =>
              _envelope(401, 'unauthorized', 'Missing or invalid credentials.'),
        );

        await expectLater(
          client.postJson('/beer-logs', body: {'a': 1}),
          throwsA(isA<UnauthorizedApiException>()),
        );
      },
    );
  });

  group('every feature shows only localized, safe text', () {
    // (feature name, its error-text function, the l10n getters it should pick)
    final features =
        <
          String,
          ({
            String Function(BuildContext, Object) text,
            String Function(AppLocalizations) network,
            String Function(AppLocalizations) generic,
            String Function(AppLocalizations) unavailable,
          })
        >{
          'catalog': (
            text: catalogErrorText,
            network: (l) => l.catalogErrorNetwork,
            generic: (l) => l.catalogErrorGeneric,
            unavailable: (l) => l.catalogErrorServiceUnavailable,
          ),
          'beerLog': (
            text: beerLogErrorText,
            network: (l) => l.beerLogErrorNetwork,
            generic: (l) => l.beerLogErrorGeneric,
            unavailable: (l) => l.beerLogErrorServiceUnavailable,
          ),
          'collection': (
            text: collectionErrorText,
            network: (l) => l.collectionErrorNetwork,
            generic: (l) => l.collectionErrorGeneric,
            unavailable: (l) => l.collectionErrorServiceUnavailable,
          ),
          'map': (
            text: mapErrorText,
            network: (l) => l.mapErrorNetwork,
            generic: (l) => l.mapErrorGeneric,
            unavailable: (l) => l.mapErrorServiceUnavailable,
          ),
          'statistics': (
            text: statisticsErrorText,
            network: (l) => l.statisticsErrorNetwork,
            generic: (l) => l.statisticsErrorGeneric,
            unavailable: (l) => l.statisticsErrorServiceUnavailable,
          ),
          'achievements': (
            text: achievementsErrorText,
            network: (l) => l.achievementsErrorNetwork,
            generic: (l) => l.achievementsErrorGeneric,
            unavailable: (l) => l.achievementsErrorServiceUnavailable,
          ),
          'contribution': (
            text: contributionErrorText,
            network: (l) => l.contributionErrorNetwork,
            generic: (l) => l.contributionErrorGeneric,
            unavailable: (l) => l.contributionErrorServiceUnavailable,
          ),
        };

    const backendText = 'RAW-BACKEND-TEXT constraint secret_fkey';

    for (final locale in const [Locale('en'), Locale('es')]) {
      for (final entry in features.entries) {
        testWidgets('${entry.key} (${locale.languageCode})', (tester) async {
          late BuildContext captured;
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  captured = context;
                  return const SizedBox();
                },
              ),
            ),
          );
          final l10n = AppLocalizations.of(captured);
          final feature = entry.value;

          expect(
            feature.text(captured, const TimeoutApiException()),
            feature.network(l10n),
            reason: 'a timeout uses the localized network message',
          );
          expect(
            feature.text(
              captured,
              const PayloadTooLargeApiException(
                message: backendText,
                statusCode: 413,
              ),
            ),
            feature.generic(l10n),
            reason: '413 falls back to the localized generic message',
          );
          expect(
            feature.text(
              captured,
              const ServiceUnavailableApiException(
                message: backendText,
                statusCode: 503,
                code: 'service_unavailable',
              ),
            ),
            feature.unavailable(l10n),
          );

          // Whatever the exception, the backend's own text never reaches the UI.
          for (final error in const <ApiException>[
            TimeoutApiException(),
            PayloadTooLargeApiException(message: backendText),
            ServiceUnavailableApiException(message: backendText),
            NetworkApiException(message: backendText),
            ApiException(message: backendText, statusCode: 500),
          ]) {
            expect(
              feature.text(captured, error),
              isNot(contains('RAW-BACKEND')),
            );
          }
        });
      }
    }
  });
}
