import 'auth_models.dart';

/// Boundary between BeerApp and Supabase Auth. Business logic (mapping
/// errors, deciding what a screen shows) lives in controllers/screens that
/// depend on this interface, never directly on `supabase_flutter`, so
/// widget tests can supply a fake instead of a live Supabase project.
abstract class AuthRepository {
  AppUser? get currentUser;

  /// Filtered, domain-level auth events — see [AuthEvent].
  Stream<AuthEvent> get events;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> updatePassword(String newPassword);

  /// Implemented in execution-order Step F, once Google Cloud OAuth
  /// credentials exist (see docs/DECISIONS.md) — not before, since it
  /// can't be meaningfully written or tested without them yet.
  Future<void> signInWithGoogle();
}
