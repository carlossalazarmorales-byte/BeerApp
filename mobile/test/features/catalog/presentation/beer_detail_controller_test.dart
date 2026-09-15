import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/beer_style.dart';
import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:beerapp/features/catalog/domain/models/country.dart';
import 'package:beerapp/features/catalog/presentation/beer_detail/beer_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_catalog_repository.dart';

void main() {
  FakeCatalogRepository seededRepository() {
    return FakeCatalogRepository()
      ..countries = const [
        Country(
          id: 'country-1',
          isoCode: 'IE',
          name: 'Ireland',
          continent: 'Europe',
        ),
      ]
      ..beerStyles = const [BeerStyle(id: 'style-1', name: 'Dry Stout')]
      ..beersById['beer-1'] = const Beer(
        id: 'beer-1',
        officialName: 'Test Stout',
        breweryId: 'brewery-1',
        styleId: 'style-1',
        countryId: 'country-1',
        verified: true,
      )
      ..breweriesById['brewery-1'] = const Brewery(
        id: 'brewery-1',
        name: 'Test Brewery',
        countryId: 'country-1',
        verified: true,
      );
  }

  test(
    'works from a cold repository with no prior list load (deep-link safe)',
    () async {
      final repository = seededRepository();
      final controller = BeerDetailController(
        repository: repository,
        beerId: 'beer-1',
      );

      await controller.load();

      expect(controller.beer?.officialName, 'Test Stout');
      expect(controller.brewery?.name, 'Test Brewery');
      expect(controller.styleName, 'Dry Stout');
      expect(controller.countryName, 'Ireland');
      expect(controller.breweryCountryName, 'Ireland');
      expect(controller.error, isNull);
    },
  );

  test(
    'getBrewery is only called after getBeer resolves, not in parallel',
    () async {
      final repository = seededRepository();
      final controller = BeerDetailController(
        repository: repository,
        beerId: 'beer-1',
      );

      await controller.load();

      final beerIndex = repository.callLog.indexOf('getBeer:beer-1');
      final breweryIndex = repository.callLog.indexOf('getBrewery:brewery-1');
      expect(beerIndex, greaterThanOrEqualTo(0));
      expect(breweryIndex, greaterThan(beerIndex));
    },
  );

  test('a getBeer failure surfaces as an error, beer stays null', () async {
    final repository = seededRepository()
      ..getBeerError = Exception('not found');
    final controller = BeerDetailController(
      repository: repository,
      beerId: 'missing',
    );

    await controller.load();

    expect(controller.beer, isNull);
    expect(controller.error, isNotNull);
    expect(
      repository.callLog.contains('getBrewery:brewery-1'),
      isFalse,
      reason: 'brewery must never be fetched when the beer fetch failed',
    );
  });
}
