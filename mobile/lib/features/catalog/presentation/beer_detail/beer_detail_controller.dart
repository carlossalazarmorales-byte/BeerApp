import 'package:flutter/foundation.dart';

import '../../domain/catalog_repository.dart';
import '../../domain/models/beer.dart';
import '../../domain/models/brewery.dart';
import '../catalog_debug_log.dart';

/// Drives the beer detail screen. Takes a `beerId`, not a [Beer] object --
/// this must work standing alone from a cold/deep link, with nothing
/// upstream (e.g. the beer list) having loaded anything yet.
///
/// Load order matters: [Beer.breweryId] isn't known until `getBeer` returns,
/// so the brewery fetch cannot start in parallel with it -- it's a second,
/// sequential step once the beer resolves. Country/style lookups have no
/// such dependency and run concurrently with the beer fetch.
class BeerDetailController extends ChangeNotifier {
  BeerDetailController({required this._repository, required this._beerId});

  final CatalogRepository _repository;
  final String _beerId;

  Beer? beer;
  Brewery? brewery;
  String? styleName;
  String? countryName;
  String? breweryCountryName;
  bool isLoading = false;
  Object? error;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final beerFuture = _repository.getBeer(_beerId);
      final countriesFuture = _repository.getCountries();
      final stylesFuture = _repository.getBeerStyles();

      final loadedBeer = await beerFuture;
      final countries = await countriesFuture;
      final styles = await stylesFuture;

      // Can only start once loadedBeer.breweryId is known.
      final loadedBrewery = await _repository.getBrewery(loadedBeer.breweryId);

      final countryNames = {for (final c in countries) c.id: c.name};
      final styleNames = {for (final s in styles) s.id: s.name};

      beer = loadedBeer;
      brewery = loadedBrewery;
      styleName = loadedBeer.styleId == null
          ? null
          : styleNames[loadedBeer.styleId];
      countryName = loadedBeer.countryId == null
          ? null
          : countryNames[loadedBeer.countryId];
      breweryCountryName = countryNames[loadedBrewery.countryId];
    } catch (e, st) {
      error = e;
      logCatalogError('BeerDetailController.load', e, st);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
