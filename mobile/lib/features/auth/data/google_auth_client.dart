import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_models.dart';

/// The two tokens Supabase's `signInWithIdToken` needs for Google.
class GoogleAuthTokens {
  const GoogleAuthTokens({required this.idToken, required this.accessToken});

  final String idToken;
  final String accessToken;
}

/// Seam between [SupabaseAuthRepository] and the real `google_sign_in`
/// plugin singleton, so the repository is unit-testable without a live
/// Credential Manager call.
abstract class GoogleAuthClient {
  Future<GoogleAuthTokens> signIn();
}

/// Real implementation, wrapping the `google_sign_in` v7 singleton.
class GoogleSignInAuthClient implements GoogleAuthClient {
  GoogleSignInAuthClient(this._googleSignIn);

  final GoogleSignIn _googleSignIn;

  @override
  Future<GoogleAuthTokens> signIn() async {
    // authenticate(), authorizationForScopes(), and authorizeScopes() can
    // all throw GoogleSignInException (including cancellation) — one
    // mapping boundary around the whole sequence, not just the first call.
    final String? idToken;
    final String? accessToken;
    try {
      final account = await _googleSignIn.authenticate();
      idToken = account.authentication.idToken;

      // Minimal scope: 'email' is enough to obtain the access token
      // Supabase requires; no broader Google API permissions requested.
      const scopes = ['email'];
      GoogleSignInClientAuthorization? authorization = await account
          .authorizationClient
          .authorizationForScopes(scopes);
      authorization ??= await account.authorizationClient.authorizeScopes(
        scopes,
      );
      accessToken = authorization.accessToken;
    } on GoogleSignInException catch (e) {
      throw AuthFailure(mapGoogleSignInError(e));
    }

    return requireTokens(idToken: idToken, accessToken: accessToken);
  }

  /// Structured error code, not string matching — v7's Android
  /// CredentialManager-based flow can also report a real configuration
  /// error as `canceled`, indistinguishable from an actual dismissed
  /// picker; that's a plugin/platform limitation, not something mappable
  /// more precisely here. Applies uniformly regardless of which call in the
  /// authenticate/authorize sequence threw.
  @visibleForTesting
  static AuthFailureCode mapGoogleSignInError(GoogleSignInException error) {
    return error.code == GoogleSignInExceptionCode.canceled
        ? AuthFailureCode.cancelled
        : AuthFailureCode.unknown;
  }

  /// Pure validation seam, factored out so the "missing/invalid token"
  /// branch is unit-testable with plain strings — [GoogleSignInAccount] and
  /// [GoogleSignInClientAuthorization] are platform-interface types with no
  /// practical fake in a plain `flutter_test` run.
  @visibleForTesting
  static GoogleAuthTokens requireTokens({
    required String? idToken,
    required String? accessToken,
  }) {
    if (idToken == null ||
        idToken.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
    return GoogleAuthTokens(idToken: idToken, accessToken: accessToken);
  }
}

/// Used when `Env.googleServerClientId` is empty, so `main.dart` never calls
/// `GoogleSignIn.instance.initialize()` with a blank client ID.
class UnconfiguredGoogleAuthClient implements GoogleAuthClient {
  const UnconfiguredGoogleAuthClient();

  @override
  Future<GoogleAuthTokens> signIn() async {
    throw const AuthFailure(AuthFailureCode.providerNotConfigured);
  }
}
