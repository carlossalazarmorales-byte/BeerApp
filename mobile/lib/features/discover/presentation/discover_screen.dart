import 'package:flutter/material.dart';

import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/beer_list/beer_list_screen.dart';

/// The Discover destination: real catalog browsing via [BeerListScreen].
/// Kept as a thin wrapper (rather than folding the list directly into the
/// route builder) so this is the one place the Discover tab's identity is
/// established, independent of how the catalog feature is implemented --
/// Phase 5 (Search and Discover) will add filters/sections here without
/// touching `features/catalog/`.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({required this.catalogRepository, super.key});

  final CatalogRepository catalogRepository;

  @override
  Widget build(BuildContext context) {
    return BeerListScreen(repository: catalogRepository);
  }
}
