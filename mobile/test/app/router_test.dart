import 'package:beerapp/app/app.dart';
import 'package:beerapp/app/router.dart';
import 'package:beerapp/core/onboarding/age_gate_controller.dart';
import 'package:beerapp/design_system/components/navigation/bottom_nav_bar.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/auth/presentation/complete_profile_screen.dart';
import 'package:beerapp/features/auth/presentation/sign_in_screen.dart';
import 'package:beerapp/features/auth/presentation/welcome_screen.dart';
import 'package:beerapp/features/map/presentation/map_screen.dart';
import 'package:beerapp/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_age_gate_storage.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_profile_repository.dart';

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
  }) {
    final authRepository = FakeAuthRepository(initialUser: initialUser);
    final profileRepository = FakeProfileRepository();
    if (initialProfile != null) profileRepository.seed(initialProfile);

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
    );

    return _Harness._(
      authRepository: authRepository,
      profileRepository: profileRepository,
      ageGateController: ageGateController,
      authController: authController,
      router: router,
    );
  }

  _Harness._({
    required this.authRepository,
    required this.profileRepository,
    required this.ageGateController,
    required this.authController,
    required this.router,
  });

  final FakeAuthRepository authRepository;
  final FakeProfileRepository profileRepository;
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
}
