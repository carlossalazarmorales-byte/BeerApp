import 'package:flutter/widgets.dart';

import 'locale_controller.dart';

/// Exposes the app-wide [LocaleController] via `LocaleScope.of(context)`.
/// Kept as its own small [InheritedNotifier], mirroring
/// `core/onboarding/age_gate_scope.dart` -- the language override is a
/// local-device concern independent of any Supabase session.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    required LocaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'No LocaleScope found in context');
    return scope!.notifier!;
  }
}
