import 'package:beerapp/design_system/components/cards/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders its child content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppCard(child: Text('Card content'))),
      ),
    );

    expect(find.text('Card content'), findsOneWidget);
  });
}
