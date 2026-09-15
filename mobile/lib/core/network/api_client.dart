import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'access_token_provider.dart';
import 'api_exception.dart';

/// Thin GET-only JSON client for BeerApp's FastAPI backend. Attaches the
/// current Supabase access token as a bearer header and maps the backend's
/// shared `{"error": {"code", "message"}}` envelope to typed [ApiException]
/// subtypes. Does not retry on 401 itself -- a fresh/refreshed token was
/// already attempted by [AccessTokenProvider] before the request went out.
class ApiClient {
  ApiClient({
    required this._httpClient,
    required this._baseUrl,
    required this._accessTokenProvider,
  });

  final http.Client _httpClient;
  final String _baseUrl;
  final AccessTokenProvider _accessTokenProvider;

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final token = await _accessTokenProvider.getAccessToken();
    if (token == null) {
      throw const UnauthorizedApiException(
        message: 'No authenticated session.',
      );
    }

    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);

    final http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
    } on SocketException catch (error) {
      throw NetworkApiException(message: error.message);
    } on http.ClientException catch (error) {
      throw NetworkApiException(message: error.message);
    } on TimeoutException {
      throw const NetworkApiException(message: 'Request timed out.');
    }

    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          statusCode: status,
          message: 'Malformed response body.',
        );
      }
    }

    var message = 'Request failed with status $status.';
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded['error'] is Map<String, dynamic>) {
        final error = decoded['error'] as Map<String, dynamic>;
        code = error['code'] as String?;
        message = (error['message'] as String?) ?? message;
      }
    } catch (_) {
      // Malformed/non-JSON error body -- fall back to the generic message
      // built above rather than propagating a parse failure.
    }

    switch (status) {
      case 401:
        throw UnauthorizedApiException(
          statusCode: status,
          code: code,
          message: message,
        );
      case 404:
        throw NotFoundApiException(
          statusCode: status,
          code: code,
          message: message,
        );
      case 422:
        throw ValidationApiException(
          statusCode: status,
          code: code,
          message: message,
        );
      case 503:
        throw ServiceUnavailableApiException(
          statusCode: status,
          code: code,
          message: message,
        );
      default:
        throw ApiException(statusCode: status, code: code, message: message);
    }
  }
}
