import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder for the Profile destination. Real auth-backed profile data
/// arrives once Supabase Auth exists (a later phase) — this only
/// establishes the nav destination.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.navProfile,
      description: l10n.profileScreenDescription,
      icon: Icons.person_outline,
    );
  }
}
