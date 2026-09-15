import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/auth/presentation/reset_password_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';

Widget _wrap(FakeAuthRepository authRepository) {
  return AuthScope(
    controller: AuthController(
      authRepository: authRepository,
      profileRepository: FakeProfileRepository(),
    ),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ResetPasswordScreen(authRepository: authRepository),
    ),
  );
}

void main() {
  testWidgets(
    'a same_password rejection shows the specific "must be different" '
    'message, not the generic error',
    (tester) async {
      final authRepository = FakeAuthRepository()
        ..errorToThrow = const AuthFailure(AuthFailureCode.samePassword);

      await tester.pumpWidget(_wrap(authRepository));
      await tester.enterText(find.byType(TextFormField), 'currentPassword1');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Your new password must be different from your current password.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Something went wrong. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'any other update-password failure still shows the existing generic '
    'message',
    (tester) async {
      final authRepository = FakeAuthRepository()
        ..errorToThrow = const AuthFailure(AuthFailureCode.weakPassword);

      await tester.pumpWidget(_wrap(authRepository));
      await tester.enterText(find.byType(TextFormField), 'somePassword1');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    },
  );
}
