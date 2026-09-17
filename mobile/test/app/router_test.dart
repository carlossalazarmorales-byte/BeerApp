import 'package:beerapp/app/app.dart';
import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/app/router.dart';
import 'package:beerapp/core/onboarding/age_gate_controller.dart';
import 'package:beerapp/design_system/components/navigation/bottom_nav_bar.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/auth/presentation/complete_profile_screen.dart';
import 'package:beerapp/features/auth/presentation/profile_unavailable_screen.dart';
import 'package:beerapp/features/auth/presentation/sign_in_screen.dart';
import 'package:beerapp/features/auth/presentation/welcome_screen.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/catalog/presentation/beer_detail/beer_detail_screen.dart';
import 'package:beerapp/features/map/presentation/map_screen.dart';
import 'package:beerapp/features/profile/presentation/profile_screen.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_age_gate_storage.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_catalog_repository.dart';
import '../fakes/fake_collection_repository.dart';
import '../fakes/fake_log_repository.dart';
import '../fakes/fake_map_repository.dart';
import '../fakes/fake_profile_repository.dart';
import '../fakes/fake_statistics_repository.dart';

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(BottomNavBar), matching: find.text(label));

/// Builds the real `BeerApp` widget tree against fakes — this is the
/// router's actual redirect logic, not a reimplementation of it, so these
/// tests catch real regressions in `router.dart`.
///
/// [initialProfile], if given, must be seeded into [profileRepository]
/// *before* [AuthController] is constructed: its `_initialize()` reads the
/// profile synchronously (up to its first await) as soon as the controller
/// is built, so seeding afterward would be too late to affect its status.
class _Harness {
  factory _Harness({
    AppUser? initialUser,
    bool ageAcknowledged = false,
    Profile? initialProfile,
    Object? initialProfileError,
  }) {
    final authRepository = FakeAuthRepository(initialUser: initialUser);
    final profileRepository = FakeProfileRepository();
    if (initialProfile != null) profileRepository.seed(initialProfile);
    if (initialProfileError != null) {
      profileRepository.getProfileError = initialProfileError;
    }
    final catalogRepository = FakeCatalogRepository();

    final ageGateController = AgeGateController(
      storage: FakeAgeGateStorage(initiallyAcknowledged: ageAcknowledged),
    );
    final authController = AuthController(
      authRepository: authRepository,
      profileRepository: profileRepository,
    );
    final router = createRouter(
      authRepository: authRepository,
      profileRepository: profileRepository,
      authController: authController,
      ageGateController: ageGateController,
      catalogRepository: catalogRepository,
      logRepository: FakeLogRepository(),
      collectionRepository: FakeCollectionRepository(),
      mapRepository: FakeMapRepository(),
      statisticsRepository: FakeStatisticsRepository(),
      refreshSignal: CollectionRefreshSignal(),
    );

    return _Harness._(
      authRepository: authRepository,
      profileRepository: profileRepository,
      catalogRepository: catalogRepository,
      ageGateController: ageGateController,
      authController: authController,
      router: router,
    );
  }

  _Harness._({
    required this.authRepository,
    required this.profileRepository,
    required this.catalogRepository,
    required this.ageGateController,
    required this.authController,
    required this.router,
  });

  final FakeAuthRepository authRepository;
  final FakeProfileRepository profileRepository;
  final FakeCatalogRepository catalogRepository;
  final AgeGateController ageGateController;
  final AuthController authController;
  final GoRouter router;

  Widget get app => BeerApp(
    router: router,
    authController: authController,
    ageGateController: ageGateController,
  );
}

