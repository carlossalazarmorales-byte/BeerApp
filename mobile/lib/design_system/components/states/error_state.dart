import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import '../buttons/primary_button.dart';

/// Reusable error state with an optional retry action and an optional
/// secondary action (a plain text button below the primary one) -- added
/// for the Scanner feature, where several states (permission denied,
/// barcode not found, network error) all need a different primary action
/// alongside the same "Search manually" fallback. Generic, not
/// scanner-specific, so any other feature needing a two-action error state
/// can reuse it too.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  final String? message;
  final VoidCallback? onRetry;

  /// Overrides the primary button's label. Defaults to
  /// [AppLocalizations.errorStateRetryLabel] ("Retry") when null -- most
  /// callers just want "Retry"; Scanner states need labels like "Try camera
  /// again" or "Scan again" for the same primary-action slot.
  final String? retryLabel;

  /// Label for a secondary text-button action, shown below the primary
  /// retry button (or alone, if [onRetry] is null). Ignored if
  /// [onSecondaryAction] is null.
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? l10n.errorStateDefaultMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: retryLabel ?? l10n.errorStateRetryLabel,
                onPressed: onRetry,
              ),
            ],
            if (onSecondaryAction != null && secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
