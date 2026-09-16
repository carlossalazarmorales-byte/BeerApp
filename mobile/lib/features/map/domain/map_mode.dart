/// Server-side filter for `GET /map/beers`. Never includes a "breweries"
/// value -- that's a separate endpoint (`GET /map/breweries`), never a
/// `state` value of this one. Mirrors the backend's `_MapState` literal.
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
/// states" (All beers / Tried / Not tried / Favorites / Wishlist /
/// Breweries). Exactly one is active at a time; these are not independently
/// combinable filters (see docs/DECISIONS.md).
enum MapMode {
  all,
  tried,
  notTried,
  favorites,
  wishlist,
  breweries;

  /// The beer-state filter this mode maps to, or `null` for [breweries] --
  /// that mode calls `MapRepository.getMapBreweries` instead, never
  /// `getMapBeers`.
  BeerMapState? get beerState {
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
      case MapMode.breweries:
        return null;
    }
  }
}
