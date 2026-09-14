import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Reusable "nothing here" state for empty lists/collections.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.message, this.icon = Icons.inbox_outlined});

  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? l10n.emptyStateDefaultMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
