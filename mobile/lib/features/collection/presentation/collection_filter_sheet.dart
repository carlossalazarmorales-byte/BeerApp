import 'package:flutter/material.dart';

import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/chips/app_filter_chip.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'collection_controller.dart';

/// Transactional filter picker for the Collection screen, mirroring
/// Discover's own filter sheet: `_draft*` fields hold the in-progress
/// selection locally, independent of [CollectionController]'s applied
/// filters, until "Show results" calls [CollectionController.applyFilters]
/// once. Dismissing the sheet any other way discards the draft and applies
/// nothing.
class CollectionFilterSheet extends StatefulWidget {
  const CollectionFilterSheet({required this.controller, super.key});

  final CollectionController controller;

  @override
  State<CollectionFilterSheet> createState() => _CollectionFilterSheetState();
}

class _CollectionFilterSheetState extends State<CollectionFilterSheet> {
  late String? _draftStyleId = widget.controller.appliedStyleId;
  late String? _draftCountryId = widget.controller.appliedCountryId;
  late String? _draftBreweryId = widget.controller.appliedBreweryId;

  void _clearAll() {
    setState(() {
      _draftStyleId = null;
      _draftCountryId = null;
      _draftBreweryId = null;
    });
  }

  void _apply() {
    widget.controller.applyFilters(
      styleId: _draftStyleId,
      countryId: _draftCountryId,
      breweryId: _draftBreweryId,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final breweryNames = {
      for (final b in widget.controller.breweryOptions) b.id: b.name,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.collectionFiltersSheetTitle,
                  style: AppTypography.titleLarge,
                ),
                TextButton(
                  onPressed: _clearAll,
                  child: Text(l10n.discoverClearAllAction),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _FilterSection(
              label: l10n.discoverFilterSectionStyle,
              options: widget.controller.styleNames,
              selectedId: _draftStyleId,
              onSelected: (id) => setState(() => _draftStyleId = id),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FilterSection(
              label: l10n.discoverFilterSectionCountry,
              options: widget.controller.countryNames,
              selectedId: _draftCountryId,
              onSelected: (id) => setState(() => _draftCountryId = id),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FilterSection(
              label: l10n.discoverFilterSectionBrewery,
              options: breweryNames,
              selectedId: _draftBreweryId,
              onSelected: (id) => setState(() => _draftBreweryId = id),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: l10n.discoverShowResultsAction,
                onPressed: _apply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final String label;
  final Map<String, String> options;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final entry in options.entries)
              AppFilterChip(
                label: entry.value,
                selected: selectedId == entry.key,
                onSelected: (_) =>
                    onSelected(selectedId == entry.key ? null : entry.key),
              ),
          ],
        ),
      ],
    );
  }
}
