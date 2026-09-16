/// This user's favorite/wishlist state for one catalog beer. Mirrors the
/// backend's `CollectionStateOut` schema. `isFavorite`/`isWishlist` default
/// to `false` for a beer with no collection row yet -- see
/// `CollectionRepository.getState`'s doc comment.
class CollectionState {
  const CollectionState({
    required this.beerId,
    required this.isFavorite,
    required this.isWishlist,
  });

  final String beerId;
  final bool isFavorite;
  final bool isWishlist;

  factory CollectionState.fromJson(Map<String, dynamic> json) {
    return CollectionState(
      beerId: json['beer_id'] as String,
      isFavorite: json['is_favorite'] as bool,
      isWishlist: json['is_wishlist'] as bool,
    );
  }
}
