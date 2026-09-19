import '../../../core/network/api_client.dart';
import '../../catalog/domain/models/paged_result.dart';
import '../domain/contribution_repository.dart';
import '../domain/models/contribution_input.dart';
import '../domain/models/contribution_summary.dart';
import '../domain/models/duplicate_candidates.dart';

/// `ContributionRepository` backed by the FastAPI contribution endpoints.
/// Never reads or writes the contribution tables (or any catalog table) via
/// Supabase/PostgREST -- `ApiClient` is the only path in, matching the rest
/// of the catalog/personal-data access model (docs/ARCHITECTURE.md).
class ApiContributionRepository implements ContributionRepository {
  ApiContributionRepository(this._client);

  final ApiClient _client;

  @override
  Future<PagedResult<ContributionSummary>> getHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _client.getJson(
      '/contributions',
      query: {'page': '$page', 'page_size': '$pageSize'},
    ) as Map<String, dynamic>;
    return PagedResult.fromJson(json, ContributionSummary.fromJson);
  }

  @override
  Future<ContributionSummary> submitBeer(BeerContributionInput input) async {
    final json = await _client.postJson(
      '/beer-contributions',
      body: input.toJson(),
    ) as Map<String, dynamic>;
    return ContributionSummary.fromBeerSubmission(json);
  }

  @override
  Future<ContributionSummary> submitBrewery(
    BreweryContributionInput input,
  ) async {
    final json = await _client.postJson(
      '/brewery-contributions',
      body: input.toJson(),
    ) as Map<String, dynamic>;
    return ContributionSummary.fromBrewerySubmission(json);
  }

  @override
  Future<BeerDuplicateCandidates> checkBeerDuplicates(
    BeerContributionInput input,
  ) async {
    final json = await _client.getJson(
      '/beer-contributions/duplicate-candidates',
      query: input.toDuplicateCheckQuery(),
    ) as Map<String, dynamic>;
    return BeerDuplicateCandidates.fromJson(json);
  }

  @override
  Future<BreweryDuplicateCandidates> checkBreweryDuplicates(
    BreweryContributionInput input,
  ) async {
    final json = await _client.getJson(
      '/brewery-contributions/duplicate-candidates',
      query: input.toDuplicateCheckQuery(),
    ) as Map<String, dynamic>;
    return BreweryDuplicateCandidates.fromJson(json);
  }
}
