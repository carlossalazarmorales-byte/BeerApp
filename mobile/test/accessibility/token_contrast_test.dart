import 'dart:math' as math;

import 'package:beerapp/design_system/components/buttons/primary_button.dart';
import 'package:beerapp/design_system/components/navigation/scan_nav_button.dart';
import 'package:beerapp/design_system/tokens/app_colors.dart';
import 'package:beerapp/design_system/tokens/app_gradients.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x relative luminance / contrast ratio, computed from the design
/// tokens (so a token change re-runs the check). This is a check of the app's
/// own colour pairs against the AA thresholds -- NOT a WCAG conformance claim.
double _luminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // (foreground, background, where it is used)
  final textPairs = <(String, Color, Color)>[
    ('body text on the page', AppColors.onSurface, AppColors.surface),
    (
      'secondary text on the page',
      AppColors.onSurfaceVariant,
      AppColors.surface,
    ),
    (
      'secondary text on a card / disabled button',
      AppColors.onSurfaceVariant,
      AppColors.surfaceContainerHigh,
    ),
    (
      'placeholder text on a text field',
      AppColors.onSurfaceVariant,
      AppColors.surfaceContainerLow,
    ),
    (
      'secondary button label',
      AppColors.onSecondaryFixed,
      AppColors.secondaryContainer,
    ),
    (
      'ABV / rating badge',
      AppColors.onSecondaryFixed,
      AppColors.tertiaryContainer,
    ),
    ('selected nav label', AppColors.primary, AppColors.surface),
    (
      'selected filter chip',
      AppColors.onPrimaryContainer,
      AppColors.primaryContainer,
    ),
    ('error text', AppColors.error, AppColors.surface),
  ];

  group('text colour pairs meet WCAG AA (4.5:1)', () {
    for (final (name, foreground, background) in textPairs) {
      test(name, () {
        expect(
          contrast(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$name: ${contrast(foreground, background)}',
        );
      });
    }
  });

  group('graphics and icons meet the 3:1 non-text threshold', () {
    test('icon and chart colour (primary) on the page', () {
      expect(
        contrast(AppColors.primary, AppColors.surface),
        greaterThanOrEqualTo(3),
      );
    });
    test('wishlist icon (secondary) on the page', () {
      expect(
        contrast(AppColors.secondary, AppColors.surface),
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('PrimaryButton / ScanNavButton foreground on the amber gradient', () {
    // The gradient is drawn corner to corner, so a label can sit anywhere along
    // it. The requirement is therefore on the WORST point of the whole
    // gradient, not on its centre: sampled every 0.5% from the dark end
    // (t = 0) to the bright end (t = 1).
    final colors = AppGradients.primary.colors;
    final start = colors.first;
    final end = colors.last;
    Color at(double t) => Color.lerp(start, end, t)!;
    final samples = [for (var i = 0; i <= 200; i++) i / 200];
    final foreground = AppColors.onPrimaryGradient;

    double worst() =>
        samples.map((t) => contrast(foreground, at(t))).reduce(math.min);

    test('the gradient is still a two-stop amber gradient ending at the brand gold', () {
      expect(colors.length, 2);
      expect(end, AppColors.primaryContainer);
      expect(AppGradients.primary.begin, Alignment.topLeft);
      expect(AppGradients.primary.end, Alignment.bottomRight);
    });

    test('the foreground is an existing dark design-system token', () {
      expect(foreground, AppColors.onSurface);
    });

    test('dark endpoint passes AA', () {
      expect(contrast(foreground, at(0)), greaterThanOrEqualTo(4.5));
    });

    test('midpoint passes AA', () {
      expect(contrast(foreground, at(0.5)), greaterThanOrEqualTo(4.5));
    });

    test('bright endpoint passes AA', () {
      expect(contrast(foreground, at(1)), greaterThanOrEqualTo(4.5));
    });

    test('the WORST point across the whole gradient passes AA (>= 4.5:1)', () {
      expect(worst(), greaterThanOrEqualTo(4.5), reason: 'worst: ${worst()}');
    });

    test('and keeps headroom above the threshold', () {
      expect(worst(), greaterThan(4.8), reason: 'worst: ${worst()}');
    });

    test('the gradient is still visibly a gradient (its ends differ)', () {
      expect(contrast(start, end), greaterThan(1.8));
    });

    test('the dark end is amber, not a new hue', () {
      final hsv = HSVColor.fromColor(start);
      final gold = HSVColor.fromColor(AppColors.primaryContainer);
      expect((hsv.hue - gold.hue).abs(), lessThan(8));
    });

    testWidgets('an enabled PrimaryButton really draws that pair', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Continue',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Continue'));
      expect(text.style?.color, AppColors.onPrimaryGradient);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.add)).color,
        AppColors.onPrimaryGradient,
      );

      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.gradient != null);
      expect(decoration.gradient, AppGradients.primary);
    });

    testWidgets('a disabled PrimaryButton keeps its muted styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrimaryButton(label: 'Continue', onPressed: null),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Continue'));
      expect(text.style?.color, AppColors.onSurfaceVariant);
      final decorations = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>();
      expect(decorations.any((d) => d.gradient != null), isFalse);
      expect(
        decorations.any((d) => d.color == AppColors.surfaceContainerHigh),
        isTrue,
      );
      // The disabled pair itself is one of the AA text pairs asserted above.
    });

    testWidgets('the scan button draws the same gradient and dark icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanNavButton(
              semanticLabel: 'Add',
              icon: Icons.add,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        tester.widget<Icon>(find.byIcon(Icons.add)).color,
        AppColors.onPrimaryGradient,
      );
      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.gradient != null);
      expect(decoration.gradient, AppGradients.primary);
    });

    test(
      'the focus ring (onSurface) is visible against the whole gradient',
      () {
        // Non-text contrast threshold is 3:1.
        final ring = AppColors.onSurface;
        final lowest = samples
            .map((t) => contrast(ring, at(t)))
            .reduce(math.min);
        expect(lowest, greaterThanOrEqualTo(3));
      },
    );
  });
}
