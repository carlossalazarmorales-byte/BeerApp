import 'package:beerapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MainApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
