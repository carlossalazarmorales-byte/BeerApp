import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder for the Map destination. The real interactive MapLibre map
/// is built in a later phase — this only establishes the nav destination.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.navMap,
      description: l10n.mapScreenDescription,
      icon: Icons.map_outlined,
    );
  }
}
