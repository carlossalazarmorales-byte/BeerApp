import 'package:beerapp/app/startup_failure_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required StartupFailureKind kind,
  VoidCallback? onRetry,
  String? diagnostics,
  bool? showDiagnostics,
  Locale locale = const Locale('en'),
}) async {
  // MaterialApp resolves its locale from the platform's locale LIST.
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    StartupFailureApp(
      kind: kind,
      onRetry: onRetry,
      diagnostics: diagnostics,
      showDiagnostics: showDiagnostics,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('configuration failure', () {
    testWidgets(
      'shows the localized message and NO retry (it cannot succeed)',
      (tester) async {
        await _pump(
          tester,
          kind: StartupFailureKind.configuration,
          onRetry: () {},
        );

        expect(find.text("BeerApp isn't set up correctly"), findsOneWidget);
        expect(
          find.textContaining('missing required configuration'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets('is localized in Spanish', (tester) async {
      await _pump(
        tester,
        kind: StartupFailureKind.configuration,
        locale: const Locale('es'),
      );

      expect(
        find.text('BeerApp no está configurada correctamente'),
        findsOneWidget,
      );
      expect(find.textContaining('configuración necesaria'), findsOneWidget);
    });
  });

  group('initialization failure', () {
    testWidgets('shows the localized message and a working Retry', (
      tester,
    ) async {
      var retried = 0;
      await _pump(
        tester,
        kind: StartupFailureKind.initialization,
        onRetry: () => retried++,
      );

      expect(find.text("BeerApp couldn't start"), findsOneWidget);
      expect(find.textContaining('Something went wrong'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('is localized in Spanish, including the Retry label', (
      tester,
    ) async {
      await _pump(
        tester,
        kind: StartupFailureKind.initialization,
        onRetry: () {},
        locale: const Locale('es'),
      );

      expect(find.text('BeerApp no pudo iniciarse'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('offers no Retry when no retry callback was provided', (
      tester,
    ) async {
      await _pump(tester, kind: StartupFailureKind.initialization);

      expect(find.text('Retry'), findsNothing);
    });
  });

  group('diagnostics are for developers only', () {
    testWidgets('are hidden when disabled (release)', (tester) async {
      await _pump(
        tester,
        kind: StartupFailureKind.configuration,
        diagnostics: 'EnvConfigException: apiBaseUrlIsLocal',
        showDiagnostics: false,
      );

      expect(find.byKey(const ValueKey('startup-diagnostics')), findsNothing);
      expect(find.textContaining('apiBaseUrlIsLocal'), findsNothing);
    });

    testWidgets('are shown when enabled (debug)', (tester) async {
      await _pump(
        tester,
        kind: StartupFailureKind.configuration,
        diagnostics: 'EnvConfigException: apiBaseUrlIsLocal',
        showDiagnostics: true,
      );

      expect(find.byKey(const ValueKey('startup-diagnostics')), findsOneWidget);
      expect(find.textContaining('apiBaseUrlIsLocal'), findsOneWidget);
    });

    testWidgets('default to the build mode (debug in tests)', (tester) async {
      await _pump(
        tester,
        kind: StartupFailureKind.initialization,
        diagnostics: 'StateError',
      );

      expect(find.textContaining('StateError'), findsOneWidget);
    });

    testWidgets('the user-facing text never contains a stack trace or URL', (
      tester,
    ) async {
      await _pump(
        tester,
        kind: StartupFailureKind.initialization,
        onRetry: () {},
        showDiagnostics: false,
      );

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(texts, isNot(contains('http')));
      expect(texts, isNot(contains('#0')));
      expect(texts, isNot(contains('Exception')));
    });
  });

  testWidgets('the title is exposed to assistive technology as a header', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, kind: StartupFailureKind.initialization);

    expect(
      tester.getSemantics(find.text("BeerApp couldn't start")),
      matchesSemantics(label: "BeerApp couldn't start", isHeader: true),
    );
    handle.dispose();
  });
}
