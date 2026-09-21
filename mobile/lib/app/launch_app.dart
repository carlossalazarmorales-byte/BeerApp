import 'package:flutter/widgets.dart';

import '../core/config/env_validator.dart';
import '../core/logging/debug_log.dart';
import 'startup_failure_app.dart';

/// Builds the real app (validates configuration, initializes services, wires
/// dependencies). Anything it throws is handled by [launchApp].
typedef AppBuilder = Future<Widget> Function();

/// Runs [build] and shows the result; if startup fails, shows a localized
/// [StartupFailureApp] instead of crashing.
///
/// - [EnvConfigException] -> a non-retryable "this build isn't configured
///   correctly" screen, with only the value-free problem names as debug
///   diagnostics.
/// - Any other error -> a retryable "couldn't start" screen; Retry runs [build]
///   again. Only the error's *type* is offered as diagnostics, and only in
///   debug builds.
///
/// [run] defaults to `runApp`; tests inject their own.
Future<void> launchApp(
  AppBuilder build, {
  void Function(Widget app)? run,
  bool? showDiagnostics,
}) async {
  final runner = run ?? runApp;
  try {
    runner(await build());
  } on EnvConfigException catch (error, stackTrace) {
    DebugLog.error('startup', 'invalid configuration', error, stackTrace);
    runner(
      StartupFailureApp(
        kind: StartupFailureKind.configuration,
        diagnostics: error.toString(),
        showDiagnostics: showDiagnostics,
      ),
    );
  } catch (error, stackTrace) {
    DebugLog.error('startup', 'initialization failed', error, stackTrace);
    runner(
      StartupFailureApp(
        kind: StartupFailureKind.initialization,
        diagnostics: error.runtimeType.toString(),
        showDiagnostics: showDiagnostics,
        onRetry: () =>
            launchApp(build, run: run, showDiagnostics: showDiagnostics),
      ),
    );
  }
}
