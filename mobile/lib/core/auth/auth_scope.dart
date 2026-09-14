import 'package:flutter/widgets.dart';

import '../../features/auth/presentation/auth_controller.dart';

/// Exposes the app-wide [AuthController] via `AuthScope.of(context)` —
/// a small hand-rolled [InheritedNotifier] instead of a state-management
/// package (see docs/DECISIONS.md).
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    required AuthController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found in context');
    return scope!.notifier!;
  }
}
