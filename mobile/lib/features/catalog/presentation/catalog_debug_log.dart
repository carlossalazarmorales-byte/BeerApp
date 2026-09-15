import 'package:flutter/foundation.dart';

/// Debug-only diagnostic log for a caught catalog-loading exception --
/// never shown in the UI (see `catalog_error_text.dart`), never printed in
/// release builds ([kDebugMode]-guarded), and never logs secrets: nothing
/// in the catalog data/parsing path ever touches the access/refresh token,
/// the `Authorization` header, or `DATABASE_URL`, so [error]/[stackTrace]
/// are safe to print as-is.
void logCatalogError(String context, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('[catalog] $context failed: ${error.runtimeType}: $error');
  debugPrint(stackTrace.toString());
}
