import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/core/locale/locale_controller.dart';
import 'package:beerapp/core/locale/locale_scope.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/profile/presentation/settings_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_account_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_locale_preference_storage.dart';
import '../../../fakes/fake_profile_repository.dart';

class _Harness {
  factory _Harness({String? preferredCurrency}) {
    final authRepository = FakeAuthRepository(
      initialUser: const AppUser(id: 'user-1', email: 'user@example.com'),
    );
    final profileRepository = FakeProfileRepository()
      ..currentUserId = 'user-1'
      ..seed(
        Profile(
          id: 'user-1',
          username: 'beerfan',
          displayName: 'Carlos',
          preferredCurrency: preferredCurrency,
        ),
      );
    final authController = AuthController(
      authRepository: authRepository,
      profileRepository: profileRepository,
    );
    final localeController = LocaleController(
      storage: FakeLocalePreferenceStorage(),
    );
    final accountRepository = FakeAccountRepository();

    return _Harness._(
      authRepository: authRepository,
      profileRepository: profileRepository,
      authController: authController,
      localeController: localeController,
      accountRepository: accountRepository,
    );
  }

  _Harness._({
    required this.authRepository,
    required this.profileRepository,
    required this.authController,
    required this.localeController,
    required this.accountRepository,
  });

  final FakeAuthRepository authRepository;
  final FakeProfileRepository profileRepository;
  final AuthController authController;
  final LocaleController localeController;
  final FakeAccountRepository accountRepository;

  Widget get app => AuthScope(
    controller: authController,
    child: LocaleScope(
      controller: localeController,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          profileRepository: profileRepository,
          authRepository: authRepository,
          accountRepository: accountRepository,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows "Not set" when no preferred currency is set', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('shows the current preferred currency', (tester) async {
    final harness = _Harness(preferredCurrency: 'EUR');
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('EUR'), findsOneWidget);
  });

  testWidgets(
    'picking a currency writes it through the repository and refreshes '
    'the profile',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preferred currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EUR').last);
      await tester.pumpAndSettle();

      expect(harness.profileRepository.callLog, ['setPreferredCurrency']);
      expect(harness.authController.profile?.preferredCurrency, 'EUR');
    },
  );

  testWidgets(
    'dismissing the currency picker without a selection makes no write',
    (tester) async {
      final harness = _Harness(preferredCurrency: 'EUR');
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preferred currency'));
      await tester.pumpAndSettle();
      // Tap the barrier (outside the sheet) to dismiss without selecting.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(harness.profileRepository.callLog, isEmpty);
      expect(harness.authController.profile?.preferredCurrency, 'EUR');
    },
  );

  testWidgets('picking a language updates LocaleController without any profile '
      'repository call', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    expect(harness.localeController.locale, const Locale('es'));
    expect(harness.profileRepository.callLog, isEmpty);
  });

  testWidgets(
    'Change password sends a reset email to the signed-in user\'s own '
    'address and shows a confirmation, with no navigation',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(harness.authRepository.passwordResetEmailCalls, [
        'user@example.com',
      ]);
      expect(
        find.text('Check your email for a link to reset your password.'),
        findsOneWidget,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets('shows a dedicated Privacy settings row (ROADMAP.md\'s Phase 12 '
      'placeholder task), distinct from the Privacy Policy document row', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('Privacy settings'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.tap(find.text('Privacy settings'));
    await tester.pumpAndSettle();

    // The pushed placeholder route's AppBar title, disambiguated from the
    // still-mounted (offstage-underneath) Settings row of the same name --
    // MaterialPageRoute keeps the previous route in the tree by default.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Privacy settings'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This content isn\'t available yet. Check back before release.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'the delete-account confirm action stays disabled until the typed '
    'text matches the username exactly',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      TextButton confirmButton() => tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete account').last,
      );
      expect(confirmButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      expect(confirmButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'beerfan');
      await tester.pump();
      expect(confirmButton().onPressed, isNotNull);
    },
  );

  testWidgets(
    'confirmed deletion calls deleteAccount then signs out locally, never '
    'the other way around',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'beerfan');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete account').last);
      // Not pumpAndSettle(): on the success path _isDeletingAccount is
      // deliberately never reset (the real app expects the router to react
      // to the resulting signedOut event and unmount this screen instead --
      // see docs/DECISIONS.md), so its CircularProgressIndicator keeps
      // scheduling frames forever in this isolated test with no router,
      // which pumpAndSettle can never settle against. A few bounded pumps
      // are enough to flush the async delete-then-signOut chain.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(harness.accountRepository.deleteAccountCallCount, 1);
      expect(harness.authController.status, AppAuthStatus.unauthenticated);
    },
  );

  testWidgets(
    'a failing local sign-out AFTER a successful delete is swallowed -- '
    'still reaches unauthenticated with no error shown (regression test '
    'for the verified gotrue local-clears-before-network-throw sequencing)',
    (tester) async {
      final harness = _Harness();
      harness.authRepository.errorToThrow = Exception('network revoke failed');
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'beerfan');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete account').last);
      // See the bounded-pump comment in the test above -- pumpAndSettle
      // cannot settle while the success-path spinner keeps animating with
      // no router present to unmount this screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(harness.accountRepository.deleteAccountCallCount, 1);
      // Local state already transitioned to unauthenticated -- the fake's
      // signOut() clears state and fires signedOut *before* throwing,
      // mirroring the real gotrue SDK (see docs/DECISIONS.md).
      expect(harness.authController.status, AppAuthStatus.unauthenticated);
      // No error snackbar/dialog from the swallowed post-delete exception.
      expect(
        find.text('Couldn\'t delete your account. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a failing deleteAccount() call shows the generic error and never '
    'signs out (the account may still exist)',
    (tester) async {
      final harness = _Harness();
      harness.accountRepository.deleteAccountError = Exception('boom');
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'beerfan');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete account').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Couldn\'t delete your account. Please try again.'),
        findsOneWidget,
      );
      expect(
        harness.authController.status,
        AppAuthStatus.authenticatedComplete,
      );
    },
  );
}
