import 'beer.dart';

/// A catalog [Beer] plus whether the *current* user has already tried it --
/// the `GET /beers` list response shape (backend's `BeerCatalogOut`), shared
/// by Discover (which always requests `untriedOnly: true`, so `isTried` is
/// always false there in practice) and Add Beer (the full catalog, where a
/// beer can be either). Kept off the plain [Beer] model itself, which stays
/// user-independent per docs/ARCHITECTURE.md's global/personal split -- see
/// the identical precedent in `MapBeer`/`CollectionBeer`.
class DiscoverBeer {
  const DiscoverBeer({required this.beer, required this.isTried});

  final Beer beer;
  final bool isTried;

  factory DiscoverBeer.fromJson(Map<String, dynamic> json) {
    return DiscoverBeer(
      beer: Beer.fromJson(json),
      isTried: json['is_tried'] as bool,
    );
  }
}
