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
}
