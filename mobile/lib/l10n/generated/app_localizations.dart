import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// The application title, used by the OS task switcher and app metadata.
  ///
  /// In en, this message translates to:
  /// **'BeerApp'**
  String get appTitle;

  /// Bottom navigation label for the Map destination.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Bottom navigation label for the Discover destination.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// Bottom navigation label for the Scan destination.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// Bottom navigation label for the Collection destination.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get navCollection;

  /// Bottom navigation label for the Profile destination.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Badge shown on placeholder screens for features not built yet.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoonBadge;

  /// Placeholder description for the Discover screen.
  ///
  /// In en, this message translates to:
  /// **'Find new breweries, styles and beers worth trying.'**
  String get discoverScreenDescription;

  /// Placeholder description for the Scan screen.
  ///
  /// In en, this message translates to:
  /// **'Scan a beer label to add it to your collection in seconds.'**
  String get scanScreenDescription;

  /// Placeholder description for the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Manage your profile, achievements and preferences.'**
  String get profileScreenDescription;

  /// Tooltip/label for the sign-out action on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutAction;

  /// Profile screen subtitle once a real signed-in user/profile exists.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}.'**
  String profileScreenGreeting(String name);

  /// Subtitle shown on the welcome/landing screen.
  ///
  /// In en, this message translates to:
  /// **'Discover, collect, and remember every beer you try.'**
  String get welcomeSubtitle;

  /// Required adult-audience acknowledgement checkbox label on the welcome screen.
  ///
  /// In en, this message translates to:
  /// **'I confirm I am of legal drinking age in my jurisdiction.'**
  String get welcomeAgeStatement;

  /// Welcome screen button leading to sign-up.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get welcomeCreateAccount;

  /// Welcome screen button leading to sign-in.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get welcomeSignIn;

  /// Google sign-in button label, shown on the welcome and sign-in screens.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Sign-in screen title.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Sign-in screen submit button label.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInSubmit;

  /// Link to the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgotPassword;

  /// Link to the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get signInNoAccount;

  /// Sign-up screen title.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// Sign-up screen submit button label.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpSubmit;

  /// Link to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get signUpHaveAccount;

  /// Post-signup, pre-confirmation screen title.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmailTitle;

  /// Post-signup, pre-confirmation screen body.
  ///
  /// In en, this message translates to:
  /// **'We sent you a confirmation link. Tap it to finish creating your account.'**
  String get checkEmailMessage;

  /// Link back to sign-in from the check-email screen.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get checkEmailBackToSignIn;

  /// Forgot-password screen title.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// Forgot-password screen instructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to reset your password.'**
  String get forgotPasswordDescription;

  /// Forgot-password screen submit button label.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get forgotPasswordSubmit;

  /// Shown after submitting the forgot-password form, regardless of whether the email exists (avoids account enumeration).
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, we\'ve sent a password reset link.'**
  String get forgotPasswordConfirmation;

  /// Link back to sign-in after requesting a password reset.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get forgotPasswordBackToSignIn;

  /// Reset-password screen title, reached via the emailed link.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetPasswordTitle;

  /// Reset-password screen submit button label.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get resetPasswordSubmit;

  /// Shown when Supabase Auth rejects a password update with the same_password error code.
  ///
  /// In en, this message translates to:
  /// **'Your new password must be different from your current password.'**
  String get passwordSameAsCurrentError;

  /// Shown when a signed-in user's profile fails to load (network/server error) — distinct from an incomplete profile.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your profile. Check your connection and try again.'**
  String get profileUnavailableError;

  /// Complete-profile screen title, shown only for OAuth sign-ups without a username.
  ///
  /// In en, this message translates to:
  /// **'Choose a username'**
  String get completeProfileTitle;

  /// Complete-profile screen instructions.
  ///
  /// In en, this message translates to:
  /// **'Pick a username to finish setting up your BeerApp account.'**
  String get completeProfileDescription;

  /// Complete-profile screen submit button label.
  ///
  /// In en, this message translates to:
  /// **'Save username'**
  String get completeProfileSubmit;

  /// Placeholder for an email input field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// Placeholder for a password input field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// Placeholder for a username input field.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameHint;

  /// Client-side email field validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalidError;

  /// Client-side password field validation error on sign-in.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get passwordRequiredError;

  /// Client-side password field validation error on sign-up/reset.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordTooShortError;

  /// Client-side username field validation error; mirrors the database CHECK constraint.
  ///
  /// In en, this message translates to:
  /// **'Usernames must be 3-20 characters: lowercase letters, numbers, and underscores only.'**
  String get usernameInvalidError;

  /// Shown when the database's unique constraint rejects a username.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get usernameTakenError;

  /// Generic sign-in failure message; never distinguishes which field was wrong (avoids account enumeration).
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authInvalidCredentialsError;

  /// Generic fallback error for auth actions, used instead of showing a raw backend error message.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authGenericError;

  /// Shown when Google Sign-In is tapped before the provider is configured (Phase 2 Step F).
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t available yet.'**
  String get googleSignInUnavailableError;

  /// Accessible label announced while a loading state is shown.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingStateMessage;

  /// Default message shown by the reusable empty state when no custom message is provided.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get emptyStateDefaultMessage;

  /// Default message shown by the reusable error state when no custom message is provided.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorStateDefaultMessage;

  /// Label for the retry button shown by the reusable error state.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get errorStateRetryLabel;

  /// Shown when a catalog request fails because there is no usable authenticated session.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again to continue.'**
  String get catalogErrorUnauthorized;

  /// Shown when the backend can't verify the session or is otherwise temporarily unavailable (HTTP 503).
  ///
  /// In en, this message translates to:
  /// **'The beer catalog is temporarily unavailable. Please try again in a moment.'**
  String get catalogErrorServiceUnavailable;

  /// Shown when a catalog request fails due to no network connectivity.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get catalogErrorNetwork;

  /// Shown when a beer detail request returns 404.
  ///
  /// In en, this message translates to:
  /// **'This beer could not be found.'**
  String get catalogErrorNotFound;

  /// Fallback error message for catalog requests, used instead of showing a raw backend error message.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the beer catalog. Please try again.'**
  String get catalogErrorGeneric;

  /// Placeholder text for the Discover search field.
  ///
  /// In en, this message translates to:
  /// **'Search beers, breweries, styles, countries'**
  String get discoverSearchHint;

  /// Accessible label for the button that clears the Discover search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get discoverSearchClearAction;

  /// Label for the chip/button that opens the Discover filters bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get discoverFiltersAction;

  /// Title of the Discover filters bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get discoverFiltersSheetTitle;

  /// Section label for the beer style filter in the Discover filters sheet.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get discoverFilterSectionStyle;

  /// Section label for the country filter in the Discover filters sheet.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get discoverFilterSectionCountry;

  /// Section label for the brewery filter in the Discover filters sheet.
  ///
  /// In en, this message translates to:
  /// **'Brewery'**
  String get discoverFilterSectionBrewery;

  /// Action inside the Discover filters sheet that resets the in-progress filter selection.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get discoverClearAllAction;

  /// Action that applies the Discover filters sheet's selection and closes it.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get discoverShowResultsAction;

  /// Shown when a Discover search/filter combination matches no beers.
  ///
  /// In en, this message translates to:
  /// **'No beers match your search.'**
  String get discoverNoResultsMessage;

  /// Label for the brewery field on the beer detail screen.
  ///
  /// In en, this message translates to:
  /// **'Brewery'**
  String get beerDetailBreweryLabel;

  /// Label for the beer style field on the beer detail screen.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get beerDetailStyleLabel;

  /// Label for the alcohol-by-volume stat on the beer detail screen.
  ///
  /// In en, this message translates to:
  /// **'ABV'**
  String get beerDetailAbvLabel;

  /// Label for the bitterness (IBU) stat on the beer detail screen.
  ///
  /// In en, this message translates to:
  /// **'IBU'**
  String get beerDetailIbuLabel;

  /// Label for the description section on the beer detail screen.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get beerDetailDescriptionLabel;

  /// Badge shown on a beer/brewery whose catalog data has been verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get beerDetailVerifiedBadge;

  /// Generic label for a dialog's cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Button on the beer detail screen that opens the log-entry form.
  ///
  /// In en, this message translates to:
  /// **'Log this beer'**
  String get beerDetailLogAction;

  /// Heading for the list of the current user's own logs for a beer, on the beer detail screen.
  ///
  /// In en, this message translates to:
  /// **'Your logs'**
  String get beerLogSectionTitle;

  /// Shown in place of the log list when the current user has no logs for this beer.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t logged this beer yet.'**
  String get beerLogEmptyMessage;

  /// Button that fetches the next page of the user's logs for a beer.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get beerLogLoadMoreAction;

  /// Title of the bottom sheet used to create a new beer log.
  ///
  /// In en, this message translates to:
  /// **'Log this beer'**
  String get beerLogFormTitleCreate;

  /// Title of the bottom sheet used to edit an existing beer log.
  ///
  /// In en, this message translates to:
  /// **'Edit log'**
  String get beerLogFormTitleEdit;

  /// Label above the 1-5 rating input in the log form.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get beerLogRatingLabel;

  /// Accessible label for one star in the rating input.
  ///
  /// In en, this message translates to:
  /// **'Rate {rating} out of 5'**
  String beerLogRatingStarSemanticLabel(int rating);

  /// Expands the log form beyond the quick rating-only path to show the optional detail fields.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get beerLogAddDetailsAction;

  /// Placeholder for the optional review text field in the log form.
  ///
  /// In en, this message translates to:
  /// **'Review (optional)'**
  String get beerLogReviewHint;

  /// Placeholder for the optional serving-note text field in the log form.
  ///
  /// In en, this message translates to:
  /// **'Serving note (optional)'**
  String get beerLogServingNoteHint;

  /// Placeholder for the optional price field in the log form.
  ///
  /// In en, this message translates to:
  /// **'Price (optional)'**
  String get beerLogPriceHint;

  /// Placeholder for the optional 3-letter currency code field in the log form.
  ///
  /// In en, this message translates to:
  /// **'Currency, e.g. USD'**
  String get beerLogCurrencyHint;

  /// Placeholder for the optional venue name field in the log form.
  ///
  /// In en, this message translates to:
  /// **'Venue (optional)'**
  String get beerLogVenueHint;

  /// Label/placeholder for the optional serving-volume field in the log form. Deliberately neutral -- no example value or consumption-oriented copy.
  ///
  /// In en, this message translates to:
  /// **'Serving volume (ml)'**
  String get beerLogServingVolumeLabel;

  /// Submit button label for the log form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get beerLogSaveAction;

  /// Action that deletes an existing beer log.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get beerLogDeleteAction;

  /// Confirmation dialog title before deleting a beer log.
  ///
  /// In en, this message translates to:
  /// **'Delete this log?'**
  String get beerLogDeleteConfirmTitle;

  /// Confirmation dialog body before deleting a beer log.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get beerLogDeleteConfirmMessage;

  /// Snackbar shown after successfully creating or editing a beer log.
  ///
  /// In en, this message translates to:
  /// **'Log saved.'**
  String get beerLogSavedConfirmation;

  /// Snackbar shown after successfully deleting a beer log.
  ///
  /// In en, this message translates to:
  /// **'Log deleted.'**
  String get beerLogDeletedConfirmation;

  /// Shown when a beer log request fails because there is no usable authenticated session.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again to continue.'**
  String get beerLogErrorUnauthorized;

  /// Shown when the backend can't verify the session or is otherwise temporarily unavailable (HTTP 503).
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available right now. Please try again in a moment.'**
  String get beerLogErrorServiceUnavailable;

  /// Shown when a beer log request fails due to no network connectivity.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get beerLogErrorNetwork;

  /// Shown when a beer log request returns 404 (missing or not owned by the current user).
  ///
  /// In en, this message translates to:
  /// **'This log could not be found.'**
  String get beerLogErrorNotFound;

  /// Shown when a beer log request returns 400 (e.g. a future consumption date, or a price/currency combination that isn't valid).
  ///
  /// In en, this message translates to:
  /// **'Check the date and price/currency fields and try again.'**
  String get beerLogErrorInvalidRequest;

  /// Fallback error message for beer log requests, used instead of showing a raw backend error message.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your log. Please try again.'**
  String get beerLogErrorGeneric;

  /// Accessible label/tooltip for the favorite button on the beer detail screen when the beer is not currently favorited.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get beerDetailAddToFavoritesAction;

  /// Accessible label/tooltip for the favorite button on the beer detail screen when the beer is currently favorited.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get beerDetailRemoveFromFavoritesAction;

  /// Accessible label/tooltip for the wishlist button on the beer detail screen when the beer is not currently on the wishlist.
  ///
  /// In en, this message translates to:
  /// **'Add to wishlist'**
  String get beerDetailAddToWishlistAction;

  /// Accessible label/tooltip for the wishlist button on the beer detail screen when the beer is currently on the wishlist.
  ///
  /// In en, this message translates to:
  /// **'Remove from wishlist'**
  String get beerDetailRemoveFromWishlistAction;

  /// Collection screen tab label for the Logged (unique beers tried) view.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get collectionTabLogged;

  /// Collection screen tab label for the Favorites view.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get collectionTabFavorites;

  /// Collection screen tab label for the Wishlist view.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get collectionTabWishlist;

  /// Title of the Collection screen's filters bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get collectionFiltersSheetTitle;

  /// Collection screen sort option: most-recent-activity-first.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get collectionSortRecent;

  /// Collection screen sort option: by the beer's latest logged rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get collectionSortRating;

  /// Collection screen sort option: alphabetically by beer name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get collectionSortName;

  /// Shown on the Collection screen's Logged tab when the user has no beer logs.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t logged any beers yet.'**
  String get collectionLoggedEmptyMessage;

  /// Shown on the Collection screen's Favorites tab when the user has no favorites.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t favorited any beers yet.'**
  String get collectionFavoritesEmptyMessage;

  /// Shown on the Collection screen's Wishlist tab when the user has no wishlist beers.
  ///
  /// In en, this message translates to:
  /// **'Your wishlist is empty.'**
  String get collectionWishlistEmptyMessage;

  /// Shown when a Collection request fails because there is no usable authenticated session.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again to continue.'**
  String get collectionErrorUnauthorized;

  /// Shown when the backend can't verify the session or is otherwise temporarily unavailable (HTTP 503).
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available right now. Please try again in a moment.'**
  String get collectionErrorServiceUnavailable;

  /// Shown when a Collection request fails due to no network connectivity.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get collectionErrorNetwork;

  /// Shown when a Collection request returns 404 (the beer itself doesn't exist).
  ///
  /// In en, this message translates to:
  /// **'This beer could not be found.'**
  String get collectionErrorNotFound;

  /// Fallback error message for Collection requests, used instead of showing a raw backend error message.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your collection. Please try again.'**
  String get collectionErrorGeneric;

  /// Map mode selector option: every beer with a resolvable location.
  ///
  /// In en, this message translates to:
  /// **'All beers'**
  String get mapModeAll;

  /// Map mode selector option: only beers the current user has logged.
  ///
  /// In en, this message translates to:
  /// **'Tried'**
  String get mapModeTried;

  /// Map mode selector option: only beers the current user has not logged.
  ///
  /// In en, this message translates to:
  /// **'Not tried'**
  String get mapModeNotTried;

  /// Map mode selector option: only the current user's favorited beers.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get mapModeFavorites;

  /// Map mode selector option: only the current user's wishlist beers.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get mapModeWishlist;

  /// Map mode selector option: breweries instead of beers.
  ///
  /// In en, this message translates to:
  /// **'Breweries'**
  String get mapModeBreweries;

  /// Placeholder text for the Map screen's search field.
  ///
  /// In en, this message translates to:
  /// **'Search a country or region'**
  String get mapSearchHint;

  /// Title shown when the map tile provider isn't configured on this build.
  ///
  /// In en, this message translates to:
  /// **'Map unavailable'**
  String get mapUnavailableTitle;

  /// Message shown in place of the map when the tile provider isn't configured -- the rest of the app keeps working normally.
  ///
  /// In en, this message translates to:
  /// **'The interactive map isn\'t set up on this build yet.'**
  String get mapUnavailableMessage;

  /// Non-blocking notice shown when the server's safety cap truncated the map's results.
  ///
  /// In en, this message translates to:
  /// **'Showing a partial set of results -- not everything matched is displayed.'**
  String get mapTruncatedMessage;

  /// Shown when the current mode/search combination matches no beers.
  ///
  /// In en, this message translates to:
  /// **'No beers match this view.'**
  String get mapBeersEmptyMessage;

  /// Shown when the current search matches no breweries.
  ///
  /// In en, this message translates to:
  /// **'No breweries match this view.'**
  String get mapBreweriesEmptyMessage;

  /// Button on the Map screen's beer preview card that navigates to the full beer detail screen.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get mapBeerPreviewViewDetailsAction;

  /// Shown when a Map request fails because there is no usable authenticated session.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again to continue.'**
  String get mapErrorUnauthorized;

  /// Shown when the backend can't verify the session or is otherwise temporarily unavailable (HTTP 503).
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available right now. Please try again in a moment.'**
  String get mapErrorServiceUnavailable;

  /// Shown when a Map request fails due to no network connectivity.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get mapErrorNetwork;

  /// Fallback error message for Map requests, used instead of showing a raw backend error message.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the map. Please try again.'**
  String get mapErrorGeneric;

  /// Title of the card on the Profile screen that navigates to Statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get profileStatisticsCardTitle;

  /// Subtitle of the card on the Profile screen that navigates to Statistics.
  ///
  /// In en, this message translates to:
  /// **'See your personal beer activity'**
  String get profileStatisticsCardSubtitle;

  /// App bar title for the Statistics screen.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsScreenTitle;

  /// Shown on the Statistics screen when the user has no logs and no favorites yet.
  ///
  /// In en, this message translates to:
  /// **'Log a beer or favorite one to see your statistics here.'**
  String get statisticsEmptyMessage;

  /// Shown when a Statistics request fails because there is no usable authenticated session.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again to continue.'**
  String get statisticsErrorUnauthorized;

  /// Shown when the backend can't verify the session or is otherwise temporarily unavailable (HTTP 503).
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available right now. Please try again in a moment.'**
  String get statisticsErrorServiceUnavailable;

  /// Shown when a Statistics request fails due to no network connectivity.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get statisticsErrorNetwork;

  /// Fallback error message for Statistics requests, used instead of showing a raw backend error message.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your statistics. Please try again.'**
  String get statisticsErrorGeneric;

  /// Statistics overview tile label for the count of distinct beers logged.
  ///
  /// In en, this message translates to:
  /// **'Unique beers'**
  String get statisticsTotalUniqueBeersLabel;

  /// Statistics overview tile label for the total number of log entries.
  ///
  /// In en, this message translates to:
  /// **'Total logs'**
  String get statisticsTotalLogsLabel;

  /// Statistics overview tile label for the count of distinct countries discovered.
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get statisticsCountriesDiscoveredLabel;

  /// Statistics overview tile label for the count of distinct beer styles discovered.
  ///
  /// In en, this message translates to:
  /// **'Styles'**
  String get statisticsStylesDiscoveredLabel;

  /// Statistics overview tile label for the count of distinct breweries discovered.
  ///
  /// In en, this message translates to:
  /// **'Breweries'**
  String get statisticsBreweriesDiscoveredLabel;

  /// Statistics overview tile label for the average of the user's own log ratings.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get statisticsAverageRatingLabel;

  /// Placeholder shown for average rating when the user has no rated logs.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get statisticsAverageRatingNoneLabel;

  /// Section title for the per-currency amount-spent breakdown.
  ///
  /// In en, this message translates to:
  /// **'Amount spent'**
  String get statisticsAmountSpentSectionTitle;

  /// Shown in the amount-spent section when the user has no logs with a price recorded.
  ///
  /// In en, this message translates to:
  /// **'No priced logs yet.'**
  String get statisticsAmountSpentEmptyLabel;

  /// Section title for the favorite style/country/brewery breakdown.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get statisticsFavoritesSectionTitle;

  /// Row label for the user's most-favorited beer style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get statisticsFavoriteStyleLabel;

  /// Row label for the user's most-favorited beer country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get statisticsFavoriteCountryLabel;

  /// Row label for the user's most-favorited brewery.
  ///
  /// In en, this message translates to:
  /// **'Brewery'**
  String get statisticsFavoriteBreweryLabel;

  /// Placeholder shown for a favorite dimension when the user has zero Collection favorites.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get statisticsFavoriteNoneLabel;

  /// Title for the trailing-12-month log-activity bar chart.
  ///
  /// In en, this message translates to:
  /// **'Monthly activity'**
  String get statisticsMonthlyActivityChartTitle;

  /// Title for the all-time, per-year log-activity bar chart.
  ///
  /// In en, this message translates to:
  /// **'Yearly activity'**
  String get statisticsYearlyActivityChartTitle;

  /// Shown in place of the yearly activity chart when the user has no logs at all.
  ///
  /// In en, this message translates to:
  /// **'No activity recorded yet.'**
  String get statisticsYearlyActivityEmptyLabel;

  /// Short (3-letter) month abbreviation for January, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get statisticsMonthJan;

  /// Short (3-letter) month abbreviation for February, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get statisticsMonthFeb;

  /// Short (3-letter) month abbreviation for March, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get statisticsMonthMar;

  /// Short (3-letter) month abbreviation for April, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get statisticsMonthApr;

  /// Short (3-letter) month abbreviation for May, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get statisticsMonthMay;

  /// Short (3-letter) month abbreviation for June, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get statisticsMonthJun;

  /// Short (3-letter) month abbreviation for July, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get statisticsMonthJul;

  /// Short (3-letter) month abbreviation for August, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get statisticsMonthAug;

  /// Short (3-letter) month abbreviation for September, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get statisticsMonthSep;

  /// Short (3-letter) month abbreviation for October, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get statisticsMonthOct;

  /// Short (3-letter) month abbreviation for November, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get statisticsMonthNov;

  /// Short (3-letter) month abbreviation for December, used as a monthly activity chart axis label.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get statisticsMonthDec;

  /// Title of the card on the Profile screen that navigates to Achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get profileAchievementsCardTitle;

  /// Subtitle of the card on the Profile screen that navigates to Achievements.
  ///
  /// In en, this message translates to:
  /// **'See what you\'ve unlocked'**
  String get profileAchievementsCardSubtitle;

  /// App bar title for the Achievements screen.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievementsScreenTitle;

  /// Shown when an Achievements request fails because there is no usable authenticated session.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again to continue.'**
  String get achievementsErrorUnauthorized;

  /// Shown when the backend can't verify the session or is otherwise temporarily unavailable (HTTP 503).
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available right now. Please try again in a moment.'**
  String get achievementsErrorServiceUnavailable;

  /// Shown when an Achievements request fails due to no network connectivity.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get achievementsErrorNetwork;

  /// Fallback error message for Achievements requests, used instead of showing a raw backend error message.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your achievements. Please try again.'**
  String get achievementsErrorGeneric;

  /// Status label shown on an achievement tile that has not been unlocked yet.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get achievementsLockedLabel;

  /// Status label shown on an unlocked achievement tile, with the date it was unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked on {date}'**
  String achievementsUnlockedOnLabel(String date);

  /// Progress label under an achievement's progress bar -- current count out of the target (or, for a compound achievement, conditions met out of total conditions).
  ///
  /// In en, this message translates to:
  /// **'{current} / {target}'**
  String achievementsProgressFormat(int current, int target);

  /// Transient in-app banner shown when exactly one achievement is newly unlocked since the last refresh.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked: {name}'**
  String achievementsNewUnlockBannerOne(String name);

  /// Transient in-app banner shown when more than one achievement is newly unlocked since the last refresh.
  ///
  /// In en, this message translates to:
  /// **'{count} new achievements unlocked'**
  String achievementsNewUnlockBannerMany(int count);

  /// Achievements category heading -- beers tried (no entries in the Phase 10 starter catalog).
  ///
  /// In en, this message translates to:
  /// **'Beers Tried'**
  String get achievementsCategoryBeersTried;

  /// Achievements category heading -- countries (no entries in the Phase 10 starter catalog).
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get achievementsCategoryCountries;

  /// Achievements category heading -- styles (no entries in the Phase 10 starter catalog).
  ///
  /// In en, this message translates to:
  /// **'Styles'**
  String get achievementsCategoryStyles;

  /// Achievements category heading -- breweries (no entries in the Phase 10 starter catalog).
  ///
  /// In en, this message translates to:
  /// **'Breweries'**
  String get achievementsCategoryBreweries;

  /// Achievements category heading -- reviews (no entries in the Phase 10 starter catalog).
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get achievementsCategoryReviews;

  /// Achievements category heading -- ratings (no entries in the Phase 10 starter catalog).
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get achievementsCategoryRatings;

  /// Achievements category heading -- Collection (favorites/wishlist).
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get achievementsCategoryCollection;

  /// Achievements category heading -- special/compound milestones.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get achievementsCategorySpecial;

  /// Name of the collection_first_favorite achievement.
  ///
  /// In en, this message translates to:
  /// **'First Favorite'**
  String get achievementNameCollectionFirstFavorite;

  /// Description of the collection_first_favorite achievement.
  ///
  /// In en, this message translates to:
  /// **'Add a beer to your favorites.'**
  String get achievementDescriptionCollectionFirstFavorite;

  /// Name of the collection_first_wishlist achievement.
  ///
  /// In en, this message translates to:
  /// **'First Wishlist Add'**
  String get achievementNameCollectionFirstWishlist;

  /// Description of the collection_first_wishlist achievement.
  ///
  /// In en, this message translates to:
  /// **'Add a beer to your wishlist.'**
  String get achievementDescriptionCollectionFirstWishlist;

  /// Name of the collection_curator achievement.
  ///
  /// In en, this message translates to:
  /// **'Curator'**
  String get achievementNameCollectionCurator;

  /// Description of the collection_curator achievement.
  ///
  /// In en, this message translates to:
  /// **'Have at least one favorite and one wishlist beer.'**
  String get achievementDescriptionCollectionCurator;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
