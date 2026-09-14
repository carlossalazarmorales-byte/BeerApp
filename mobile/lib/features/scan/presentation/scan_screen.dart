import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder for the Scan destination. Real camera/barcode scanning is
/// built in a later phase — this only establishes the nav destination
/// behind the emphasized Scan button.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.navScan,
      description: l10n.scanScreenDescription,
      icon: Icons.qr_code_scanner,
    );
  }
}
