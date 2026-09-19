import 'package:flutter/material.dart';

import '../../../../design_system/components/buttons/primary_button.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// One catalog entry that looks like the suggestion.
class DuplicateItem {
  const DuplicateItem({required this.title, this.subtitle, this.onView});

  final String title;
  final String? subtitle;

  /// Opens the entry's detail, when it has one.
  final VoidCallback? onView;
}

class DuplicateSection {
  const DuplicateSection({required this.title, required this.items});

  final String title;
  final List<DuplicateItem> items;
}

/// The NON-BLOCKING duplicate warning: similar catalog entries, and (for
/// beers) a bare notice that another pending suggestion may already carry the
/// barcode. The user can always go on with "Submit anyway".
///
/// Pops `true` for "Submit anyway", `false` for "Review". Dismissing it any
/// other way pops null, which callers treat like "Review" -- the suggestion is
/// never submitted by dismissing.
///
/// The pending-barcode notice deliberately carries no detail: the backend
/// never reveals another user's suggestion, so there is nothing to show.
class DuplicateWarningSheet extends StatelessWidget {
  const DuplicateWarningSheet({
    required this.sections,
    required this.showPendingBarcodeWarning,
    super.key,
  });

  final List<DuplicateSection> sections;
  final bool showPendingBarcodeWarning;

  static Future<bool?> show(
    BuildContext context, {
    required List<DuplicateSection> sections,
    required bool showPendingBarcodeWarning,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DuplicateWarningSheet(
        sections: sections,
        showPendingBarcodeWarning: showPendingBarcodeWarning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.contributionDuplicateSheetTitle,
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.contributionDuplicateSheetBody,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (showPendingBarcodeWarning) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.contributionDuplicatePendingBarcode,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            for (final section in sections) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(section.title, style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              for (final item in section.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title),
                  subtitle: item.subtitle == null ? null : Text(item.subtitle!),
                  trailing: item.onView == null
                      ? null
                      : TextButton(
                          onPressed: item.onView,
                          child: Text(l10n.contributionDuplicateViewAction),
                        ),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: l10n.contributionDuplicateSubmitAnywayAction,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.contributionDuplicateReviewAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
