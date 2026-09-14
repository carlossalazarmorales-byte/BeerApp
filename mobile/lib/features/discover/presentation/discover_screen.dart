import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder for the Discover destination. Real catalog browsing arrives
/// once the beer catalog exists (a later phase) — this only establishes
/// the nav destination.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.navDiscover,
      description: l10n.discoverScreenDescription,
      icon: Icons.explore_outlined,
    );
  }
}
