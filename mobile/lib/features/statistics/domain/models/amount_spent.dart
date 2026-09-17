import '../../../catalog/domain/models/json_parsing.dart';

/// One currency's total across the user's priced logs. Statistics never
/// sums across currencies -- there is no per-user default currency until
/// Phase 12 profile editing, so a blind sum would silently misrepresent the
/// true amount (see docs/DECISIONS.md).
class AmountSpent {
  const AmountSpent({required this.currency, required this.total});

  final String currency;
  final double total;

  factory AmountSpent.fromJson(Map<String, dynamic> json) => AmountSpent(
    currency: json['currency'] as String,
    // `total` is a Decimal on the backend (money), serialized as a string --
    // same convention as BeerLog.price/Beer.abv -- so it goes through
    // parseNullableDouble, not a bare `as double` cast.
    total: parseNullableDouble(json['total'])!,
  );
}
