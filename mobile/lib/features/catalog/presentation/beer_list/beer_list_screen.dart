import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../design_system/components/states/empty_state.dart';
import '../../../../design_system/components/states/error_state.dart';
import '../../../../design_system/components/states/loading_state.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/catalog_repository.dart';
import '../catalog_error_text.dart';
import 'beer_list_controller.dart';
import 'beer_list_tile.dart';

/// The Discover tab's real content: a paginated, infinite-scrolling list of
/// catalog beers. `DiscoverScreen` is a thin wrapper around this.
class BeerListScreen extends StatefulWidget {
  const BeerListScreen({required this.repository, super.key});

  final CatalogRepository repository;

  @override
  State<BeerListScreen> createState() => _BeerListScreenState();
}

class _BeerListScreenState extends State<BeerListScreen> {
  static const double _loadMoreThreshold = 300;

  late final BeerListController _controller = BeerListController(
    repository: widget.repository,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDiscover)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoadingInitial && _controller.items.isEmpty) {
      return const LoadingState();
    }

    if (_controller.error != null && _controller.items.isEmpty) {
      return ErrorState(
        message: catalogErrorText(context, _controller.error!),
        onRetry: _controller.loadInitial,
      );
    }

    if (_controller.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [EmptyState()],
        ),
      );
    }

    return RefreshIndicator(
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
              onTap: () => context.push(AppRoutes.beerDetailPath(beer.id)),
            );
          }
          return _ListFooter(controller: _controller);
        },
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final BeerListController controller;

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
