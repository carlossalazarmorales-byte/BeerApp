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

  /// Discover tab -- also the "search manually" fallback destination from
  /// the Scan screen (permission denied/unsupported/not-found/error
  /// states). A single-route `StatefulShellBranch` (no nested sub-routes),
  /// so `context.go(discover)` resolves straight to that branch like
  /// `navigationShell.goBranch` would, with no extra navigation plumbing.
  static const String discover = '/discover';

  /// Beer detail. Declared as a top-level route (not nested inside the
  /// Discover tab's `StatefulShellBranch`) so it builds on the root
  /// navigator, full-screen above the bottom-nav shell, rather than staying
  /// on the Discover branch's own nested navigator.
  static const String beerDetail = '/discover/beers/:beerId';

  static String beerDetailPath(String beerId) => '/discover/beers/$beerId';

  /// Statistics. Declared as a top-level route (not nested inside the
  /// Profile tab's `StatefulShellBranch`) so it builds on the root
  /// navigator, full-screen above the bottom-nav shell -- same reasoning as
  /// [beerDetail].
  static const String statistics = '/profile/statistics';

  /// Achievements. Top-level route, same reasoning as [statistics].
  static const String achievements = '/profile/achievements';

  /// Edit Profile. Top-level route (not nested inside the Profile tab's
  /// `StatefulShellBranch`), same reasoning as [statistics] -- full-screen
  /// above the bottom-nav shell.
  static const String editProfile = '/profile/edit';

  /// Settings. Top-level route, same reasoning as [editProfile].
  static const String settings = '/profile/settings';
}
