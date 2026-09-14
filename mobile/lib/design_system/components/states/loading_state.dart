import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../tokens/app_colors.dart';

/// Reusable loading indicator for a screen or section that is fetching
/// data. Announces itself to assistive technology via a semantic label.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        label: l10n.loadingStateMessage,
        child: const CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
