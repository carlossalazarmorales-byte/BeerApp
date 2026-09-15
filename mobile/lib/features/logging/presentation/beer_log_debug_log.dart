import 'package:flutter/foundation.dart';

/// Debug-only diagnostic log for a caught beer-log exception -- never shown
/// in the UI (see `beer_log_error_text.dart`), never printed in release
/// builds ([kDebugMode]-guarded), and never logs secrets: nothing in the
/// logging data/parsing path ever touches the access/refresh token, the
/// `Authorization` header, or `DATABASE_URL`, so [error]/[stackTrace] are
/// safe to print as-is. Mirrors `features/catalog/presentation/catalog_debug_log.dart`.
void logBeerLogError(String context, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('[logging] $context failed: ${error.runtimeType}: $error');
  debugPrint(stackTrace.toString());
}
