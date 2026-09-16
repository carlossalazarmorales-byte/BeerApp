import 'package:flutter/material.dart';

import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/models/map_brewery.dart';

/// Bottom-sheet preview shown when a brewery marker/cluster point is
/// tapped. Renders entirely from [brewery] -- a self-sufficient DTO -- so
/// opening this sheet never makes a follow-up network request. There is no
/// brewery detail screen in the app (see ROADMAP.md Phase 8) -- this card's
/// only action is dismissing it.
class BreweryPreviewCard extends StatelessWidget {
  const BreweryPreviewCard({required this.brewery, super.key});

  final MapBrewery brewery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locationParts = [
      if (brewery.city != null) brewery.city!,
      if (brewery.countryName != null) brewery.countryName!,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(brewery.name, style: AppTypography.titleLarge),
                  ),
                  if (brewery.verified) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _VerifiedBadge(label: l10n.beerDetailVerifiedBadge),
                  ],
                ],
              ),
              if (locationParts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  locationParts.join(' · '),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              if (brewery.description != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(brewery.description!, style: AppTypography.bodyMedium),
              ],
              if (brewery.website != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  brewery.website!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.onSecondaryFixed,
        ),
      ),
    );
  }
}
