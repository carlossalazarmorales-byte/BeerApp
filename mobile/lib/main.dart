import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/auth/auth_deep_link_handler.dart';
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
    // Automatic deep-link session detection is disabled here and handled
    // explicitly by AuthDeepLinkHandler below instead — see that file's
    // doc comment for why (a documented upstream race can otherwise miss
    // a cold-start password-recovery link entirely).
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
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

  // Constructed only now that AuthController's onAuthStateChange listener
  // (above) already exists, so any passwordRecovery event this triggers
  // is guaranteed to be observed.
  AuthDeepLinkHandler();

  runApp(
    BeerApp(
      router: router,
      authController: authController,
      ageGateController: ageGateController,
    ),
  );
}
