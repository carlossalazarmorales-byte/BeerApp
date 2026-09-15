import 'dart:convert';

import 'package:beerapp/core/network/access_token_provider.dart';
import 'package:beerapp/core/network/api_client.dart';
import 'package:beerapp/features/logging/data/api_log_repository.dart';
import 'package:beerapp/features/logging/domain/models/beer_log_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AlwaysTokenProvider implements AccessTokenProvider {
  @override
  Future<String?> getAccessToken() async => 'token';
}

Map<String, dynamic> _logJson({int? servingVolumeMl = 330}) => {
  'id': 'log-1',
  'user_id': 'user-1',
  'beer_id': 'beer-1',
  'rating': 4,
  'review': null,
  'consumed_at': '2026-01-01T10:00:00+00:00',
  'serving_note': null,
  'price': null,
  'currency': null,
  'venue_name': null,
  'serving_volume_ml': servingVolumeMl,
  'created_at': '2026-01-01T10:00:00+00:00',
  'updated_at': '2026-01-01T10:00:00+00:00',
};

void main() {
  test(
    'getLogs parses the Page envelope and forwards beerId/pagination',
    () async {
      Uri? capturedUri;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'items': [_logJson()],
              'page': 1,
              'page_size': 20,
              'total': 1,
            }),
            200,
          );
        }),
        baseUrl: 'https://api.example.com',
        accessTokenProvider: _AlwaysTokenProvider(),
      );
      final repository = ApiLogRepository(client);

      final result = await repository.getLogs(
        beerId: 'beer-1',
        page: 1,
        pageSize: 20,
      );

      expect(result.items.single.id, 'log-1');
      expect(capturedUri!.queryParameters['beer_id'], 'beer-1');
      expect(capturedUri!.path, '/beer-logs');
    },
  );

  test('createLog POSTs the create input and parses the response', () async {
    String? capturedMethod;
    Map<String, dynamic>? capturedBody;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_logJson()), 201);
      }),
      baseUrl: 'https://api.example.com',
      accessTokenProvider: _AlwaysTokenProvider(),
    );
    final repository = ApiLogRepository(client);

    final log = await repository.createLog(
      const BeerLogCreateInput(
        beerId: 'beer-1',
        rating: 4,
        servingVolumeMl: 330,
      ),
    );

    expect(capturedMethod, 'POST');
    expect(capturedBody, {
      'beer_id': 'beer-1',
      'rating': 4,
      'serving_volume_ml': 330,
    });
    expect(log.id, 'log-1');
    expect(log.servingVolumeMl, 330);
  });

  test('updateLog PATCHes only the fields present in the patch', () async {
    String? capturedMethod;
    Map<String, dynamic>? capturedBody;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_logJson(servingVolumeMl: null)), 200);
      }),
      baseUrl: 'https://api.example.com',
      accessTokenProvider: _AlwaysTokenProvider(),
    );
    final repository = ApiLogRepository(client);

    final log = await repository.updateLog(
      'log-1',
      const BeerLogUpdateInput(servingVolumeMl: null),
    );

    expect(capturedMethod, 'PATCH');
    expect(capturedBody, {'serving_volume_ml': null});
    expect(log.servingVolumeMl, isNull);
  });

  test('deleteLog completes successfully on a 204 with no body and never attempts to decode it', () async {
    String? capturedMethod;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        capturedMethod = request.method;
        return http.Response('', 204);
      }),
      baseUrl: 'https://api.example.com',
      accessTokenProvider: _AlwaysTokenProvider(),
    );
    final repository = ApiLogRepository(client);

    // Must not throw -- a jsonDecode('') would throw FormatException.
    await repository.deleteLog('log-1');

    expect(capturedMethod, 'DELETE');
  });
}
