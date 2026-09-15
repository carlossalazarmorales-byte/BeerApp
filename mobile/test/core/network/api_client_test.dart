import 'dart:convert';
import 'dart:io';

import 'package:beerapp/core/network/access_token_provider.dart';
import 'package:beerapp/core/network/api_client.dart';
import 'package:beerapp/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeAccessTokenProvider implements AccessTokenProvider {
  _FakeAccessTokenProvider(this.token);

  String? token;

  @override
  Future<String?> getAccessToken() async => token;
}

ApiClient _client(
  Future<http.Response> Function(http.Request request) handler, {
  String? token = 'token-123',
}) {
  return ApiClient(
    httpClient: MockClient((request) => handler(request)),
    baseUrl: 'https://api.example.com',
    accessTokenProvider: _FakeAccessTokenProvider(token),
  );
}

void main() {
  test(
    'attaches the bearer token and decodes a successful JSON response',
    () async {
      http.Request? capturedRequest;
      final client = _client((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final result = await client.getJson('/beers');

      expect(capturedRequest!.headers['Authorization'], 'Bearer token-123');
      expect(result, {'ok': true});
    },
  );

  test('no usable session: throws UnauthorizedApiException without sending a request', () async {
    var called = false;
    final client = _client((request) async {
      called = true;
      return http.Response('', 200);
    }, token: null);

    await expectLater(
      client.getJson('/beers'),
      throwsA(isA<UnauthorizedApiException>()),
    );
    expect(called, isFalse);
  });

  test(
    '401 maps to UnauthorizedApiException with backend code/message',
    () async {
      final client = _client(
        (request) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'unauthorized',
              'message': 'Missing or invalid credentials.',
            },
          }),
          401,
        ),
      );

      await expectLater(
        client.getJson('/beers'),
        throwsA(
          isA<UnauthorizedApiException>()
              .having((e) => e.code, 'code', 'unauthorized')
              .having(
                (e) => e.message,
                'message',
                'Missing or invalid credentials.',
              ),
        ),
      );
    },
  );

  test('404 maps to NotFoundApiException', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({
          'error': {'code': 'not_found', 'message': 'Beer x not found'},
        }),
        404,
      ),
    );

    await expectLater(
      client.getJson('/beers/x'),
      throwsA(isA<NotFoundApiException>()),
    );
  });

  test('422 maps to ValidationApiException', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'validation_error',
            'message': 'Request validation failed.',
          },
        }),
        422,
      ),
    );

    await expectLater(
      client.getJson('/beers'),
      throwsA(isA<ValidationApiException>()),
    );
  });

  test('503 maps to ServiceUnavailableApiException', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'service_unavailable',
            'message': 'Unable to verify session at this time.',
          },
        }),
        503,
      ),
    );

    await expectLater(
      client.getJson('/beers'),
      throwsA(isA<ServiceUnavailableApiException>()),
    );
  });

  test('an unmapped status falls back to the generic ApiException', () async {
    final client = _client((request) async => http.Response('', 500));

    await expectLater(
      client.getJson('/beers'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having(
              (e) => e,
              'specific subtype',
              isNot(isA<NotFoundApiException>()),
            ),
      ),
    );
  });

  test('a connection failure maps to NetworkApiException, not a raw platform exception', () async {
    final client = _client(
      (request) async => throw const SocketException('connection refused'),
    );

    await expectLater(
      client.getJson('/beers'),
      throwsA(isA<NetworkApiException>()),
    );
  });
}
