import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Shown only for `AppAuthStatus.authenticatedProfileUnavailable` — the
/// user is genuinely authenticated, but their profile row couldn't be
/// loaded (a network/Postgrest failure), so there is no way to know
/// whether they still need `/complete-profile` or not. Never conflate this
/// with an incomplete profile — retrying here just re-fetches; it never
/// invents or clears a username.
class ProfileUnavailableScreen extends StatelessWidget {
  const ProfileUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: ErrorState(
          message: l10n.profileUnavailableError,
          onRetry: () => AuthScope.of(context).refreshProfile(),
        ),
      ),
    );
  }
}
