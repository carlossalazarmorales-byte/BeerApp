// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BeerApp';

  @override
  String get navMap => 'Map';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navScan => 'Scan';

  @override
  String get navCollection => 'Collection';

  @override
  String get navProfile => 'Profile';

  @override
  String get comingSoonBadge => 'Coming soon';

  @override
  String get mapScreenDescription =>
      'Explore the beers around you on an interactive world map.';

  @override
  String get discoverScreenDescription =>
      'Find new breweries, styles and beers worth trying.';

  @override
  String get scanScreenDescription =>
      'Scan a beer label to add it to your collection in seconds.';

  @override
  String get collectionScreenDescription =>
      'Keep track of every beer you have tried and rated.';

  @override
  String get profileScreenDescription =>
      'Manage your profile, achievements and preferences.';

  @override
  String get loadingStateMessage => 'Loading…';

  @override
  String get emptyStateDefaultMessage => 'Nothing here yet.';

  @override
  String get errorStateDefaultMessage => 'Something went wrong.';

  @override
  String get errorStateRetryLabel => 'Retry';
}
