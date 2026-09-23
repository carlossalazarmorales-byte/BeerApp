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

  /// Bottom navigation label for the Scan screen's app bar title. Scan is no longer a bottom-nav destination itself -- it is reached only from the Add Beer screen -- but keeps this title since it still accurately describes the screen.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// Bottom navigation label for the Add Beer destination (center nav action).
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get navAdd;

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

  /// Button label, shown on every non-scanning Scan screen state, to fall back to the Add Beer screen's manual search (Scan is reached only by pushing from Add Beer, so this pops back to it).
  ///
  /// In en, this message translates to:
  /// **'Search manually'**
  String get scanSearchManuallyAction;

  /// Shown on the Scan screen when camera permission has been denied. If the OS will no longer show the permission prompt, enabling it requires the device's system settings.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed only for scanning barcodes. If \"Try camera again\" doesn\'t prompt you, enable camera access for BeerApp in your device\'s system settings. You can still search for beers manually in the meantime.'**
  String get scanPermissionDeniedMessage;

  /// Button label to retry requesting camera permission/starting the scanner, shown when permission was denied.
  ///
  /// In en, this message translates to:
  /// **'Try camera again'**
  String get scanTryCameraAgainAction;

  /// Shown on the Scan screen when the device has no usable camera/scanning support.
  ///
  /// In en, this message translates to:
  /// **'Scanning isn\'t available on this device. You can still search for beers manually.'**
  String get scanUnsupportedMessage;

  /// Shown on the Scan screen when a decoded barcode doesn't match any beer.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a beer with that barcode in our catalog.'**
  String get scanNotFoundMessage;

  /// Button label to reset the scanner and scan another barcode.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgainAction;

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

  /// App bar title for the Add Beer screen, opened from the center bottom-nav action.
  ///
  /// In en, this message translates to:
  /// **'Add a beer'**
  String get addBeerScreenTitle;

  /// Placeholder text for the Add Beer screen's search field. Searches the full catalog, including beers the user has already tried.
  ///
  /// In en, this message translates to:
  /// **'Search beers, breweries, styles, countries'**
  String get addBeerSearchHint;

  /// Shown when an Add Beer search matches no beers.
  ///
  /// In en, this message translates to:
  /// **'No beers match your search.'**
  String get addBeerNoResultsMessage;

  /// Secondary action on the Add Beer screen that opens the barcode scanner as a shortcut to identify a beer, instead of searching manually.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get addBeerScanAction;

  /// Accessible label announced for a beer shown with the locked (not-yet-tried) visual treatment, in addition to its name.
  ///
  /// In en, this message translates to:
  /// **'Locked. You haven\'t logged this beer yet.'**
  String get beerLockedSemanticLabel;

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

  /// Map legend label: a country with zero catalog beers (charcoal fill).
  ///
  /// In en, this message translates to:
  /// **'No catalog'**
  String get mapLegendZeroCatalog;

  /// Map legend label: a country with catalog beers but no logs from the current user yet (gray fill).
  ///
  /// In en, this message translates to:
  /// **'Catalog available'**
  String get mapLegendZeroHistory;

  /// Map legend label: a country where the current user has at least one log (amber/gold fill). Deliberately neutral wording -- never "complete"/"finished".
  ///
  /// In en, this message translates to:
  /// **'In your history'**
  String get mapLegendHasHistory;

  /// Map legend label: a beer-origin point the current user has not logged (gray point).
  ///
  /// In en, this message translates to:
  /// **'Not in history'**
  String get mapLegendPointUntried;

  /// Map legend label: a beer-origin point the current user has logged at least once (gold point).
  ///
  /// In en, this message translates to:
  /// **'In history'**
  String get mapLegendPointTried;

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

  /// Title of the card on the Profile screen that navigates to Edit Profile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfileCardTitle;

  /// Subtitle of the card on the Profile screen that navigates to Edit Profile.
  ///
  /// In en, this message translates to:
  /// **'Username and display name'**
  String get profileEditProfileCardSubtitle;

  /// Title of the card on the Profile screen that navigates to Settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsCardTitle;

  /// Subtitle of the card on the Profile screen that navigates to Settings.
  ///
  /// In en, this message translates to:
  /// **'Currency, language and account'**
  String get profileSettingsCardSubtitle;

  /// App bar title for the Edit Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileScreenTitle;

  /// Placeholder for the display name input field on Edit Profile.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get displayNameHint;

  /// Submit button label on the Edit Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editProfileSaveAction;

  /// Snackbar shown after Edit Profile saves successfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get editProfileSuccessMessage;

  /// App bar title for the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreenTitle;

  /// Title of the Settings row that opens the preferred-currency picker.
  ///
  /// In en, this message translates to:
  /// **'Preferred currency'**
  String get settingsCurrencyRowTitle;

  /// Shown as the preferred-currency row's subtitle when no currency has been chosen yet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsCurrencyNotSet;

  /// Title of the bottom sheet listing selectable currency codes.
  ///
  /// In en, this message translates to:
  /// **'Preferred currency'**
  String get settingsCurrencyPickerTitle;

  /// Option in the currency picker that clears the preferred currency back to unset.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsCurrencyClearOption;

  /// Shown when the database rejects a preferred-currency value (CHECK constraint).
  ///
  /// In en, this message translates to:
  /// **'That currency isn\'t valid.'**
  String get settingsCurrencyInvalidError;

  /// Title of the Settings row that opens the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageRowTitle;

  /// Title of the bottom sheet listing selectable languages.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguagePickerTitle;

  /// Language picker option that clears the override and follows the device's system locale.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystemOption;

  /// Language picker option for English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglishOption;

  /// Language picker option for Spanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get settingsLanguageSpanishOption;

  /// Title of the Settings row that triggers a password-reset email.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePasswordRowTitle;

  /// Subtitle of the Settings change-password row.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a reset link'**
  String get settingsChangePasswordRowSubtitle;

  /// Snackbar shown after the Settings change-password row successfully triggers a reset email.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a link to reset your password.'**
  String get settingsChangePasswordConfirmation;

  /// Title of the Settings row that opens the privacy-settings placeholder (ROADMAP.md Phase 12's dedicated 'Privacy settings placeholder' task -- distinct from the Privacy Policy document row below).
  ///
  /// In en, this message translates to:
  /// **'Privacy settings'**
  String get settingsPrivacySettingsRowTitle;

  /// Title of the Settings row that opens the Privacy Policy placeholder.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicyRowTitle;

  /// Title of the Settings row that opens the Terms of Service placeholder.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfServiceRowTitle;

  /// Description shown on the Privacy Policy / Terms of Service placeholder screen.
  ///
  /// In en, this message translates to:
  /// **'This content isn\'t available yet. Check back before release.'**
  String get settingsLegalPlaceholderDescription;

  /// Snackbar shown when the Privacy Policy / Terms of Service link could not be opened in the browser. Never includes the URL or an error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link. Please try again later.'**
  String get settingsLegalLinkOpenFailed;

  /// Title of the startup-failure screen shown when the build's configuration is missing or invalid.
  ///
  /// In en, this message translates to:
  /// **'BeerApp isn\'t set up correctly'**
  String get startupFailureConfigurationTitle;

  /// Body of the configuration startup-failure screen. Deliberately generic: never names a setting, URL or key.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is missing required configuration. Please update BeerApp or try again later.'**
  String get startupFailureConfigurationMessage;

  /// Title of the startup-failure screen shown when starting the app failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'BeerApp couldn\'t start'**
  String get startupFailureInitializationTitle;

  /// Body of the initialization startup-failure screen, shown with a Retry button.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while starting the app. Please try again.'**
  String get startupFailureInitializationMessage;

  /// Title of the Settings row that opens the delete-account confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccountRowTitle;

  /// Subtitle of the Settings delete-account row.
  ///
  /// In en, this message translates to:
  /// **'Permanently erase your account and data'**
  String get settingsDeleteAccountRowSubtitle;

  /// Title of the delete-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountDialogTitle;

  /// Body of the delete-account confirmation dialog, explaining what is deleted.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, including your logs, collection, and achievements. This can\'t be undone.'**
  String get deleteAccountDialogMessage;

  /// Instruction in the delete-account dialog telling the user to type their own username to enable the destructive action.
  ///
  /// In en, this message translates to:
  /// **'Type your username, {username}, to confirm.'**
  String deleteAccountDialogConfirmHint(String username);

  /// Destructive confirm button label in the delete-account dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountConfirmAction;

  /// Shown when DELETE /account fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Please try again.'**
  String get deleteAccountGenericError;

  /// Title of the Profile card that opens the Contributions screen.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get profileContributionsCardTitle;

  /// Subtitle of the Profile card that opens the Contributions screen.
  ///
  /// In en, this message translates to:
  /// **'Suggest missing beers and breweries'**
  String get profileContributionsCardSubtitle;

  /// App bar title of the Contributions screen (submission history).
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get contributionsScreenTitle;

  /// Explains on the Contributions screen that a suggestion is not a catalog entry.
  ///
  /// In en, this message translates to:
  /// **'Suggestions are reviewed before they can join the catalog. Nothing you submit here appears in the catalog until then.'**
  String get contributionsIntro;

  /// Button on the Contributions screen that opens the suggest-a-beer form.
  ///
  /// In en, this message translates to:
  /// **'Suggest a beer'**
  String get contributionsSuggestBeerAction;

  /// Button on the Contributions screen that opens the suggest-a-brewery form.
  ///
  /// In en, this message translates to:
  /// **'Suggest a brewery'**
  String get contributionsSuggestBreweryAction;

  /// Section title above the list of the user's own past suggestions.
  ///
  /// In en, this message translates to:
  /// **'Your suggestions'**
  String get contributionsHistoryTitle;

  /// Empty state of the submission history.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t suggested anything yet.'**
  String get contributionsEmptyMessage;

  /// Label for a beer suggestion in the history list.
  ///
  /// In en, this message translates to:
  /// **'Beer'**
  String get contributionKindBeer;

  /// Label for a brewery suggestion in the history list.
  ///
  /// In en, this message translates to:
  /// **'Brewery'**
  String get contributionKindBrewery;

  /// Status of a suggestion that has not been reviewed yet.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get contributionStatusPending;

  /// Status of a suggestion a moderator approved (not reachable until moderation exists).
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get contributionStatusApproved;

  /// Status of a suggestion a moderator did not accept (not reachable until moderation exists).
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get contributionStatusRejected;

  /// Status label for a status value this app version does not recognize.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get contributionStatusUnknown;

  /// Primary button on the suggest-a-beer and suggest-a-brewery forms.
  ///
  /// In en, this message translates to:
  /// **'Submit suggestion'**
  String get contributionSubmitAction;

  /// Shown when a search or barcode scan finds nothing; opens the suggest-a-beer form.
  ///
  /// In en, this message translates to:
  /// **'Suggest this beer'**
  String get contributionSuggestThisBeerAction;

  /// Form validation: a required field is blank.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get contributionValidationRequired;

  /// Form validation: text exceeds the maximum length.
  ///
  /// In en, this message translates to:
  /// **'Must be at most {max} characters.'**
  String contributionValidationTooLong(int max);

  /// Form validation: the ABV is not a number in range.
  ///
  /// In en, this message translates to:
  /// **'Enter an ABV between 0 and 99.99 with at most 2 decimals.'**
  String get contributionValidationAbv;

  /// Form validation: the barcode is not 8, 12 or 13 digits.
  ///
  /// In en, this message translates to:
  /// **'Enter digits only (8, 12 or 13 digits).'**
  String get contributionValidationBarcode;

  /// Form validation: no brewery chosen for a beer suggestion.
  ///
  /// In en, this message translates to:
  /// **'Choose a brewery or enter its name.'**
  String get contributionValidationBreweryRequired;

  /// Form validation: no country chosen for a brewery suggestion.
  ///
  /// In en, this message translates to:
  /// **'Choose a country or enter its name.'**
  String get contributionValidationCountryRequired;

  /// Picker option meaning the wanted brewery/style/country is not in the catalog; reveals a text field.
  ///
  /// In en, this message translates to:
  /// **'Not listed'**
  String get contributionOptionNotListed;

  /// Picker option for leaving the optional beer style empty.
  ///
  /// In en, this message translates to:
  /// **'No style'**
  String get contributionOptionNoStyle;

  /// App bar title of the suggest-a-beer form.
  ///
  /// In en, this message translates to:
  /// **'Suggest a beer'**
  String get suggestBeerScreenTitle;

  /// Hint of the beer name field.
  ///
  /// In en, this message translates to:
  /// **'Beer name'**
  String get suggestBeerNameHint;

  /// Label of the brewery picker.
  ///
  /// In en, this message translates to:
  /// **'Brewery'**
  String get suggestBeerBreweryLabel;

  /// Hint of the free-text brewery field shown when the brewery is not listed.
  ///
  /// In en, this message translates to:
  /// **'Brewery name'**
  String get suggestBeerProposedBreweryHint;

  /// Label of the optional style picker.
  ///
  /// In en, this message translates to:
  /// **'Style (optional)'**
  String get suggestBeerStyleLabel;

  /// Hint of the free-text style field shown when the style is not listed.
  ///
  /// In en, this message translates to:
  /// **'Style name'**
  String get suggestBeerProposedStyleHint;

  /// Hint of the optional ABV field.
  ///
  /// In en, this message translates to:
  /// **'ABV % (optional)'**
  String get suggestBeerAbvHint;

  /// Hint of the optional barcode field.
  ///
  /// In en, this message translates to:
  /// **'Barcode (optional)'**
  String get suggestBeerBarcodeHint;

  /// App bar title of the suggest-a-brewery form.
  ///
  /// In en, this message translates to:
  /// **'Suggest a brewery'**
  String get suggestBreweryScreenTitle;

  /// Hint of the brewery name field.
  ///
  /// In en, this message translates to:
  /// **'Brewery name'**
  String get suggestBreweryNameHint;

  /// Label of the country picker.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get suggestBreweryCountryLabel;

  /// Hint of the free-text country field shown when the country is not listed.
  ///
  /// In en, this message translates to:
  /// **'Country name'**
  String get suggestBreweryProposedCountryHint;

  /// Hint of the optional region field.
  ///
  /// In en, this message translates to:
  /// **'Region (optional)'**
  String get suggestBreweryRegionHint;

  /// Hint of the optional city field.
  ///
  /// In en, this message translates to:
  /// **'City (optional)'**
  String get suggestBreweryCityHint;

  /// Title of the non-blocking duplicate warning sheet.
  ///
  /// In en, this message translates to:
  /// **'Similar entries found'**
  String get contributionDuplicateSheetTitle;

  /// Body of the duplicate warning sheet.
  ///
  /// In en, this message translates to:
  /// **'Please check these before submitting. If yours is different, you can still submit it.'**
  String get contributionDuplicateSheetBody;

  /// Heading above catalog beers that look like the suggestion.
  ///
  /// In en, this message translates to:
  /// **'Similar beers already in the catalog'**
  String get contributionDuplicateSimilarBeers;

  /// Heading above catalog breweries that look like the suggestion.
  ///
  /// In en, this message translates to:
  /// **'Similar breweries already in the catalog'**
  String get contributionDuplicateSimilarBreweries;

  /// Non-blocking warning that another user's pending suggestion carries the same barcode. Reveals nothing else.
  ///
  /// In en, this message translates to:
  /// **'Another pending suggestion may already include this barcode.'**
  String get contributionDuplicatePendingBarcode;

  /// Duplicate warning sheet: go back and edit.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get contributionDuplicateReviewAction;

  /// Duplicate warning sheet: submit despite the warning.
  ///
  /// In en, this message translates to:
  /// **'Submit anyway'**
  String get contributionDuplicateSubmitAnywayAction;

  /// Opens a similar catalog beer's detail.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get contributionDuplicateViewAction;

  /// Shown when the barcode already belongs to a catalog beer.
  ///
  /// In en, this message translates to:
  /// **'View existing beer'**
  String get contributionViewExistingBeerAction;

  /// Success heading after a suggestion is stored.
  ///
  /// In en, this message translates to:
  /// **'Suggestion received'**
  String get contributionSubmittedTitle;

  /// Success body: the suggestion is not a catalog entry yet.
  ///
  /// In en, this message translates to:
  /// **'It\'s pending review. It won\'t appear in the catalog until it has been reviewed.'**
  String get contributionSubmittedBody;

  /// Closes the success state.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get contributionSubmittedDoneAction;

  /// Title of the confirm-discard dialog when leaving an edited form.
  ///
  /// In en, this message translates to:
  /// **'Discard this suggestion?'**
  String get contributionDiscardTitle;

  /// Body of the confirm-discard dialog.
  ///
  /// In en, this message translates to:
  /// **'Your changes will be lost.'**
  String get contributionDiscardBody;

  /// Confirms discarding the form.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get contributionDiscardConfirmAction;

  /// Cancels discarding the form.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get contributionDiscardCancelAction;

  /// Contribution request rejected as unauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get contributionErrorUnauthorized;

  /// Contribution request failed with a 503.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again shortly.'**
  String get contributionErrorServiceUnavailable;

  /// Contribution request failed without a response.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection and try again.'**
  String get contributionErrorNetwork;

  /// Contribution request rejected with a 422.
  ///
  /// In en, this message translates to:
  /// **'Some details aren\'t valid. Please check the fields and try again.'**
  String get contributionErrorValidation;

  /// A referenced brewery/style/country was not found.
  ///
  /// In en, this message translates to:
  /// **'One of the selected catalog entries no longer exists. Please choose again.'**
  String get contributionErrorNotFound;

  /// Hard block: the barcode is already assigned to a catalog beer.
  ///
  /// In en, this message translates to:
  /// **'This barcode already belongs to a beer in the catalog.'**
  String get contributionErrorBarcodeInCatalog;

  /// Hard block: the user's own identical pending suggestion exists.
  ///
  /// In en, this message translates to:
  /// **'You already have an identical suggestion pending review.'**
  String get contributionErrorAlreadySubmitted;

  /// Fallback contribution error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get contributionErrorGeneric;

  /// Screen-reader label for a collection tile's latest rating badge (shown visually as 4/5).
  ///
  /// In en, this message translates to:
  /// **'Rated {rating} out of 5'**
  String collectionRatingSemanticLabel(int rating);

  /// Screen-reader summary of the monthly activity chart when every month is empty.
  ///
  /// In en, this message translates to:
  /// **'Monthly activity: no entries in the last 12 months.'**
  String get statisticsMonthlyChartSemanticEmpty;

  /// Screen-reader summary of the monthly activity bar chart: total logs and the busiest month.
  ///
  /// In en, this message translates to:
  /// **'Monthly activity over the last 12 months: {total, plural, =1{1 entry} other{{total} entries}} in total. Month with most entries: {month}, {count, plural, =1{1 entry} other{{count} entries}}.'**
  String statisticsMonthlyChartSemanticSummary(
    int total,
    String month,
    int count,
  );

  /// One year and its log count, as read by a screen reader for the yearly activity chart.
  ///
  /// In en, this message translates to:
  /// **'{year}: {count, plural, =1{1 entry} other{{count} entries}}'**
  String statisticsYearlyChartSemanticEntry(int year, int count);

  /// Screen-reader summary of the yearly activity bar chart; entries is a comma-separated list of year entries.
  ///
  /// In en, this message translates to:
  /// **'Yearly activity: {entries}.'**
  String statisticsYearlyChartSemanticSummary(String entries);

  /// Full month name, read aloud in the monthly chart's screen-reader summary. month is one of january..december.
  ///
  /// In en, this message translates to:
  /// **'{month, select, january{January} february{February} march{March} april{April} may{May} june{June} july{July} august{August} september{September} october{October} november{November} december{December} other{}}'**
  String statisticsMonthLongName(String month);
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
