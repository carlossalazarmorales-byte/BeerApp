import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Profile destination. Full profile editing (avatar, currency/units,
/// language preference) is Phase 12 — for now this only proves the real
/// username set via Supabase Auth/`/complete-profile` reaches the shell.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = AuthScope.of(context).profile;
    final name = profile?.displayName ?? profile?.username;

    return PlaceholderScreen(
      title: l10n.navProfile,
      description: name == null
          ? l10n.profileScreenDescription
          : l10n.profileScreenGreeting(name),
      icon: Icons.person_outline,
    );
  }
}
