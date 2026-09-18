import '../../../core/network/api_client.dart';
import '../domain/account_repository.dart';

/// `AccountRepository` backed by FastAPI's `DELETE /account`. No bespoke
/// error mapping is needed -- `ApiClient`'s existing typed `ApiException`
/// hierarchy (e.g. `ServiceUnavailableApiException` for a 503) is enough
/// granularity for the Settings screen's generic failure message; there is
/// no domain-specific failure mode analogous to `usernameTaken` here.
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._client);

  final ApiClient _client;

  @override
  Future<void> deleteAccount() => _client.deleteJson('/account');
}
