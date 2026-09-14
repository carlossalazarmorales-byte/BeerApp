import 'package:beerapp/features/auth/data/supabase_auth_repository.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
}
