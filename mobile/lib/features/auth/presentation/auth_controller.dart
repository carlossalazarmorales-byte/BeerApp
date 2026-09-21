import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/debug_log.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

enum AppAuthStatus {
  /// Initial state, while a persisted session is still being resolved.
  unknown,
  unauthenticated,

  /// Signed in, but `profiles.username` is null — the router forces
  /// `/complete-profile` and nothing else until this resolves. This means
  /// the profile loaded successfully and genuinely has no username yet
  /// (an OAuth signup) — never confuse this with [authenticatedProfileUnavailable].
  authenticatedIncompleteProfile,

  /// Signed in, but the profile row could not be loaded at all (a network
  /// or Postgrest failure) — distinct from [authenticatedIncompleteProfile]
  /// on purpose: a failed *request* says nothing about whether a username
  /// exists, so it must never be treated as "needs completing". The router
  /// forces a retryable error screen instead of `/complete-profile`.
  authenticatedProfileUnavailable,
  authenticatedComplete,
}

/// The one piece of app-wide auth/profile state, exposed via [AuthScope].
/// Deliberately a hand-rolled [ChangeNotifier] rather than a state-
/// management package — see docs/DECISIONS.md.
class AuthController extends ChangeNotifier {
  // Named params stay public (`authRepository`) while the backing fields
  // stay private, so `prefer_initializing_formals` (which would require a
  // private param name, unusable by callers) doesn't apply here.
  AuthController({
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
    // ignore: prefer_initializing_formals
  }) : _authRepository = authRepository,
       // ignore: prefer_initializing_formals
       _profileRepository = profileRepository {
    _subscription = _authRepository.events.listen(
      _onAuthEvent,
      onError: (Object error, StackTrace stackTrace) {
        // Current Supabase guidance: network errors (e.g. an offline token
        // refresh) are emitted as stream errors, not events. Without this,
        // Dart rethrows them as unhandled zone exceptions. Only the error
        // itself is logged (debug builds only, sanitized), never a
        // session/token.
        DebugLog.error('auth', 'auth stream error', error);
      },
    );
    unawaited(_initialize());
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  late final StreamSubscription<AuthEvent> _subscription;

  AppAuthStatus _status = AppAuthStatus.unknown;
  AppAuthStatus get status => _status;

  Profile? _profile;
  Profile? get profile => _profile;

  /// True from a `passwordRecovery` auth event until [completePasswordReset]
  /// is called — the router checks this before its normal status-based
  /// rules so it can force `/reset-password` regardless of [status].
  bool _passwordRecoveryPending = false;
  bool get passwordRecoveryPending => _passwordRecoveryPending;

  Future<void> _initialize() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _status = AppAuthStatus.unauthenticated;
    } else {
      await _refreshProfileStatus(user.id);
    }
    notifyListeners();
  }

  Future<void> _onAuthEvent(AuthEvent event) async {
    switch (event) {
      case AuthEvent.signedIn:
        _passwordRecoveryPending = false;
        final user = _authRepository.currentUser;
        if (user != null) {
          await _refreshProfileStatus(user.id);
        }
      case AuthEvent.signedOut:
        _passwordRecoveryPending = false;
        _profile = null;
        _status = AppAuthStatus.unauthenticated;
      case AuthEvent.passwordRecovery:
        _passwordRecoveryPending = true;
    }
    notifyListeners();
  }

  Future<void> _refreshProfileStatus(String userId) async {
    try {
      final profile = await _profileRepository.getProfile(userId);
      _profile = profile;
      _status = (profile?.isComplete ?? false)
          ? AppAuthStatus.authenticatedComplete
          : AppAuthStatus.authenticatedIncompleteProfile;
    } catch (error) {
      // A real network/Postgrest call can fail transiently in a way the
      // fakes used in tests never do. Left uncaught, this would strand
      // [status] at whatever it already was -- most dangerously `unknown`
      // on first launch, which leaves the router unable to ever leave the
      // splash screen (`stillResolving` never clears).
      //
      // A failed *request* is deliberately never mapped to
      // `authenticatedIncompleteProfile` -- that status specifically means
      // "the profile loaded and has no username", which this doesn't know
      // one way or the other. `authenticatedProfileUnavailable` is its own
      // state precisely so an existing user with a set username is never
      // wrongly routed to `/complete-profile` just because a fetch failed.
      DebugLog.error('auth', 'profile fetch failed', error);
      _status = AppAuthStatus.authenticatedProfileUnavailable;
    }
  }

  /// Called by `/complete-profile` right after a successful username save,
  /// and by the `/profile-unavailable` retry action — both just need the
  /// profile re-fetched and [status] recomputed from the result.
  Future<void> refreshProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) return;
    await _refreshProfileStatus(user.id);
    notifyListeners();
  }

  /// Delegates to the repository; the resulting `signedOut` event (handled
  /// in [_onAuthEvent] above) is what actually updates [status] and
  /// notifies listeners, so callers don't need to do anything else.
  Future<void> signOut() => _authRepository.signOut();

  /// Called by `/reset-password` right after a successful password update.
  Future<void> completePasswordReset() async {
    _passwordRecoveryPending = false;
    final user = _authRepository.currentUser;
    if (user != null) {
      await _refreshProfileStatus(user.id);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
