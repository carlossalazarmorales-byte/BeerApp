import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/achievement.dart';
import '../achievement_localizations.dart';
import 'achievement_category_icon.dart';

/// One achievement, locked or unlocked. Progress bars are neutral --
/// "N of target" for a single-metric achievement, "N of M conditions met"
/// for a compound one -- never a raw alcohol-consumption number (see
/// CLAUDE.md's Responsible Product Design rules; the Phase 10 starter
/// catalog is Collection-based only, but this tile makes no assumption
/// about that beyond what the backend sends).
class AchievementTile extends StatelessWidget {
  const AchievementTile({required this.achievement, super.key});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unlocked = achievement.unlocked;
    final foreground = unlocked
        ? AppColors.onSurface
        : AppColors.onSurfaceVariant;
    final target = achievement.progressTarget;
    final current = achievement.progressCurrent;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            achievementCategoryIcons[achievement.category] ??
                Icons.emoji_events,
            color: unlocked ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievementName(l10n, achievement.key),
                  style: AppTypography.bodyMedium.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  achievementDescription(l10n, achievement.key),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (current != null && target != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: AppRadii.xsRadius,
                    child: LinearProgressIndicator(
                      value: target == 0 ? 1 : current / target,
                      minHeight: 6,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.achievementsProgressFormat(current, target),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  unlocked
                      ? l10n.achievementsUnlockedOnLabel(
                          _isoDate(achievement.unlockedAt!),
                        )
                      : l10n.achievementsLockedLabel,
                  style: AppTypography.bodySmall.copyWith(
                    color: unlocked
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _isoDate(DateTime dateTime) =>
    dateTime.toIso8601String().split('T').first;
