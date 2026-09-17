import '../../../l10n/generated/app_localizations.dart';

/// Maps a stable backend achievement key to its localized name/description.
/// This is the one place a normal future achievement still touches Dart --
/// one switch arm here plus one ARB string pair per locale -- everything
/// else (catalog entry, category, progress) is fully data-driven from the
/// `GET /achievements` response. An unrecognized key (a retired achievement
/// somehow still present, or a client/server version mismatch) falls back to
/// the key itself rather than throwing.
String achievementName(AppLocalizations l10n, String key) => switch (key) {
  'collection_first_favorite' => l10n.achievementNameCollectionFirstFavorite,
  'collection_first_wishlist' => l10n.achievementNameCollectionFirstWishlist,
  'collection_curator' => l10n.achievementNameCollectionCurator,
  _ => key,
};

String achievementDescription(AppLocalizations l10n, String key) =>
    switch (key) {
      'collection_first_favorite' =>
        l10n.achievementDescriptionCollectionFirstFavorite,
      'collection_first_wishlist' =>
        l10n.achievementDescriptionCollectionFirstWishlist,
      'collection_curator' => l10n.achievementDescriptionCollectionCurator,
      _ => '',
    };
