import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/core/config/legal_config.dart';
import 'package:beerapp/core/links/external_link_opener.dart';
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

class _FakeOpener implements ExternalLinkOpener {
  final List<Uri> opened = [];
  bool succeeds = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeeds;
  }
}

final _privacyUrl = Uri.parse('https://legal.example.com/privacy');
final _termsUrl = Uri.parse('https://legal.example.com/terms');

Future<_FakeOpener> _pump(
  WidgetTester tester, {
  LegalConfig legalConfig = const LegalConfig(),
  Locale locale = const Locale('en'),
  bool openSucceeds = true,
}) async {
  final opener = _FakeOpener()..succeeds = openSucceeds;
  final authRepository = FakeAuthRepository(
    initialUser: const AppUser(id: 'user-1', email: 'user@example.com'),
  );
  final profileRepository = FakeProfileRepository()
    ..currentUserId = 'user-1'
    ..seed(
      const Profile(id: 'user-1', username: 'beerfan', displayName: 'Carlos'),
    );
  final authController = AuthController(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
  final localeController = LocaleController(
    storage: FakeLocalePreferenceStorage(),
  );

  await tester.pumpWidget(
    AuthScope(
      controller: authController,
      child: LocaleScope(
        controller: localeController,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(
            profileRepository: profileRepository,
            authRepository: authRepository,
            accountRepository: FakeAccountRepository(),
            legalConfig: legalConfig,
            linkOpener: opener,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opener;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('no legal URL configured (placeholder behaviour is unchanged)', () {
    testWidgets('Privacy Policy opens the "not available yet" placeholder', (
      tester,
    ) async {
      final opener = await _pump(tester);

      await _tap(tester, 'Privacy Policy');

      expect(find.textContaining("isn't available yet"), findsOneWidget);
      expect(opener.opened, isEmpty);
    });

    testWidgets('Terms of Service opens the placeholder too', (tester) async {
      final opener = await _pump(tester);

      await _tap(tester, 'Terms of Service');

      expect(find.textContaining("isn't available yet"), findsOneWidget);
      expect(opener.opened, isEmpty);
    });

    testWidgets('the rows show no "opens in browser" hint', (tester) async {
      await _pump(tester);
      await tester.ensureVisible(find.text('Privacy Policy'));

      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });
  });

  group('legal URLs configured', () {
    final config = LegalConfig(
      privacyPolicyUri: _privacyUrl,
      termsOfServiceUri: _termsUrl,
    );

    testWidgets('Privacy Policy opens the configured URL in the browser', (
      tester,
    ) async {
      final opener = await _pump(tester, legalConfig: config);

      await _tap(tester, 'Privacy Policy');

      expect(opener.opened, [_privacyUrl]);
      // No in-app screen replaced the settings page.
      expect(find.textContaining("isn't available yet"), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('Terms of Service opens its own configured URL', (
      tester,
    ) async {
      final opener = await _pump(tester, legalConfig: config);

      await _tap(tester, 'Terms of Service');

      expect(opener.opened, [_termsUrl]);
    });

    testWidgets('both rows show the "opens in browser" hint', (tester) async {
      await _pump(tester, legalConfig: config);
      await tester.ensureVisible(find.text('Terms of Service'));

      expect(find.byIcon(Icons.open_in_new), findsNWidgets(2));
    });

    testWidgets('a successful launch shows no error', (tester) async {
      await _pump(tester, legalConfig: config);

      await _tap(tester, 'Privacy Policy');

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the unrelated "Privacy settings" row is still a placeholder', (
      tester,
    ) async {
      final opener = await _pump(tester, legalConfig: config);

      await _tap(tester, 'Privacy settings');

      expect(find.textContaining("isn't available yet"), findsOneWidget);
      expect(opener.opened, isEmpty);
    });
  });

  group('only one document configured', () {
    testWidgets(
      'the configured one launches, the other keeps its placeholder',
      (tester) async {
        final opener = await _pump(
          tester,
          legalConfig: LegalConfig(privacyPolicyUri: _privacyUrl),
        );
        await tester.ensureVisible(find.text('Terms of Service'));
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);

        await _tap(tester, 'Terms of Service');
        expect(find.textContaining("isn't available yet"), findsOneWidget);
        expect(opener.opened, isEmpty);
      },
    );
  });

  group('launch failure', () {
    final config = LegalConfig(
      privacyPolicyUri: _privacyUrl,
      termsOfServiceUri: _termsUrl,
    );

    testWidgets('shows a localized message, never the URL', (tester) async {
      final opener = await _pump(
        tester,
        legalConfig: config,
        openSucceeds: false,
      );

      await _tap(tester, 'Privacy Policy');

      expect(opener.opened, [_privacyUrl]);
      expect(
        find.text("Couldn't open the link. Please try again later."),
        findsOneWidget,
      );
      expect(find.textContaining('legal.example.com'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('is localized in Spanish', (tester) async {
      await _pump(
        tester,
        legalConfig: config,
        openSucceeds: false,
        locale: const Locale('es'),
      );

      await _tap(tester, 'Política de privacidad');

      expect(
        find.text('No se pudo abrir el enlace. Inténtalo de nuevo más tarde.'),
        findsOneWidget,
      );
    });

    testWidgets('the screen stays usable and the user can try again', (
      tester,
    ) async {
      final opener = await _pump(
        tester,
        legalConfig: config,
        openSucceeds: false,
      );

      await _tap(tester, 'Privacy Policy');
      opener.succeeds = true;
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await _tap(tester, 'Privacy Policy');

      expect(opener.opened, [_privacyUrl, _privacyUrl]);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
