import 'package:flutter/foundation.dart';

/// Debug-only diagnostic log for a caught achievements exception -- never
/// shown in the UI (see `achievements_error_text.dart`), never printed in
/// release builds ([kDebugMode]-guarded). Mirrors
/// `features/statistics/presentation/statistics_debug_log.dart`.
void logAchievementsError(String context, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('[achievements] $context failed: ${error.runtimeType}: $error');
  debugPrint(stackTrace.toString());
}
