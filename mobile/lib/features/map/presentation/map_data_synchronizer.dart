import '../data/country_boundaries.dart';
import '../domain/models/map_beer.dart';
import '../domain/models/map_country.dart';
import 'map_debug_log.dart';

/// The only platform operation the map data needs. The screen wraps
/// MapLibre's controller in an adapter; tests supply a recording fake, so
/// the synchronization logic is verifiable without a platform view.
abstract interface class MapSurface {
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> data);
}

/// What the controller currently wants on the map. [countryBoundaries] is
/// effectively constant after the bundled asset finishes loading (see
/// `CountryBoundaries.load`) -- it is still read fresh on every sync so an
/// empty-to-loaded transition (the boundaries asset resolving after the
/// first sync already ran) is picked up like any other change.
class MapSnapshot {
  const MapSnapshot({
    required this.beers,
    required this.countryCoverage,
    required this.countryBoundaries,
  });

  final List<MapBeer> beers;
  final List<MapCountry> countryCoverage;
  final List<CountryBoundary> countryBoundaries;
}

/// GeoJSON for the beers source. Coordinates are `[longitude, latitude]` per
/// the GeoJSON spec; `id` and `properties.beer_id` let a tap resolve back to
/// the beer. `properties.is_tried` drives the points layer's data-driven
/// circle color (see MapScreen) -- gray untried, gold tried.
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
        'properties': {'beer_id': beer.beerId, 'is_tried': beer.isTried},
      },
  ],
};

/// The country-fill layer's three flat, non-gradient states (QA Round 1
/// Block 2). Never a 4th "full coverage" tier and never derived from a
/// continuous ratio -- see docs/QA_ROUND_1.md Block 2 and CLAUDE.md's
/// Responsible Product Design section.
enum CountryFillState {
  zeroCatalog('zero_catalog'),
  zeroHistory('zero_history'),
  hasHistory('has_history');

  const CountryFillState(this.value);

  /// The exact `fill_state` property value MapScreen's style expression
  /// matches on.
  final String value;
}

/// GeoJSON for the countries fill source: every bundled boundary polygon,
/// each tagged with its [CountryFillState] resolved against [coverage] by
/// ISO code. A boundary with no clean ISO code in this release of the
/// source data (`CountryBoundary.isoCode == null`), or whose ISO code has
/// no row in [coverage] at all, is [CountryFillState.zeroCatalog] --
/// absence is the "zero catalog" signal, never a fabricated ISO mapping or
/// a zero-count row (see `CountryBoundaries`/`MapCountry`).
Map<String, dynamic> countryFillFeatureCollection(
  List<CountryBoundary> boundaries,
  List<MapCountry> coverage,
) {
  final coverageByIso = <String, MapCountry>{
    for (final country in coverage) country.isoCode.toUpperCase(): country,
  };
  return {
    'type': 'FeatureCollection',
    'features': [
      for (final boundary in boundaries)
        {
          'type': 'Feature',
          'geometry': boundary.geometry,
          'properties': {
            'fill_state': _fillState(boundary, coverageByIso).value,
          },
        },
    ],
  };
}

CountryFillState _fillState(
  CountryBoundary boundary,
  Map<String, MapCountry> coverageByIso,
) {
  final isoCode = boundary.isoCode;
  if (isoCode == null) return CountryFillState.zeroCatalog;
  final entry = coverageByIso[isoCode.toUpperCase()];
  if (entry == null) return CountryFillState.zeroCatalog;
  return entry.triedBeerCount > 0
      ? CountryFillState.hasHistory
      : CountryFillState.zeroHistory;
}

/// Keeps the map's two GeoJSON sources (beers, country fill) in step with
/// the controller -- and does **no work when nothing changed**.
///
/// Per sync:
/// - a source is re-uploaded only if its content fingerprint changed since
///   the map last received it;
/// - overlapping syncs coalesce: while one runs, further requests just mark
///   it dirty, and it re-reads the LATEST snapshot instead of replaying
///   stale ones;
/// - a failed platform call is logged (debug only) and leaves that piece
///   marked unsynced, so the next sync retries it rather than leaving the
///   map stale.
class MapDataSynchronizer {
  MapDataSynchronizer({
    required this._surface,
    required this._beersSourceId,
    required this._countriesSourceId,
  });

  final MapSurface _surface;
  final String _beersSourceId;
  final String _countriesSourceId;

  int? _beersFingerprint;
  int? _countryFillFingerprint;

  bool _running = false;
  bool _rerun = false;

  /// Forget what the map holds. Call after the style (re)loads and the
  /// sources are (re)created empty, so the next [sync] uploads everything.
  void invalidate() {
    _beersFingerprint = null;
    _countryFillFingerprint = null;
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

    final countryFillFingerprint = _fingerprintCountryFill(
      snapshot.countryBoundaries,
      snapshot.countryCoverage,
    );
    if (countryFillFingerprint != _countryFillFingerprint) {
      await _surface.setGeoJsonSource(
        _countriesSourceId,
        countryFillFeatureCollection(
          snapshot.countryBoundaries,
          snapshot.countryCoverage,
        ),
      );
      _countryFillFingerprint = countryFillFingerprint;
    }
  }

  // Cheap O(n) content fingerprints: only what the map renders.
  static int _fingerprintBeers(List<MapBeer> beers) {
    var hash = beers.length;
    for (final beer in beers) {
      hash = Object.hash(
        hash,
        beer.beerId,
        beer.latitude,
        beer.longitude,
        beer.isTried,
      );
    }
    return hash;
  }

  // Boundaries are effectively constant once loaded (a bundled asset), so
  // their count alone is enough to detect the one real transition that
  // matters: the asset resolving from "not yet loaded" (0) to loaded (the
  // fixed feature count). Coverage drives every fingerprint change after
  // that.
  static int _fingerprintCountryFill(
    List<CountryBoundary> boundaries,
    List<MapCountry> coverage,
  ) {
    var hash = Object.hash(boundaries.length, coverage.length);
    for (final country in coverage) {
      hash = Object.hash(hash, country.isoCode, country.triedBeerCount > 0);
    }
    return hash;
  }
}
