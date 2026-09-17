import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/amount_spent.dart';

/// Lists each currency's total on its own row -- deliberately never summed
/// across currencies (see [AmountSpent]'s doc comment).
class AmountSpentSection extends StatelessWidget {
  const AmountSpentSection({required this.amountSpent, super.key});

  final List<AmountSpent> amountSpent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.statisticsAmountSpentSectionTitle,
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (amountSpent.isEmpty)
            Text(
              l10n.statisticsAmountSpentEmptyLabel,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            for (final amount in amountSpent)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(amount.currency, style: AppTypography.bodyMedium),
                    Text(
                      amount.total.toStringAsFixed(2),
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
