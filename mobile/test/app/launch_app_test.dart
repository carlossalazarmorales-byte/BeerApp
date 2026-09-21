import 'package:beerapp/app/launch_app.dart';
import 'package:beerapp/app/startup_failure_app.dart';
import 'package:beerapp/core/config/env_validator.dart';
import 'package:beerapp/core/logging/debug_log.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  late List<Widget> shown;

  setUp(() {
    shown = [];
    // Keep the debug log out of the test output.
    DebugLog.sink = (_) {};
  });
  tearDown(DebugLog.reset);

  Future<void> launch(AppBuilder build, {bool? showDiagnostics}) =>
      launchApp(build, run: shown.add, showDiagnostics: showDiagnostics);

  test('runs the built app when startup succeeds', () async {
    await launch(() async => const _Marker());

    expect(shown, hasLength(1));
    expect(shown.single, isA<_Marker>());
  });

  test(
    'an invalid configuration shows the non-retryable failure screen',
    () async {
      await launch(
        () async =>
            throw const EnvConfigException([EnvProblem.apiBaseUrlIsLocal]),
      );

      final screen = shown.single as StartupFailureApp;
      expect(screen.kind, StartupFailureKind.configuration);
      expect(screen.onRetry, isNull);
      // Only value-free problem names are ever offered as diagnostics.
      expect(screen.diagnostics, 'EnvConfigException: apiBaseUrlIsLocal');
    },
  );

  test('any other startup error shows the retryable failure screen', () async {
    await launch(() async => throw StateError('boom'));

    final screen = shown.single as StartupFailureApp;
    expect(screen.kind, StartupFailureKind.initialization);
    expect(screen.onRetry, isNotNull);
  });

  test(
    'the diagnostics for an unexpected error are its TYPE, never its message',
    () async {
      await launch(
        () async => throw StateError(
          'sb_secret_abc failed at https://host/cb?code=SECRET stack #0',
        ),
      );

      final screen = shown.single as StartupFailureApp;
      expect(screen.diagnostics, 'StateError');
      expect(screen.diagnostics, isNot(contains('SECRET')));
      expect(screen.diagnostics, isNot(contains('sb_secret')));
    },
  );

  test(
    'retry runs the builder again and shows the app if it now works',
    () async {
      var attempts = 0;
      await launch(() async {
        attempts++;
        if (attempts == 1) throw StateError('first attempt fails');
        return const _Marker();
      });
      expect(shown.single, isA<StartupFailureApp>());

      (shown.single as StartupFailureApp).onRetry!();
      await pumpEventQueue();

      expect(attempts, 2);
      expect(shown, hasLength(2));
      expect(shown.last, isA<_Marker>());
    },
  );

  test('retry that fails again shows the failure screen again', () async {
    await launch(() async => throw StateError('always'));

    (shown.single as StartupFailureApp).onRetry!();
    await pumpEventQueue();

    expect(shown, hasLength(2));
    expect(shown.last, isA<StartupFailureApp>());
  });

  test(
    'the diagnostics visibility choice is passed to the failure screen',
    () async {
      await launch(() async => throw StateError('x'), showDiagnostics: false);

      // Rendered by StartupFailureApp; see startup_failure_app_test.dart.
      expect(shown.single, isA<StartupFailureApp>());
    },
  );

  test(
    'nothing is logged in a release build even when startup fails',
    () async {
      final lines = <String>[];
      DebugLog.sink = lines.add;
      DebugLog.enabled = () => false;

      await launch(() async => throw StateError('secret'));

      expect(lines, isEmpty);
    },
  );
}
