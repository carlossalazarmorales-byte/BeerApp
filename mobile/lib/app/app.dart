import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_scope.dart';
import '../core/locale/locale_controller.dart';
import '../core/locale/locale_scope.dart';
import '../core/onboarding/age_gate_controller.dart';
import '../core/onboarding/age_gate_scope.dart';
import '../design_system/theme/app_theme.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../l10n/generated/app_localizations.dart';

/// BeerApp's root widget: wires up theming, localization, routing, and the
/// app-wide controllers ([AuthController], [AgeGateController],
/// [LocaleController]) via their scopes. `MaterialApp.router` replaces the
/// Phase 1 `MaterialApp` now that auth-gating and deep links give go_router
/// a real job to do (see docs/DECISIONS.md).
class BeerApp extends StatelessWidget {
  const BeerApp({
    required this.router,
    required this.authController,
    required this.ageGateController,
    required this.localeController,
    super.key,
  });

  final GoRouter router;
  final AuthController authController;
  final AgeGateController ageGateController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return AgeGateScope(
      controller: ageGateController,
      child: AuthScope(
        controller: authController,
        child: LocaleScope(
          controller: localeController,
          // ListenableBuilder, not just LocaleScope, because
          // MaterialApp.router's `locale:` is a constructor parameter read
          // directly here -- InheritedNotifier alone only rebuilds
          // descendants that call LocaleScope.of(context), which this
          // widget itself never does. This makes a Settings language
          // change apply immediately, with no relaunch required.
          child: ListenableBuilder(
            listenable: localeController,
            builder: (context, _) => MaterialApp.router(
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context).appTitle,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              locale: localeController.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
  }
}
