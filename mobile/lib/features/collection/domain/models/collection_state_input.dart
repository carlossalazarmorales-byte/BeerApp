/// Write-side payload for `PATCH /collection/{beerId}`. Unlike
/// `BeerLogUpdateInput`, neither field is ever meaningfully "explicit null"
/// -- a flag is either an absolute `true`/`false` or omitted entirely to
/// preserve the current value -- so a plain nullable field is sufficient,
/// no sentinel needed. [toPatchJson] drops omitted fields so the backend's
/// `extra="forbid"`/empty-patch checks see exactly what the caller intended.
class CollectionStateInput {
  const CollectionStateInput({this.isFavorite, this.isWishlist});

  final bool? isFavorite;
  final bool? isWishlist;

  Map<String, dynamic> toPatchJson() {
    final json = <String, dynamic>{};
    if (isFavorite != null) json['is_favorite'] = isFavorite;
    if (isWishlist != null) json['is_wishlist'] = isWishlist;
    return json;
  }
}
