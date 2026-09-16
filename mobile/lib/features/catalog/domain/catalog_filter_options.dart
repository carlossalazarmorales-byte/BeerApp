import 'catalog_repository.dart';
import 'models/brewery.dart';

/// Country/style name lookups (`id -> name`), for resolving a beer's own
/// `countryId`/`styleId` into display text. Small, bounded catalog lists --
/// fetched in full, never paginated.
class CatalogNameLookups {
  const CatalogNameLookups({
    required this.countryNames,
    required this.styleNames,
  });

  final Map<String, String> countryNames;
  final Map<String, String> styleNames;
}

Future<CatalogNameLookups> loadCatalogNameLookups(
  CatalogRepository repository,
) async {
  final countries = await repository.getCountries();
  final styles = await repository.getBeerStyles();
  return CatalogNameLookups(
    countryNames: {for (final c in countries) c.id: c.name},
    styleNames: {for (final s in styles) s.id: s.name},
  );
}

/// Hard cap on how many brewery filter-option pages are fetched, so an
/// unexpectedly large catalog can't be pulled into memory in full. Above
/// this (500 breweries), the filter picker simply won't offer the rest --
/// see docs/DECISIONS.md for the documented Phase 5 limit and the planned
/// future fix (a searchable/typeahead brewery picker).
const int maxBreweryFilterOptionPages = 5;
const int breweryFilterOptionsPageSize = 100;

/// Paginated brewery *filter-option* list (the picker's choices) -- distinct
/// from resolving a specific beer's brewery *name* for display, which is
/// never safe to do from this capped cache (see
/// features/collection/domain/collection_repository.dart's doc comment).
Future<List<Brewery>> loadBreweryFilterOptions(
  CatalogRepository repository,
) async {
  final options = <Brewery>[];
  var page = 1;
  while (page <= maxBreweryFilterOptionPages) {
    final result = await repository.getBreweries(
      page: page,
      pageSize: breweryFilterOptionsPageSize,
    );
    options.addAll(result.items);
    if (options.length >= result.total || result.items.isEmpty) break;
    page += 1;
  }
  return options;
}
