/// Mirrors the backend's capped-list response envelope (`CappedList[T]`)
/// used by `/map/beers` and `/map/breweries`. `truncated=true` means the
/// server's safety cap was hit and [items] is not the complete result --
/// callers must surface that rather than treating [items] (or any
/// camera-fit computed from it) as the complete map. This cap is a Phase 8
/// safety backstop, not real pagination -- see docs/DECISIONS.md.
class MapResult<T> {
  const MapResult({required this.items, required this.truncated});

  final List<T> items;
  final bool truncated;

  factory MapResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    return MapResult(
      items: (json['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(itemParser)
          .toList(),
      truncated: json['truncated'] as bool,
    );
  }
}
