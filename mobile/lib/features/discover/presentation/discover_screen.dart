import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/chips/app_filter_chip.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/components/states/empty_state.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/beer_list/beer_list_tile.dart';
import '../../catalog/presentation/catalog_error_text.dart';
import 'discover_controller.dart';

/// The Discover tab: search, style/country/brewery filters, and the
/// paginated, infinite-scrolling catalog feed. Its `State` is kept alive by
/// `router.dart`'s `StatefulShellBranch` for `/discover`, so the controller
/// (query, filters, scroll position) survives a push to `BeerDetailScreen`
/// and back.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({required this.repository, super.key});

  final CatalogRepository repository;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const double _loadMoreThreshold = 300;

  late final DiscoverController _controller = DiscoverController(
    repository: widget.repository,
  );
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _controller.loadMore();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.setQuery('');
  }

  Future<void> _openFiltersSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => _FiltersSheet(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDiscover)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: AppTextField(
              controller: _searchController,
              hintText: l10n.discoverSearchHint,
              leadingIcon: Icons.search,
              textInputAction: TextInputAction.search,
              onChanged: _controller.setQuery,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.discoverSearchClearAction,
                    onPressed: _clearSearch,
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _FilterChipsRow(
                controller: _controller,
                onOpenFilters: _openFiltersSheet,
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_controller.isLoadingInitial && _controller.items.isEmpty) {
      return const LoadingState();
    }

    if (_controller.error != null && _controller.items.isEmpty) {
      return ErrorState(
        message: catalogErrorText(context, _controller.error!),
        onRetry: _controller.refresh,
      );
    }

    final isSearchOrFilterActive =
        _controller.query.isNotEmpty || _controller.hasActiveFilters;

    if (_controller.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              message: isSearchOrFilterActive
                  ? l10n.discoverNoResultsMessage
                  : null,
            ),
            // PRODUCT.md §21: search -> not found -> "add missing beer". Only
            // offered for an actual text search (a filter-only empty result
            // has no beer name to suggest), and it only opens a form -- it
            // adds nothing to the catalog by itself.
            if (_controller.query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: PrimaryButton(
                  label: l10n.contributionSuggestThisBeerAction,
                  onPressed: () => context.push(
                    AppRoutes.suggestBeerPath(name: _controller.query.trim()),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_controller.isLoadingInitial)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _controller.items.length + 1,
              itemBuilder: (context, index) {
                if (index < _controller.items.length) {
                  final beer = _controller.items[index];
                  return BeerListTile(
                    beer: beer,
                    styleName: beer.styleId == null
                        ? null
                        : _controller.styleNames[beer.styleId],
                    countryName: beer.countryId == null
                        ? null
                        : _controller.countryNames[beer.countryId],
                    onTap: () =>
                        context.push(AppRoutes.beerDetailPath(beer.id)),
                  );
                }
                return _ListFooter(controller: _controller);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.controller,
    required this.onOpenFilters,
  });

  final DiscoverController controller;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final breweryNames = {
      for (final b in controller.breweryOptions) b.id: b.name,
    };

    final filtersLabel = controller.activeFilterCount > 0
        ? '${l10n.discoverFiltersAction} (${controller.activeFilterCount})'
        : l10n.discoverFiltersAction;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          AppFilterChip(
            label: filtersLabel,
            selected: controller.hasActiveFilters,
            onSelected: (_) => onOpenFilters(),
          ),
          if (controller.appliedStyleId != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppFilterChip(
              label:
                  controller.styleNames[controller.appliedStyleId] ??
                  controller.appliedStyleId!,
              selected: true,
              // Tapping the chip body reopens the sheet to edit it; a
              // FilterChip's delete button is only interactive when
              // `onSelected` is also non-null (Flutter's `RawChip.isEnabled`
              // gates both), so this also enables the remove (x) affordance.
              onSelected: (_) => onOpenFilters(),
              onDeleted: () => controller.applyFilters(
                styleId: null,
                countryId: controller.appliedCountryId,
                breweryId: controller.appliedBreweryId,
              ),
            ),
          ],
          if (controller.appliedCountryId != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppFilterChip(
              label:
                  controller.countryNames[controller.appliedCountryId] ??
                  controller.appliedCountryId!,
              selected: true,
              onSelected: (_) => onOpenFilters(),
              onDeleted: () => controller.applyFilters(
                styleId: controller.appliedStyleId,
                countryId: null,
                breweryId: controller.appliedBreweryId,
              ),
            ),
          ],
          if (controller.appliedBreweryId != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppFilterChip(
              label:
                  breweryNames[controller.appliedBreweryId] ??
                  controller.appliedBreweryId!,
              selected: true,
              onSelected: (_) => onOpenFilters(),
              onDeleted: () => controller.applyFilters(
                styleId: controller.appliedStyleId,
                countryId: controller.appliedCountryId,
                breweryId: null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final DiscoverController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final loadMoreError = controller.loadMoreError;
    if (loadMoreError != null) {
      final l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: TextButton(
            onPressed: controller.loadMore,
            child: Text(
              '${catalogErrorText(context, loadMoreError)} '
              '${l10n.errorStateRetryLabel}',
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Transactional filter picker: `_draft*` fields hold the in-progress
/// selection locally, independent of [DiscoverController]'s applied filters,
/// until "Show results" calls [DiscoverController.applyFilters] once.
/// Dismissing the sheet any other way discards the draft.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.controller});

  final DiscoverController controller;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
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
                  l10n.discoverFiltersSheetTitle,
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
