/// Pure helpers for interpreting a MapLibre cluster-tap feature payload
/// (from `queryRenderedFeatures`). Extracted so the numeric/ordering/
/// source-mapping logic can be unit tested without a native MapLibre
/// platform view, which the widget-test environment doesn't back with a
/// real implementation.
library;

/// Parses a GeoJSON cluster feature's `cluster_id` property into an int.
/// MapLibre's platform channel can hand this back as any [num] subtype; the
/// only property this app ever needs an int for is one already known to be
/// numeric on a real cluster feature. Returns `null` for anything else --
/// callers must treat that as "not a valid cluster id" and do nothing, never
/// substitute a default like `0`.
int? parseClusterId(Object? rawClusterId) {
  if (rawClusterId is num) return rawClusterId.toInt();
  return null;
}

/// A plain (latitude, longitude) pair, in the order every `LatLng`-shaped
/// API in this app expects -- distinct from GeoJSON's own (longitude,
/// latitude) axis order.
typedef LatLngValue = ({double latitude, double longitude});

/// Converts a GeoJSON Point's `coordinates` array (`[longitude, latitude]`,
/// per RFC 7946 section 3.1.1) into a [LatLngValue]. Returns `null` for
/// anything that isn't a valid 2-element numeric pair, so callers never
/// silently center on `(0, 0)` or a stale value.
LatLngValue? geoJsonCoordinatesToLatLng(Object? coordinates) {
  if (coordinates is! List || coordinates.length != 2) return null;
  final longitude = coordinates[0];
  final latitude = coordinates[1];
  if (longitude is! num || latitude is! num) return null;
  return (latitude: latitude.toDouble(), longitude: longitude.toDouble());
}

/// Maps a tapped cluster-related layer id to the GeoJSON source id it
/// clusters -- explicit beer-vs-brewery cases, never an ambiguous "if not
/// beer, assume brewery" binary guess.
///
/// Each entity has *two* cluster-related layers sharing one source: the
/// circle bubble and its point-count text label. MapLibre's native hit-test
/// can resolve a tap to either -- on Android, confirmed live, a tap
/// squarely on a cluster's rendered label resolves to the count label
/// layer, not the circle beneath it, because the text glyph's bounds win
/// hit-testing where the two overlap. Both layers render the exact same
/// cluster features from the exact same source, so both must map to that
/// source; treating only the circle layer as "known" (the label layer
/// falling through to "unrecognized") silently no-ops on a real fraction of
/// genuine cluster taps.
///
/// Returns `null` for any layer id that isn't one of the four known
/// cluster-related layers.
String? clusterSourceIdForLayer(
  String layerId, {
  required String beersClusterLayerId,
  required String beersClusterCountLayerId,
  required String breweriesClusterLayerId,
  required String breweriesClusterCountLayerId,
  required String beersSourceId,
  required String breweriesSourceId,
}) {
  if (layerId == beersClusterLayerId || layerId == beersClusterCountLayerId) {
    return beersSourceId;
  }
  if (layerId == breweriesClusterLayerId ||
      layerId == breweriesClusterCountLayerId) {
    return breweriesSourceId;
  }
  return null;
}
