import '../domain/map_mode.dart';
import '../domain/models/map_beer.dart';
import '../domain/models/map_brewery.dart';
import 'map_debug_log.dart';

/// The only two platform operations the map data needs. The screen wraps
/// MapLibre's controller in an adapter; tests supply a recording fake, so the
/// synchronization logic is verifiable without a platform view.
abstract interface class MapSurface {
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> data);
  Future<void> setLayerVisibility(String layerId, bool visible);
}

/// What the controller currently wants on the map.
class MapSnapshot {
  const MapSnapshot({
    required this.beers,
    required this.breweries,
    required this.mode,
  });

  final List<MapBeer> beers;
  final List<MapBrewery> breweries;
  final MapMode mode;
}

/// GeoJSON for the beers source. Coordinates are `[longitude, latitude]` per the
/// GeoJSON spec; `id` and `properties.beer_id` let a tap resolve back to the
/// beer.
Map<String, dynamic> beerFeatureCollection(List<MapBeer> beers) => {
  'type': 'FeatureCollection',
  'features': [
    for (final beer in beers)
      {
        'type': 'Feature',
        'id': beer.beerId,
        'geometry': {
          'type': 'Point',
          'coordinates': [beer.longitude, beer.latitude],
        },
        'properties': {'beer_id': beer.beerId},
      },
  ],
};

/// GeoJSON for the breweries source (see [beerFeatureCollection]).
Map<String, dynamic> breweryFeatureCollection(List<MapBrewery> breweries) => {
  'type': 'FeatureCollection',
  'features': [
    for (final brewery in breweries)
      {
        'type': 'Feature',
        'id': brewery.breweryId,
        'geometry': {
          'type': 'Point',
          'coordinates': [brewery.longitude, brewery.latitude],
        },
        'properties': {'brewery_id': brewery.breweryId},
      },
  ],
};

/// Keeps the map's two GeoJSON sources and its layer visibility in step with
/// the controller -- and does **no work when nothing changed**.
///
/// Before this existed, every controller notification rebuilt BOTH collections
/// and issued 2 `setGeoJsonSource` + 6 `setLayerVisibility` platform calls, even
/// for the loading-start notification (which still carries the previous data)
/// and for a mode/search change that touched only one collection. Each load
/// notifies twice, so one search cost 16 platform calls, up to 4 of them
/// re-uploading a full collection that had not changed.
///
/// Now, per sync:
/// - a source is re-uploaded only if its content fingerprint (ids and
///   coordinates) changed since the map last received it;
/// - layer visibility is set only when the beers/breweries mode flipped;
/// - overlapping syncs coalesce: while one runs, further requests just mark it
///   dirty, and it re-reads the LATEST snapshot instead of replaying stale ones;
/// - a failed platform call is logged (debug only) and leaves that piece marked
///   unsynced, so the next sync retries it rather than leaving the map stale.
class MapDataSynchronizer {
  MapDataSynchronizer({
    required this._surface,
    required this._beersSourceId,
    required this._breweriesSourceId,
    required this._beerLayerIds,
    required this._breweryLayerIds,
  });

  final MapSurface _surface;
  final String _beersSourceId;
  final String _breweriesSourceId;
  final List<String> _beerLayerIds;
  final List<String> _breweryLayerIds;

  int? _beersFingerprint;
  int? _breweriesFingerprint;
  bool? _showingBreweries;

  bool _running = false;
  bool _rerun = false;

  /// Forget what the map holds. Call after the style (re)loads and the sources
  /// are (re)created empty, so the next [sync] uploads everything.
  void invalidate() {
    _beersFingerprint = null;
    _breweriesFingerprint = null;
    _showingBreweries = null;
    if (_running) _rerun = true;
  }

  /// Brings the map up to date with `read()`. Never throws; never overlaps.
  Future<void> sync(MapSnapshot Function() read) async {
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerun = false;
        await _syncOnce(read());
      } while (_rerun);
    } catch (error, stackTrace) {
      // Nothing that failed was marked synced, so the next notification retries.
      logMapError('MapDataSynchronizer.sync', error, stackTrace);
    } finally {
      _running = false;
    }
  }

  Future<void> _syncOnce(MapSnapshot snapshot) async {
    final beersFingerprint = _fingerprintBeers(snapshot.beers);
    if (beersFingerprint != _beersFingerprint) {
      await _surface.setGeoJsonSource(
        _beersSourceId,
        beerFeatureCollection(snapshot.beers),
      );
      _beersFingerprint = beersFingerprint;
    }

    final breweriesFingerprint = _fingerprintBreweries(snapshot.breweries);
    if (breweriesFingerprint != _breweriesFingerprint) {
      await _surface.setGeoJsonSource(
        _breweriesSourceId,
        breweryFeatureCollection(snapshot.breweries),
      );
      _breweriesFingerprint = breweriesFingerprint;
    }

    final showBreweries = snapshot.mode == MapMode.breweries;
    if (showBreweries != _showingBreweries) {
      for (final layerId in _beerLayerIds) {
        await _surface.setLayerVisibility(layerId, !showBreweries);
      }
      for (final layerId in _breweryLayerIds) {
        await _surface.setLayerVisibility(layerId, showBreweries);
      }
      _showingBreweries = showBreweries;
    }
  }

  // Cheap O(n) content fingerprints: only what the map renders (id + position).
  static int _fingerprintBeers(List<MapBeer> beers) {
    var hash = beers.length;
    for (final beer in beers) {
      hash = Object.hash(hash, beer.beerId, beer.latitude, beer.longitude);
    }
    return hash;
  }

  static int _fingerprintBreweries(List<MapBrewery> breweries) {
    var hash = breweries.length;
    for (final brewery in breweries) {
      hash = Object.hash(
        hash,
        brewery.breweryId,
        brewery.latitude,
        brewery.longitude,
      );
    }
    return hash;
  }
}
