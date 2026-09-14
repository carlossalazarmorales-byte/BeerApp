import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/env.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  AppUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : AppUser(id: user.id);
  }

  @override
  Stream<AuthEvent> get events => _client.auth.onAuthStateChange
      .map(_mapAuthChangeEvent)
      .where((event) => event != null)
      .cast<AuthEvent>();

  AuthEvent? _mapAuthChangeEvent(supabase.AuthState state) {
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
    } on supabase.AuthException catch (_) {
      throw const AuthFailure(AuthFailureCode.weakPassword);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    // Implemented in execution-order Step F, once Google Cloud OAuth
    // credentials are configured (see docs/DECISIONS.md). A controlled
    // AuthFailure rather than UnimplementedError so the UI can show a
    // clear "not available yet" message instead of a generic error.
    throw const AuthFailure(AuthFailureCode.providerNotConfigured);
  }
}
