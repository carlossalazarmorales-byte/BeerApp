import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/logging/domain/models/beer_log.dart';
import 'package:beerapp/features/logging/presentation/beer_log/beer_log_controller.dart';
import 'package:beerapp/features/logging/presentation/beer_log/log_form_sheet.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_auth_repository.dart';
import '../../../../fakes/fake_log_repository.dart';
import '../../../../fakes/fake_profile_repository.dart';

AuthController _controllerWithPreferredCurrency(String? preferredCurrency) {
  final authRepository = FakeAuthRepository(
    initialUser: const AppUser(id: 'user-1'),
  );
  final profileRepository = FakeProfileRepository()
    ..currentUserId = 'user-1'
    ..seed(
      Profile(
        id: 'user-1',
        username: 'beerfan',
        preferredCurrency: preferredCurrency,
      ),
    );
  return AuthController(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
}

Widget _harness(
  AuthController authController, {
  required BeerLogController controller,
  BeerLog? existing,
}) {
  return AuthScope(
    controller: authController,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LogFormSheet(controller: controller, existing: existing),
      ),
    ),
  );
}

/// The currency field only renders once "Add details" is tapped -- index
/// within the expanded field list is review(0)/servingNote(1)/
/// servingVolume(2)/price(3)/currency(4)/venue(5).
Future<TextFormField> _expandAndGetCurrencyField(WidgetTester tester) async {
  await tester.tap(find.text('Add details'));
  await tester.pumpAndSettle();
  return tester.widget<TextFormField>(find.byType(TextFormField).at(4));
}

BeerLog _existingLog({String? currency}) => BeerLog(
  id: 'log-1',
  userId: 'user-1',
  beerId: 'beer-1',
  consumedAt: DateTime.utc(2026, 1, 1),
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  currency: currency,
  price: currency == null ? null : 4.5,
);

void main() {
  testWidgets(
    'a new log seeds the currency field from preferred_currency exactly '
    'once',
    (tester) async {
      final authController = _controllerWithPreferredCurrency('EUR');
      final controller = BeerLogController(
        repository: FakeLogRepository(),
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );

      await tester.pumpWidget(_harness(authController, controller: controller));
      await tester.pumpAndSettle();

      final field = await _expandAndGetCurrencyField(tester);
      expect(field.controller!.text, 'EUR');
    },
  );

  testWidgets(
    'a new log with no preferred_currency leaves the currency field empty',
    (tester) async {
      final authController = _controllerWithPreferredCurrency(null);
      final controller = BeerLogController(
        repository: FakeLogRepository(),
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );

      await tester.pumpWidget(_harness(authController, controller: controller));
      await tester.pumpAndSettle();

      final field = await _expandAndGetCurrencyField(tester);
      expect(field.controller!.text, isEmpty);
    },
  );

  testWidgets(
    'once seeded, the value is never reapplied on a later rebuild -- a '
    "user's own edit is preserved",
    (tester) async {
      final authController = _controllerWithPreferredCurrency('EUR');
      final controller = BeerLogController(
        repository: FakeLogRepository(),
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );

      await tester.pumpWidget(_harness(authController, controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add details'));
      await tester.pumpAndSettle();

      final currencyFieldFinder = find.byType(TextFormField).at(4);
      await tester.enterText(currencyFieldFinder, 'USD');
      // Force a rebuild (didChangeDependencies re-runs on every dependency
      // change, not just the first) by rebuilding the widget tree.
      await tester.pumpWidget(_harness(authController, controller: controller));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(currencyFieldFinder);
      expect(field.controller!.text, 'USD');
    },
  );

  testWidgets(
    "editing an existing log's stored currency is never overwritten by a "
    'different preferred_currency',
    (tester) async {
      final authController = _controllerWithPreferredCurrency('EUR');
      final controller = BeerLogController(
        repository: FakeLogRepository(),
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );
      final existing = _existingLog(currency: 'USD');

      await tester.pumpWidget(
        _harness(authController, controller: controller, existing: existing),
      );
      await tester.pumpAndSettle();

      // Editing an existing log with details already set auto-expands, no
      // "Add details" tap needed.
      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).at(4),
      );
      expect(field.controller!.text, 'USD');
    },
  );

  testWidgets(
    'an existing log with no stored currency is still never seeded from '
    'preferred_currency (edits never seed, only brand-new logs do)',
    (tester) async {
      final authController = _controllerWithPreferredCurrency('EUR');
      final controller = BeerLogController(
        repository: FakeLogRepository(),
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );
      // No currency, but a review so the form still auto-expands details.
      final existing = BeerLog(
        id: 'log-1',
        userId: 'user-1',
        beerId: 'beer-1',
        consumedAt: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        review: 'Great beer',
      );

      await tester.pumpWidget(
        _harness(authController, controller: controller, existing: existing),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).at(4),
      );
      expect(field.controller!.text, isEmpty);
    },
  );
}
