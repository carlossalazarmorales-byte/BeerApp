/// Route path constants shared between `router.dart` and the screens that
/// navigate between each other, so no path string is duplicated.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String checkEmail = '/check-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String completeProfile = '/complete-profile';

  /// Shown for `AppAuthStatus.authenticatedProfileUnavailable` — a failed
  /// profile *request*, never to be confused with [completeProfile] (a
  /// successfully-loaded profile that's missing a username).
  static const String profileUnavailable = '/profile-unavailable';

  /// The authenticated shell's default destination (Map tab).
  static const String home = '/map';

  /// Beer detail. Declared as a top-level route (not nested inside the
  /// Discover tab's `StatefulShellBranch`) so it builds on the root
  /// navigator, full-screen above the bottom-nav shell, rather than staying
  /// on the Discover branch's own nested navigator.
  static const String beerDetail = '/discover/beers/:beerId';

  static String beerDetailPath(String beerId) => '/discover/beers/$beerId';
}
