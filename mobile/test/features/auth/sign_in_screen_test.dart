import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/presentation/sign_in_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';

Widget _wrap(FakeAuthRepository authRepository) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SignInScreen(authRepository: authRepository),
  );
}

void main() {
  testWidgets(
    'tapping Continue with Google before it is configured shows a controlled '
    'message instead of an uncaught exception',
    (tester) async {
      final authRepository = FakeAuthRepository()
        ..errorToThrow = const AuthFailure(
          AuthFailureCode.providerNotConfigured,
        );

      await tester.pumpWidget(_wrap(authRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text("Google sign-in isn't available yet."), findsOneWidget);
    },
  );

  testWidgets(
    'cancelling the Google account picker resets silently, with no error '
    'message shown',
    (tester) async {
      final authRepository = FakeAuthRepository()
        ..errorToThrow = const AuthFailure(AuthFailureCode.cancelled);

      await tester.pumpWidget(_wrap(authRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text("Google sign-in isn't available yet."), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsNothing,
      );
    },
  );
}
