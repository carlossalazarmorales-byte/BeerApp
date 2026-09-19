import '../../catalog/domain/models/paged_result.dart';
import 'models/contribution_input.dart';
import 'models/contribution_summary.dart';
import 'models/duplicate_candidates.dart';

/// Boundary between the contribution screens and the FastAPI contribution
/// endpoints. A contribution is a private, user-owned *proposal*: nothing
/// here creates or edits a catalog beer/brewery, and nothing creates a log,
/// favorite, wishlist entry or achievement.
abstract class ContributionRepository {
  /// The signed-in user's own submissions, newest first.
  Future<PagedResult<ContributionSummary>> getHistory({
    int page = 1,
    int pageSize = 20,
  });

  /// Stores the suggestion as `pending`. Throws [ConflictApiException] with
  /// code `barcode_in_catalog` or `already_submitted` for the two hard
  /// blocks, [NotFoundApiException] if a referenced catalog id no longer
  /// exists.
  Future<ContributionSummary> submitBeer(BeerContributionInput input);

  Future<ContributionSummary> submitBrewery(BreweryContributionInput input);

  Future<BeerDuplicateCandidates> checkBeerDuplicates(
    BeerContributionInput input,
  );

  Future<BreweryDuplicateCandidates> checkBreweryDuplicates(
    BreweryContributionInput input,
  );
}
