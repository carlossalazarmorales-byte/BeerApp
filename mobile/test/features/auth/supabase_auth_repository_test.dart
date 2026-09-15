import 'dart:async';

import 'package:beerapp/features/auth/data/supabase_auth_repository.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    'signInWithGoogle() throws a controlled providerNotConfigured AuthFailure, '
    'not UnimplementedError, and needs no real credentials',
    () async {
      // A SupabaseClient can be constructed standalone (no network call,
      // no Supabase.initialize()) — these values are placeholders never
      // actually used, since signInWithGoogle() throws before touching
      // the client.
      final repository = SupabaseAuthRepository(
        SupabaseClient('https://example.supabase.co', 'placeholder-key'),
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
    },
  );

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
}
