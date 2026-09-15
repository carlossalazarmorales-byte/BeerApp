import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';

/// Shared "coming soon" layout reused by every Phase 1 feature screen:
/// an icon, the screen title, a description, and a "coming soon" badge.
/// No real data or navigation lives here — that arrives feature-by-feature
/// in later phases.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.description,
    required this.icon,
    this.actions,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  /// App-bar actions, e.g. the Profile screen's sign-out button. Null for
  /// every other Phase 1 placeholder screen.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: AppRadii.fullRadius,
                ),
                child: Text(
                  l10n.comingSoonBadge,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.onSecondaryFixed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
