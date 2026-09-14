import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder for the Collection destination. Real personal logs/reviews
/// arrive once user-owned data exists (a later phase) — this only
/// establishes the nav destination.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.navCollection,
      description: l10n.collectionScreenDescription,
      icon: Icons.collections_bookmark_outlined,
    );
  }
}
