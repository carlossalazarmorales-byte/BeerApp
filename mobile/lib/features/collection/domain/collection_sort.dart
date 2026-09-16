/// Sort options for a Collection list, shared across all three tabs.
/// `rating` always means the beer's *latest* log's rating, never an
/// average (see docs/DECISIONS.md); `recent` means "most recently added to
/// this tab's state" -- latest log date for Logged, favorited/wishlisted-at
/// for Favorites/Wishlist.
enum CollectionSort {
  recent,
  rating,
  // Named `alphabetical`, not `name` -- an enum value literally named
  // `name` shadows the built-in `Enum.name` getter within the enum's own
  // body, which broke `queryValue` below (it resolved to the constant
  // itself instead of the instance getter).
  alphabetical;

  /// The exact `sort=` query value the backend expects.
  String get queryValue {
    switch (this) {
      case CollectionSort.recent:
        return 'recent';
      case CollectionSort.rating:
        return 'rating';
      case CollectionSort.alphabetical:
        return 'name';
    }
  }
}
