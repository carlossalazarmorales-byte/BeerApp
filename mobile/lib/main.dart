import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/config/env.dart';
import 'core/onboarding/age_gate_controller.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/data/supabase_profile_repository.dart';
import 'features/auth/presentation/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.validate();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  final authRepository = SupabaseAuthRepository(Supabase.instance.client);
  final profileRepository = SupabaseProfileRepository(Supabase.instance.client);
  final authController = AuthController(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
  final ageGateController = AgeGateController();
  final router = createRouter(
    authRepository: authRepository,
    profileRepository: profileRepository,
    authController: authController,
    ageGateController: ageGateController,
  );

  runApp(
    BeerApp(
      router: router,
      authController: authController,
      ageGateController: ageGateController,
    ),
  );
}
