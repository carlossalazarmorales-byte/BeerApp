import 'package:flutter/material.dart';

import '../../../../design_system/components/buttons/primary_button.dart';
import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/components/states/error_state.dart';
import '../../../../design_system/components/states/loading_state.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/collection_refresh_signal.dart';
import '../../../collection/domain/collection_repository.dart';
import '../../../collection/presentation/collection_state_controller.dart';
import '../../../logging/domain/log_repository.dart';
import '../../../logging/presentation/beer_log/beer_log_controller.dart';
import '../../../logging/presentation/beer_log/log_form_sheet.dart';
import '../../../logging/presentation/beer_log/log_list_section.dart';
import '../../domain/catalog_repository.dart';
import '../catalog_error_text.dart';
import 'beer_detail_controller.dart';

/// Full-screen beer detail, pushed above the bottom-nav shell (see
/// app/router.dart).
class BeerDetailScreen extends StatefulWidget {
  const BeerDetailScreen({
    required this.repository,
    required this.logRepository,
    required this.collectionRepository,
    required this.refreshSignal,
    required this.beerId,
    super.key,
  });

  final CatalogRepository repository;
  final LogRepository logRepository;
  final CollectionRepository collectionRepository;
  final CollectionRefreshSignal refreshSignal;
  final String beerId;

  @override
  State<BeerDetailScreen> createState() => _BeerDetailScreenState();
}

class _BeerDetailScreenState extends State<BeerDetailScreen> {
  late final BeerDetailController _controller = BeerDetailController(
    repository: widget.repository,
    beerId: widget.beerId,
  );
  late final BeerLogController _logController = BeerLogController(
    repository: widget.logRepository,
    beerId: widget.beerId,
    refreshSignal: widget.refreshSignal,
  );
  late final CollectionStateController _collectionController =
      CollectionStateController(
        repository: widget.collectionRepository,
        beerId: widget.beerId,
        refreshSignal: widget.refreshSignal,
      );

  @override
  void initState() {
    super.initState();
    _controller.load();
    _logController.load();
    _collectionController.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _logController.dispose();
    _collectionController.dispose();
    super.dispose();
  }

  Future<void> _openLogForm() async {
    final saved = await LogFormSheet.show(context, controller: _logController);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).beerLogSavedConfirmation),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The AppBar title (the beer's name, once loaded) must rebuild on the
    // same notifications as the body -- both live inside this one
    // ListenableBuilder rather than splitting it out, so the title isn't
    // stuck showing its initial (pre-load) value. Merged with
    // _logController/_collectionController too, so "Your logs" and the
    // favorite/wishlist buttons rebuild from the same single listenable.
    // _collectionController's own load failure is deliberately never
    // consulted by _buildBody's guards below -- a collection-state failure
    // can only ever disable the favorite/wishlist buttons, never block the
    // rest of the screen.
    return ListenableBuilder(
      listenable: Listenable.merge([
        _controller,
        _logController,
        _collectionController,
      ]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_controller.beer?.officialName ?? ''),
          actions: _controller.beer == null
              ? null
              : [_buildCollectionActions(context)],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildCollectionActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Disabled while loading, or if the initial load never succeeded (no
    // confirmed baseline state to toggle from) -- a collection-state
    // failure only ever disables these two buttons, never the rest of the
    // screen (see this method's caller). A later failed mutation rolls
    // back to the last-known-good value and does not disable the buttons,
    // since retrying is safe once there's a confirmed baseline.
    final disabled =
        _collectionController.isLoading || !_collectionController.hasLoaded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _collectionController.isFavorite ? Icons.star : Icons.star_border,
          ),
          tooltip: _collectionController.isFavorite
              ? l10n.beerDetailRemoveFromFavoritesAction
              : l10n.beerDetailAddToFavoritesAction,
          onPressed: disabled
              ? null
              : () => _collectionController.setFavorite(
                  !_collectionController.isFavorite,
                ),
        ),
        IconButton(
          icon: Icon(
            _collectionController.isWishlist
                ? Icons.bookmark
                : Icons.bookmark_border,
          ),
          tooltip: _collectionController.isWishlist
              ? l10n.beerDetailRemoveFromWishlistAction
              : l10n.beerDetailAddToWishlistAction,
          onPressed: disabled
              ? null
              : () => _collectionController.setWishlist(
                  !_collectionController.isWishlist,
                ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading && _controller.beer == null) {
      return const LoadingState();
    }

    final error = _controller.error;
    if (error != null && _controller.beer == null) {
      return ErrorState(
        message: catalogErrorText(context, error),
        onRetry: _controller.load,
      );
    }

    final beer = _controller.beer;
    if (beer == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final brewery = _controller.brewery;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _BeerImage(imageUrl: beer.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        beer.officialName,
                        style: AppTypography.headlineLarge,
                      ),
                    ),
                    if (beer.verified) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _Badge(label: l10n.beerDetailVerifiedBadge),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (brewery != null)
                  _InfoCard(
                    label: l10n.beerDetailBreweryLabel,
                    title: brewery.name,
                    subtitle: [
                      if (brewery.city != null) brewery.city!,
                      if (_controller.breweryCountryName != null)
                        _controller.breweryCountryName!,
                    ].join(' • '),
                  ),
                if (_controller.styleName != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _InfoCard(
                    label: l10n.beerDetailStyleLabel,
                    title: _controller.styleName!,
                    subtitle: '',
                  ),
                ],
                if (beer.abv != null || beer.ibu != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (beer.abv != null)
                        Expanded(
                          child: _StatTile(
                            label: l10n.beerDetailAbvLabel,
                            value: '${beer.abv!.toStringAsFixed(1)}%',
                          ),
                        ),
                      if (beer.abv != null && beer.ibu != null)
                        const SizedBox(width: AppSpacing.md),
                      if (beer.ibu != null)
                        Expanded(
                          child: _StatTile(
                            label: l10n.beerDetailIbuLabel,
                            value: '${beer.ibu}',
                          ),
                        ),
                    ],
                  ),
                ],
                if (beer.description != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.beerDetailDescriptionLabel,
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(beer.description!, style: AppTypography.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: l10n.beerDetailLogAction,
                    onPressed: _openLogForm,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LogListSection(controller: _logController),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BeerImage extends StatelessWidget {
  const _BeerImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = Container(
      color: AppColors.secondaryContainer,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_bar_outlined,
        size: 48,
        color: AppColors.secondary,
      ),
    );
    if (url == null) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: AppRadii.fullRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.onSecondaryFixed,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(title, style: AppTypography.titleLarge),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppTypography.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.titleLarge),
        ],
      ),
    );
  }
}
