import 'package:flutter/foundation.dart';

/// Removes anything that must never reach a log line -- URLs (an auth callback
/// carries a one-time code in its query), JWTs, bearer tokens, `key=value`
/// secrets and Supabase key prefixes. Applied to every debug log line as a
/// second line of defence; the first is not logging such values at all.
String sanitizeForLog(String text) {
  return text
      .replaceAll(RegExp('[A-Za-z][A-Za-z0-9+.\\-]*://[^\\s\'"<>)]+'), '<url>')
      .replaceAll(
        RegExp('eyJ[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]*'),
        '<jwt>',
      )
      .replaceAll(
        RegExp('Bearer\\s+[A-Za-z0-9._\\-~+/]+=*', caseSensitive: false),
        'Bearer <redacted>',
      )
      .replaceAllMapped(
        RegExp(
          '\\b(access_token|refresh_token|token|code|apikey|api_key|key|'
          'password|secret|authorization)\\s*[=:]\\s*[^\\s,&;}]+',
          caseSensitive: false,
        ),
        (match) => '${match[1]}=<redacted>',
      )
      .replaceAll(RegExp('sb_[a-z]+_[A-Za-z0-9_\\-]+'), '<key>');
}

/// Development-only diagnostics. **Nothing is emitted unless [enabled]** (by
/// default [kDebugMode]), so a release build writes nothing to the device log
/// through this. Every line passes through [sanitizeForLog]. There is no crash
/// or analytics vendor: this is the app's only error output.
abstract final class DebugLog {
  /// Overridable so tests can prove release-mode silence.
  static bool Function() enabled = _isDebugBuild;
  static void Function(String line) sink = _print;

  static bool _isDebugBuild() => kDebugMode;
  static void _print(String line) => debugPrint(line);

  /// Restores the production wiring (tests only).
  @visibleForTesting
  static void reset() {
    enabled = _isDebugBuild;
    sink = _print;
  }

  static void message(String tag, String message) {
    if (!enabled()) return;
    sink('[$tag] ${sanitizeForLog(message)}');
  }

  /// Logs a caught error as its type plus a sanitized description, and an
  /// optional sanitized stack trace.
  static void error(
    String tag,
    String context,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (!enabled()) return;
    sink(
      '[$tag] $context: ${error.runtimeType}: '
      '${sanitizeForLog(error.toString())}',
    );
    if (stackTrace != null) sink(sanitizeForLog(stackTrace.toString()));
  }
}
