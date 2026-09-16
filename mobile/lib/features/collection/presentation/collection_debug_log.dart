import 'package:flutter/foundation.dart';

/// Debug-only diagnostic log for a caught collection exception -- never
/// shown in the UI (see `collection_error_text.dart`), never printed in
/// release builds ([kDebugMode]-guarded), and never logs secrets. Mirrors
/// `features/logging/presentation/beer_log_debug_log.dart`.
void logCollectionError(String context, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('[collection] $context failed: ${error.runtimeType}: $error');
  debugPrint(stackTrace.toString());
}
