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

/// 400 — a structurally valid request that's semantically wrong given the
/// resource's current state (e.g. a future `consumed_at`, or a price/
/// currency combination a PATCH would leave inconsistent). First introduced
/// for beer logs -- no Phase 3 catalog endpoint has such a case.
class InvalidRequestApiException extends ApiException {
  const InvalidRequestApiException({
    required super.message,
    super.statusCode,
    super.code,
  });
}

/// 409 — a well-formed request that collides with existing state. First used
/// by Phase 13 contributions. Unlike the other subtypes, [code] is a specific
/// machine-readable reason (e.g. `barcode_in_catalog`, `already_submitted`)
/// that callers branch on -- the localized text still comes from the
/// feature's own error mapping, never from [message].
class ConflictApiException extends ApiException {
  const ConflictApiException({
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

/// 413 — the request body exceeded the backend's size limit (`payload_too_large`).
/// The app's own request bodies are far below that limit, so this is not
/// expected in normal use; it maps to its own type so callers never mistake it
/// for a generic failure, while the UI still shows only the feature's
/// localized generic error -- never the backend message.
class PayloadTooLargeApiException extends ApiException {
  const PayloadTooLargeApiException({
    required super.message,
    super.statusCode,
    super.code,
  });
}

/// 503 — the backend couldn't verify the session (e.g. JWKS unreachable), a
/// database/network dependency was temporarily unavailable
/// (`service_unavailable`), or it is otherwise temporarily unavailable.
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

/// The request outlived [ApiClient]'s request timeout. A [NetworkApiException]
/// on purpose: every feature's error mapping already turns that type into its
/// localized "check your connection / try again" text, so a timeout needs no
/// new UI string and can never surface a raw message.
class TimeoutApiException extends NetworkApiException {
  const TimeoutApiException() : super(message: 'Request timed out.');
}
