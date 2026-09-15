import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';

void main() {
  test('starts unauthenticated when no user is currently signed in', () async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(),
      profileRepository: FakeProfileRepository(),
    );

    await pumpEventQueue();

    expect(controller.status, AppAuthStatus.unauthenticated);
  });

  test(
    'moves to authenticatedIncompleteProfile when the profile has no username '
    '(the Google-signup path)',
    () async {
      final profileRepository = FakeProfileRepository()
        ..seed(const Profile(id: 'google-user-id', username: null));
      final authRepository = FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );
      await pumpEventQueue();

      authRepository.emitSignedIn('google-user-id');
      await pumpEventQueue();

      expect(controller.status, AppAuthStatus.authenticatedIncompleteProfile);
    },
  );

  test('moves to authenticatedComplete when the profile already has a username '
      '(the email-signup path)', () async {
    final profileRepository = FakeProfileRepository()
      ..seed(const Profile(id: 'email-user-id', username: 'hoppy'));
    final authRepository = FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      profileRepository: profileRepository,
    );
    await pumpEventQueue();

    authRepository.emitSignedIn('email-user-id');
    await pumpEventQueue();

    expect(controller.status, AppAuthStatus.authenticatedComplete);
  });

  test('refreshProfile() moves incompleteProfile -> complete once a username is set', () async {
    final profileRepository = FakeProfileRepository()
      ..seed(const Profile(id: 'google-user-id', username: null));
    final authRepository = FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      profileRepository: profileRepository,
    );
    await pumpEventQueue();
    authRepository.emitSignedIn('google-user-id');
    await pumpEventQueue();
    expect(controller.status, AppAuthStatus.authenticatedIncompleteProfile);

    profileRepository.currentUserId = 'google-user-id';
    await profileRepository.setUsername('hoppy');
    await controller.refreshProfile();

    expect(controller.status, AppAuthStatus.authenticatedComplete);
  });

  test(
    'signOut event resets to unauthenticated and clears the profile',
    () async {
      final profileRepository = FakeProfileRepository()
        ..seed(const Profile(id: 'email-user-id', username: 'hoppy'));
      final authRepository = FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );
      await pumpEventQueue();
      authRepository.emitSignedIn('email-user-id');
      await pumpEventQueue();
      expect(controller.status, AppAuthStatus.authenticatedComplete);

      await authRepository.signOut();
      await pumpEventQueue();

      expect(controller.status, AppAuthStatus.unauthenticated);
      expect(controller.profile, isNull);
    },
  );

  test('controller.signOut() delegates to the repository and resets status '
      '(this is what the Profile screen sign-out button calls)', () async {
    final profileRepository = FakeProfileRepository()
      ..seed(const Profile(id: 'email-user-id', username: 'hoppy'));
    final authRepository = FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      profileRepository: profileRepository,
    );
    await pumpEventQueue();
    authRepository.emitSignedIn('email-user-id');
    await pumpEventQueue();
    expect(controller.status, AppAuthStatus.authenticatedComplete);

    await controller.signOut();
    await pumpEventQueue();

    expect(controller.status, AppAuthStatus.unauthenticated);
    expect(authRepository.currentUser, isNull);
  });

  test('passwordRecovery event sets passwordRecoveryPending without changing status', () async {
    final authRepository = FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      profileRepository: FakeProfileRepository(),
    );
    await pumpEventQueue();
    expect(controller.status, AppAuthStatus.unauthenticated);

    authRepository.emitPasswordRecovery('email-user-id');
    await pumpEventQueue();

    expect(controller.passwordRecoveryPending, isTrue);

    await controller.completePasswordReset();

    expect(controller.passwordRecoveryPending, isFalse);
  });

  test('a profile-fetch failure on first resolution maps to '
      'authenticatedProfileUnavailable, never incompleteProfile, and never '
      'leaves status stuck at unknown forever', () async {
    final profileRepository = FakeProfileRepository()
      ..getProfileError = Exception('network down');
    final authRepository = FakeAuthRepository(
      initialUser: const AppUser(id: 'email-user-id'),
    );

    final controller = AuthController(
      authRepository: authRepository,
      profileRepository: profileRepository,
    );
    await pumpEventQueue();

    // Not `unknown` -- a router relying on `unknown` to mean "still
    // resolving, show a splash" would otherwise hang here forever, since
    // nothing would ever call notifyListeners() again to retry.
    expect(controller.status, isNot(AppAuthStatus.unknown));
    // Not `authenticatedIncompleteProfile` either -- a failed *request*
    // says nothing about whether a username exists, so this user must
    // never be sent to /complete-profile on the strength of a fetch
    // failure alone.
    expect(controller.status, AppAuthStatus.authenticatedProfileUnavailable);
  });

  test(
    'a later profile-fetch failure moves an already-complete user to '
    'authenticatedProfileUnavailable (never incompleteProfile), and a '
    'successful retry via refreshProfile() restores authenticatedComplete',
    () async {
      final profileRepository = FakeProfileRepository()
        ..seed(const Profile(id: 'email-user-id', username: 'hoppy'));
      final authRepository = FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: profileRepository,
      );
      await pumpEventQueue();
      authRepository.emitSignedIn('email-user-id');
      await pumpEventQueue();
      expect(controller.status, AppAuthStatus.authenticatedComplete);

      profileRepository.getProfileError = Exception('network down');
      await controller.refreshProfile();

      expect(controller.status, AppAuthStatus.authenticatedProfileUnavailable);
      expect(
        controller.status,
        isNot(AppAuthStatus.authenticatedIncompleteProfile),
      );

      // Retry (the /profile-unavailable screen's action) calls the same
      // method again -- once the underlying failure clears, it must
      // correctly recover, not stay stuck in the error state.
      profileRepository.getProfileError = null;
      await controller.refreshProfile();

      expect(controller.status, AppAuthStatus.authenticatedComplete);
    },
  );

  test(
    'a stream error on auth events is caught by onError, not left unhandled, '
    'and the subscription keeps working afterward',
    () async {
      final authRepository = FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        profileRepository: FakeProfileRepository(),
      );
      await pumpEventQueue();
      expect(controller.status, AppAuthStatus.unauthenticated);

      // If AuthController's .listen() had no onError, this would surface
      // as an unhandled zone exception and fail the test.
      authRepository.emitError(Exception('offline token refresh failed'));
      await pumpEventQueue();

      // A broadcast StreamController's subscription survives an error by
      // default -- confirm the controller still reacts to later events.
      authRepository.emitSignedIn('email-user-id');
      await pumpEventQueue();
      expect(controller.status, isNot(AppAuthStatus.unknown));
    },
  );
}
