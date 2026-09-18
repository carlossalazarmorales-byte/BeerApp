import 'dart:async';

import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/auth_repository.dart';

/// In-memory [AuthRepository] fake — lets tests drive [AuthController] and
/// the router's redirect logic without a live Supabase project.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser}) : _currentUser = initialUser;

  AppUser? _currentUser;
  final _controller = StreamController<AuthEvent>.broadcast();

  /// Set by a test to make the next sign-in/sign-up/sign-out call throw.
  Object? errorToThrow;

  /// Set by a test to make the next [sendPasswordResetEmail] call throw —
  /// separate from [errorToThrow] so a test can exercise a failing
  /// "change password" trigger without also making sign-out fail.
  Object? passwordResetEmailErrorToThrow;

  /// Every email [sendPasswordResetEmail] was called with, in order —
  /// lets a test assert Settings' "Change password" row used the signed-in
  /// user's own email with no navigation/re-entry required.
  final List<String> passwordResetEmailCalls = [];

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AuthEvent> get events => _controller.stream;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    emitSignedIn('fake-user-id');
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    // Deliberately does not sign the user in — matches Supabase's real
    // behavior of requiring email confirmation first.
  }

  @override
  Future<void> signOut() async {
    // Mirrors the real gotrue SDK's verified _signOut behavior (see
    // docs/DECISIONS.md, Phase 12): local session state clears and
    // `signedOut` fires synchronously, unconditionally, *before* any
    // network-revoke failure is thrown — never the other way around. This
    // is what the Settings delete-account try/catch-around-signOut()
    // sequencing test relies on.
    _currentUser = null;
    _controller.add(AuthEvent.signedOut);
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    passwordResetEmailCalls.add(email);
    if (passwordResetEmailErrorToThrow != null) {
      throw passwordResetEmailErrorToThrow!;
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> signInWithGoogle() async {
    if (errorToThrow != null) throw errorToThrow!;
    emitSignedIn('fake-google-user-id');
  }

  void emitSignedIn(String userId, {String? email}) {
    _currentUser = AppUser(id: userId, email: email);
    _controller.add(AuthEvent.signedIn);
  }

  void emitPasswordRecovery(String userId) {
    _currentUser = AppUser(id: userId);
    _controller.add(AuthEvent.passwordRecovery);
  }

  /// Simulates a stream error (e.g. a failed token refresh while offline) —
  /// the real `onAuthStateChange` can emit these; this fake otherwise never
  /// does, so tests need an explicit way to trigger it.
  void emitError(Object error) => _controller.addError(error);

  void dispose() => unawaited(_controller.close());
}
