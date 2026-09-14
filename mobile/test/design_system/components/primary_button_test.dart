import 'package:beerapp/design_system/components/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders its label and fires onPressed when tapped', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Continue',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('meets the minimum 48dp touch target height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(label: 'Continue', onPressed: () {}),
        ),
      ),
    );

    final size = tester.getSize(find.byType(PrimaryButton));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('does not fire onPressed when null (disabled)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PrimaryButton(label: 'Continue', onPressed: null)),
      ),
    );

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
