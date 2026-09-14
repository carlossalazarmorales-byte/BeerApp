import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_scope.dart';
import '../core/onboarding/age_gate_controller.dart';
import '../core/onboarding/age_gate_scope.dart';
import '../design_system/theme/app_theme.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../l10n/generated/app_localizations.dart';

/// BeerApp's root widget: wires up theming, localization, routing, and the
/// two app-wide controllers ([AuthController], [AgeGateController]) via
/// their scopes. `MaterialApp.router` replaces the Phase 1 `MaterialApp`
/// now that auth-gating and deep links give go_router a real job to do
/// (see docs/DECISIONS.md).
class BeerApp extends StatelessWidget {
  const BeerApp({
    required this.router,
    required this.authController,
    required this.ageGateController,
    super.key,
  });

  final GoRouter router;
  final AuthController authController;
  final AgeGateController ageGateController;

  @override
  Widget build(BuildContext context) {
    return AgeGateScope(
      controller: ageGateController,
      child: AuthScope(
        controller: authController,
        child: MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }
}
