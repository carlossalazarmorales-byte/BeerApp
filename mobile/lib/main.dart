import 'package:flutter/widgets.dart';

import 'app/build_app.dart';
import 'app/launch_app.dart';
import 'core/bootstrap/global_error_handlers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Last-resort handlers first, so an error during startup is also covered.
  installGlobalErrorHandlers();
  // Everything that can fail at startup happens inside buildApp(); launchApp
  // shows a localized failure screen instead of crashing if it does.
  await launchApp(buildApp);
}
