import 'package:flutter/foundation.dart';

/// Debug-only diagnostic log for a caught contribution exception -- never
/// shown in the UI (see `contribution_error_text.dart`), never printed in
/// release builds ([kDebugMode]-guarded), and never logs secrets: nothing in
/// the data/parsing path touches the access/refresh token or the
/// `Authorization` header. Mirrors `beer_log_debug_log.dart`.
void logContributionError(String context, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('[contributions] $context failed: ${error.runtimeType}: $error');
  debugPrint(stackTrace.toString());
}
