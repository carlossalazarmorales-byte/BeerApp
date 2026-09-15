import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/profile/presentation/profile_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_profile_repository.dart';

void main() {
  testWidgets(
    'a failed sign-out shows an error instead of an uncaught exception, and '
    'leaves the button usable again',
    (tester) async {
      final authRepository = FakeAuthRepository(
        initialUser: const AppUser(id: 'email-user-id'),
      )..errorToThrow = Exception('network down');
      final profileRepository = FakeProfileRepository()
        ..seed(const Profile(id: 'email-user-id', username: 'hoppy'));
      final authController = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );
      await tester.pumpWidget(
        AuthScope(
          controller: authController,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.logout), findsOneWidget);
    },
  );
}
