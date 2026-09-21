import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/components/states/error_state.dart';
import '../design_system/theme/app_theme.dart';
import '../design_system/tokens/app_spacing.dart';
import '../l10n/generated/app_localizations.dart';

/// Why the app could not start.
enum StartupFailureKind {
  /// The build's configuration is missing or invalid (see `EnvProblem`). Not
  /// retryable: the same build will fail again, so there is no Retry button.
  configuration,

  /// Anything else that failed while starting (e.g. initializing a service).
  /// Retryable.
  initialization,
}

/// Shown instead of the app when startup fails, so a broken build or a failed
/// initialization presents a calm, localized message rather than a crash or a
/// blank screen.
///
/// It is a standalone [MaterialApp] (nothing else exists yet), localized from
/// the device locale. It never shows an exception, stack trace, URL or key: the
/// user-facing text is fixed. [diagnostics] -- only ever a value-free
/// description such as an error *type* or `EnvProblem` names -- is rendered
/// solely when [showDiagnostics] is true, which defaults to debug builds.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    required this.kind,
    this.onRetry,
    this.diagnostics,
    this._showDiagnostics,
    super.key,
  });

  final StartupFailureKind kind;

  /// Called by the Retry button; only offered for
  /// [StartupFailureKind.initialization].
  final VoidCallback? onRetry;
  final String? diagnostics;
  final bool? _showDiagnostics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _StartupFailureScreen(
        kind: kind,
        onRetry: kind == StartupFailureKind.initialization ? onRetry : null,
        diagnostics: (_showDiagnostics ?? kDebugMode) ? diagnostics : null,
      ),
    );
  }
}

class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({
    required this.kind,
    required this.onRetry,
    required this.diagnostics,
  });

  final StartupFailureKind kind;
  final VoidCallback? onRetry;
  final String? diagnostics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isConfiguration = kind == StartupFailureKind.configuration;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      isConfiguration
                          ? l10n.startupFailureConfigurationTitle
                          : l10n.startupFailureInitializationTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
                ErrorState(
                  message: isConfiguration
                      ? l10n.startupFailureConfigurationMessage
                      : l10n.startupFailureInitializationMessage,
                  onRetry: onRetry,
                ),
                if (diagnostics != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SelectableText(
                      diagnostics!,
                      key: const ValueKey('startup-diagnostics'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
