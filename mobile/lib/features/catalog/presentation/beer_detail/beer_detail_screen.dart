import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/components/states/error_state.dart';
import '../../../../design_system/components/states/loading_state.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/catalog_repository.dart';
import '../catalog_error_text.dart';
import 'beer_detail_controller.dart';

/// Full-screen beer detail, pushed above the bottom-nav shell (see
/// app/router.dart). No rating/review/favorite/wishlist/log UI -- explicitly
/// out of scope for this phase.
class BeerDetailScreen extends StatefulWidget {
  const BeerDetailScreen({
    required this.repository,
    required this.beerId,
    super.key,
  });

  final CatalogRepository repository;
  final String beerId;

  @override
  State<BeerDetailScreen> createState() => _BeerDetailScreenState();
}

class _BeerDetailScreenState extends State<BeerDetailScreen> {
  late final BeerDetailController _controller = BeerDetailController(
    repository: widget.repository,
    beerId: widget.beerId,
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The AppBar title (the beer's name, once loaded) must rebuild on the
    // same notifications as the body -- both live inside this one
    // ListenableBuilder rather than splitting it out, so the title isn't
    // stuck showing its initial (pre-load) value.
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(_controller.beer?.officialName ?? '')),
        body: _buildBody(context),
      ),
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
