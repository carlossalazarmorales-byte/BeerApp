import 'package:beerapp/features/auth/domain/account_repository.dart';

class FakeAccountRepository implements AccountRepository {
  /// Records how many times [deleteAccount] was called -- Settings tests
  /// assert this stays 0 when confirmation is rejected/cancelled, and
  /// exactly 1 on a successful confirmed delete.
  int deleteAccountCallCount = 0;

  Object? deleteAccountError;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    final error = deleteAccountError;
    if (error != null) throw error;
  }
}
