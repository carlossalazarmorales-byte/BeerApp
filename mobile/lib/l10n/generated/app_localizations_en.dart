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
  String get discoverScreenDescription =>
      'Find new breweries, styles and beers worth trying.';

  @override
  String get scanScreenDescription =>
      'Scan a beer label to add it to your collection in seconds.';

  @override
  String get profileScreenDescription =>
      'Manage your profile, achievements and preferences.';

  @override
  String get logoutAction => 'Sign out';

  @override
  String profileScreenGreeting(String name) {
    return 'Signed in as $name.';
  }

  @override
  String get welcomeSubtitle =>
      'Discover, collect, and remember every beer you try.';

  @override
  String get welcomeAgeStatement =>
      'I confirm I am of legal drinking age in my jurisdiction.';

  @override
  String get welcomeCreateAccount => 'Create an account';

  @override
  String get welcomeSignIn => 'I already have an account';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubmit => 'Sign in';

  @override
  String get signInForgotPassword => 'Forgot password?';

  @override
  String get signInNoAccount => 'Don\'t have an account? Sign up';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpSubmit => 'Create account';

  @override
  String get signUpHaveAccount => 'Already have an account? Sign in';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String get checkEmailMessage =>
      'We sent you a confirmation link. Tap it to finish creating your account.';

  @override
  String get checkEmailBackToSignIn => 'Back to sign in';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordDescription =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get forgotPasswordSubmit => 'Send reset link';

  @override
  String get forgotPasswordConfirmation =>
      'If an account exists for that email, we\'ve sent a password reset link.';

  @override
  String get forgotPasswordBackToSignIn => 'Back to sign in';

  @override
  String get resetPasswordTitle => 'Choose a new password';

  @override
  String get resetPasswordSubmit => 'Update password';

  @override
  String get passwordSameAsCurrentError =>
      'Your new password must be different from your current password.';

  @override
  String get profileUnavailableError =>
      'We couldn\'t load your profile. Check your connection and try again.';

  @override
  String get completeProfileTitle => 'Choose a username';

  @override
  String get completeProfileDescription =>
      'Pick a username to finish setting up your BeerApp account.';

  @override
  String get completeProfileSubmit => 'Save username';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get usernameHint => 'Username';

  @override
  String get emailInvalidError => 'Enter a valid email address.';

  @override
  String get passwordRequiredError => 'Enter your password.';

  @override
  String get passwordTooShortError => 'Password must be at least 8 characters.';

  @override
  String get usernameInvalidError =>
      'Usernames must be 3-20 characters: lowercase letters, numbers, and underscores only.';

  @override
  String get usernameTakenError => 'That username is already taken.';

  @override
  String get authInvalidCredentialsError => 'Invalid email or password.';

  @override
  String get authGenericError => 'Something went wrong. Please try again.';

  @override
  String get googleSignInUnavailableError =>
      'Google sign-in isn\'t available yet.';

  @override
  String get loadingStateMessage => 'Loading…';

  @override
  String get emptyStateDefaultMessage => 'Nothing here yet.';

  @override
  String get errorStateDefaultMessage => 'Something went wrong.';

  @override
  String get errorStateRetryLabel => 'Retry';

  @override
  String get catalogErrorUnauthorized =>
      'Your session has expired. Please sign in again to continue.';

  @override
  String get catalogErrorServiceUnavailable =>
      'The beer catalog is temporarily unavailable. Please try again in a moment.';

  @override
  String get catalogErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get catalogErrorNotFound => 'This beer could not be found.';

  @override
  String get catalogErrorGeneric =>
      'We couldn\'t load the beer catalog. Please try again.';

  @override
  String get discoverSearchHint => 'Search beers, breweries, styles, countries';

  @override
  String get discoverSearchClearAction => 'Clear search';

  @override
  String get discoverFiltersAction => 'Filters';

  @override
  String get discoverFiltersSheetTitle => 'Filters';

  @override
  String get discoverFilterSectionStyle => 'Style';

  @override
  String get discoverFilterSectionCountry => 'Country';

  @override
  String get discoverFilterSectionBrewery => 'Brewery';

  @override
  String get discoverClearAllAction => 'Clear all';

  @override
  String get discoverShowResultsAction => 'Show results';

  @override
  String get discoverNoResultsMessage => 'No beers match your search.';

  @override
  String get beerDetailBreweryLabel => 'Brewery';

  @override
  String get beerDetailStyleLabel => 'Style';

  @override
  String get beerDetailAbvLabel => 'ABV';

  @override
  String get beerDetailIbuLabel => 'IBU';

  @override
  String get beerDetailDescriptionLabel => 'Description';

  @override
  String get beerDetailVerifiedBadge => 'Verified';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get beerDetailLogAction => 'Log this beer';

  @override
  String get beerLogSectionTitle => 'Your logs';

  @override
  String get beerLogEmptyMessage => 'You haven\'t logged this beer yet.';

  @override
  String get beerLogLoadMoreAction => 'Load more';

  @override
  String get beerLogFormTitleCreate => 'Log this beer';

  @override
  String get beerLogFormTitleEdit => 'Edit log';

  @override
  String get beerLogRatingLabel => 'Rating';

  @override
  String beerLogRatingStarSemanticLabel(int rating) {
    return 'Rate $rating out of 5';
  }

  @override
  String get beerLogAddDetailsAction => 'Add details';

  @override
  String get beerLogReviewHint => 'Review (optional)';

  @override
  String get beerLogServingNoteHint => 'Serving note (optional)';

  @override
  String get beerLogPriceHint => 'Price (optional)';

  @override
  String get beerLogCurrencyHint => 'Currency, e.g. USD';

  @override
  String get beerLogVenueHint => 'Venue (optional)';

  @override
  String get beerLogServingVolumeLabel => 'Serving volume (ml)';

  @override
  String get beerLogSaveAction => 'Save';

  @override
  String get beerLogDeleteAction => 'Delete';

  @override
  String get beerLogDeleteConfirmTitle => 'Delete this log?';

  @override
  String get beerLogDeleteConfirmMessage => 'This can\'t be undone.';

  @override
  String get beerLogSavedConfirmation => 'Log saved.';

  @override
  String get beerLogDeletedConfirmation => 'Log deleted.';

  @override
  String get beerLogErrorUnauthorized =>
      'Your session has expired. Please sign in again to continue.';

  @override
  String get beerLogErrorServiceUnavailable =>
      'This isn\'t available right now. Please try again in a moment.';

  @override
  String get beerLogErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get beerLogErrorNotFound => 'This log could not be found.';

  @override
  String get beerLogErrorInvalidRequest =>
      'Check the date and price/currency fields and try again.';

  @override
  String get beerLogErrorGeneric =>
      'We couldn\'t save your log. Please try again.';

  @override
  String get beerDetailAddToFavoritesAction => 'Add to favorites';

  @override
  String get beerDetailRemoveFromFavoritesAction => 'Remove from favorites';

  @override
  String get beerDetailAddToWishlistAction => 'Add to wishlist';

  @override
  String get beerDetailRemoveFromWishlistAction => 'Remove from wishlist';

  @override
  String get collectionTabLogged => 'Logged';

  @override
  String get collectionTabFavorites => 'Favorites';

  @override
  String get collectionTabWishlist => 'Wishlist';

  @override
  String get collectionFiltersSheetTitle => 'Filters';

  @override
  String get collectionSortRecent => 'Recent';

  @override
  String get collectionSortRating => 'Rating';

  @override
  String get collectionSortName => 'Name';

  @override
  String get collectionLoggedEmptyMessage =>
      'You haven\'t logged any beers yet.';

  @override
  String get collectionFavoritesEmptyMessage =>
      'You haven\'t favorited any beers yet.';

  @override
  String get collectionWishlistEmptyMessage => 'Your wishlist is empty.';

  @override
  String get collectionErrorUnauthorized =>
      'Your session has expired. Please sign in again to continue.';

  @override
  String get collectionErrorServiceUnavailable =>
      'This isn\'t available right now. Please try again in a moment.';

  @override
  String get collectionErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get collectionErrorNotFound => 'This beer could not be found.';

  @override
  String get collectionErrorGeneric =>
      'We couldn\'t load your collection. Please try again.';

  @override
  String get mapModeAll => 'All beers';

  @override
  String get mapModeTried => 'Tried';

  @override
  String get mapModeNotTried => 'Not tried';

  @override
  String get mapModeFavorites => 'Favorites';

  @override
  String get mapModeWishlist => 'Wishlist';

  @override
  String get mapModeBreweries => 'Breweries';

  @override
  String get mapSearchHint => 'Search a country or region';

  @override
  String get mapUnavailableTitle => 'Map unavailable';

  @override
  String get mapUnavailableMessage =>
      'The interactive map isn\'t set up on this build yet.';

  @override
  String get mapTruncatedMessage =>
      'Showing a partial set of results -- not everything matched is displayed.';

  @override
  String get mapBeersEmptyMessage => 'No beers match this view.';

  @override
  String get mapBreweriesEmptyMessage => 'No breweries match this view.';

  @override
  String get mapBeerPreviewViewDetailsAction => 'View details';

  @override
  String get mapErrorUnauthorized =>
      'Your session has expired. Please sign in again to continue.';

  @override
  String get mapErrorServiceUnavailable =>
      'This isn\'t available right now. Please try again in a moment.';

  @override
  String get mapErrorNetwork => 'Check your internet connection and try again.';

  @override
  String get mapErrorGeneric => 'We couldn\'t load the map. Please try again.';

  @override
  String get profileStatisticsCardTitle => 'Statistics';

  @override
  String get profileStatisticsCardSubtitle => 'See your personal beer activity';

  @override
  String get statisticsScreenTitle => 'Statistics';

  @override
  String get statisticsEmptyMessage =>
      'Log a beer or favorite one to see your statistics here.';

  @override
  String get statisticsErrorUnauthorized =>
      'Your session has expired. Please sign in again to continue.';

  @override
  String get statisticsErrorServiceUnavailable =>
      'This isn\'t available right now. Please try again in a moment.';

  @override
  String get statisticsErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get statisticsErrorGeneric =>
      'We couldn\'t load your statistics. Please try again.';

  @override
  String get statisticsTotalUniqueBeersLabel => 'Unique beers';

  @override
  String get statisticsTotalLogsLabel => 'Total logs';

  @override
  String get statisticsCountriesDiscoveredLabel => 'Countries';

  @override
  String get statisticsStylesDiscoveredLabel => 'Styles';

  @override
  String get statisticsBreweriesDiscoveredLabel => 'Breweries';

  @override
  String get statisticsAverageRatingLabel => 'Average rating';

  @override
  String get statisticsAverageRatingNoneLabel => '—';

  @override
  String get statisticsAmountSpentSectionTitle => 'Amount spent';

  @override
  String get statisticsAmountSpentEmptyLabel => 'No priced logs yet.';

  @override
  String get statisticsFavoritesSectionTitle => 'Favorites';

  @override
  String get statisticsFavoriteStyleLabel => 'Style';

  @override
  String get statisticsFavoriteCountryLabel => 'Country';

  @override
  String get statisticsFavoriteBreweryLabel => 'Brewery';

  @override
  String get statisticsFavoriteNoneLabel => '—';

  @override
  String get statisticsMonthlyActivityChartTitle => 'Monthly activity';

  @override
  String get statisticsYearlyActivityChartTitle => 'Yearly activity';

  @override
  String get statisticsYearlyActivityEmptyLabel => 'No activity recorded yet.';

  @override
  String get statisticsMonthJan => 'Jan';

  @override
  String get statisticsMonthFeb => 'Feb';

  @override
  String get statisticsMonthMar => 'Mar';

  @override
  String get statisticsMonthApr => 'Apr';

  @override
  String get statisticsMonthMay => 'May';

  @override
  String get statisticsMonthJun => 'Jun';

  @override
  String get statisticsMonthJul => 'Jul';

  @override
  String get statisticsMonthAug => 'Aug';

  @override
  String get statisticsMonthSep => 'Sep';

  @override
  String get statisticsMonthOct => 'Oct';

  @override
  String get statisticsMonthNov => 'Nov';

  @override
  String get statisticsMonthDec => 'Dec';

  @override
  String get profileAchievementsCardTitle => 'Achievements';

  @override
  String get profileAchievementsCardSubtitle => 'See what you\'ve unlocked';

  @override
  String get achievementsScreenTitle => 'Achievements';

  @override
  String get achievementsErrorUnauthorized =>
      'Your session has expired. Please sign in again to continue.';

  @override
  String get achievementsErrorServiceUnavailable =>
      'This isn\'t available right now. Please try again in a moment.';

  @override
  String get achievementsErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get achievementsErrorGeneric =>
      'We couldn\'t load your achievements. Please try again.';

  @override
  String get achievementsLockedLabel => 'Locked';

  @override
  String achievementsUnlockedOnLabel(String date) {
    return 'Unlocked on $date';
  }

  @override
  String achievementsProgressFormat(int current, int target) {
    return '$current / $target';
  }

  @override
  String achievementsNewUnlockBannerOne(String name) {
    return 'Achievement unlocked: $name';
  }

  @override
  String achievementsNewUnlockBannerMany(int count) {
    return '$count new achievements unlocked';
  }

  @override
  String get achievementsCategoryBeersTried => 'Beers Tried';

  @override
  String get achievementsCategoryCountries => 'Countries';

  @override
  String get achievementsCategoryStyles => 'Styles';

  @override
  String get achievementsCategoryBreweries => 'Breweries';

  @override
  String get achievementsCategoryReviews => 'Reviews';

  @override
  String get achievementsCategoryRatings => 'Ratings';

  @override
  String get achievementsCategoryCollection => 'Collection';

  @override
  String get achievementsCategorySpecial => 'Special';

  @override
  String get achievementNameCollectionFirstFavorite => 'First Favorite';

  @override
  String get achievementDescriptionCollectionFirstFavorite =>
      'Add a beer to your favorites.';

  @override
  String get achievementNameCollectionFirstWishlist => 'First Wishlist Add';

  @override
  String get achievementDescriptionCollectionFirstWishlist =>
      'Add a beer to your wishlist.';

  @override
  String get achievementNameCollectionCurator => 'Curator';

  @override
  String get achievementDescriptionCollectionCurator =>
      'Have at least one favorite and one wishlist beer.';
}
