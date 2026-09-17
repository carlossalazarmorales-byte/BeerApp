import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';

/// A single labeled number in the Statistics overview grid -- e.g. "Total
/// logs: 12". [value] is plain text so the caller can pass a formatted
/// number or a localized placeholder ("—") for a null value, uniformly.
class StatTile extends StatelessWidget {
  const StatTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
