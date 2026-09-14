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
}
