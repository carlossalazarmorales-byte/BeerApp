import 'package:flutter/foundation.dart';

/// Debug-only diagnostic log for a caught map exception -- never shown in
/// the UI (see `map_error_text.dart`), never printed in release builds
/// ([kDebugMode]-guarded), never logs secrets. Mirrors
/// `features/collection/presentation/collection_debug_log.dart`.
void logMapError(String context, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('[map] $context failed: ${error.runtimeType}: $error');
  debugPrint(stackTrace.toString());
}