void main() {
  testWidgets(
    'age gate not acknowledged: lands on welcome and bounces back from a direct sign-in navigation',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);

      harness.router.go('/sign-in');
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    },
  );

  testWidgets(
    'age gate acknowledged, unauthenticated: sign-in is reachable, shell is not',
    (tester) async {
      final harness = _Harness(ageAcknowledged: true);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      harness.router.go('/sign-in');
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);

      harness.router.go('/map');
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated with an incomplete profile is forced onto /complete-profile',
    (tester) async {
      final harness = _Harness(
        ageAcknowledged: true,
        initialUser: const AppUser(id: 'google-user-id'),
        initialProfile: const Profile(id: 'google-user-id', username: null),
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byType(CompleteProfileScreen), findsOneWidget);

      harness.router.go('/map');
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsNothing);
      expect(find.byType(CompleteProfileScreen), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated with a complete profile reaches the shell and cannot re-enter sign-in',
    (tester) async {
      final harness = _Harness(
        ageAcknowledged: true,
        initialUser: const AppUser(id: 'email-user-id'),
        initialProfile: const Profile(id: 'email-user-id', username: 'hoppy'),
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);

      harness.router.go('/sign-in');
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(MapScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a profile-load failure is forced onto /profile-unavailable, never '
    '/complete-profile, and retry recovers into the shell once it succeeds',
    (tester) async {
      final harness = _Harness(
        ageAcknowledged: true,
        initialUser: const AppUser(id: 'email-user-id'),
        initialProfileError: Exception('network down'),
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileUnavailableScreen), findsOneWidget);
      expect(find.byType(CompleteProfileScreen), findsNothing);

      harness.router.go('/map');
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsNothing);
      expect(find.byType(ProfileUnavailableScreen), findsOneWidget);

      // Fix the underlying failure and seed the profile the fetch would
      // have returned, then tap the screen's retry action.
      harness.profileRepository.getProfileError = null;
      harness.profileRepository.seed(
        const Profile(id: 'email-user-id', username: 'hoppy'),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(MapScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping bottom nav items switches shell tabs and preserves widget state',
    (tester) async {
      final harness = _Harness(
        ageAcknowledged: true,
        initialUser: const AppUser(id: 'email-user-id'),
        initialProfile: const Profile(id: 'email-user-id', username: 'hoppy'),
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      final mapScreenBefore = tester.widget(find.byType(MapScreen));

      await tester.tap(_navLabel('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(_navLabel('Map'));
      await tester.pumpAndSettle();

      final mapScreenAfter = tester.widget(find.byType(MapScreen));
      expect(identical(mapScreenBefore, mapScreenAfter), isTrue);
    },
  );

  testWidgets(
    'beer detail is a full-screen route above the shell: hides the bottom '
    'nav and preserves Discover state on pop',
    (tester) async {
      final harness = _Harness(
        ageAcknowledged: true,
        initialUser: const AppUser(id: 'email-user-id'),
        initialProfile: const Profile(id: 'email-user-id', username: 'hoppy'),
      );
      harness.catalogRepository
        ..beersByPage[1] = const PagedResult(
          items: [
            Beer(
              id: 'beer-1',
              officialName: 'Test Pale Ale',
              breweryId: 'brewery-1',
              verified: false,
            ),
          ],
          page: 1,
          pageSize: 20,
          total: 1,
        )
        ..beersById['beer-1'] = const Beer(
          id: 'beer-1',
          officialName: 'Test Pale Ale',
          breweryId: 'brewery-1',
          verified: false,
        )
        ..breweriesById['brewery-1'] = const Brewery(
          id: 'brewery-1',
          name: 'Test Brewery',
          countryId: 'country-1',
          verified: false,
        );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      harness.router.go('/discover');
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavBar), findsOneWidget);
      expect(find.text('Test Pale Ale'), findsOneWidget);

      harness.router.push(AppRoutes.beerDetailPath('beer-1'));
      await tester.pumpAndSettle();

      expect(find.byType(BeerDetailScreen), findsOneWidget);
      expect(
        find.byType(BottomNavBar),
        findsNothing,
        reason: 'beer detail is a full-screen route above the shell',
      );

      harness.router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(BeerDetailScreen), findsNothing);
      expect(find.byType(BottomNavBar), findsOneWidget);
      // The Discover branch's own Navigator (and its already-loaded list)
      // was never torn down while covered by the detail route.
      expect(find.text('Test Pale Ale'), findsOneWidget);
    },
  );
}
