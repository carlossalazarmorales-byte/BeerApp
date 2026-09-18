import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/onboarding/age_gate_controller.dart';
import '../features/achievements/domain/achievements_repository.dart';
import '../features/achievements/presentation/achievements_screen.dart';
import '../features/auth/domain/account_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/profile_repository.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/check_email_screen.dart';
import '../features/auth/presentation/complete_profile_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/profile_unavailable_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/catalog/presentation/beer_detail/beer_detail_screen.dart';
import '../features/collection/domain/collection_repository.dart';
import '../features/collection/presentation/collection_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/logging/domain/log_repository.dart';
import '../features/map/domain/map_repository.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/scan/presentation/scan_screen.dart';
import '../features/statistics/domain/statistics_repository.dart';
import '../features/statistics/presentation/statistics_screen.dart';
import '../shared/collection_refresh_signal.dart';
import '../shared/widgets/splash_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

const List<String> _publicAuthRoutes = [
  AppRoutes.welcome,
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.checkEmail,
  AppRoutes.forgotPassword,
];

/// The three-layer redirect model described in the Phase 2 plan (Routing
/// decision): the age gate first, then password-recovery, then the normal
/// auth-status rules. Closes over the controllers directly rather than
/// reading them from `context`/an InheritedWidget, since the router already
/// holds direct references to the same instances passed to
/// `refreshListenable`.
String? _redirect(
  AgeGateController ageGate,
  AuthController auth,
  GoRouterState state,
) {
  final location = state.matchedLocation;

  final stillResolving =
      ageGate.status == AgeGateStatus.unknown ||
      auth.status == AppAuthStatus.unknown;
  if (stillResolving) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (ageGate.status == AgeGateStatus.notAcknowledged) {
    return location == AppRoutes.welcome ? null : AppRoutes.welcome;
  }

  if (auth.passwordRecoveryPending) {
    return location == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }

  switch (auth.status) {
    case AppAuthStatus.unknown:
      return AppRoutes.splash;
    case AppAuthStatus.unauthenticated:
      return _publicAuthRoutes.contains(location) ? null : AppRoutes.signIn;
    case AppAuthStatus.authenticatedIncompleteProfile:
      return location == AppRoutes.completeProfile
          ? null
          : AppRoutes.completeProfile;
    case AppAuthStatus.authenticatedProfileUnavailable:
      return location == AppRoutes.profileUnavailable
          ? null
          : AppRoutes.profileUnavailable;
    case AppAuthStatus.authenticatedComplete:
      final isAuthOnlyRoute =
          location == AppRoutes.splash ||
          _publicAuthRoutes.contains(location) ||
          location == AppRoutes.completeProfile ||
          location == AppRoutes.profileUnavailable ||
          location == AppRoutes.resetPassword;
      return isAuthOnlyRoute ? AppRoutes.home : null;
  }
}

GoRouter createRouter({
  required AuthRepository authRepository,
  required ProfileRepository profileRepository,
  required AccountRepository accountRepository,
  required AuthController authController,
  required AgeGateController ageGateController,
  required CatalogRepository catalogRepository,
  required LogRepository logRepository,
  required CollectionRepository collectionRepository,
  required MapRepository mapRepository,
  required StatisticsRepository statisticsRepository,
  required AchievementsRepository achievementsRepository,
  required CollectionRefreshSignal refreshSignal,
}) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: Listenable.merge([ageGateController, authController]),
    redirect: (context, state) =>
        _redirect(ageGateController, authController, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) =>
            WelcomeScreen(authRepository: authRepository),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) =>
            SignInScreen(authRepository: authRepository),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) =>
            SignUpScreen(authRepository: authRepository),
      ),
      GoRoute(
        path: AppRoutes.checkEmail,
        builder: (context, state) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) =>
            ForgotPasswordScreen(authRepository: authRepository),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) =>
            ResetPasswordScreen(authRepository: authRepository),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) =>
            CompleteProfileScreen(profileRepository: profileRepository),
      ),
      GoRoute(
        path: AppRoutes.profileUnavailable,
        builder: (context, state) => const ProfileUnavailableScreen(),
      ),
      // Declared as a top-level route, not nested inside the Discover
      // branch's `routes` below, so it builds on the root navigator --
      // full-screen above the bottom-nav shell, hiding it, while the
      // Discover branch's own navigator (and DiscoverScreen's search/filter
      // state and scroll position) stays untouched underneath.
      GoRoute(
        path: AppRoutes.beerDetail,
        builder: (context, state) => BeerDetailScreen(
          repository: catalogRepository,
          logRepository: logRepository,
          collectionRepository: collectionRepository,
          refreshSignal: refreshSignal,
          beerId: state.pathParameters['beerId']!,
        ),
      ),
      // Declared as a top-level route, not nested inside the Profile
      // branch's `routes` below, for the same reasoning as [beerDetail]
      // above -- full-screen above the bottom-nav shell.
      GoRoute(
        path: AppRoutes.statistics,
        builder: (context, state) => StatisticsScreen(
          repository: statisticsRepository,
          refreshSignal: refreshSignal,
        ),
      ),
      // Declared as a top-level route, same reasoning as [statistics] above.
      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => AchievementsScreen(
          repository: achievementsRepository,
          refreshSignal: refreshSignal,
        ),
      ),
      // Declared as a top-level route, same reasoning as [statistics] above.
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) =>
            EditProfileScreen(profileRepository: profileRepository),
      ),
      // Declared as a top-level route, same reasoning as [statistics] above.
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => SettingsScreen(
          profileRepository: profileRepository,
          authRepository: authRepository,
          accountRepository: accountRepository,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => MapScreen(
                  repository: mapRepository,
                  catalogRepository: catalogRepository,
                  refreshSignal: refreshSignal,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                builder: (context, state) =>
                    DiscoverScreen(repository: catalogRepository),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) =>
                    ScanScreen(catalogRepository: catalogRepository),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/collection',
                builder: (context, state) => CollectionScreen(
                  repository: collectionRepository,
                  catalogRepository: catalogRepository,
                  refreshSignal: refreshSignal,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
