import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('English locale resolves nav-label and placeholder strings', (
    tester,
  ) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(l10n.navMap, 'Map');
    expect(l10n.navDiscover, 'Discover');
    expect(l10n.navScan, 'Scan');
    expect(l10n.navCollection, 'Collection');
    expect(l10n.navProfile, 'Profile');
    expect(l10n.comingSoonBadge, 'Coming soon');
  });

  testWidgets('Spanish locale resolves nav-label and placeholder strings', (
    tester,
  ) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(l10n.navMap, 'Mapa');
    expect(l10n.navDiscover, 'Descubrir');
    expect(l10n.navScan, 'Escanear');
    expect(l10n.navCollection, 'Colección');
    expect(l10n.navProfile, 'Perfil');
    expect(l10n.comingSoonBadge, 'Próximamente');
  });

  testWidgets(
    'the Discover screen renders with Spanish resolved instead of falling back to English',
    (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Text(l10n.discoverScreenDescription);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Encuentra nuevas cervecerías, estilos y cervezas que vale la pena probar.',
        ),
        findsOneWidget,
      );
    },
  );
}
