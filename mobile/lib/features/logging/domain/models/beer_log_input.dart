/// Write-side payload for creating a beer log. Unlike [BeerLogUpdateInput],
/// CREATE has no existing row to preserve or clear -- "omitted" and
/// "explicitly null" mean the same thing (no value), so plain nullable
/// fields are sufficient; [toJson] simply drops null entries.
class BeerLogCreateInput {
  const BeerLogCreateInput({
    required this.beerId,
    this.rating,
    this.review,
    this.consumedAt,
    this.servingNote,
    this.price,
    this.currency,
    this.venueName,
    this.servingVolumeMl,
  });

  final String beerId;
  final int? rating;
  final String? review;
  final DateTime? consumedAt;
  final String? servingNote;
  final double? price;
  final String? currency;
  final String? venueName;
  final int? servingVolumeMl;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'beer_id': beerId};
    if (rating != null) json['rating'] = rating;
    if (review != null) json['review'] = review;
    if (consumedAt != null) {
      json['consumed_at'] = consumedAt!.toUtc().toIso8601String();
    }
    if (servingNote != null) json['serving_note'] = servingNote;
    if (price != null) json['price'] = price;
    if (currency != null) json['currency'] = currency;
    if (venueName != null) json['venue_name'] = venueName;
    if (servingVolumeMl != null) json['serving_volume_ml'] = servingVolumeMl;
    return json;
  }
}

/// Write-side payload for editing a beer log (PATCH semantics).
///
/// A plain Dart class with nullable named parameters cannot distinguish
/// `BeerLogUpdateInput(venueName: null)` (explicit clear) from
/// `BeerLogUpdateInput()` (don't touch `venueName` at all) -- both would
/// otherwise leave the field `null` with no way to tell which happened.
/// Every field here defaults to a private sentinel instead of `null`, so
/// "the caller passed null" and "the caller passed nothing" stay
/// distinguishable, matching the backend's `exclude_unset` PATCH semantics
/// exactly:
///
/// - `BeerLogUpdateInput(review: "new text")` -> `{"review": "new text"}`
/// - `BeerLogUpdateInput(venueName: null)` -> `{"venue_name": null}`
/// - `BeerLogUpdateInput()` -> `{}` (and [isEmpty] is `true`)
///
/// Trade-off: constructor parameters are typed `Object?` rather than their
/// true type, so a caller passing the wrong type fails at the `as T?` cast
/// inside [toPatchJson] rather than at the call site. Accepted because every
/// construction of this class is localized to the logging feature's
/// controller/form, not scattered across the codebase, and is covered by
/// exact-JSON unit tests.
class BeerLogUpdateInput {
  const BeerLogUpdateInput({
    this._rating = _unset,
    this._review = _unset,
    this._consumedAt = _unset,
    this._servingNote = _unset,
    this._price = _unset,
    this._currency = _unset,
    this._venueName = _unset,
    this._servingVolumeMl = _unset,
  });

  static const Object _unset = Object();

  final Object? _rating;
  final Object? _review;
  final Object? _consumedAt;
  final Object? _servingNote;
  final Object? _price;
  final Object? _currency;
  final Object? _venueName;
  final Object? _servingVolumeMl;

  Map<String, dynamic> toPatchJson() {
    final json = <String, dynamic>{};
    if (!identical(_rating, _unset)) json['rating'] = _rating as int?;
    if (!identical(_review, _unset)) json['review'] = _review as String?;
    if (!identical(_consumedAt, _unset)) {
      json['consumed_at'] = (_consumedAt as DateTime?)
          ?.toUtc()
          .toIso8601String();
    }
    if (!identical(_servingNote, _unset)) {
      json['serving_note'] = _servingNote as String?;
    }
    if (!identical(_price, _unset)) json['price'] = _price as double?;
    if (!identical(_currency, _unset)) json['currency'] = _currency as String?;
    if (!identical(_venueName, _unset)) {
      json['venue_name'] = _venueName as String?;
    }
    if (!identical(_servingVolumeMl, _unset)) {
      json['serving_volume_ml'] = _servingVolumeMl as int?;
    }
    return json;
  }

  bool get isEmpty => toPatchJson().isEmpty;
}
