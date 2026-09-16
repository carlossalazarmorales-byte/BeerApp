import 'package:beerapp/features/map/domain/map_mode.dart';
import 'package:beerapp/features/map/domain/map_repository.dart';
import 'package:beerapp/features/map/domain/models/map_beer.dart';
import 'package:beerapp/features/map/domain/models/map_brewery.dart';
import 'package:beerapp/features/map/domain/models/map_result.dart';

class FakeMapRepository implements MapRepository {
  FakeMapRepository({this.delay = Duration.zero});

  /// Artificial delay before every method resolves -- zero by default, set
  /// to a small non-zero value to observe an intermediate loading state or
  /// to simulate a race between two in-flight requests.
  final Duration delay;

  /// Per-call delay override, keyed by the same call-log string [callLog]
  /// records -- lets a test make one specific request resolve slower/faster
  /// than [delay], deterministically simulating a race.
  Map<String, Duration> extraDelayByCallKey = {};

  /// Keyed by `'state|countryId|q'`.
  Map<String, MapResult<MapBeer>> beersByRequest = {};

  /// Keyed by `'countryId|q'`.
  Map<String, MapResult<MapBrewery>> breweriesByRequest = {};

  Object? getMapBeersError;
  Object? getMapBreweriesError;

  /// Records call order/keys -- used to assert e.g. that exactly one
  /// request was made for a given mode/search.
  final List<String> callLog = [];

  Future<void> _maybeDelay(String callKey) async {
    final effectiveDelay = extraDelayByCallKey[callKey] ?? delay;
    if (effectiveDelay > Duration.zero) {
      await Future<void>.delayed(effectiveDelay);
    }
  }

  static String _beersKey(BeerMapState state, String? countryId, String? q) =>
      '${state.queryValue}|${countryId ?? ''}|${q ?? ''}';

  static String _breweriesKey(String? countryId, String? q) =>
      '${countryId ?? ''}|${q ?? ''}';

  @override
  Future<MapResult<MapBeer>> getMapBeers({
    required BeerMapState state,
    String? countryId,
    String? q,
  }) async {
    final key = _beersKey(state, countryId, q);
    callLog.add('getMapBeers:$key');
    await _maybeDelay('getMapBeers:$key');
    final error = getMapBeersError;
    if (error != null) throw error;
    return beersByRequest[key] ?? const MapResult(items: [], truncated: false);
  }

  @override
  Future<MapResult<MapBrewery>> getMapBreweries({
    String? countryId,
    String? q,
  }) async {
    final key = _breweriesKey(countryId, q);
    callLog.add('getMapBreweries:$key');
    await _maybeDelay('getMapBreweries:$key');
    final error = getMapBreweriesError;
    if (error != null) throw error;
    return breweriesByRequest[key] ??
        const MapResult(items: [], truncated: false);
  }
}
