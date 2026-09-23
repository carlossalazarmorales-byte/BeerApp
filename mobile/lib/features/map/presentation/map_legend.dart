import 'package:flutter/material.dart';

import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Explains the map's country-fill and beer-point color states. Color alone
/// (a subtle gray-vs-charcoal or gray-vs-gold distinction) must not be the
/// only way a user can tell these states apart -- this legend's text labels
/// are the accessible fallback. Wording is deliberately neutral ("in your
/// history", not "complete"/"unlocked all") -- see docs/QA_ROUND_1.md
/// Block 2 and CLAUDE.md's Responsible Product Design section: this is
/// informational map coverage, never a completion/reward mechanic.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow(
            shape: _LegendShape.square,
            color: AppColors.mapZeroCatalog,
            label: l10n.mapLegendZeroCatalog,
          ),
          _LegendRow(
            shape: _LegendShape.square,
            color: AppColors.mapZeroHistory,
            label: l10n.mapLegendZeroHistory,
          ),
          _LegendRow(
            shape: _LegendShape.square,
            color: AppColors.mapHasHistory,
            label: l10n.mapLegendHasHistory,
          ),
          _LegendRow(
            shape: _LegendShape.circle,
            color: AppColors.mapZeroHistory,
            label: l10n.mapLegendPointUntried,
          ),
          _LegendRow(
            shape: _LegendShape.circle,
            color: AppColors.primaryContainer,
            label: l10n.mapLegendPointTried,
          ),
        ],
      ),
    );
  }
}

enum _LegendShape { square, circle }

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.shape,
    required this.color,
    required this.label,
  });

  final _LegendShape shape;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: shape == _LegendShape.circle
                  ? BoxShape.circle
                  : BoxShape.rectangle,
              borderRadius: shape == _LegendShape.square
                  ? BorderRadius.circular(2)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
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
