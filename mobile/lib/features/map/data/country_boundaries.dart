import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One country polygon/multipolygon from the bundled boundaries asset, with
/// its ISO-3166-1 alpha-2 code resolved as cleanly as this release of the
/// source data allows.
///
/// [isoCode] is `null` when the source feature has no clean 2-letter code
/// in this release (see `assets/map/NOTICE.txt` for the specific
/// currently-known cases). A `null` [isoCode] is not an error: the country
/// still renders on the map, always in the "zero catalog" fill state,
/// since it can never be matched against a `MapCountry` coverage row.
/// Callers must never fabricate an ISO mapping to avoid this.
class CountryBoundary {
  const CountryBoundary({required this.isoCode, required this.geometry});

  final String? isoCode;

  /// Raw GeoJSON geometry object (`Polygon` or `MultiPolygon`), passed
  /// through unmodified into the map's fill-layer FeatureCollection.
  final Map<String, dynamic> geometry;
}

/// Loads the bundled world-country boundaries used by the map's
/// country-fill layer. See `assets/map/NOTICE.txt` for the exact source
/// release, its known ISO-code gaps, and the processing already applied to
/// the bundled file (simplification, property/precision stripping) -- this
/// loader does no further data massaging beyond the ISO-code preference
/// below.
abstract final class CountryBoundaries {
  static const String assetPath = 'assets/map/world_countries_50m.geojson';

  static Future<List<CountryBoundary>> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final features = (decoded['features'] as List).cast<Map<String, dynamic>>();
    return [
      for (final feature in features)
        CountryBoundary(
          isoCode: _resolveIsoCode(
            (feature['properties'] as Map?)?.cast<String, dynamic>(),
          ),
          geometry: (feature['geometry'] as Map).cast<String, dynamic>(),
        ),
    ];
  }

  /// `ISO_A2_EH` is Natural Earth's "de facto" ISO column, added
  /// specifically to resolve the handful of sovereign/disputed entities
  /// (Norway, France, Kosovo, Taiwan, ...) whose plain `ISO_A2` is the
  /// sentinel `"-99"` in this dataset -- so it is preferred here. A small
  /// remainder (e.g. "N. Cyprus", Somaliland) has no clean code in either
  /// column at all -- those return `null`, never a guessed/invented code.
  static String? _resolveIsoCode(Map<String, dynamic>? properties) {
    if (properties == null) return null;
    return _clean(properties['ISO_A2_EH'] as String?) ??
        _clean(properties['ISO_A2'] as String?);
  }

  /// A clean code is exactly 2 alphabetic characters -- rules out the
  /// `"-99"` sentinel, Taiwan's plain `ISO_A2` (`"CN-TW"`), and anything
  /// else that isn't a real ISO-3166-1 alpha-2 code.
  static String? _clean(String? raw) {
    if (raw == null) return null;
    final upper = raw.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(upper)) return null;
    return upper;
  }
}
