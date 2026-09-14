import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

enum AppAuthStatus {
  /// Initial state, while a persisted session is still being resolved.
  unknown,
  unauthenticated,

  /// Signed in, but `profiles.username` is null — the router forces
  /// `/complete-profile` and nothing else until this resolves.
  authenticatedIncompleteProfile,
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
    _subscription = _authRepository.events.listen(_onAuthEvent);
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
    final profile = await _profileRepository.getProfile(userId);
    _profile = profile;
    _status = (profile?.isComplete ?? false)
        ? AppAuthStatus.authenticatedComplete
        : AppAuthStatus.authenticatedIncompleteProfile;
  }

  /// Called by `/complete-profile` right after a successful username save.
  Future<void> refreshProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) return;
    await _refreshProfileStatus(user.id);
    notifyListeners();
  }

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
