import 'package:flutter/material.dart';

import '../../design_system/components/states/loading_state.dart';

/// Shown only while the age-gate flag and/or the persisted Supabase session
/// are still resolving — the router redirects away as soon as both are
/// known, so this is never a real destination a user lingers on.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: LoadingState());
  }
}
