/// Server-side filter for `GET /map/beers`. Mirrors the backend's
/// `_MapState` literal.
enum BeerMapState {
  all,
  tried,
  notTried,
  favorites,
  wishlist;

  /// The exact `state=` query value the backend expects.
  String get queryValue {
    switch (this) {
      case BeerMapState.all:
        return 'all';
      case BeerMapState.tried:
        return 'tried';
      case BeerMapState.notTried:
        return 'not_tried';
      case BeerMapState.favorites:
        return 'favorites';
      case BeerMapState.wishlist:
        return 'wishlist';
    }
  }
}

/// The map's single-select display mode -- PRODUCT.md's "possible map
/// states" (All beers / Tried / Not tried / Favorites / Wishlist). Exactly
/// one is active at a time; these are not independently combinable filters
/// (see docs/DECISIONS.md). There is no "Breweries" mode -- QA Round 1
/// Block 2 removed it from the main map, which is beer-origin-first; the
/// backend's brewery endpoints remain for other features.
enum MapMode {
  all,
  tried,
  notTried,
  favorites,
  wishlist;

  /// The beer-state filter this mode maps to.
  BeerMapState get beerState {
    switch (this) {
      case MapMode.all:
        return BeerMapState.all;
      case MapMode.tried:
        return BeerMapState.tried;
      case MapMode.notTried:
        return BeerMapState.notTried;
      case MapMode.favorites:
        return BeerMapState.favorites;
      case MapMode.wishlist:
        return BeerMapState.wishlist;
    }
  }
}
