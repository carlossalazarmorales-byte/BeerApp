/// Raised by [ApiClient] for any non-success outcome. Carries the raw
/// backend `code`/`message` (and HTTP status, when there was a response) for
/// diagnostics only — UI code must never show [message] directly; it maps
/// the exception's *type* to a localized string instead (see
/// `features/catalog/presentation/catalog_error_text.dart`).
class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.code});

  final int? statusCode;
  final String? code;
  final String message;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code, message: $message)';
}

/// No usable authenticated session (token provider returned no token, even
/// after attempting a refresh), or the server rejected the attached token
/// with 401.
class UnauthorizedApiException extends ApiException {
  const UnauthorizedApiException({
    required super.message,
    super.statusCode,
    super.code,
  });
}

/// 404 — a well-formed resource id that doesn't exist.
class NotFoundApiException extends ApiException {
  const NotFoundApiException({
    required super.message,
    super.statusCode,
    super.code,
  });
}

/// 422 — malformed request shape (bad UUID, out-of-range page/page_size).
class ValidationApiException extends ApiException {
  const ValidationApiException({
    required super.message,
    super.statusCode,
    super.code,
  });
}

/// 503 — the backend couldn't verify the session (e.g. JWKS unreachable) or
/// is otherwise temporarily unavailable.
class ServiceUnavailableApiException extends ApiException {
  const ServiceUnavailableApiException({
    required super.message,
    super.statusCode,
    super.code,
  });
}

/// No response was ever received — offline, DNS failure, connection refused,
/// timeout. Distinct from a server-returned error.
class NetworkApiException extends ApiException {
  const NetworkApiException({required super.message});
}
