import 'package:flutter/foundation.dart';

import '../logging/debug_log.dart';

/// Where an uncaught error is reported. [source] is `flutter` (a framework/
/// widget error) or `platform` (an uncaught async/platform error).
typedef UncaughtErrorSink = void Function(
  String source,
  Object error,
  StackTrace? stackTrace,
);

void _logToDebugConsole(String source, Object error, StackTrace? stackTrace) {
  DebugLog.error('uncaught', source, error, stackTrace);
}

/// Installs the app's last-resort error handlers and returns a function that
/// restores the previous ones (used by tests).
///
/// - `FlutterError.onError`: framework errors. In debug builds the standard
///   red-screen/console presentation is kept for developers; in release nothing
///   is printed (the default handler would dump the exception and stack to the
///   device log).
/// - `PlatformDispatcher.instance.onError`: uncaught asynchronous errors, which
///   otherwise terminate the isolate's error zone. Returning `true` marks them
///   handled, so a stray async failure never crashes the app.
///
/// There is deliberately **no crash-reporting or analytics vendor** here: the
/// only output is [DebugLog], which writes nothing outside debug builds and
/// sanitizes what it does write. No error text ever reaches the UI.
void Function() installGlobalErrorHandlers({
  bool? isDebug,
  UncaughtErrorSink? sink,
}) {
  final debug = isDebug ?? kDebugMode;
  final report = sink ?? _logToDebugConsole;

  final previousFlutterHandler = FlutterError.onError;
  final previousPlatformHandler = PlatformDispatcher.instance.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    report('flutter', details.exception, details.stack);
    if (debug) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    report('platform', error, stackTrace);
    return true;
  };

  return () {
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
  };
}
