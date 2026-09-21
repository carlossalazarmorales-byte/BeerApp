import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_deep_link_handler.dart';
import '../core/config/env.dart';
import '../core/locale/locale_controller.dart';
import '../core/network/api_client.dart';
import '../core/network/supabase_access_token_provider.dart';
import '../core/network/supabase_session_source.dart';
import '../core/onboarding/age_gate_controller.dart';
import '../features/achievements/data/api_achievements_repository.dart';
import '../features/auth/data/api_account_repository.dart';
import '../features/auth/data/google_auth_client.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/data/supabase_profile_repository.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/catalog/data/api_catalog_repository.dart';
import '../features/collection/data/api_collection_repository.dart';
import '../features/contributions/data/api_contribution_repository.dart';
import '../features/logging/data/api_log_repository.dart';
import '../features/map/data/api_map_repository.dart';
import '../features/statistics/data/api_statistics_repository.dart';
import '../shared/collection_refresh_signal.dart';
import 'app.dart';
import 'router.dart';

/// The app's composition root: validates the build configuration, initializes
/// Supabase and the Google client, and wires every repository and controller.
/// Returns the root widget; it does not call `runApp` itself, so [launchApp]
/// can catch a failure anywhere in here and show a localized startup-failure
/// screen instead of crashing.
///
/// Throws `EnvConfigException` (from `Env.validate`) for an unusable
/// configuration, before anything is initialized.
Future<Widget> buildApp() async {
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

  final GoogleAuthClient googleAuthClient;
  if (Env.googleServerClientId.isEmpty) {
    googleAuthClient = const UnconfiguredGoogleAuthClient();
  } else {
    await GoogleSignIn.instance.initialize(
      serverClientId: Env.googleServerClientId,
    );
    googleAuthClient = GoogleSignInAuthClient(GoogleSignIn.instance);
  }

  final authRepository = SupabaseAuthRepository(
    Supabase.instance.client,
    googleAuthClient: googleAuthClient,
  );
  final profileRepository = SupabaseProfileRepository(Supabase.instance.client);
  final authController = AuthController(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
  final ageGateController = AgeGateController();
  final localeController = LocaleController();

  // Owned for the process's entire lifetime, the same lifecycle as
  // Supabase.instance.client -- intentionally never closed, since a Flutter
  // mobile app runs no cleanup code at process teardown.
  final httpClient = http.Client();
  final accessTokenProvider = SupabaseAccessTokenProvider(
    SupabaseSessionSource(Supabase.instance.client),
  );
  final apiClient = ApiClient(
    httpClient: httpClient,
    baseUrl: Env.apiBaseUrl,
    accessTokenProvider: accessTokenProvider,
  );
  final catalogRepository = ApiCatalogRepository(apiClient);
  final logRepository = ApiLogRepository(apiClient);
  final collectionRepository = ApiCollectionRepository(apiClient);
  final mapRepository = ApiMapRepository(apiClient);
  final statisticsRepository = ApiStatisticsRepository(apiClient);
  final achievementsRepository = ApiAchievementsRepository(apiClient);
  final accountRepository = ApiAccountRepository(apiClient);
  final contributionRepository = ApiContributionRepository(apiClient);
  final collectionRefreshSignal = CollectionRefreshSignal();

  final router = createRouter(
    authRepository: authRepository,
    profileRepository: profileRepository,
    accountRepository: accountRepository,
    authController: authController,
    ageGateController: ageGateController,
    catalogRepository: catalogRepository,
    logRepository: logRepository,
    collectionRepository: collectionRepository,
    mapRepository: mapRepository,
    statisticsRepository: statisticsRepository,
    achievementsRepository: achievementsRepository,
    contributionRepository: contributionRepository,
    refreshSignal: collectionRefreshSignal,
  );

  // Constructed only now that AuthController's onAuthStateChange listener
  // (above) already exists, so any passwordRecovery event this triggers
  // is guaranteed to be observed.
  AuthDeepLinkHandler();

  return BeerApp(
    router: router,
    authController: authController,
    ageGateController: ageGateController,
    localeController: localeController,
  );
}
