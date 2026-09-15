import 'dart:async';

import 'package:beerapp/features/auth/data/google_auth_client.dart';
import 'package:beerapp/features/auth/data/supabase_auth_repository.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [SupabaseClient] can be constructed standalone (no network call, no
/// Supabase.initialize()) — used as a placeholder wherever a test needs one
/// but never actually reaches it (signInWithGoogle() throws before touching
/// the client).
SupabaseClient _placeholderClient() =>
    SupabaseClient('https://example.supabase.co', 'placeholder-key');

class _ThrowingGoogleAuthClient implements GoogleAuthClient {
  _ThrowingGoogleAuthClient(this.error);

  final Object error;

  @override
  Future<GoogleAuthTokens> signIn() => Future<GoogleAuthTokens>.error(error);
}

void main() {
  test('mapAuthStateStream forwards stream errors unmodified -- it must not '
      'swallow them, since AuthController is the one place that is supposed '
      'to handle them via its own onError', () async {
    final source = StreamController<AuthState>();
    final events = SupabaseAuthRepository.mapAuthStateStream(source.stream);

    Object? receivedError;
    events.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        receivedError = error;
      },
    );

    final injectedError = Exception('offline token refresh failed');
    source.addError(injectedError);
    await pumpEventQueue();

    expect(receivedError, same(injectedError));

    await source.close();
  });

  test(
    'mapUpdatePasswordError maps the structured same_password error code '
    '(not string matching on the message) to AuthFailureCode.samePassword',
    () {
      const error = AuthException(
        'New password should be different from the old password.',
        code: 'same_password',
      );

      expect(
        SupabaseAuthRepository.mapUpdatePasswordError(error),
        AuthFailureCode.samePassword,
      );
    },
  );

  test('mapUpdatePasswordError falls back to the existing generic weakPassword '
      'code for any other error, coded or not', () {
    const codedDifferently = AuthException(
      'Password should be at least 6 characters.',
      code: 'weak_password',
    );
    const uncoded = AuthException('Some other failure');

    expect(
      SupabaseAuthRepository.mapUpdatePasswordError(codedDifferently),
      AuthFailureCode.weakPassword,
    );
    expect(
      SupabaseAuthRepository.mapUpdatePasswordError(uncoded),
      AuthFailureCode.weakPassword,
    );
  });

  group('signInWithGoogle()', () {
    test('throws providerNotConfigured when Google is not configured, without '
        'needing real Google credentials', () async {
      final repository = SupabaseAuthRepository(
        _placeholderClient(),
        googleAuthClient: const UnconfiguredGoogleAuthClient(),
      );

      await expectLater(
        repository.signInWithGoogle,
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.providerNotConfigured,
          ),
        ),
      );
    });

    test('propagates a cancelled AuthFailure from the Google auth client '
        'unchanged -- the canceled-picker scenario', () async {
      final repository = SupabaseAuthRepository(
        _placeholderClient(),
        googleAuthClient: _ThrowingGoogleAuthClient(
          const AuthFailure(AuthFailureCode.cancelled),
        ),
      );

      await expectLater(
        repository.signInWithGoogle,
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.cancelled,
          ),
        ),
      );
    });
  });

  group('GoogleSignInAuthClient.mapGoogleSignInError', () {
    test('maps the canceled code to AuthFailureCode.cancelled', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'user canceled',
      );

      expect(
        GoogleSignInAuthClient.mapGoogleSignInError(error),
        AuthFailureCode.cancelled,
      );
    });

    test('maps any other code to AuthFailureCode.unknown', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'something else went wrong',
      );

      expect(
        GoogleSignInAuthClient.mapGoogleSignInError(error),
        AuthFailureCode.unknown,
      );
    });

    test('maps canceled the same way regardless of which step in the '
        'authenticate/authorize sequence raised it -- signIn() wraps '
        'authenticate(), authorizationForScopes(), and authorizeScopes() in '
        'one try/catch, all funneled through this single mapping function', () {
      const fromAuthorizeScopes = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'user canceled the authorization prompt',
      );

      expect(
        GoogleSignInAuthClient.mapGoogleSignInError(fromAuthorizeScopes),
        AuthFailureCode.cancelled,
      );
    });
  });

  group('GoogleSignInAuthClient.requireTokens', () {
    test('returns tokens when both are present', () {
      final tokens = GoogleSignInAuthClient.requireTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
      );

      expect(tokens.idToken, 'id-token');
      expect(tokens.accessToken, 'access-token');
    });

    test('throws AuthFailure(unknown) when the ID token is missing', () {
      expect(
        () => GoogleSignInAuthClient.requireTokens(
          idToken: null,
          accessToken: 'access-token',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.unknown,
          ),
        ),
      );
    });

    test('throws AuthFailure(unknown) when the access token is missing', () {
      expect(
        () => GoogleSignInAuthClient.requireTokens(
          idToken: 'id-token',
          accessToken: null,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.unknown,
          ),
        ),
      );
    });

    test('throws AuthFailure(unknown) when either token is empty', () {
      expect(
        () => GoogleSignInAuthClient.requireTokens(
          idToken: '',
          accessToken: 'access-token',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(
        () => GoogleSignInAuthClient.requireTokens(
          idToken: 'id-token',
          accessToken: '',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });
  });
}
