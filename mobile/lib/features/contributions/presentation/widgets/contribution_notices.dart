import 'package:flutter/material.dart';

import '../../../../design_system/components/buttons/primary_button.dart';
import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Inline notice for a hard block (the suggestion cannot go through as
/// entered), with an optional follow-up action such as "View existing beer".
class ContributionBlockedBanner extends StatelessWidget {
  const ContributionBlockedBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.block, size: 20, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message, style: AppTypography.bodyMedium)),
            ],
          ),
          if (actionLabel != null && onAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
        ],
      ),
    );
  }
}

/// Inline error text shown next to the submit button for a failed check or
/// submit (network, validation, ...) -- distinct from a hard block.
class ContributionErrorText extends StatelessWidget {
  const ContributionErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
    );
  }
}

/// Shown once the backend has confirmed the suggestion is stored as pending
/// review. The wording is deliberate: a suggestion is *received* and
/// *pending review* -- it has not been added to, and is not visible in, the
/// catalog.
class ContributionSubmittedView extends StatelessWidget {
  const ContributionSubmittedView({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.contributionSubmittedTitle,
              textAlign: TextAlign.center,
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.contributionSubmittedBody,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.contributionSubmittedDoneAction,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}
