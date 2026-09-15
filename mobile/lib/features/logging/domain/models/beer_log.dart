import '../../../catalog/domain/models/json_parsing.dart';

/// A user's personal record of having tried/reviewed a catalog beer.
/// User-owned, distinct from the global [Beer] catalog entity -- mirrors
/// the backend's `BeerLogOut` schema. A user may have multiple logs for the
/// same beer (see docs/DECISIONS.md).
class BeerLog {
  const BeerLog({
    required this.id,
    required this.userId,
    required this.beerId,
    required this.consumedAt,
    required this.createdAt,
    required this.updatedAt,
    this.rating,
    this.review,
    this.servingNote,
    this.price,
    this.currency,
    this.venueName,
    this.servingVolumeMl,
  });

  final String id;
  final String userId;
  final String beerId;
  final int? rating;
  final String? review;
  final DateTime consumedAt;
  final String? servingNote;
  final double? price;
  final String? currency;
  final String? venueName;

  /// Canonical unit is milliliters. Never inferred/defaulted -- `null` means
  /// the log simply has no recorded volume, not zero.
  final int? servingVolumeMl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BeerLog.fromJson(Map<String, dynamic> json) {
    return BeerLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      beerId: json['beer_id'] as String,
      rating: json['rating'] as int?,
      review: json['review'] as String?,
      consumedAt: DateTime.parse(json['consumed_at'] as String),
      servingNote: json['serving_note'] as String?,
      price: parseNullableDouble(json['price']),
      currency: json['currency'] as String?,
      venueName: json['venue_name'] as String?,
      servingVolumeMl: json['serving_volume_ml'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
