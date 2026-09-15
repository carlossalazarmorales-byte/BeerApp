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

  /// Placeholder description for the Map screen.
  ///
  /// In en, this message translates to:
  /// **'Explore the beers around you on an interactive world map.'**
  String get mapScreenDescription;

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

  /// Placeholder description for the Collection screen.
  ///
  /// In en, this message translates to:
  /// **'Keep track of every beer you have tried and rated.'**
  String get collectionScreenDescription;

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
