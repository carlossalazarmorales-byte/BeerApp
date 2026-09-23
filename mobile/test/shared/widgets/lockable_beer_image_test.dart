import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/widgets/lockable_beer_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 56, height: 56, child: child)),
    ),
  );
}

void main() {
  testWidgets('unlocked shows a plain image with no lock badge', (
    tester,
  ) async {
    await _pump(tester, const LockableBeerImage(imageUrl: null));

    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('unlocked is also the default when isUnlocked is omitted', (
    tester,
  ) async {
    await _pump(tester, const LockableBeerImage(imageUrl: null));

    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets(
    'locked shows the grayscale-filtered image with a corner lock badge, '
    'and never uses heavy opacity or a blur filter',
    (tester) async {
      await _pump(
        tester,
        const LockableBeerImage(imageUrl: null, isUnlocked: false),
      );

      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
    },
  );

  testWidgets(
    'locked announces an accessible "locked" label, and the lock badge '
    'itself is not separately announced (no duplicate)',
    (tester) async {
      final handle = tester.ensureSemantics();

      await _pump(
        tester,
        const LockableBeerImage(imageUrl: null, isUnlocked: false),
      );

      final node = tester.getSemantics(find.byType(LockableBeerImage));
      expect(node.label, contains('Locked'));
      handle.dispose();
    },
  );

  testWidgets('unlocked adds no semantics of its own (purely decorative)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pump(tester, const LockableBeerImage(imageUrl: null));

    final node = tester.getSemantics(find.byType(LockableBeerImage));
    expect(node.label, isEmpty);
    handle.dispose();
  });
}
