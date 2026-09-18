import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/profile/presentation/edit_profile_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_profile_repository.dart';

// See profile_screen_test.dart's _signInController for why this is
// deliberately synchronous (no Future.delayed).
AuthController _signedInController(FakeProfileRepository profileRepository) {
  final authRepository = FakeAuthRepository(
    initialUser: const AppUser(id: 'user-1'),
  );
  profileRepository
    ..currentUserId = 'user-1'
    ..seed(
      const Profile(id: 'user-1', username: 'beerfan', displayName: 'Carlos'),
    );
  return AuthController(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
}

Widget _harness(
  AuthController authController,
  FakeProfileRepository profileRepository,
) {
  return AuthScope(
    controller: authController,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EditProfileScreen(profileRepository: profileRepository),
                ),
              ),
              child: const Text('Open Edit Profile'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openEditProfile(WidgetTester tester) async {
  await tester.tap(find.text('Open Edit Profile'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills username and display name from the signed-in profile', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository();
    final authController = _signedInController(profileRepository);

    await tester.pumpWidget(_harness(authController, profileRepository));
    await _openEditProfile(tester);

    final usernameField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    final displayNameField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(usernameField.controller!.text, 'beerfan');
    expect(displayNameField.controller!.text, 'Carlos');
  });

  testWidgets(
    'saving performs exactly one repository call, never two independent '
    'writes',
    (tester) async {
      final profileRepository = FakeProfileRepository();
      final authController = _signedInController(profileRepository);

      await tester.pumpWidget(_harness(authController, profileRepository));
      await _openEditProfile(tester);

      await tester.enterText(find.byType(TextFormField).at(1), 'New Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profileRepository.callLog, ['updateEditableProfile']);
    },
  );

  testWidgets('a successful save refreshes the profile and pops back', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository();
    final authController = _signedInController(profileRepository);

    await tester.pumpWidget(_harness(authController, profileRepository));
    await _openEditProfile(tester);

    await tester.enterText(find.byType(TextFormField).at(1), 'New Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Open Edit Profile'), findsOneWidget);
    expect(authController.profile?.displayName, 'New Name');
  });

  testWidgets(
    'a duplicate username shows the existing usernameTaken error and makes '
    'no partial change',
    (tester) async {
      final profileRepository = FakeProfileRepository()
        ..updateEditableProfileError = ProfileFailureCode.usernameTaken;
      final authController = _signedInController(profileRepository);

      await tester.pumpWidget(_harness(authController, profileRepository));
      await _openEditProfile(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'taken_name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('That username is already taken.'), findsOneWidget);
      // Still on Edit Profile -- no pop, no navigation away, and the
      // profile itself is unchanged (still the seeded username).
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(authController.profile?.username, 'beerfan');
    },
  );

  testWidgets('an empty username blocks submission -- no repository call', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository();
    final authController = _signedInController(profileRepository);

    await tester.pumpWidget(_harness(authController, profileRepository));
    await _openEditProfile(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(profileRepository.callLog, isEmpty);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });
}
