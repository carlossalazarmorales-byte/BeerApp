import 'dart:async';

import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/auth_repository.dart';

/// In-memory [AuthRepository] fake — lets tests drive [AuthController] and
/// the router's redirect logic without a live Supabase project.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser}) : _currentUser = initialUser;

  AppUser? _currentUser;
  final _controller = StreamController<AuthEvent>.broadcast();

  /// Set by a test to make the next sign-in/sign-up call throw.
  Object? errorToThrow;

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
    _currentUser = null;
    _controller.add(AuthEvent.signedOut);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signInWithGoogle() async {
    if (errorToThrow != null) throw errorToThrow!;
    emitSignedIn('fake-google-user-id');
  }

  void emitSignedIn(String userId) {
    _currentUser = AppUser(id: userId);
    _controller.add(AuthEvent.signedIn);
  }

  void emitPasswordRecovery(String userId) {
    _currentUser = AppUser(id: userId);
    _controller.add(AuthEvent.passwordRecovery);
  }

  void dispose() => unawaited(_controller.close());
}
