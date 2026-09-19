import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'access_token_provider.dart';
import 'api_exception.dart';

/// Thin JSON client for BeerApp's FastAPI backend. Attaches the current
/// Supabase access token as a bearer header and maps the backend's shared
/// `{"error": {"code", "message"}}` envelope to typed [ApiException]
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

  Future<dynamic> getJson(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> postJson(String path, {Map<String, dynamic>? body}) {
    return _send('POST', path, body: body);
  }

  Future<dynamic> patchJson(String path, {Map<String, dynamic>? body}) {
    return _send('PATCH', path, body: body);
  }

  /// Returns nothing: every 204 response has an empty body, and `_decode`'s
  /// empty-body branch (below) already returns `null` for it without ever
  /// attempting `jsonDecode` -- there is nothing for a caller to use here.
  Future<void> deleteJson(String path) async {
    await _send('DELETE', path);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final token = await _accessTokenProvider.getAccessToken();
    if (token == null) {
      throw const UnauthorizedApiException(
        message: 'No authenticated session.',
      );
    }

    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);

    final headers = {'Authorization': 'Bearer $token'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
        case 'POST':
          response = await _httpClient.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'PATCH':
          response = await _httpClient.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: headers);
        default:
          throw ArgumentError('Unsupported method: $method');
      }
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
      // Covers 204 No Content (DELETE) along with any other empty-bodied
      // success response -- jsonDecode is never attempted on an empty body,
      // regardless of status code, as long as it's in this range.
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
      case 400:
        throw InvalidRequestApiException(
          statusCode: status,
          code: code,
          message: message,
        );
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
      case 409:
        throw ConflictApiException(
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
