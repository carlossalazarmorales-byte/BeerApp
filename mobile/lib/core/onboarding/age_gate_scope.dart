import 'package:flutter/widgets.dart';

import 'age_gate_controller.dart';

/// Exposes the app-wide [AgeGateController] via `AgeGateScope.of(context)`.
/// Kept as its own small [InheritedNotifier] rather than merged into
/// [AuthScope] — the age gate is a local-device concern independent of any
/// Supabase session.
class AgeGateScope extends InheritedNotifier<AgeGateController> {
  const AgeGateScope({
    required AgeGateController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AgeGateController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AgeGateScope>();
    assert(scope != null, 'No AgeGateScope found in context');
    return scope!.notifier!;
  }
}
