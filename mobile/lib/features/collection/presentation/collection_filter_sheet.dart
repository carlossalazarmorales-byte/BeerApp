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

    // Fixed header + fixed footer, with only the (potentially long, e.g.
    // ~500 breweries) filter content scrolling between them -- a plain
    // Column here would overflow off the bottom of the sheet on a short
    // viewport or a large option count, with no way to reach "Show results"
    // (see docs/QA_ROUND_1.md). isScrollControlled:true on the
    // showModalBottomSheet call lets the sheet grow to full height; it does
    // not by itself make anything inside it scrollable.
    return SafeArea(
      child: ConstrainedBox(
        // Caps the sheet at 90% of the viewport (accounting for the
        // keyboard, if open) so there is always room to see the footer
        // button below it -- the Flexible/shrinkWrap combination below then
        // sizes the sheet to its content up to this bound, and only
        // scrolls the filter section once content actually exceeds it.
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * 0.9 -
              MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Row(
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
            ),
            Flexible(
              // A single-child scroll view already sizes itself to
              // min(content height, the incoming bounded constraint) with no
              // shrinkWrap flag needed (unlike a lazy ListView) -- so this
              // shrinks to content for a small filter set, and only scrolls
              // once content exceeds the Flexible's allocated share of the
              // ConstrainedBox above.
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: l10n.discoverShowResultsAction,
                  onPressed: _apply,
                ),
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
