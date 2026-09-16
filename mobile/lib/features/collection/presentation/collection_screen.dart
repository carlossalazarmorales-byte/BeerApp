import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/chips/app_filter_chip.dart';
import '../../../design_system/components/states/empty_state.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/collection_refresh_signal.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../domain/collection_repository.dart';
import '../domain/collection_sort.dart';
import '../domain/collection_tab.dart';
import 'collection_controller.dart';
import 'collection_error_text.dart';
import 'collection_filter_sheet.dart';
import 'collection_tab_bar.dart';
import 'collection_tile.dart';

/// The Collection tab: Logged/Favorites/Wishlist tabs, shared filters/sort,
/// and the paginated, infinite-scrolling list. Its `State` is kept alive by
/// `router.dart`'s `StatefulShellBranch` for `/collection`, so the
/// controller (tab, filters, sort, scroll position) survives a push to
/// `BeerDetailScreen` and back -- and, via [CollectionRefreshSignal], stays
/// fresh even while a different tab is showing (see that signal's doc
/// comment).
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    required this.repository,
    required this.catalogRepository,
    required this.refreshSignal,
    super.key,
  });

  final CollectionRepository repository;
  final CatalogRepository catalogRepository;
  final CollectionRefreshSignal refreshSignal;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  static const double _loadMoreThreshold = 300;

  late final CollectionController _controller = CollectionController(
    repository: widget.repository,
    catalogRepository: widget.catalogRepository,
    refreshSignal: widget.refreshSignal,
  );
  final ScrollController _scrollController = ScrollController();

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

  Future<void> _openFiltersSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => CollectionFilterSheet(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navCollection)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CollectionTabBar(
                  selected: _controller.tab,
                  onChanged: (tab) => _controller.setTab(tab),
                  labels: {
                    CollectionTab.logged: l10n.collectionTabLogged,
                    CollectionTab.favorites: l10n.collectionTabFavorites,
                    CollectionTab.wishlist: l10n.collectionTabWishlist,
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: _FilterAndSortRow(
                controller: _controller,
                onOpenFilters: _openFiltersSheet,
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoadingInitial && _controller.items.isEmpty) {
      return const LoadingState();
    }

    if (_controller.error != null && _controller.items.isEmpty) {
      return ErrorState(
        message: collectionErrorText(context, _controller.error!),
        onRetry: _controller.refresh,
      );
    }

    if (_controller.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [EmptyState(message: _emptyMessage(context))],
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
                  return CollectionTile(
                    beer: beer,
                    onTap: () =>
                        context.push(AppRoutes.beerDetailPath(beer.beerId)),
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

  String _emptyMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_controller.tab) {
      case CollectionTab.logged:
        return l10n.collectionLoggedEmptyMessage;
      case CollectionTab.favorites:
        return l10n.collectionFavoritesEmptyMessage;
      case CollectionTab.wishlist:
        return l10n.collectionWishlistEmptyMessage;
    }
  }
}

class _FilterAndSortRow extends StatelessWidget {
  const _FilterAndSortRow({
    required this.controller,
    required this.onOpenFilters,
  });

  final CollectionController controller;
  final VoidCallback onOpenFilters;

  String _sortLabel(AppLocalizations l10n, CollectionSort sort) {
    switch (sort) {
      case CollectionSort.recent:
        return l10n.collectionSortRecent;
      case CollectionSort.rating:
        return l10n.collectionSortRating;
      case CollectionSort.alphabetical:
        return l10n.collectionSortName;
    }
  }

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
          const SizedBox(width: AppSpacing.md),
          for (final sort in CollectionSort.values) ...[
            AppFilterChip(
              label: _sortLabel(l10n, sort),
              selected: controller.sort == sort,
              onSelected: (_) => controller.setSort(sort),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final CollectionController controller;

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
              '${collectionErrorText(context, loadMoreError)} '
              '${l10n.errorStateRetryLabel}',
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
