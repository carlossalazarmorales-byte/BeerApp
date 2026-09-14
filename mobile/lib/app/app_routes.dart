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

  /// The authenticated shell's default destination (Map tab).
  static const String home = '/map';
}
