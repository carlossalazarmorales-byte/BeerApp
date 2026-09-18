import 'package:beerapp/features/auth/data/supabase_profile_repository.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapUsernameWriteError', () {
    test('maps 23505 (unique violation) to usernameTaken', () {
      const error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );

      expect(
        SupabaseProfileRepository.mapUsernameWriteError(error),
        ProfileFailureCode.usernameTaken,
      );
    });

    test('maps 23514 (check violation) to invalidUsername', () {
      const error = PostgrestException(
        message: 'new row violates check constraint',
        code: '23514',
      );

      expect(
        SupabaseProfileRepository.mapUsernameWriteError(error),
        ProfileFailureCode.invalidUsername,
      );
    });

    test('falls back to network for any other error, coded or not', () {
      const coded = PostgrestException(message: 'timeout', code: '57014');
      const uncoded = PostgrestException(message: 'connection reset');

      expect(
        SupabaseProfileRepository.mapUsernameWriteError(coded),
        ProfileFailureCode.network,
      );
      expect(
        SupabaseProfileRepository.mapUsernameWriteError(uncoded),
        ProfileFailureCode.network,
      );
    });
  });

  group('mapPreferredCurrencyWriteError', () {
    test('maps 23514 (check violation) to invalidCurrency', () {
      const error = PostgrestException(
        message:
            'new row violates check constraint '
            '"profiles_preferred_currency_format"',
        code: '23514',
      );

      expect(
        SupabaseProfileRepository.mapPreferredCurrencyWriteError(error),
        ProfileFailureCode.invalidCurrency,
      );
    });

    test('falls back to network for any other error, coded or not', () {
      const coded = PostgrestException(message: 'timeout', code: '57014');
      const uncoded = PostgrestException(message: 'connection reset');

      expect(
        SupabaseProfileRepository.mapPreferredCurrencyWriteError(coded),
        ProfileFailureCode.network,
      );
      expect(
        SupabaseProfileRepository.mapPreferredCurrencyWriteError(uncoded),
        ProfileFailureCode.network,
      );
    });

    test('never maps to usernameTaken/invalidUsername -- distinct failure '
        'domain from username writes', () {
      const error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );

      expect(
        SupabaseProfileRepository.mapPreferredCurrencyWriteError(error),
        isNot(ProfileFailureCode.usernameTaken),
      );
    });
  });
}
