import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/profile/presentation/profile_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_profile_repository.dart';

Widget _harness(GoRouter router, AuthController authController) {
  return AuthScope(
    controller: authController,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/profile',
  routes: [
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.statistics,
      builder: (context, state) =>
          const Scaffold(body: Text('Statistics Screen')),
    ),
    GoRoute(
      path: AppRoutes.achievements,
      builder: (context, state) =>
          const Scaffold(body: Text('Achievements Screen')),
    ),
    GoRoute(
      path: AppRoutes.editProfile,
      builder: (context, state) =>
          const Scaffold(body: Text('Edit Profile Screen')),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) =>
          const Scaffold(body: Text('Settings Screen')),
    ),
    GoRoute(
      path: AppRoutes.contributions,
      builder: (context, state) =>
          const Scaffold(body: Text('Contributions Screen')),
    ),
  ],
);

// Deliberately synchronous -- AuthController's own constructor runs
// synchronously up to its first internal await (see
// AuthController._initialize()), and the subsequent pumpWidget/pumpAndSettle
// calls below flush that pending microtask-based initialization on their
// own. A `Future.delayed` here (even Duration.zero) would rely on a real
// Timer, which testWidgets' fake-async zone never elapses on its own before
// the first pump -- that previously hung every test in this file for the
// full 10-minute per-test timeout.
AuthController _signedInController({String? displayName}) {
  final authRepository = FakeAuthRepository(
    initialUser: const AppUser(id: 'user-1'),
  );
  final profileRepository = FakeProfileRepository()
    ..currentUserId = 'user-1'
    ..seed(
      Profile(id: 'user-1', username: 'beerfan', displayName: displayName),
    );
  return AuthController(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
}

void main() {
  testWidgets('shows a greeting using the signed-in profile', (tester) async {
    final authController = _signedInController(displayName: 'Carlos');

    await tester.pumpWidget(_harness(_router(), authController));
    await tester.pumpAndSettle();

    expect(find.text('Signed in as Carlos.'), findsOneWidget);
  });

  testWidgets('shows the Statistics entry card', (tester) async {
    final authController = _signedInController(displayName: 'Carlos');

    await tester.pumpWidget(_harness(_router(), authController));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('See your personal beer activity'), findsOneWidget);
  });

  testWidgets('tapping the Statistics card navigates to AppRoutes.statistics', (
    tester,
  ) async {
    final authController = _signedInController(displayName: 'Carlos');

    await tester.pumpWidget(_harness(_router(), authController));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.text('Statistics Screen'), findsOneWidget);
  });

  testWidgets('shows the Achievements entry card and navigates to it', (
    tester,
  ) async {
    final authController = _signedInController(displayName: 'Carlos');

    await tester.pumpWidget(_harness(_router(), authController));
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Achievements Screen'), findsOneWidget);
  });

  testWidgets('shows the Edit Profile entry card and navigates to it', (
    tester,
  ) async {
    final authController = _signedInController(displayName: 'Carlos');

    await tester.pumpWidget(_harness(_router(), authController));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile Screen'), findsOneWidget);
  });

  testWidgets('shows the Settings entry card and navigates to it', (
    tester,
  ) async {
    final authController = _signedInController(displayName: 'Carlos');

    await tester.pumpWidget(_harness(_router(), authController));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings Screen'), findsOneWidget);
  });

  testWidgets('shows the Contributions entry card and navigates to it', (
    tester,
  ) async {
    // Contributions is the last card; a taller surface keeps every card fully
    // on screen (the default 800x600 clips it at the edge).
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authController = _signedInController(displayName: 'Carlos');

    await tester.pumpWidget(_harness(_router(), authController));
    await tester.pumpAndSettle();

    expect(find.text('Suggest missing beers and breweries'), findsOneWidget);

    await tester.tap(find.text('Contributions'));
    await tester.pumpAndSettle();

    expect(find.text('Contributions Screen'), findsOneWidget);
  });
}
