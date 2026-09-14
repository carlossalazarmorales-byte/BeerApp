import 'package:flutter/material.dart';

import '../design_system/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_shell.dart';

/// BeerApp's root widget: wires up theming and localization and hosts the
/// [AppShell]. Light theme only — dark mode is deferred to a later phase.
class BeerApp extends StatelessWidget {
  const BeerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppShell(),
    );
  }
}
