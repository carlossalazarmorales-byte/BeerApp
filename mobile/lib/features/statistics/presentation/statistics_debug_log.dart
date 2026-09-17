import 'package:flutter/foundation.dart';

/// Debug-only diagnostic log for a caught statistics exception -- never
/// shown in the UI (see `statistics_error_text.dart`), never printed in
/// release builds ([kDebugMode]-guarded), and never logs secrets. Mirrors
/// `features/collection/presentation/collection_debug_log.dart`.
void logStatisticsError(String context, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('[statistics] $context failed: ${error.runtimeType}: $error');
  debugPrint(stackTrace.toString());
}
