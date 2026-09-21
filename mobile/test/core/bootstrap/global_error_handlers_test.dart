import 'dart:ui';

import 'package:beerapp/core/bootstrap/global_error_handlers.dart';
import 'package:beerapp/core/logging/debug_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reported {
  _Reported(this.source, this.error, this.stackTrace);

  final String source;
  final Object error;
  final StackTrace? stackTrace;
}

void main() {
  late FlutterExceptionHandler? originalFlutterHandler;
  late FlutterExceptionHandler originalPresentError;
  late ErrorCallback? originalPlatformHandler;
  late List<_Reported> reported;
  late int presented;
  late void Function() restore;

  setUp(() {
    originalFlutterHandler = FlutterError.onError;
    originalPresentError = FlutterError.presentError;
    originalPlatformHandler = PlatformDispatcher.instance.onError;
    reported = [];
    presented = 0;
    // Count (and swallow) the developer-facing presentation so the test log
    // stays clean and "was it presented?" is observable.
    FlutterError.presentError = (_) => presented++;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterHandler;
    FlutterError.presentError = originalPresentError;
    PlatformDispatcher.instance.onError = originalPlatformHandler;
    DebugLog.reset();
  });

  void install({required bool isDebug}) {
    restore = installGlobalErrorHandlers(
      isDebug: isDebug,
      sink: (source, error, stackTrace) =>
          reported.add(_Reported(source, error, stackTrace)),
    );
  }

  FlutterErrorDetails details(Object error) =>
      FlutterErrorDetails(exception: error, stack: StackTrace.current);

  test('framework errors are reported with their source', () {
    install(isDebug: false);
    final error = StateError('widget failed');

    FlutterError.onError!(details(error));

    expect(reported, hasLength(1));
    expect(reported.single.source, 'flutter');
    expect(reported.single.error, same(error));
    expect(reported.single.stackTrace, isNotNull);
  });

  test('uncaught async errors are reported and marked handled', () {
    install(isDebug: false);
    final error = StateError('async failed');

    final handled = PlatformDispatcher.instance.onError!(
      error,
      StackTrace.current,
    );

    expect(
      handled,
      isTrue,
      reason: 'true means "handled": the app keeps running',
    );
    expect(reported.single.source, 'platform');
    expect(reported.single.error, same(error));
  });

  test('debug builds keep the developer-facing error presentation', () {
    install(isDebug: true);

    FlutterError.onError!(details(StateError('x')));

    expect(presented, 1);
  });

  test('release builds do not dump the error to the console', () {
    install(isDebug: false);

    FlutterError.onError!(details(StateError('x')));

    expect(presented, 0);
  });

  test('restoring puts the previous handlers back', () {
    install(isDebug: false);
    final installedFlutterHandler = FlutterError.onError;
    final installedPlatformHandler = PlatformDispatcher.instance.onError;
    expect(installedFlutterHandler, isNot(same(originalFlutterHandler)));

    restore();

    expect(FlutterError.onError, same(originalFlutterHandler));
    expect(PlatformDispatcher.instance.onError, same(originalPlatformHandler));
    expect(installedPlatformHandler, isNotNull);
  });

  group('with the default sink (no vendor, debug console only)', () {
    late List<String> lines;

    setUp(() {
      lines = [];
      DebugLog.sink = lines.add;
      restore = installGlobalErrorHandlers(isDebug: false);
    });

    test('a release build writes nothing anywhere', () {
      DebugLog.enabled = () => false;

      FlutterError.onError!(details(StateError('secret sb_secret_x')));
      PlatformDispatcher.instance.onError!(StateError('y'), StackTrace.current);

      expect(lines, isEmpty);
    });

    test('a debug build logs a sanitized line, never a raw URL or token', () {
      DebugLog.enabled = () => true;

      PlatformDispatcher.instance.onError!(
        StateError('failed https://host/cb?code=SECRET'),
        StackTrace.current,
      );

      expect(lines, isNotEmpty);
      expect(lines.join('\n'), contains('[uncaught] platform'));
      expect(lines.join('\n'), isNot(contains('SECRET')));
    });
  });
}
