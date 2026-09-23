import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/secondary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/components/states/empty_state.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/inline_progress.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/collection_refresh_signal.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/beer.dart';
import '../../catalog/presentation/beer_list/beer_list_tile.dart';
import '../../catalog/presentation/catalog_error_text.dart';
import '../../logging/domain/log_repository.dart';
import '../../logging/presentation/beer_log/beer_log_controller.dart';
import '../../logging/presentation/beer_log/log_form_sheet.dart';
import 'add_beer_controller.dart';

/// The center bottom-nav ("+") destination: the app's only user-facing
/// entry point for creating a NEW log (QA Round 1 Block 1).
///
/// PRIMARY path: search the full catalog (including already-tried beers --
/// a user may deliberately log one again) and pick a beer, which opens the
/// existing [LogFormSheet]. SECONDARY path: "Scan barcode" pushes the
/// existing scanner as a shortcut to identify a beer, which feeds the same
/// form -- the scanner never auto-creates a log.
class AddBeerScreen extends StatefulWidget {
  const AddBeerScreen({
    required this.catalogRepository,
    required this.logRepository,
    required this.refreshSignal,
    super.key,
  });

  final CatalogRepository catalogRepository;
  final LogRepository logRepository;
  final CollectionRefreshSignal refreshSignal;

  @override
  State<AddBeerScreen> createState() => _AddBeerScreenState();
}

class _AddBeerScreenState extends State<AddBeerScreen> {
  static const double _loadMoreThreshold = 300;

  late final AddBeerController _controller = AddBeerController(
    repository: widget.catalogRepository,
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

  Future<void> _openLogForm(Beer beer) async {
    final logController = BeerLogController(
      repository: widget.logRepository,
      beerId: beer.id,
      refreshSignal: widget.refreshSignal,
    );
    final saved = await LogFormSheet.show(context, controller: logController);
    logController.dispose();
    if (saved != true) return;
    // Only after the save is confirmed -- flips this beer's tile to
    // unlocked immediately, without requiring another search/reload.
    _controller.markTried(beer.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).beerLogSavedConfirmation),
        ),
      );
    }
  }

  Future<void> _scanBarcode() async {
    final beer = await context.push<Beer>(AppRoutes.scan);
    if (beer != null && mounted) {
      await _openLogForm(beer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addBeerScreenTitle)),
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
              hintText: l10n.addBeerSearchHint,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SecondaryButton(
                label: l10n.addBeerScanAction,
                onPressed: _scanBarcode,
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

    if (_controller.items.isEmpty) {
      return EmptyState(message: l10n.addBeerNoResultsMessage);
    }

    return Column(
      children: [
        if (_controller.isLoadingInitial) const InlineProgressBar(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: _controller.items.length + 1,
            itemBuilder: (context, index) {
              if (index < _controller.items.length) {
                final item = _controller.items[index];
                final beer = item.beer;
                return BeerListTile(
                  beer: beer,
                  // Unlocked == tried (has at least one log already) --
                  // Add Beer shows the full catalog, so both states occur
                  // here, unlike Discover.
                  isUnlocked: item.isTried,
                  onTap: () => _openLogForm(beer),
                );
              }
              return _ListFooter(controller: _controller);
            },
          ),
        ),
      ],
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final AddBeerController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: InlineSpinner(size: 24)),
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
