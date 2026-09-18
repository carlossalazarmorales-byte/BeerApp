import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/env.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import 'google_auth_client.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {required this._googleAuthClient});

  final supabase.SupabaseClient _client;
  final GoogleAuthClient _googleAuthClient;

  @override
  AppUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : AppUser(id: user.id, email: user.email);
  }

  @override
  Stream<AuthEvent> get events =>
      mapAuthStateStream(_client.auth.onAuthStateChange);

  /// The map/filter transformation applied to the real `onAuthStateChange`
  /// stream, factored out over an arbitrary input stream so a test can feed
  /// it a stream error without needing a live Supabase client.
  ///
  /// Deliberately does NOT intercept stream errors (no `handleError`) —
  /// current Supabase guidance requires an `onError` handler on
  /// `onAuthStateChange` (network errors, e.g. an offline token refresh,
  /// arrive as stream errors, not events), but that handler belongs solely
  /// at the actual `.listen()` call in [AuthController]. A `handleError`
  /// here that doesn't rethrow would silently consume the error before
  /// that listener ever saw it, and logging it at both layers would be
  /// noise for one event. `map`/`where`/`cast` forward stream errors
  /// through unchanged by default, so nothing extra is needed for that.
  @visibleForTesting
  static Stream<AuthEvent> mapAuthStateStream(
    Stream<supabase.AuthState> source,
  ) {
    return source
        .map(_mapAuthChangeEvent)
        .where((event) => event != null)
        .cast<AuthEvent>();
  }

  static AuthEvent? _mapAuthChangeEvent(supabase.AuthState state) {
    switch (state.event) {
      case supabase.AuthChangeEvent.signedIn:
        return AuthEvent.signedIn;
      case supabase.AuthChangeEvent.signedOut:
        return AuthEvent.signedOut;
      case supabase.AuthChangeEvent.passwordRecovery:
        return AuthEvent.passwordRecovery;
      default:
        return null;
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
        emailRedirectTo: Env.authRedirectUrl,
      );
    } on supabase.AuthException catch (_) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on supabase.AuthException catch (_) {
      // Never distinguish "no such user" from "wrong password" — avoids
      // account enumeration.
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: Env.authRedirectUrl,
      );
    } on supabase.AuthException catch (_) {
      throw const AuthFailure(AuthFailureCode.network);
    }
    // Deliberately no other branch: Supabase itself does not reveal whether
    // the email exists, and neither does this method.
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } on supabase.AuthException catch (error) {
      throw AuthFailure(mapUpdatePasswordError(error));
    }
  }

  /// Structured error code, not string matching on `error.message` — the
  /// message text isn't a stable contract, the code is. Factored out as
  /// its own testable function so the mapping (specifically: does
  /// `same_password` really produce [AuthFailureCode.samePassword], and
  /// does everything else still fall back to the existing generic code)
  /// can be verified without a live Supabase call.
  @visibleForTesting
  static AuthFailureCode mapUpdatePasswordError(supabase.AuthException error) {
    return error.code == 'same_password'
        ? AuthFailureCode.samePassword
        : AuthFailureCode.weakPassword;
  }

  @override
  Future<void> signInWithGoogle() async {
    final tokens = await _googleAuthClient.signIn();
    try {
      await _client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
    } on supabase.AuthException catch (_) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }
}
